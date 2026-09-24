extends Node

## Regresyon: enemy_projectile.gd artık Area2D değil (bkz. dosya başı PERF notu) - isabet, eski Area2D'nin
## kurallarıyla (collision_mask 2, daire-daire örtüşmesi, devre dışı şekil sayılmaz, ağ kopyası hasar vermez)
## mesafeyle hesaplanıyor. Bu testler o kuralların korunduğunu gerçek fizik kareleriyle doğrular.

const EnemyProjectileScene: PackedScene = preload("res://scenes/enemy_projectile.tscn")


class FakeBody extends CharacterBody2D:
	var hits: int = 0
	var last_amount: float = 0.0

	func take_damage(amount: float, _source: Node = null) -> void:
		hits += 1
		last_amount = amount


var _spawned: Array = []


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


func _make_body(pos: Vector2, group: String, layer: int = 2, radius: float = 12.0, body_scale: float = 1.0) -> FakeBody:
	var b := FakeBody.new()
	b.collision_layer = layer
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	b.add_child(cs)
	b.add_to_group(group)
	add_child(b)
	b.global_position = pos
	b.scale = Vector2(body_scale, body_scale)
	_spawned.append(b)
	return b


func _fire(from: Vector2, dir: Vector2, network_copy: bool = false) -> Node2D:
	var p: Node2D = EnemyProjectileScene.instantiate()
	p.direction = dir
	p.damage = 7.0
	if network_copy:
		p.set_meta("network_spawned", true)
	add_child(p)
	p.global_position = from
	_spawned.append(p)
	return p


func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func test_hits_player_layer_body_once_and_frees() -> void:
	var body := _make_body(Vector2(1000, 1000), "player")
	var p := _fire(Vector2(900, 1000), Vector2.RIGHT)
	await _physics_frames(60)
	assert(body.hits == 1, "oyuncu katmanındaki gövdeye tam 1 kez isabet etmeli: %d" % body.hits)
	assert(is_equal_approx(body.last_amount, 7.0), "mermi hasarı aynen iletilmeli")
	assert(not is_instance_valid(p), "isabet eden mermi yok olmalı")
	_cleanup()


func test_hits_remote_player_puppet() -> void:
	var body := _make_body(Vector2(2000, 1000), "remote_players")
	_fire(Vector2(1900, 1000), Vector2.RIGHT)
	await _physics_frames(60)
	assert(body.hits == 1, "RemotePlayer kuklası (remote_players) da hedef olmalı: %d" % body.hits)
	_cleanup()


func test_passes_through_layer_zero_and_disabled_shape() -> void:
	var no_layer := _make_body(Vector2(3000, 1000), "player_allies", 0)
	var dead := _make_body(Vector2(3000, 1200), "remote_players")
	(dead.get_child(0) as CollisionShape2D).disabled = true
	_fire(Vector2(2900, 1000), Vector2.RIGHT)
	_fire(Vector2(2900, 1200), Vector2.RIGHT)
	await _physics_frames(60)
	assert(no_layer.hits == 0, "collision_layer 0 olan gövde (evcil hayvanlar) vurulmamalı")
	assert(dead.hits == 0, "şekli kapalı (ölü) gövde vurulmamalı")
	_cleanup()


func test_network_copy_never_damages_but_disappears() -> void:
	var body := _make_body(Vector2(4000, 1000), "player")
	var p := _fire(Vector2(3900, 1000), Vector2.RIGHT, true)
	await _physics_frames(60)
	assert(body.hits == 0, "ağ görsel kopyası hasar vermemeli")
	assert(not is_instance_valid(p), "ağ kopyası çarpınca yok olmalı")
	_cleanup()


func test_hit_radius_uses_scaled_shape() -> void:
	## Gövde ölçeği 0.5 (main.tscn Player / remote_player.tscn kökü gibi): yarıçap 12 -> etkin 6, mermi 8 -> erişim 14.
	var body := _make_body(Vector2(5000, 1000), "player", 2, 12.0, 0.5)
	_fire(Vector2(4900, 1017), Vector2.RIGHT) ## 17 px yanından geçer -> ıskalamalı
	await _physics_frames(60)
	assert(body.hits == 0, "ölçeklenmiş gövdenin erişimi dışından geçen mermi vurmamalı: %d" % body.hits)
	_fire(Vector2(4900, 1010), Vector2.RIGHT) ## 10 px -> vurmalı
	await _physics_frames(60)
	assert(body.hits == 1, "ölçeklenmiş gövdenin erişimi içinden geçen mermi vurmalı: %d" % body.hits)
	_cleanup()


func test_expires_after_lifetime() -> void:
	var p := _fire(Vector2(-9000, -9000), Vector2.RIGHT)
	await _physics_frames(int(3.2 * Engine.physics_ticks_per_second))
	assert(not is_instance_valid(p), "hedefsiz mermi LIFETIME sonunda kendini silmeli")
	_cleanup()
