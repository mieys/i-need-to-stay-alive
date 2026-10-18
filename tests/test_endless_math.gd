extends Node

## Kullanıcı isteği (2026-10-05): Final bosslarını yenince "Sonsuza Devam Et". Saf kat/ölçek/boss dalgası hesapları
## (scripts/endless_math.gd) - enemy_spawner.gd bunları host'ta okur.

const EndlessMathScript: GDScript = preload("res://scripts/endless_math.gd")
const FINAL_POOL := ["agac3", "demon3", "golem3", "hayalet3", "lich3", "mantar3", "ork3",
		"rat3", "rontgen3", "vampire3", "zombie3", "iblis3", "iskelet3"]


func test_layer_follows_elapsed_time() -> void:
	assert(EndlessMathScript.layer_for_elapsed(0.0, 100.0) == 1, "başlangıç Kat 1")
	assert(EndlessMathScript.layer_for_elapsed(99.9, 100.0) == 1, "Kat 1 bitmeden Kat 2 olmamalı")
	assert(EndlessMathScript.layer_for_elapsed(100.0, 100.0) == 2, "100 sn = Kat 2")
	assert(EndlessMathScript.layer_for_elapsed(250.0, 100.0) == 3, "250 sn = Kat 3")
	assert(EndlessMathScript.layer_for_elapsed(-5.0, 100.0) == 1, "negatif süre Kat 1'de kalmalı")
	assert(EndlessMathScript.layer_for_elapsed(500.0, 0.0) == 1, "geçersiz kat süresi (0) çökmemeli")


func test_scale_tier_starts_at_final_and_climbs() -> void:
	assert(EndlessMathScript.scale_tier(1) == 16, "Kat 1 = Final'in kademesi (sert sıçrama yok)")
	assert(EndlessMathScript.scale_tier(2) == 17)
	assert(EndlessMathScript.scale_tier(10) == 25)
	assert(EndlessMathScript.scale_tier(0) == 16, "0/negatif kat Kat 1 gibi davranmalı")


func test_boss_wave_layers() -> void:
	for layer in [1, 2, 4, 5, 7]:
		assert(not EndlessMathScript.is_boss_wave_layer(layer), "Kat %d boss katı olmamalı" % layer)
	for layer in [3, 6, 9, 12]:
		assert(EndlessMathScript.is_boss_wave_layer(layer), "Kat %d boss katı olmalı" % layer)
	assert(not EndlessMathScript.is_boss_wave_layer(0), "Kat 0 boss katı olmamalı")


func test_boss_wave_size_grows_and_caps_at_final_roster() -> void:
	var expected := {3: 3, 6: 5, 9: 7, 12: 9, 15: 11, 18: 13, 21: 13, 60: 13}
	for layer: int in expected.keys():
		assert(EndlessMathScript.boss_wave_size(layer) == expected[layer],
				"Kat %d dalga boyutu %d olmalı, %d geldi" % [layer, expected[layer], EndlessMathScript.boss_wave_size(layer)])
	assert(EndlessMathScript.boss_wave_size(4) == 0, "boss katı olmayan katta dalga boyutu 0")
	assert(EndlessMathScript.MAX_WAVE_SIZE == FINAL_POOL.size(), "tavan Final'in 13 bossu")


func test_wave_timing_inside_the_layer() -> void:
	assert(is_equal_approx(EndlessMathScript.layer_start_elapsed(3, 100.0), 200.0))
	assert(is_equal_approx(EndlessMathScript.boss_trigger_elapsed(3, 100.0), 275.0), "boss katın %75'inde (Kat 3 = 200 + 75)")
	assert(is_equal_approx(EndlessMathScript.boss_trigger_elapsed(1, 100.0), 75.0))


func test_pick_wave_ids_returns_distinct_members_without_touching_pool() -> void:
	var pool: Array = FINAL_POOL.duplicate()
	var picked: Array = EndlessMathScript.pick_wave_ids(pool, 5)
	assert(picked.size() == 5, "5 id istendi: %d geldi" % picked.size())
	var seen := {}
	for id in picked:
		assert(FINAL_POOL.has(id), "havuz dışı id: %s" % id)
		assert(not seen.has(id), "tekrarlı id: %s" % id)
		seen[id] = true
	assert(pool == FINAL_POOL, "havuz değiştirilmemeli")
	assert(EndlessMathScript.pick_wave_ids(pool, 99).size() == FINAL_POOL.size(), "havuzdan fazlası istenirse hepsi gelir")
	assert(EndlessMathScript.pick_wave_ids(pool, 0).is_empty(), "0 istenirse boş")
	assert(EndlessMathScript.pick_wave_ids([], 3).is_empty(), "boş havuz çökmemeli")


