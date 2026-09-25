extends Node2D

## Yaratıkların duvar dolanma yol ızgarası (bkz. _ready / enemy_pathing.gd).
const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")

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
@export var difficulty_ramp: float = 0.001
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
@export var max_concurrent_enemies: int = 200
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
const FULL_ENEMY_CAP_PLAYER_COUNT := 5
const ENEMY_CAP_STEP_PER_MISSING_PLAYER := 20
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
		## ÇOK OYUNCULU DÜZELTME (2026-09-24 senkron analizi): istemci maks can/kalkanı kendisi hesaplıyor, ama sonradan
		## katılan oyuncu için bu hesap ŞİMDİKİ oyun saati (Kademe 3+ zamanla artan can) ve ŞİMDİKİ oyuncu sayısıyla
		## yapılıyor - eski yaratıkların barı dolu can'da bile boş görünüyordu. Host'un gerçek değerleri + görünmez hayalet
		## durumu ayrıca gönderilir (aynı düğümden reliable RPC'ler sırayla varır).
		_rpc_client_catchup_enemy_state.rpc_id(peer_id, net_id, float(enemy.max_health), float(enemy.item_shield_max),
				enemy.get("is_ability_invisible") == true)


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

	if DEBUG_RAMP_TEST_ENABLED and _debug_ramp_elapsed < DEBUG_RAMP_TEST_SECONDS:
		_debug_ramp_elapsed += delta

	## Debug modu (kullanıcı isteği: "düşman spawnlarını aktif/kapalı" - bkz. GameManager.
	## debug_enemy_spawns_enabled notu) - bu satırdan yukarısı zaten host-authoritative kapının
	## İÇİNDE (bkz. fonksiyon başındaki "sadece host" erken dönüşü), o yüzden host kapatınca
	## herkes için gerçekten kapanmış olur.
	if GameManager.debug_enemy_spawns_enabled:
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
	var tier: int = 1 + int(_tier_time() / tier_duration)
	return clamp(tier, 1, 15)


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


## Oyuncu sayısına göre NİHAİ (Kademe 15) yaratık tavanı: 1->120, 2->140, 3->160, 4->180, 5+->200 (bkz.
## FULL_ENEMY_CAP_PLAYER_COUNT notu). Erken kademelerde bu tavan _tier_crowding_scale ile ayrıca kısılır (değişmedi).
func player_enemy_cap(players: int) -> int:
	var missing: int = maxi(0, FULL_ENEMY_CAP_PLAYER_COUNT - maxi(1, players))
	return maxi(1, max_concurrent_enemies - missing * ENEMY_CAP_STEP_PER_MISSING_PLAYER)


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
const GATE_SURVIVOR_RADIUS := 1600.0
const GATE_MAX_WAIT_MSEC := 30000
var _gate_wait_started_msec: int = 0


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
	return _spawn_tier if _spawn_tier >= time_tier else 0


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
			if not is_instance_valid(rp) or rp.get("is_dead") == true:
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
	var roster: Array = TIER_ROSTER.get(tier, [])
	if roster.is_empty():
		return
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
		var id: String = roster[randi() % roster.size()]
		var spawn_pos: Vector2
		if ambush_pos != null:
			spawn_pos = _ambush_pack_member_position(Vector2(ambush_pos), i)
		else:
			spawn_pos = _random_spawn_position(anchor_pos, false, bias_dir)
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, spawn_pos, network_id)
		if not enemy:
			continue
		enemy.set_meta("spawn_tier", tier) ## bkz. Kademe kapısı notu (_older_tier_survivor_count)
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
	var t: float = _tier_time() ## Kademe saati (boss kapısı - bkz. _tier_time)
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
	if _tier_time() >= trigger_time: ## 15. kademenin bossları ölmeden Final gelmez (bkz. _tier_time)
		_final_spawned = true
		_spawn_boss_group(FINAL_CREATURES, FINAL_TIER)


