extends Node

## Bumerang (2026-09-26): birimlerin içinden geçmez - gidişte ilk düşmana çarpıp döner, dönüşte vurmaz; görünüm sakin
## (24 kare, yavaş dönüş, hava çizgisi yok, tek hayalet); boyu kafadaki ikonla aynı ve ikon %20 küçük.

const BoomerangScene: PackedScene = preload("res://scenes/boomerang_projectile.tscn")
const WeaponScene: PackedScene = preload("res://scenes/weapon_boomerang.tscn")


class FakeEnemy extends Node2D:
	var hits: int = 0

	func _init() -> void:
		add_to_group("enemies")

	func take_damage(_amount: float, _crit: bool = false, _pen: float = 0.0, _area: bool = false) -> void:
		hits += 1


func _make_proj() -> Area2D:
	var p: Area2D = BoomerangScene.instantiate() as Area2D
	add_child(p)
	p.set("impact_sounds", [] as Array[AudioStream]) ## test sessiz
	p.set("impact_scene", null)
	return p


func test_bounces_off_first_enemy_and_ignores_hits_on_return() -> void:
	var p: Area2D = _make_proj()
	var a := FakeEnemy.new()
	var b := FakeEnemy.new()
	add_child(a)
	add_child(b)
	assert(p.get("_returning") == false)
	p._on_body_entered(a)
	assert(a.hits == 1, "ilk düşmana vurmalı")
	assert(p.get("_returning") == true, "çarpınca geri dönmeli (içinden geçmemeli)")
	p._on_body_entered(b)
	assert(b.hits == 0, "dönüşte vurmamalı")
	p.queue_free()
	a.queue_free()
	b.queue_free()


func test_network_copy_also_bounces() -> void:
	var p: Area2D = _make_proj()
	p.set_meta("network_spawned", true)
	var a := FakeEnemy.new()
	add_child(a)
	p._on_body_entered(a)
	assert(a.hits == 0, "kozmetik kopya hasar vermez")
	assert(p.get("_returning") == true, "kozmetik kopya da çarptığı yerden dönmeli")
	p.queue_free()
	a.queue_free()


func test_body_matches_head_icon_and_icon_is_20_percent_smaller() -> void:
	var w: Node2D = WeaponScene.instantiate() as Node2D
	var icon: Sprite2D = w.get_node("Icon") as Sprite2D
	assert(is_equal_approx(icon.scale.x, 0.4125 * 0.8), "ikon %%20 küçük olmalı: %s" % icon.scale.x)
	var script: Script = load("res://scripts/boomerang_projectile.gd")
	var icon_scale: float = script.get_script_constant_map()["ICON_SCALE"]
	assert(is_equal_approx(icon_scale, icon.scale.x), "mermi gövdesi ikonla aynı ölçekten hesaplanmalı")
	w.free()


func test_calm_visuals() -> void:
	var p: Area2D = _make_proj()
	assert(is_equal_approx(float(p.get("spin_speed_deg")), 480.0), "dönüş yavaşlamalı: %s" % p.get("spin_speed_deg"))
	var fx: Node = p.get_node_or_null("SpinFx")
	assert(fx == null or not (fx as CanvasItem).visible, "hava çizgileri kapalı olmalı")
	p.scale = Vector2(0.5, 0.5) ## weapon.gd _fire_at: karakterin kök ölçeği
	p._update_trail(0.016) ## hayalet ölçeği kurulduktan sonra görünür olur
	var visible_ghosts := 0
	for n in ["Trail1", "Trail2", "Trail3"]:
		var t: CanvasItem = p.get_node_or_null(n) as CanvasItem
		if t and t.visible:
			visible_ghosts += 1
	assert(visible_ghosts == 1, "tek soluk hayalet kalmalı: %d" % visible_ghosts)
	var ghost: Node2D = p.get_node("Trail1") as Node2D
	assert(is_equal_approx(ghost.global_scale.x, p.BODY_SCALE * p.GHOST_SCALE * absf(p.global_scale.x)),
		"hayalet (top_level) kökün ölçeğini hesaba katmalı: %s" % ghost.global_scale)
	var body: AnimatedSprite2D = p.get("_body")
	assert(body.sprite_frames.get_frame_count("spin") == 24, "24 karelik dönüş")
	p.queue_free()


func test_slows_near_apex() -> void:
	var p: Area2D = _make_proj()
	p.set("direction", Vector2.RIGHT)
	p.set("speed", 100.0)
	p.set("throw_distance", 100.0)
	p.set("player_node", self)
	var start: float = p.position.x
	p._physics_process(0.1)
	var first_step: float = p.position.x - start
	p.set("_traveled", 90.0)
	var before: float = p.position.x
	p._physics_process(0.1)
	var late_step: float = p.position.x - before
	assert(late_step < first_step * 0.6, "uca yaklaşırken yavaşlamalı: %s vs %s" % [late_step, first_step])
	p.queue_free()
