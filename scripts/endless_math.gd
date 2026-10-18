extends RefCounted

## SONSUZ MOD saf hesapları (kullanıcı isteği 2026-10-05: Final'in 13 bossunu yenince "Zafer" + "Sonsuza Devam Et").
## enemy_spawner.gd (host) kat / ölçek / boss dalgası kararlarını BURADAN okur, testler de aynı fonksiyonları çağırır -
## formül tek yerde (bkz. CLAUDE.md madde 3, "paylaşılan static func" kuralı).
##
## Kavramlar:
##  - ROSTER kademesi 15'te kalır: enemy_spawner TIER_ROSTER'ında 16+ yok ve `TIER_ROSTER.get(tier, TIER_ROSTER.get(1))`
##    bilinmeyen kademede 1. kademenin (fare/slime) listesine düşer. Sadece İSTATİSTİK ölçeği (apply_tier_scaling /
##    apply_boss_stats'e geçen sayı) büyür -> `scale_tier(kat)`.
##  - KAT: sonsuz mod başladığından beri geçen oyun saati / tier_duration (100 sn). Kat 1 = Final Kademe'nin ölçeği (16);
##    yani Final'den sonra sert bir sıçrama yok, kat kat devam eder. Oyun saati herkes seyyar satıcı bölgesindeyken durur -
##    kat saati de onunla durur (Kademe saatiyle aynı kural).
##  - BOSS DALGASI: her BOSS_EVERY_LAYERS katta bir, o katın %75'inde (boss_trigger_fraction ile aynı oran). Dalga boyutu
##    her dalgada WAVE_SIZE_STEP büyür, Final'in 13 bossunu aşmaz. Kademe boss kapısı (Kademe saatini tutma) sonsuzda YOK -
##    baskı zamana bağlı artmalı, boss öldürülene kadar beklememeli.

const BASE_TIER := 15 ## Final'den önceki son normal kademe (roster bu kademede kalır)
const BOSS_EVERY_LAYERS := 3
const FIRST_WAVE_SIZE := 3
const WAVE_SIZE_STEP := 2
const MAX_WAVE_SIZE := 13 ## FINAL_CREATURES'ın tamamı
const BOSS_TRIGGER_FRACTION := 0.75

## ---- SONSUZ MOD BASKISI (2026-10-18, madde 269; kullanıcı: "çok bozmuş oyunu" - Elara'nın 113 dk'lık sonsuz koşusu, 577M hasar, hiç ölmedi) ----
## Teşhis (kosular.jsonl): oyuncu gücü seviye/kart/eşya ile sınırsız büyürken sonsuzda yaratık sayısı hep 105, doğuş aralığı zaten alt sınırda, boss yok,
## yalnız kat başına +1 ölçek kademesi vardı (kademe 15 -> kat 21'de can ~x4, hasar ~x4; oyuncu canı ~100x). Üç ek baskı - HEPSİ sonsuza özel
## (normal oyun kademeleri etkilenmez: katsayılar `scale_tier` > 15 olduğunda devreye girer) ve ilk tahmindir, balans kaydındaki kat kırılımına göre ayarlanır.
## 1) Bileşik can/hasar: kat başına `1 + oran` çarpanı, kat 1'de x1 (apply_tier_scaling içinde; istemci aynı ölçek kademesini RPC ile alır).
const HEALTH_COMPOUND_PER_LAYER := 0.08 ## kat 21: 1,08^20 = x4,7 can/kalkan (kademe ölçeğinin üstüne)
const DAMAGE_COMPOUND_PER_LAYER := 0.05 ## kat 21: 1,05^20 = x2,65 hasar
## 2) Kalabalık: yaratık tavanı kat başına +3, en çok +60 (tek oyuncuda 105 -> 165; 4 kişilik tavan 168 ile aynı mertebe, performans sınırı).
const CAP_PER_LAYER := 3
const CAP_MAX_EXTRA := 60
## 3) Boss dalgaları: `GameManager.bosses_enabled` kapalıyken de (yeni sistem) 3 katta bir; havuz = elle statlı yeni 6 boss. Dalga boyutu 2'den başlar, dalga başına +1, en çok 6.
## Dalgadaki bossun can/kalkan/temas hasarı dalga başına büyür (FIXED_BOSS_STATS sabit sayılar, katla büyümezdi): `boss_health_mult` / `boss_damage_mult`.
## Not: bossların KENDİ özel saldırı sayıları (ateş topu, çığlık vb.) sabit kalır; sadece temas/menzilli hasar ve can/kalkan büyür.
const WAVE_POOL := ["minotaur1", "underground1", "balkabagi1", "wendigo1", "banshee1", "ucansetan1"]
const POOL_FIRST_WAVE_SIZE := 2
const POOL_WAVE_SIZE_STEP := 1
const BOSS_HEALTH_PER_WAVE := 0.5 ## dalga n: x(1 + 0,5 (n-1)); kat 21 = 7. dalga = x4
const BOSS_DAMAGE_PER_WAVE := 0.25 ## dalga 7: x2,5


