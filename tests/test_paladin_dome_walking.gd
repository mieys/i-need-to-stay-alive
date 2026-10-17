extends Node

## Şovalye "Yürüyen Kale" (R evrimi): kubbe oyuncuyla birlikte yürürken yaratıklar elipsin İÇİNE girmemeli
## (2026-10-17, kullanıcı: "hareket edebildiği esnada yaratıkları doğru geri itmiyor, içine giriyorlar").

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const EnemyScript: GDScript = preload("res://scripts/enemy.gd")
const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const DT := 1.0 / 60.0
const R := 126.0

var _spawned: Array[Node] = []


func _track(node: Node) -> Node:
	_spawned.append(node)
	return node


func _cleanup() -> void:
	EnemyScript.reset_zone_owners_cache()
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


class FakePlayer extends Node2D:
	var paladin_zone_active: bool = true
	var paladin_zone_radius: float = 126.0
	var is_dead: bool = false

	func take_paladin_barrier_damage(_amount: float, _attacker: Node2D = null) -> void:
		pass

	func take_damage(_amount: float, _source: Node = null) -> void:
		pass


func _make_player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_track(p)
	return p


func _make_enemy(pos: Vector2) -> Node2D:
	EnemyScript.reset_zone_owners_cache()
	var enemy: Node2D = EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	enemy.speed = 90.0
	_track(enemy)
	return enemy


func _bridge() -> Node:
	return EnemyWorldBridgeScript._instance


## Elips içi kaçınılmaz derinlik: merkezden o yöndeki kenara göre ne kadar İÇERİDE (px; pozitif = içeride).
func _penetration(enemy: Node2D, center: Vector2) -> float:
	var d: Vector2 = enemy.global_position - center
	if d.length() < 0.01:
		return R
	var u: Vector2 = d.normalized()
	var edge: float = R / sqrt(u.x * u.x + 4.0 * u.y * u.y)
	return edge - d.length()


## Şovalye `speed` px/sn ile `dir` yönünde yürür; çevresindeki yaratıkların en kötü içeri girme derinliğini döndürür.
func _walk_and_measure(speed: float, dir: Vector2, seconds: float) -> Dictionary:
	var paladin := _make_player(Vector2.ZERO)
	var enemies: Array[Node2D] = []
	## Yürüyüş yönünün ÖNÜNDE ve etrafında halka: kubbe üzerlerine yürüyecek
	for k in 24:
		var a: float = TAU * float(k) / 24.0
		var ring: float = 150.0 + 30.0 * float(k % 3)
		enemies.append(_make_enemy(Vector2(cos(a), sin(a) * 0.5) * ring))
	for k in 8:
		enemies.append(_make_enemy(dir * (170.0 + 25.0 * float(k)) + dir.orthogonal() * (float(k % 4) - 1.5) * 18.0))
	await get_tree().process_frame
	var b: Node = _bridge()
	b.set_physics_process(false)
	var worst: float = -INF
	var worst_t: float = 0.0
	var trace: Array[String] = []
	## Önce kubbe DURAĞAN: yaratıklar gelip kenara dizilsin (uyanma/yaklaşma evresi ölçüme girmesin)
	var settle: float = 0.0
	while settle < 4.0:
		b._physics_process(DT)
		settle += DT
	var t: float = 0.0
	while t < seconds:
		paladin.global_position += dir * speed * DT
		b._physics_process(DT)
		t += DT
		for ei in enemies.size():
			var e: Node2D = enemies[ei]
			var p: float = _penetration(e, paladin.global_position)
			if p > 20.0 and trace.size() < 14:
				trace.append("t=%.2f e%d rel=%s pen=%.0f" % [t, ei, (e.global_position - paladin.global_position).round(), p])
			if p > worst:
				worst = p
				worst_t = t
	b.set_physics_process(true)
	return {"worst": worst, "t": worst_t, "trace": " | ".join(trace)}


func test_dome_walking_slow_does_not_let_creatures_in() -> void:
	var r: Dictionary = await _walk_and_measure(25.0, Vector2.RIGHT, 8.0)
	_cleanup()
	assert(r["worst"] <= 2.0, "Yavaş yürüyen kubbede yaratık içeri girdi: %s px (t=%s)" % [r["worst"], r["trace"]])


