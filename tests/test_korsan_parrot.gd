extends Node

## Korsan pasifi "Papağan" (2026-09-26) - tek oyunculu mantık: altını bulur, uçar, alır (ayağında en fazla 3), omza
## döner, her altın = miktarı + 1 bonus. Hız = Korsan'ın etkin hareket hızı x1.2. (Çok oyunculu sahiplik yolları
## NetworkManager.host_take_gold_for_parrot / request_parrot_gold / parrot_gold_result - burada tek oyunculu.)
## Aynı gün ikinci tur: bonus altın başına değil TUR başına +1.

const ParrotScript := preload("res://scripts/korsan_parrot.gd")


class FakeOwner extends Node2D:
	var move_speed: float = 200.0

	func get_effective_move_speed() -> float:
		return move_speed


class FakeGold extends Node2D:
	var amount: int = 1

	func _init(a: int) -> void:
		amount = a
		add_to_group("gold_drops")


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


func _make_parrot(o: FakeOwner) -> Node2D:
	var p: Node2D = ParrotScript.new()
	o.add_child(p)
	p.setup(o, o.get_node("AnimatedSprite2D"), false)
	return p


func _run(p: Node2D, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		p._process(1.0 / 60.0)
		t += 1.0 / 60.0


func _clear_gold() -> void:
	for g in get_tree().get_nodes_in_group("gold_drops"):
		g.remove_from_group("gold_drops")
		g.queue_free()


func test_fetches_gold_with_bonus() -> void:
	_clear_gold()
	var o := _make_owner()
	var p := _make_parrot(o)
	var g := FakeGold.new(2)
	add_child(g)
	g.global_position = o.global_position + Vector2(150, 40)
	var before: int = GameManager.gold
	_run(p, 0.3)
	assert(p.state != ParrotScript.State.PERCH, "altını görünce havalanmalı")
	_run(p, 4.0)
	assert(p.state == ParrotScript.State.PERCH, "altını getirip omza konmalı")
	assert(GameManager.gold - before == 3, "2 altın + 1 tur bonusu: %d" % (GameManager.gold - before))
	assert(not p.top_level, "omuzdayken oyuncunun çocuğu gibi izlemeli")
	o.queue_free()


func test_carries_at_most_three() -> void:
	_clear_gold()
	var o := _make_owner()
	var p := _make_parrot(o)
	var golds: Array = []
	for i in range(5):
		var g := FakeGold.new(1)
		add_child(g)
		g.global_position = o.global_position + Vector2(180 + i * 12, 0)
		golds.append(g)
	var before: int = GameManager.gold
	var max_seen: int = 0
	var t := 0.0
	while t < 3.0:
		p._process(1.0 / 60.0)
		max_seen = maxi(max_seen, p._carried.size())
		if p.state == ParrotScript.State.PERCH and t > 0.5:
			break
		t += 1.0 / 60.0
	assert(max_seen == 3, "aynı anda en fazla 3 altın taşımalı: %d" % max_seen)
	assert(GameManager.gold - before == 4, "ilk turda 3 altın + 1 tur bonusu: %d" % (GameManager.gold - before))
	o.queue_free()
	_clear_gold()


func test_speed_is_1_2x_owner_and_ignores_gold_near_owner() -> void:
	_clear_gold()
	var o := _make_owner()
	o.move_speed = 250.0
	var p := _make_parrot(o)
	var near := FakeGold.new(1)
	add_child(near)
	near.global_position = o.global_position + Vector2(30, 0) ## Korsan zaten kendisi alır
	_run(p, 0.5)
	assert(p.state == ParrotScript.State.PERCH, "Korsan'ın dibindeki altın için uçmamalı")
	var far := FakeGold.new(1)
	add_child(far)
	far.global_position = o.global_position + Vector2(250, 0)
	_run(p, 0.3)
	assert(is_equal_approx(p._speed, 250.0 * ParrotScript.SPEED_MULT), "hız 1.2x: %s" % p._speed)
	o.queue_free()
	_clear_gold()


func test_puppet_follows_events() -> void:
	var o := _make_owner()
	var p: Node2D = ParrotScript.new()
	o.add_child(p)
	p.setup(o, o.get_node("AnimatedSprite2D"), true)
	p._process(1.0 / 60.0)
	p.apply_event(ParrotScript.State.FLY_TO, o.global_position + Vector2(100, 0), 2, 300.0)
	assert(p.top_level and p._carry_visual == 2)
	_run(p, 1.0)
	assert(p.global_position.distance_to(o.global_position + Vector2(100, 0)) < 1.0, "kukla hedefe uçmalı")
	p.apply_event(ParrotScript.State.PERCH, Vector2.ZERO, 0, 300.0)
	_run(p, 1.0)
	assert(p.state == ParrotScript.State.PERCH and not p.top_level, "kukla omza dönüp konmalı")
	o.queue_free()
