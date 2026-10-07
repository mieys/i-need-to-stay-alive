extends Node

## Kullanıcı bildirimi (2026-10-06): "kademe 3'ten sonra oyun oynanamayacak derecede zorlaşıyor, öncesinde de oyun aşırı kolay (bunu ben
## istemiştim) ama arada bariz bir fark var, biraz dengelenmeleri gerekiyor". Gerçek koddan ölçüm (yaratık etkin canı x doğuş sıklığı =
## "saniyede öldürülmesi gereken can", R): K2 46 -> K3 242 (x5.3) -> K4 408 -> K5 947 -> K8 5745; ilk boss etkin canı ~19.500.
## Bu dosya YUMUŞATMANIN değişmezlerini korur: Kademe 1-2 aynı (kolay), Kademe 3 sıçraması küçük, Kademeler arası artış sınırlı, ilk bosslar
## orantılı, boss ödülü aynı, host ve istemci boss formülü aynı.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const RatScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")

var _made: Array[Node] = []


## Boss doğuşu canlı bir oyuncu çapası ister (bkz. _find_any_living_player_position).
class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for e: Node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e):
			e.free()
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false


func _spawner() -> Node:
	_cleanup()
	get_tree().current_scene = self ## _spawn_creature current_scene'e ekliyor
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	_made.append(sp)
	return sp


## Bir yaratığın etkin canı: kalkan soğurması p ise vuruşun p'si kalkana gider (kalkan havuzu bitene kadar).
func _ehp(e: Node) -> float:
	var hp: float = float(e.max_health)
	var sh: float = float(e.item_shield_max)
	var p: float = float(e.shield_protection) if sh > 0.0 else 0.0
	if sh <= 0.0 or p <= 0.0:
		return hp
	var d_shield: float = sh / p
	var d_hp: float = hp / (1.0 - p)
	return d_hp if d_shield >= d_hp else d_shield + (hp - (1.0 - p) * d_shield)


## O Kademe'nin (ortasındaki zamanda) roster yaratıklarının ortalama etkin canı - spawner'ın GERÇEK yoluyla (ölçekleme + kalkan + global güçlendirme).
func _avg_ehp(sp: Node, tier: int) -> float:
	GameManager.game_time = float(tier - 1) * float(sp.tier_duration) + float(sp.tier_duration) * 0.5
	var total: float = 0.0
	var n: int = 0
	for id: String in sp.call("_spawnable_roster", tier):
		var e: Node = sp.call("_spawn_creature", id, Vector2(60 * n, 0), 9000 + n)
		if e == null:
			continue
		_made.append(e)
		e.set_meta("spawn_tier", tier)
		e.apply_tier_scaling(tier)
		sp.call("_enable_regular_shield", e, tier)
		sp.call("_apply_global_buff", e)
		total += _ehp(e)
		n += 1
	return total / maxf(1.0, float(n))


func test_shield_absorption_phases_in_from_tier_three() -> void:
	assert(is_equal_approx(SpawnerScript.SHIELD_PROTECTION, 0.3), "tam soğurma değeri değişmemeli (testler/oyun tasarımı bunu bekliyor)")
	assert(SpawnerScript.regular_shield_protection(1) == 0.0 and SpawnerScript.regular_shield_protection(2) == 0.0, "Kademe 1-2'de kalkan yok")
	var prev: float = 0.0
	for tier in range(3, 8):
		var p: float = SpawnerScript.regular_shield_protection(tier)
		assert(p > prev, "soğurma her Kademe artmalı: K%d %.3f <= %.3f" % [tier, p, prev])
		prev = p
	assert(is_equal_approx(SpawnerScript.regular_shield_protection(3), 0.3 / 5.0), "Kademe 3'te tam değerin 1/5'i")
	assert(is_equal_approx(SpawnerScript.regular_shield_protection(7), 0.3), "Kademe 7'de tam %30")
	assert(is_equal_approx(SpawnerScript.regular_shield_protection(16), 0.3) and is_equal_approx(SpawnerScript.regular_shield_protection(40), 0.3), "Final/sonsuzda tam")