func test_dome_walking_fast_does_not_let_creatures_in() -> void:
	var r: Dictionary = await _walk_and_measure(120.0, Vector2(1.0, 0.4).normalized(), 8.0)
	_cleanup()
	assert(r["worst"] <= 2.0, "Hızlı yürüyen kubbede yaratık içeri girdi: %s px (t=%s)" % [r["worst"], r["trace"]])


func test_dome_walking_down_does_not_let_creatures_in() -> void:
	var r: Dictionary = await _walk_and_measure(60.0, Vector2.DOWN, 8.0)
	_cleanup()
	assert(r["worst"] <= 2.0, "Aşağı yürüyen kubbede yaratık içeri girdi: %s px (t=%s)" % [r["worst"], r["trace"]])


## Kubbe SERT bariyer: dondurulmuş yaratık yürüyen kubbenin içinde kalmaz (eskiden donukken hiç itilmiyordu).
func test_frozen_creature_is_pushed_out_by_walking_dome() -> void:
	var paladin := _make_player(Vector2.ZERO)
	var enemy: Node2D = _make_enemy(Vector2(170.0, 0.0))
	await get_tree().process_frame
	var b: Node = _bridge()
	b.set_physics_process(false)
	for _i in 120:
		b._physics_process(DT) ## kenara dizilsin
	enemy.apply_freeze_full(30.0)
	var worst: float = -INF
	for _i in 240:
		paladin.global_position += Vector2.RIGHT * 70.0 * DT
		b._physics_process(DT)
		worst = maxf(worst, _penetration(enemy, paladin.global_position))
	b.set_physics_process(true)
	var was_frozen: bool = enemy.is_frozen
	_cleanup()
	assert(was_frozen, "Test kurulumu: yaratık donmuş olmalıydı")
	assert(worst <= 2.0, "Donmuş yaratık yürüyen kubbenin içine girdi: %s px" % worst)


## Silah darbesiyle kubbeye doğru savrulan yaratık (geri itme hızı >= 40: gövde yapıştırması atlanıyordu) içeri giremez.
func test_creature_knocked_inward_cannot_enter_the_dome() -> void:
	var paladin := _make_player(Vector2.ZERO)
	var enemy: Node2D = _make_enemy(Vector2(140.0, 0.0))
	await get_tree().process_frame
	var b: Node = _bridge()
	b.set_physics_process(false)
	for _i in 120:
		b._physics_process(DT)
	var worst: float = -INF
	for k in 90:
		if k % 15 == 0:
			enemy.apply_knockback_force(Vector2.LEFT, 600.0) ## tekrar tekrar içeri doğru vurulur
		b._physics_process(DT)
		worst = maxf(worst, _penetration(enemy, paladin.global_position))
	b.set_physics_process(true)
	_cleanup()
	assert(worst <= 2.0, "Geri itilen yaratık kubbenin içine girdi: %s px" % worst)


## İstemci kuklası: host konumu (gecikmeli kubbeye göre) kubbenin İÇİNDE olsa bile bu ekranda kubbenin dışında çizilir.
func test_client_puppet_is_kept_outside_the_dome() -> void:
	var paladin := _make_player(Vector2.ZERO)
	var enemy: Node2D = _make_enemy(Vector2(300.0, 0.0))
	await get_tree().process_frame
	enemy._ew_puppet = true ## istemci kuklası (C++ F_PUPPET)
	var b: Node = _bridge()
	b.set_physics_process(false)
	var worst: float = -INF
	for _i in 120:
		enemy._ew_world.set_net_target(enemy._ew_slot, Vector2(40.0, 10.0), Vector2.ZERO) ## host'a göre kubbenin içinde
		b._physics_process(DT)
		worst = maxf(worst, _penetration(enemy, paladin.global_position))
	b.set_physics_process(true)
	_cleanup()
	assert(worst <= 2.0, "İstemci kuklası kubbenin içine girdi: %s px" % worst)
