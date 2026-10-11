extends Node

## Ağaç görevi yeni hâli (2026-10-10): bkz. scripts/mission_tree.gd, mission_tree_bolt.gd, mission_van.gd, player.gd _block_movement_into_blockers.
## Büyüme -> aktif döngü, kademeye göre can/kalkan/vuruş (yaşayan yaratıklardan), kristal mermisi gerçek yaratığa hasar verir (istemci kopyası vermez),
## derinlik (oyuncu arkadayken ağaç üstte), "move_blockers" çarpışması, konvoy hızının oyuncu sayısıyla artması.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const TreeScript: GDScript = preload("res://scripts/mission_tree.gd")
const BoltScript: GDScript = preload("res://scripts/mission_tree_bolt.gd")
const VanScript: GDScript = preload("res://scripts/mission_van.gd")
const WEM: GDScript = preload("res://scripts/world_event_manager.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _spawned: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _enemy(pos: Vector2) -> Node2D:
	var e: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(e)
	e.global_position = pos
	return e


func _tree(pos: Vector2, simulated: bool = true) -> Node2D:
	var t: Node2D = _track(TreeScript.new()) as Node2D
	add_child(t)
	t.global_position = pos
	t.call("setup", 1, simulated)
	return t


func test_tree_grows_then_loops_active_art() -> void:
	var t: Node2D = _tree(Vector2(5000, 5000))
	var anim: AnimatedSprite2D = t.get("_anim")
	assert(anim.animation == &"grow" and anim.sprite_frames.get_frame_count(&"grow") == 3, "önce 3 karelik büyüme")
	assert(anim.sprite_frames.get_frame_count(&"active") == 6 and anim.sprite_frames.get_animation_loop(&"active"), "aktif hâl 6 kare döngü")
	assert(not anim.sprite_frames.get_animation_loop(&"grow"), "büyüme bir kez")
	await get_tree().create_timer(1.6).timeout
	assert(anim.animation == &"active", "büyüme bitince aktif döngü: %s" % anim.animation)
	_cleanup()


func test_stats_follow_the_living_creatures() -> void:
	var e1: Node2D = _enemy(Vector2(7000, 7000))
	var e2: Node2D = _enemy(Vector2(7100, 7000))
	await _frames(2)
	var hp: float = (float(e1.get("max_health")) + float(e2.get("max_health"))) * 0.5
	var dmg: float = (float(e1.get("contact_damage")) + float(e2.get("contact_damage"))) * 0.5
	var t: Node2D = _tree(Vector2(7050, 7400))
	assert(is_equal_approx(float(t.get("max_health")), dmg * TreeScript.HP_PER_ENEMY_HIT), "can = ort. yaratık hasarı x %d" % TreeScript.HP_PER_ENEMY_HIT)
	assert(is_equal_approx(float(t.get("max_shield")), dmg * TreeScript.SHIELD_PER_ENEMY_HIT), "kalkan ölçekli")
	assert(is_equal_approx(float(t.get("bolt_damage")), hp * TreeScript.BOLT_HP_RATIO), "kristal vuruşu = yaratık canının %%34'ü")
	## yaratık yokken eski sabitler
	e1.free(); e2.free()
	var t2: Node2D = _tree(Vector2(9000, 9000))
	assert(is_equal_approx(float(t2.get("max_health")), TreeScript.FALLBACK_MAX_HEALTH), "yaratık yoksa yedek can")
	_cleanup()


func test_crystal_bolt_damages_a_real_creature_and_client_copy_does_not() -> void:
	var e: Node2D = _enemy(Vector2(11000, 11000))
	await _frames(2)
	var hp0: float = float(e.get("health"))
	var b: Node2D = BoltScript.new()
	b.call("setup", e, 40.0)
	add_child(b)
	b.global_position = e.global_position + Vector2(-120, 0)
	await get_tree().create_timer(0.6).timeout
	assert(float(e.get("health")) < hp0, "host mermisi vurdu: %.1f -> %.1f" % [hp0, float(e.get("health"))])
	var hp1: float = float(e.get("health"))
	var c: Node2D = BoltScript.new()
	c.call("setup", e, 0.0)
	add_child(c)
	c.global_position = e.global_position + Vector2(-120, 0)
	await get_tree().create_timer(0.6).timeout
	assert(is_equal_approx(float(e.get("health")), hp1), "istemci (kozmetik) mermisi hasar vermez")
	_cleanup()


func test_tree_draws_over_a_player_behind_it_and_under_one_in_front() -> void:
	var t: Node2D = _tree(Vector2(13000, 13000))
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	_track(p)
	p.global_position = t.global_position + Vector2(10, -40)
	await _frames(2)
	assert(int((t.get("_anim") as Node2D).z_index) == 2, "oyuncu arkada: ağaç üstte")
	p.global_position = t.global_position + Vector2(10, 20)
	await _frames(2)
	assert(int((t.get("_anim") as Node2D).z_index) == 0, "oyuncu önde: ağaç altta")
	_cleanup()


func test_player_cannot_walk_into_the_trunk() -> void:
	var t: Node2D = _tree(Vector2(15000, 15000))
	assert(t.is_in_group("move_blockers"), "ağaç move_blockers grubunda")
	var pl: CharacterBody2D = _track(PlayerScene.instantiate()) as CharacterBody2D
	add_child(pl)
	pl.global_position = t.call("block_center") - Vector2(0.0, 12.75) + Vector2(-20, 0)
	pl.velocity = Vector2(200, 0)
	pl.call("_block_movement_into_blockers")
	assert(pl.velocity.x <= 0.01, "gövdeye doğru hız iptal: %s" % str(pl.velocity))
	pl.velocity = Vector2(-200, 0)
	pl.call("_block_movement_into_blockers")
	assert(pl.velocity.x < -199.0, "uzaklaşmak serbest")
	_cleanup()


func test_escort_speeds_up_noticeably_with_more_pushers() -> void:
	var one: float = 1.0
	var two: float = minf(WEM.ESCORT_MAX_SPEED_MULT, 1.0 + 1.0 * WEM.ESCORT_SPEED_PER_EXTRA_PLAYER)
	var four: float = minf(WEM.ESCORT_MAX_SPEED_MULT, 1.0 + 3.0 * WEM.ESCORT_SPEED_PER_EXTRA_PLAYER)
	assert(two >= one * 1.3 and four >= 2.0, "2 oyuncu >= x1,3, 4 oyuncu >= x2: %.2f / %.2f" % [two, four])
	var v: Node2D = _track(VanScript.new()) as Node2D
	add_child(v)
	assert(v.is_in_group("move_blockers") and v.has_method("block_center"), "konvoy arabası da engel")
	_cleanup()