func test_early_cut_fades_instead_of_vanishing_at_tier_three() -> void:
	assert(is_equal_approx(SpawnerScript.EARLY_TIER_DURABILITY_CUT, 0.8) and SpawnerScript.EARLY_TIER_MAX == 2, "Kademe 1-2 kesintisi aynı kalmalı (kullanıcı kolay istedi)")
	assert(is_equal_approx(SpawnerScript.early_durability_cut(1), 0.8) and is_equal_approx(SpawnerScript.early_durability_cut(2), 0.8), "Kademe 1-2: x0.8")
	assert(is_equal_approx(SpawnerScript.early_durability_cut(3), 0.85) and is_equal_approx(SpawnerScript.early_durability_cut(4), 0.90) \
			and is_equal_approx(SpawnerScript.early_durability_cut(5), 0.95), "Kademe 3-5 yumuşar")
	assert(SpawnerScript.early_durability_cut(6) == 1.0 and SpawnerScript.early_durability_cut(15) == 1.0, "Kademe 6+ kesinti yok")
	## Etkin dayanıklılık çarpanı (kesinti / (1 - soğurma)): her adım küçük (eskiden K2 0.80 -> K3 1.43 = x1.79).
	var prev: float = SpawnerScript.early_durability_cut(2)
	for tier in range(3, 8):
		var f: float = SpawnerScript.early_durability_cut(tier) / (1.0 - SpawnerScript.regular_shield_protection(tier))
		assert(f > prev and f / prev <= 1.2, "dayanıklılık basamağı K%d: %.3f -> %.3f (x%.2f) 1.2'yi aşmamalı" % [tier, prev, f, f / prev])
		prev = f


func test_damage_taper_only_touches_tiers_three_to_five() -> void:
	assert(SpawnerScript.early_damage_taper(1) == 1.0 and SpawnerScript.early_damage_taper(2) == 1.0, "Kademe 1-2 hasarı değişmedi")
	assert(is_equal_approx(SpawnerScript.early_damage_taper(3), 0.85) and is_equal_approx(SpawnerScript.early_damage_taper(5), 0.95), "K3 x0.85, K5 x0.95")
	assert(SpawnerScript.early_damage_taper(6) == 1.0, "K6+ değişmedi")


## Kullanıcı isteği (2026-10-06): "Kademe 3 ve sonrasının hasarını %10 düşür" - tablo + gerçek _apply_global_buff yolu.
func test_tier_three_and_later_creature_damage_is_ten_percent_lower() -> void:
	assert(is_equal_approx(SpawnerScript.LATE_TIER_DAMAGE_MULT, 0.9) and SpawnerScript.LATE_TIER_DAMAGE_MIN_TIER == 3, "sabitler: K3'ten itibaren x0.9")
	assert(SpawnerScript.tier_damage_mult(1, false) == 1.0 and SpawnerScript.tier_damage_mult(2, false) == 1.0, "Kademe 1-2 hasarı değişmedi")
	assert(is_equal_approx(SpawnerScript.tier_damage_mult(3, false), 0.85 * 0.9), "K3 normal: taper x0.9")
	assert(is_equal_approx(SpawnerScript.tier_damage_mult(5, false), 0.95 * 0.9), "K5 normal: taper x0.9")
	for t in [6, 8, 12, 16, 20]:
		assert(is_equal_approx(SpawnerScript.tier_damage_mult(t, false), 0.9), "Kademe %d normal yaratık x0.9" % t)
		assert(is_equal_approx(SpawnerScript.tier_damage_mult(t, true), 0.9), "Kademe %d bossu x0.9" % t)
	assert(SpawnerScript.tier_damage_mult(0, false) == 1.0, "Kademe 0 (bilinmeyen) değişmez")
	var sp: Node = _spawner()
	var buff: float = SpawnerScript.GLOBAL_DAMAGE_BUFF
	for pair in [[2, 1.0], [3, 0.85 * 0.9], [5, 0.95 * 0.9], [6, 0.9], [10, 0.9], [16, 0.9]]:
		var rat: Node = RatScene.instantiate()
		add_child(rat)
		_made.append(rat)
		rat._current_tier = int(pair[0])
		rat.contact_damage = 10.0
		rat.ranged_damage = 4.0
		sp._apply_global_buff(rat)
		assert(absf(float(rat.contact_damage) - 10.0 * buff * float(pair[1])) < 0.001, "K%d temas hasarı: %s" % [pair[0], rat.contact_damage])
		assert(absf(float(rat.ranged_damage) - 4.0 * buff * float(pair[1])) < 0.001, "K%d menzilli hasarı: %s" % [pair[0], rat.ranged_damage])
	_cleanup()


