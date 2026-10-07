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
