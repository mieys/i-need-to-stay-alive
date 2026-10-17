extends Node

## Evcil hayvan Papağan (madde 203, 2026-10-17): altın toplamaz; sahibin yakınındaki bir ağaca uçar, 3-4 sn gagalar, ağaç dibine eşya düşürür,
## omza döner, bekleme sonrası yeniden. Hız = sahibin etkin hareket hızı x1.2. Ödül zarı: parrot_tree_loot.gd.

const ParrotScript := preload("res://scripts/korsan_parrot.gd")
const LootScript := preload("res://scripts/parrot_tree_loot.gd")


class FakeOwner extends Node2D:
	var move_speed: float = 200.0
	var is_dead: bool = false

	func get_effective_move_speed() -> float:
		return move_speed


## Haritasız testte ağaç yok: sabit bir ağaç dibi döndürür, ödülü sayar.
class TestParrot extends "res://scripts/korsan_parrot.gd":
	var tree_at: Variant = null
	var drops: int = 0

	func _find_tree(_around: Vector2) -> Variant:
		return tree_at

	func _drop_loot() -> void:
		drops += 1


func _make_owner() -> FakeOwner:
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5)
	add_child(o)
	var a := AnimatedSprite2D.new()
	a.name = "AnimatedSprite2D"
	a.sprite_frames = load("res://assets/characters/korsan_frames.tres")
	a.scale = Vector2(2.125, 2.125)
	a.offset = Vector2(0, -1.8)
	o.add_child(a)
	a.play("idle_down")
	return o


func _make_parrot(o: FakeOwner) -> TestParrot:
	var p := TestParrot.new()
	o.add_child(p)
	p.setup(o, o.get_node("AnimatedSprite2D"), false)
	p._cooldown = 0.0
	return p


func _run(p: Node2D, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		p._process(1.0 / 60.0)
		t += 1.0 / 60.0


func test_pecks_tree_for_three_to_four_seconds_then_drops_and_returns() -> void:
	var o := _make_owner()
	var p := _make_parrot(o)
	p.tree_at = o.global_position + Vector2(120, 30)
	_run(p, 0.6)
	assert(p.state != ParrotScript.State.PERCH, "ağaç varsa havalanmalı")
	var guard := 0
	while p.state != ParrotScript.State.PECK and guard < 600: ## uçuş (~120 px / 240 px/s)
		p._process(1.0 / 60.0)
		guard += 1
	assert(p.state == ParrotScript.State.PECK, "ağaca varınca gagalamalı: %d" % p.state)
	assert(p.drops == 0, "gagalama bitmeden ödül düşmemeli")
	var peck_time: float = p._peck_timer
	assert(peck_time >= ParrotScript.PECK_MIN - 0.1 and peck_time <= ParrotScript.PECK_MAX, "3-4 sn gagalamalı: %s" % peck_time)
	_run(p, 4.2)
	assert(p.drops == 1, "tam 1 ödül düşmeli: %d" % p.drops)
	_run(p, 3.0)
	assert(p.state == ParrotScript.State.PERCH and not p.top_level, "ödülden sonra omza dönüp konmalı")
	assert(p._cooldown > 0.0, "konunca yeni ağaç için bekleme başlamalı")
	o.queue_free()


func test_no_tree_means_stays_perched() -> void:
	var o := _make_owner()
	var p := _make_parrot(o)
	_run(p, 2.0)
	assert(p.state == ParrotScript.State.PERCH and p.drops == 0)
	o.queue_free()


func test_does_not_take_gold() -> void:
	var o := _make_owner()
	var p := _make_parrot(o)
	var g := Node2D.new()
	g.add_to_group("gold_drops")
	add_child(g)
	g.global_position = o.global_position + Vector2(150, 40)
	var before: int = GameManager.gold
	_run(p, 3.0)
	assert(p.state == ParrotScript.State.PERCH, "altın için havalanmamalı")
	assert(GameManager.gold == before and is_instance_valid(g) and not g.get_meta("parrot_taken", false))
	g.queue_free()
	o.queue_free()


func test_speed_is_1_2x_owner() -> void:
	var o := _make_owner()
	o.move_speed = 250.0
	var p := _make_parrot(o)
	p.tree_at = o.global_position + Vector2(200, 0)
	_run(p, 0.6)
	assert(is_equal_approx(p._speed, 250.0 * ParrotScript.SPEED_MULT), "hız 1.2x: %s" % p._speed)
	o.queue_free()


func test_busy_owner_aborts_peck() -> void:
	var o := _make_owner()
	var p := _make_parrot(o)
	p.tree_at = o.global_position + Vector2(100, 0)
	_run(p, 2.0)
	assert(p.state == ParrotScript.State.PECK)
	o.is_dead = true
	_run(p, 0.1)
	assert(p.state == ParrotScript.State.RETURN and p.drops == 0, "sahip ölünce ödül düşmeden dönmeli")
	o.queue_free()


func test_puppet_follows_peck_events() -> void:
	var o := _make_owner()
	var p: Node2D = ParrotScript.new()
	o.add_child(p)
	p.setup(o, o.get_node("AnimatedSprite2D"), true)
	p._process(1.0 / 60.0)
	var tree_pos: Vector2 = o.global_position + Vector2(100, 0)
	p.apply_event(ParrotScript.State.FLY_TO, tree_pos, 0, 300.0)
	assert(p.top_level)
	_run(p, 1.0)
	assert(p.global_position.distance_to(tree_pos) < 1.0, "kukla ağaca uçmalı")
	p.apply_event(ParrotScript.State.PECK, tree_pos, 0, 300.0)
	_run(p, 0.5)
	assert(p.state == ParrotScript.State.PECK and p._sprite.animation == &"perch", "kukla ağaçta gagalamalı")
	p.apply_event(ParrotScript.State.PERCH, Vector2.ZERO, 0, 300.0)
	_run(p, 1.0)
	assert(p.state == ParrotScript.State.PERCH and not p.top_level, "kukla omza dönüp konmalı")
	o.queue_free()


func test_loot_table_orders_cheap_to_rare() -> void:
	var counts: Dictionary = {}
	var food_tiers: Array = [0, 0, 0, 0, 0, 0]
	var n: int = 4000
	for i in range(n):
		var r: Dictionary = LootScript.roll((float(i) + 0.5) / float(n), fmod(float(i) * 0.6180339, 1.0))
		counts[r["kind"]] = int(counts.get(r["kind"], 0)) + 1
		if r["kind"] == "food":
			food_tiers[int(r["tier"])] += 1
	assert(counts["food"] > counts["shield_orb"] and counts["shield_orb"] > counts["magnet"] and counts["magnet"] > counts["weapon_shard"], "yaygından nadire: %s" % counts)
	assert(float(counts["weapon_shard"]) / n < 0.05 and float(counts["magnet"]) / n < 0.1, "değerliler nadir olmalı")
	for t in range(1, 5):
		assert(food_tiers[t] > food_tiers[t + 1], "düşük yemek kademesi daha sık: %s" % [food_tiers])
	assert(food_tiers[1] > food_tiers[2] * 1.4)