## Kullanıcı isteği (2026-10-06): "3. kademeden sonra zorluğu genel olarak %10 daha düşür" - can + kalkan x0.9 (hasar düşüşüne ek), ödül aynı.
func test_tier_three_and_later_durability_is_ten_percent_lower_and_rewards_unchanged() -> void:
	assert(is_equal_approx(SpawnerScript.LATE_TIER_DURABILITY_MULT, 0.9), "sabit x0.9")
	assert(SpawnerScript.late_durability_mult(0) == 1.0 and SpawnerScript.late_durability_mult(1) == 1.0 and SpawnerScript.late_durability_mult(2) == 1.0, "Kademe 1-2 değişmedi")
	for t in [3, 5, 8, 16, 20]:
		assert(is_equal_approx(SpawnerScript.late_durability_mult(t), 0.9), "Kademe %d x0.9" % t)
	var sp: Node = _spawner()
	var by_tier: Dictionary = {}
	for tier in [2, 6]:
		var rat: Node = RatScene.instantiate()
		add_child(rat)
		_made.append(rat)
		rat._current_tier = tier
		rat.max_health = 100.0
		rat.item_shield_max = 100.0
		rat.item_shield_hp = 100.0
		sp._apply_global_buff(rat)
		by_tier[tier] = [float(rat.max_health), float(rat.item_shield_max)]
	## Kademe 2 -> 6: 0.8 (erken kesinti) kalkar, yerine 0.9 gelir; oran = 0.9 / 0.8.
	assert(absf(float(by_tier[6][0]) / float(by_tier[2][0]) - 0.9 / 0.8) < 0.001, "can oranı K6/K2 = 0.9/0.8: %s" % by_tier)
	assert(absf(float(by_tier[6][1]) / float(by_tier[2][1]) - 0.9 / 0.8) < 0.001, "kalkan oranı K6/K2 = 0.9/0.8: %s" % by_tier)
	## Boss ödülünün (XP) değişmediği test_first_bosses_are_proportionate_and_formula_is_single_sourced'ta (pacing'siz + Kademe 3+ düşüşsüz taban can).
	_cleanup()


func test_spawn_ramp_is_slower_and_early_game_is_not_harder() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 50.0
	assert(float(sp.call("_current_interval")) >= 0.57 - 0.001, "Kademe 1 doğuş aralığı eskisinden SIK olmamalı: %s" % sp.call("_current_interval"))
	GameManager.game_time = 150.0
	assert(float(sp.call("_current_interval")) >= 0.50 - 0.001, "Kademe 2 doğuş aralığı eskisinden SIK olmamalı: %s" % sp.call("_current_interval"))
	GameManager.game_time = 250.0
	var i3: float = float(sp.call("_current_interval"))
	GameManager.game_time = 750.0
	var i8: float = float(sp.call("_current_interval"))
	assert(i3 > 0.47 and i3 < 0.53, "K3'te ~0.50 sn: %s" % i3)
	assert(i8 > 0.27 and i8 < 0.33, "K8'de ~0.30 sn (eskiden 0.11): %s" % i8)
	assert(i3 / i8 < 1.8, "K3 -> K8 doğuş artışı x1.8'i aşmamalı (eskiden x3.9): x%.2f" % (i3 / i8))
	GameManager.game_time = 2000.0
	assert(absf(float(sp.call("_current_interval")) - sp.min_interval / 1.5) < 0.0001, "tavan (min_interval/1.5) hâlâ var")
	_cleanup()


func test_no_cliff_between_tiers_measured_with_the_real_spawn_path() -> void:
	var sp: Node = _spawner()
	var ehp: Dictionary = {}
	var r: Dictionary = {}
	for tier in range(1, 9):
		ehp[tier] = _avg_ehp(sp, tier)
		r[tier] = float(ehp[tier]) / float(sp.call("_current_interval")) ## saniyede öldürülmesi gereken etkin can
	## Kademe 1-2 BİLEREK kolay kaldı: ölçümdeki değerler (K1 ~5, K2 ~23) değişmedi.
	assert(absf(float(ehp[1]) - 5.0) < 1.5, "Kademe 1 etkin canı değişmemeli: %.1f" % ehp[1])
	assert(absf(float(ehp[2]) - 23.0) < 3.0, "Kademe 2 etkin canı değişmemeli: %.1f" % ehp[2])
	## Kademe 2 -> 3 sıçraması: eskiden R x5.3 (46 -> 242), şimdi ~x3.
	assert(float(r[3]) / float(r[2]) < 3.6, "K2 -> K3 sıçraması x3.6'yı aşmamalı: x%.2f" % (float(r[3]) / float(r[2])))
	assert(float(r[3]) < 170.0, "Kademe 3 R'si eskiden 242'ydi, ~130 olmalı: %.0f" % r[3])
	## Sonraki her adım sınırlı (eskiden K7 -> K8 x2.15 ve genel x1.4-2.3; şimdi en çok ~x2.4 - roster değişiminin getirdiği K5).
	for tier in range(4, 9):
		var step: float = float(r[tier]) / float(r[tier - 1])
		assert(step < 2.6, "K%d -> K%d R artışı x2.6'yı aşmamalı: x%.2f" % [tier - 1, tier, step])
	assert(float(r[8]) < 2600.0, "Kademe 8 R'si eskiden 5745'ti: %.0f" % r[8])
	_cleanup()


