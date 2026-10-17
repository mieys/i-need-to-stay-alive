extends Node

## Kullanıcı isteği (2026-10-14): "silahların mermilerin menzili sınırsız gibi, ıskalayınca bile çok uzağa gitmemeli, görüş açısıyla
## sınırlı olmalı (yaratıklar dahil)" -> scripts/projectile_range.gd. "yakın dövüşçü yaratıkların menzili çok uzun hissettiriyor"
## -> enemy.gd MELEE_REACH_EXTRA / MELEE_HIT_TOLERANCE.

const RangeScript: GDScript = preload("res://scripts/projectile_range.gd")
const VisionFog: GDScript = preload("res://scripts/vision_fog.gd")
const EnemyProjectileScene: PackedScene = preload("res://scenes/enemy_projectile.tscn")

var _made: Array[Node] = []


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func test_within_is_the_vision_ellipse_around_the_launch_point() -> void:
	var n := Node2D.new()
	add_child(n)
	_made.append(n)
	n.global_position = Vector2(1000.0, 1000.0)
	assert(RangeScript.within(n), "ilk çağrı çıkış noktasını kaydeder")
	n.global_position = Vector2(1000.0 + VisionFog.VISION_RADIUS * VisionFog.VISION_WIDTH_SCALE - 5.0, 1000.0)
	assert(RangeScript.within(n), "yatayda elipsin içi")
	n.global_position = Vector2(1000.0 + VisionFog.VISION_RADIUS * VisionFog.VISION_WIDTH_SCALE + 20.0, 1000.0)
	assert(not RangeScript.within(n), "yatayda elipsin dışı")
	n.global_position = Vector2(1000.0, 1000.0 + VisionFog.VISION_RADIUS + 20.0)
	assert(not RangeScript.within(n), "dikeyde elips daha dar")
	_cleanup()


func test_missed_enemy_projectile_disappears_at_the_vision_edge() -> void:
	var p: Node2D = EnemyProjectileScene.instantiate()
	p.direction = Vector2.RIGHT
	p.damage = 1.0
	add_child(p)
	p.global_position = Vector2(5000.0, 5000.0)
	_made.append(p)
	await _physics_frames(30) ## ~0,5 sn = ~100 px
	assert(is_instance_valid(p), "görüş içinde uçmaya devam eder")
	await _physics_frames(140) ## toplam ~2,8 sn: eski ömür (3 sn) dolmadan, ~580 px > 350 px görüş
	assert(not is_instance_valid(p) or p.is_queued_for_deletion(), "ıskalayan mermi görüş sınırında silinmeli")
	_cleanup()


func test_melee_swing_needs_the_creature_to_be_close_to_the_body() -> void:
	var e: Node2D = Enemy.new()
	_made.append(e)
	var target := Node2D.new()
	add_child(target)
	target.add_to_group("player")
	_made.append(target)
	var sep: float = (e._body_radius + Enemy.PLAYER_BODY_RADIUS) * GameManager.BODY_BLOCK_SCALE
	e.position = Vector2.ZERO
	target.global_position = Vector2(sep + Enemy.MELEE_REACH_EXTRA - 1.0, 0.0)
	assert(not e._melee_too_far(target), "menzil içinde vurur")
	target.global_position = Vector2(sep + Enemy.MELEE_REACH_EXTRA + 1.0, 0.0)
	assert(e._melee_too_far(target), "eski 26 px'lik uzaktan vurma artık yok")
	assert(Enemy.MELEE_REACH_EXTRA < 26.0 and Enemy.MELEE_HIT_TOLERANCE < 40.0, "eski değerlerden kısa")
	var other := Node2D.new()
	other.global_position = Vector2(500.0, 0.0)
	_made.append(other)
	assert(not e._melee_too_far(other), "oyuncu olmayan hedefte süzme yok (ağaç/müttefik)")
	e.free()
	_made.erase(e)
	_cleanup()