func _spawn_boss_group(ids: Array, tier: int) -> void:
	var anchor_pos = _find_any_living_player_position()
	if anchor_pos == null:
		return
	var spawned_bosses: Array = []
	for id in ids:
		var network_id: int = _next_network_enemy_id
		_next_network_enemy_id += 1
		var enemy = _spawn_creature(id, _random_spawn_position(anchor_pos, true), network_id)
		if not enemy:
			continue
		spawned_bosses.append(enemy)
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
	## Kademe boss kapısı (bkz. _tier_time): bu kademenin bossları ölene kadar Kademe saati o kademenin
	## sonunda bekler. (Final Kademe'nin bossları kapıdan sonra gelir, tutulacak bir sonraki kademe yok.)
	if BOSS_TIERS.has(tier) and not spawned_bosses.is_empty():
		_tier_bosses[tier] = spawned_bosses


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_catchup_enemy_state(network_id: int, max_hp: float, shield_max: float, invisible: bool) -> void:
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
		enemy.set_meta("spawn_tier", tier)
		if enemy.has_method("apply_tier_scaling"):
			enemy.apply_tier_scaling(tier)
		if tier >= REGULAR_SHIELD_MIN_TIER and enemy.has_method("enable_item_shield"):
			enemy.enable_item_shield(SHIELD_PROTECTION, REGULAR_SHIELD_RATIO)
		_apply_global_buff(enemy)
		if NetworkManager.is_multiplayer_active:
			_rpc_client_spawn_creature.rpc(id, spawn_pos, tier, false, network_id)
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
	var tier: int = max(1, _current_tier())
	var roster: Array = TIER_ROSTER.get(tier, TIER_ROSTER.get(1, []))
	if roster.is_empty():
		return 0
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
			enemy.apply_tier_scaling(tier)
		if tier >= REGULAR_SHIELD_MIN_TIER and enemy.has_method("enable_item_shield"):
			enemy.enable_item_shield(SHIELD_PROTECTION, REGULAR_SHIELD_RATIO)
		_apply_global_buff(enemy)
		if NetworkManager.is_multiplayer_active:
			_rpc_client_spawn_creature.rpc(id, spawn_pos, tier, false, network_id)
		spawned += 1
	return spawned


## Debug menüsündeki yaratık seçici listesi için - SCENES'in kendisi (const preload'lu Dictionary)
## dışarıdan doğrudan da okunabilir ama isimlendirilmiş bir erişim daha temiz.
func get_debug_creature_ids() -> Array:
	return SCENES.keys()


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
const EXTRA_PLAYER_DEFENSE_MULT := 0.50

## Yaratık yetenekleri (kullanıcı isteği 2026-09-24) - statla çözülen aile özellikleri (bosslar dahil, çünkü tüm spawn
## yolları _apply_global_buff'tan geçer):
##  - golem: "çok dayanıklıdır fakat biraz yavaştır (kalkan ve can oranları %30 arttır, hızlarını %20 azalt)"
##  - zombie: "zombilerin canı %30 daha fazla olsun" (sadece can; ölüm asidi enemy.gd die()'da)
const FAMILY_TRAITS := {
	"golem": {"health": 1.3, "shield": 1.3, "speed": 0.8},
	"zombie": {"health": 1.3},
}

func _apply_global_buff(enemy: Node) -> void:
	var extra_players: int = max(0, _player_count() - 1)
	## Kullanıcı isteği (2026-09-24 denge turu): ekstra oyuncu başına can/kalkan +%30 -> +%50 (her kademede).
	var multiplayer_defense_mult: float = 1.0 + float(extra_players) * EXTRA_PLAYER_DEFENSE_MULT
	var health_shield_mult: float = BOSS_HEALTH_SHIELD_MULT if enemy.is_boss else HEALTH_SHIELD_MULT
	var boss_cut: float = BOSS_CUT_2026_09_25B if enemy.is_boss else 1.0
	## Aile özellikleri (bkz. FAMILY_TRAITS) - kalkan çarpanı candan AYRI tutulur (zombide sadece can artar).
	var fam_trait: Dictionary = FAMILY_TRAITS.get(Enemy.family_of_id(str(enemy.get_meta("creature_id", ""))), {})
	var trait_health: float = float(fam_trait.get("health", 1.0))
	var trait_shield: float = float(fam_trait.get("shield", 1.0))
	enemy.speed *= float(fam_trait.get("speed", 1.0))
	enemy.max_health *= GLOBAL_DEFENSE_BUFF * multiplayer_defense_mult * health_shield_mult * trait_health * boss_cut
	enemy.health = enemy.max_health
	enemy.contact_damage *= GLOBAL_DAMAGE_BUFF * boss_cut
	if enemy.ranged_damage > 0.0:
		enemy.ranged_damage *= GLOBAL_DAMAGE_BUFF * boss_cut
	# Kalkan zaten max_health * shield_ratio ile hesaplandı; oranı bozmamak
	# için item_shield_max ve item_shield_hp'yi de aynı (savunma) çarpanla
	# büyütüyoruz.
	if enemy.item_shield_max > 0.0:
		## Kalkan zaten (trait'siz) candan türetilmişti: GLOBAL çarpanlar + ailenin KENDİ kalkan çarpanı.
		enemy.item_shield_max *= GLOBAL_DEFENSE_BUFF * multiplayer_defense_mult * health_shield_mult * trait_shield * boss_cut
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
		var reward_health: float = enemy.max_health / DURABILITY_CUT_2026_09_25 / BOSS_CUT_2026_09_25B
		enemy.xp_value = round(reward_health * Enemy.BOSS_XP_HEALTH_RATIO)
		enemy.gold_min = max(1, int(reward_health * Enemy.BOSS_GOLD_MIN_HEALTH_RATIO))
		enemy.gold_max = max(enemy.gold_min + 1, int(reward_health * Enemy.BOSS_GOLD_MAX_HEALTH_RATIO))
		enemy.gold_chance = 1.0