func test_first_bosses_are_proportionate_and_formula_is_single_sourced() -> void:
	assert(is_equal_approx(SpawnerScript.boss_health_pacing(3), 0.6) and is_equal_approx(SpawnerScript.boss_damage_pacing(3), 0.8), "K3 bossu x0.6 can, x0.8 hasar")
	assert(is_equal_approx(SpawnerScript.boss_health_pacing(6), 0.75) and is_equal_approx(SpawnerScript.boss_damage_pacing(8), 0.95), "K6/K8 yumuşatma")
	for t in [12, 15, 16, 20]:
		assert(SpawnerScript.boss_health_pacing(t) == 1.0 and SpawnerScript.boss_damage_pacing(t) == 1.0, "Kademe %d bossu değişmedi" % t)
	var base: Dictionary = SpawnerScript.boss_base_stats("iskelet3", 3)
	assert(absf(float(base["health"]) - (10.0 + 27.0) * 1.0 * SpawnerScript.BOSS_HEALTH_MULT * 0.6) < 0.01, "boss taban canı formülü: %s" % base["health"])
	assert(absf(float(base["damage"]) - (3.0 + 3.0 * 2.2) * 1.0 * SpawnerScript.BOSS_DAMAGE_MULT * 0.8) < 0.01, "boss taban hasarı formülü: %s" % base["damage"])
	## Host (_spawn_boss_group) ve istemci (_rpc_client_spawn_creature) AYNI canı vermeli.
	var sp: Node = _spawner()
	var anchor := FakePlayer.new()
	anchor.add_to_group("player")
	add_child(anchor)
	anchor.position = Vector2(500.0, 500.0)
	_made.append(anchor)
	var spawned: Array = sp.call("_spawn_boss_group", ["iskelet3"], 3)
	assert(not spawned.is_empty(), "host boss doğurmalı")
	_made.append_array(spawned)
	var host_boss: Node = spawned[0]
	sp.call("_rpc_client_spawn_creature", "iskelet3", Vector2(500, 500), 3, true, 8800, false, false)
	var client_boss: Node = null
	for b: Node in get_tree().get_nodes_in_group("boss"):
		if b != host_boss and int(b.get_meta("network_enemy_id", 0)) == 8800:
			client_boss = b
	assert(client_boss != null, "istemci yolu boss doğurmalı")
	assert(absf(float(host_boss.max_health) - float(client_boss.max_health)) < 0.01, "host/istemci boss canı aynı olmalı: %s / %s" % [host_boss.max_health, client_boss.max_health])
	assert(absf(float(host_boss.contact_damage) - float(client_boss.contact_damage)) < 0.01, "host/istemci boss hasarı aynı olmalı")
	## Boss ödülü (XP) pacing'ten ETKİLENMEZ: ödül, pacing'siz taban can üzerinden hesaplanır.
	var unpaced_base: float = (10.0 + 27.0) * SpawnerScript.BOSS_HEALTH_MULT
	var expected_xp: float = round(unpaced_base * SpawnerScript.GLOBAL_DEFENSE_BUFF * SpawnerScript.BOSS_HEALTH_SHIELD_MULT / SpawnerScript.DURABILITY_CUT_2026_09_25 * Enemy.BOSS_XP_HEALTH_RATIO)
	assert(absf(float(host_boss.xp_value) - expected_xp) <= 1.0, "boss XP ödülü aynı kalmalı: %s (beklenen %s)" % [host_boss.xp_value, expected_xp])
	_cleanup()