## Sonsuz mod başladığından beri `elapsed` saniye geçtiyse hangi kattayız (1'den başlar).
static func layer_for_elapsed(elapsed: float, layer_seconds: float) -> int:
	if layer_seconds <= 0.0:
		return 1
	return 1 + int(maxf(elapsed, 0.0) / layer_seconds)


## Kat -> yaratık/boss İSTATİSTİK kademesi (Kat 1 = 16 = Final'in kademesi).
static func scale_tier(layer: int) -> int:
	return BASE_TIER + maxi(layer, 1)


static func is_boss_wave_layer(layer: int) -> bool:
	return layer >= BOSS_EVERY_LAYERS and layer % BOSS_EVERY_LAYERS == 0


## Kaçıncı boss dalgası (1'den başlar); boss katı değilse 0.
@warning_ignore("integer_division")
static func wave_number(layer: int) -> int:
	return layer / BOSS_EVERY_LAYERS if is_boss_wave_layer(layer) else 0


static func boss_wave_size(layer: int) -> int:
	var n: int = wave_number(layer)
	if n <= 0:
		return 0
	return clampi(FIRST_WAVE_SIZE + (n - 1) * WAVE_SIZE_STEP, FIRST_WAVE_SIZE, MAX_WAVE_SIZE)


## Yeni sistem (WAVE_POOL) dalga boyutu: boss katı değilse 0.
static func pool_wave_size(layer: int) -> int:
	var n: int = wave_number(layer)
	if n <= 0:
		return 0
	return clampi(POOL_FIRST_WAVE_SIZE + (n - 1) * POOL_WAVE_SIZE_STEP, POOL_FIRST_WAVE_SIZE, WAVE_POOL.size())


## Ölçek kademesi -> sonsuz kat (0 = sonsuz değil). scale_tier(kat) = 15 + kat'ın tersi. Kat 1 = kademe 16 = Final'in kademesi.
static func layer_for_scale_tier(scale_tier: int) -> int:
	return maxi(scale_tier - BASE_TIER, 0)


## Sıradan yaratığın sonsuz kat çarpanları (can+kalkan / hasar). Kat 0-1'de 1,0 (normal oyun ve Final değişmez).
static func creature_health_mult(scale_tier: int) -> float:
	var layer: int = layer_for_scale_tier(scale_tier)
	return 1.0 if layer <= 1 else pow(1.0 + HEALTH_COMPOUND_PER_LAYER, float(layer - 1))


static func creature_damage_mult(scale_tier: int) -> float:
	var layer: int = layer_for_scale_tier(scale_tier)
	return 1.0 if layer <= 1 else pow(1.0 + DAMAGE_COMPOUND_PER_LAYER, float(layer - 1))


## Sonsuzda yaratık tavanına eklenen sayı (kat başına CAP_PER_LAYER, en çok CAP_MAX_EXTRA). Kat 0-1 = 0.
static func extra_enemy_cap(layer: int) -> int:
	return 0 if layer <= 1 else mini((layer - 1) * CAP_PER_LAYER, CAP_MAX_EXTRA)


## Dalga bossunun çarpanları (ölçek kademesinden dalga numarası çıkarılır). Boss katı olmayan her kademe (kademe bossları, Final) = 1,0.
static func boss_health_mult(scale_tier: int) -> float:
	var n: int = wave_number(layer_for_scale_tier(scale_tier))
	return 1.0 + BOSS_HEALTH_PER_WAVE * float(maxi(n - 1, 0))


static func boss_damage_mult(scale_tier: int) -> float:
	var n: int = wave_number(layer_for_scale_tier(scale_tier))
	return 1.0 + BOSS_DAMAGE_PER_WAVE * float(maxi(n - 1, 0))


## Katın başlangıcı / boss dalgasının tetik anı (sonsuz mod başından itibaren saniye).
static func layer_start_elapsed(layer: int, layer_seconds: float) -> float:
	return float(maxi(layer, 1) - 1) * layer_seconds


static func boss_trigger_elapsed(layer: int, layer_seconds: float) -> float:
	return (float(maxi(layer, 1) - 1) + BOSS_TRIGGER_FRACTION) * layer_seconds


## `pool`dan `count` farklı id seçer (Fisher-Yates, havuzu değiştirmez). Testte tohumlu rng verilebilir.
static func pick_wave_ids(pool: Array, count: int, rng: RandomNumberGenerator = null) -> Array:
	var bag: Array = pool.duplicate()
	var out: Array = []
	var take: int = mini(maxi(count, 0), bag.size())
	for i in range(take):
		var j: int = (rng.randi_range(i, bag.size() - 1) if rng != null else randi_range(i, bag.size() - 1))
		var tmp = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
		out.append(bag[i])
	return out