func test_pick_wave_ids_is_deterministic_for_a_seed() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 12345
	var b := RandomNumberGenerator.new()
	b.seed = 12345
	assert(EndlessMathScript.pick_wave_ids(FINAL_POOL, 7, a) == EndlessMathScript.pick_wave_ids(FINAL_POOL, 7, b),
			"aynı tohum aynı seçimi vermeli")


## ---- Sonsuz mod baskısı (2026-10-18, madde 269) ----

func test_creature_compound_starts_at_layer_two_and_leaves_normal_game_alone() -> void:
	for tier in [0, 1, 5, 15, 16]:
		assert(is_equal_approx(EndlessMathScript.creature_health_mult(tier), 1.0), "kademe %d (normal oyun/Final/kat 1) can çarpanı 1 olmalı" % tier)
		assert(is_equal_approx(EndlessMathScript.creature_damage_mult(tier), 1.0), "kademe %d hasar çarpanı 1 olmalı" % tier)
	assert(is_equal_approx(EndlessMathScript.creature_health_mult(EndlessMathScript.scale_tier(2)), 1.0 + EndlessMathScript.HEALTH_COMPOUND_PER_LAYER), "kat 2 = bir adım")
	var h21: float = EndlessMathScript.creature_health_mult(EndlessMathScript.scale_tier(21))
	assert(h21 > 4.0 and h21 < 5.5, "kat 21 can çarpanı ~x4,7: %f" % h21)
	var d21: float = EndlessMathScript.creature_damage_mult(EndlessMathScript.scale_tier(21))
	assert(d21 > 2.3 and d21 < 3.0, "kat 21 hasar çarpanı ~x2,65: %f" % d21)
	assert(EndlessMathScript.creature_health_mult(EndlessMathScript.scale_tier(8)) > EndlessMathScript.creature_health_mult(EndlessMathScript.scale_tier(7)), "kat arttıkça çarpan büyür")


func test_extra_enemy_cap_grows_per_layer_and_stops() -> void:
	assert(EndlessMathScript.extra_enemy_cap(0) == 0 and EndlessMathScript.extra_enemy_cap(1) == 0, "kat 0-1 ek yok")
	assert(EndlessMathScript.extra_enemy_cap(2) == EndlessMathScript.CAP_PER_LAYER, "kat 2 = +3")
	assert(EndlessMathScript.extra_enemy_cap(11) == 30, "kat 11 = +30")
	assert(EndlessMathScript.extra_enemy_cap(21) == EndlessMathScript.CAP_MAX_EXTRA, "kat 21 = üst sınır +60")
	assert(EndlessMathScript.extra_enemy_cap(500) == EndlessMathScript.CAP_MAX_EXTRA, "üst sınır aşılmaz")


func test_pool_wave_size_starts_small_and_caps_at_pool() -> void:
	var expected := {3: 2, 6: 3, 9: 4, 12: 5, 15: 6, 18: 6, 60: 6}
	for layer: int in expected.keys():
		assert(EndlessMathScript.pool_wave_size(layer) == expected[layer], "kat %d havuz dalga boyutu %d olmalı, %d geldi" % [layer, expected[layer], EndlessMathScript.pool_wave_size(layer)])
	assert(EndlessMathScript.pool_wave_size(4) == 0, "boss katı olmayan katta 0")
	assert(EndlessMathScript.WAVE_POOL.size() == 6, "havuz = 6 yeni boss")
	var seen := {}
	for id in EndlessMathScript.WAVE_POOL:
		assert(not seen.has(id), "tekrarlı havuz kimliği: %s" % id)
		seen[id] = true


func test_wave_boss_mult_only_for_wave_layers_on() -> void:
	for tier in [3, 5, 8, 12, 15, 16, 17]:
		assert(is_equal_approx(EndlessMathScript.boss_health_mult(tier), 1.0) and is_equal_approx(EndlessMathScript.boss_damage_mult(tier), 1.0), "kademe bossu/Final/kat 1-2 (ölçek %d) çarpansız" % tier)
	assert(is_equal_approx(EndlessMathScript.boss_health_mult(EndlessMathScript.scale_tier(3)), 1.0), "ilk dalga (kat 3) x1")
	assert(is_equal_approx(EndlessMathScript.boss_health_mult(EndlessMathScript.scale_tier(6)), 1.5), "2. dalga x1,5")
	assert(is_equal_approx(EndlessMathScript.boss_health_mult(EndlessMathScript.scale_tier(21)), 4.0), "7. dalga x4")
	assert(is_equal_approx(EndlessMathScript.boss_damage_mult(EndlessMathScript.scale_tier(21)), 2.5), "7. dalga hasar x2,5")
	assert(is_equal_approx(EndlessMathScript.boss_health_mult(EndlessMathScript.scale_tier(4)), 1.0), "boss katı olmayan kat x1")
