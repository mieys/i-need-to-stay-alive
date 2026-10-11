extends Node

## Saklanma çalılığı (2026-10-09): bkz. scripts/hide_brush.gd + hide_brush_manager.gd + C++ EnemyWorld.set_stealth.
## Kurallar: çalıya girerken yakında yaratık YOKSA oyuncu saklı (hiçbir yaratık hedeflemez, sınırsız); girerken yakındaki yaratıklar "görenler" olur ve
## çalıda da kovalar; yanından geçen yaratık da görür; çıkınca/ölünce kayıt silinir.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const HideBrushScript: GDScript = preload("res://scripts/hide_brush.gd")
const ManagerScript: GDScript = preload("res://scripts/hide_brush_manager.gd")
const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")
const WallLayerFactory: GDScript = preload("res://tests/wall_layer_factory.gd")

const DT := 1.0 / 30.0
const CELL := 16.0

var _spawned: Array[Node] = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	HideBrushScript.reset()
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _cc(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2(CELL * 0.5, CELL * 0.5)


## Sahte oyuncu: "player" grubunda Node2D (+ yönetici/hedefleme sadece bu üyeleri okur).
class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var brush_state: int = 0

	func set_brush_state(s: int) -> void:
		brush_state = s


func _make_player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_track(p)
	return p


func _make_enemy(pos: Vector2) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.speed = 90.0
	_track(e)
	return e


## Çalılık: (20..24, 20..24) hücreleri; oyuncu ayağı = global_position + FEET_OFFSET.
func _setup_brush() -> TileMapLayer:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, WallLayerFactory.rect_cells(20, 20, 24, 24))
	_track(layer)
	layer.name = HideBrushScript.LAYER_NAME
	HideBrushScript.set_layer_override(layer)
	return layer


func _make_manager() -> Node:
	var m: Node = ManagerScript.new()
	add_child(m)
	m.set_physics_process(false)
	_track(m)
	return m


func _inside_pos() -> Vector2:
	return _cc(Vector2i(22, 22)) - Vector2(0.0, HideBrushScript.FEET_OFFSET)


func _step_world(seconds: float) -> void:
	var b: Node = EnemyWorldBridgeScript._instance
	assert(b != null, "EnemyWorld köprüsü yok")
	b.set_physics_process(false)
	var t: float = 0.0
	while t < seconds:
		b._physics_process(DT)
		t += DT
	b.set_physics_process(true)


func test_alpha_and_layer_lookup_by_name_even_when_nested() -> void:
	assert(is_equal_approx(HideBrushScript.alpha_for(0), 1.0), "çalıda değilken tam opak")
	assert(HideBrushScript.alpha_for(1) < HideBrushScript.alpha_for(2) and HideBrushScript.alpha_for(2) < 1.0, "saklı < görülmüş < 1")
	var harita := Node2D.new()
	_track(harita)
	add_child(harita)
	var grp := Node2D.new()
	grp.name = "Orman parçaları"
	harita.add_child(grp)
	var cells: Array[Vector2i] = [Vector2i(3, 3)]
	var layer: TileMapLayer = WallLayerFactory.make_layer(grp, cells)
	layer.name = HideBrushScript.LAYER_NAME
	assert(HideBrushScript.find_layer(harita) == layer, "Katman başka bir grubun altında da adıyla bulunmalı")
	assert(HideBrushScript.find_layer(null) == null, "null harita -> null")
	_cleanup()


func test_contains_uses_the_feet_cell() -> void:
	var layer: TileMapLayer = _setup_brush()
	var tree: SceneTree = get_tree()
	assert(HideBrushScript.contains(tree, _cc(Vector2i(22, 22))), "Çalı hücresi içeride sayılmalı")
	assert(not HideBrushScript.contains(tree, _cc(Vector2i(19, 22))), "Çalının dışındaki hücre içeride sayılmamalı")
	assert(not HideBrushScript.contains(tree, _cc(Vector2i(22, 26))), "Çalının altındaki hücre içeride sayılmamalı")
	assert(layer != null)
	_cleanup()


func test_entering_unseen_hides_and_enemies_lose_the_player() -> void:
	_setup_brush()
	var player: FakePlayer = _make_player(_cc(Vector2i(10, 22)))
	var enemy: Node2D = _make_enemy(player.global_position + Vector2(600.0, 0.0)) ## SPOT_RADIUS (340) dışında: görmüyor
	await get_tree().process_frame
	var mgr: Node = _make_manager()
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_NONE, "Çalı dışında durum 0, geldi: %d" % player.brush_state)
	## Kontrol: çalıda değilken yaratık yaklaşır.
	_step_world(6.0)
	assert(enemy.global_position.distance_to(player.global_position) < 400.0, "Kontrol: açıkta yaratık oyuncuya yaklaşmalı: %.0f" % enemy.global_position.distance_to(player.global_position))
	## Yaratığı tekrar uzağa al, oyuncu çalıya girsin.
	enemy.global_position = _inside_pos() + Vector2(600.0, 0.0)
	player.global_position = _inside_pos()
	await get_tree().process_frame
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_HIDDEN, "Kimse görmeden girince SAKLI olmalı: %d" % player.brush_state)
	var d0: float = enemy.global_position.distance_to(player.global_position)
	_step_world(8.0)
	var d1: float = enemy.global_position.distance_to(player.global_position)
	assert(d1 > d0 - 150.0, "Saklı oyuncuya yaratık yaklaşmamalı: %.0f -> %.0f" % [d0, d1])
	## Çalıdan çıkınca yeniden hedeflenir.
	player.global_position = _cc(Vector2i(10, 22))
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_NONE, "Çıkınca durum 0")
	_step_world(4.0)
	assert(enemy.global_position.distance_to(player.global_position) < d1 - 100.0, "Çalıdan çıkan oyuncu yeniden hedeflenmeli")
	_cleanup()


func test_spotters_follow_into_the_brush() -> void:
	_setup_brush()
	var player: FakePlayer = _make_player(_cc(Vector2i(14, 22)))
	var enemy: Node2D = _make_enemy(player.global_position + Vector2(-200.0, 0.0)) ## SPOT_RADIUS (340) içinde (0,5 sn yürüyünce ~150 px): GÖRÜYOR
	await get_tree().process_frame
	var mgr: Node = _make_manager()
	mgr.tick()
	_step_world(0.5)
	player.global_position = _inside_pos() ## çalıya gir
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_SPOTTED, "Yaratık görürken girince 'görülmüş' olmalı: %d" % player.brush_state)
	_step_world(10.0)
	assert(enemy.global_position.distance_to(player.global_position) < 90.0, "Gören yaratık çalıya girip oyuncuya ulaşmalı: %.0f" % enemy.global_position.distance_to(player.global_position))
	_cleanup()


func test_a_creature_walking_into_a_hidden_player_notices_them() -> void:
	_setup_brush()
	var player: FakePlayer = _make_player(_inside_pos())
	var enemy: Node2D = _make_enemy(player.global_position + Vector2(700.0, 0.0))
	await get_tree().process_frame
	var mgr: Node = _make_manager()
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_HIDDEN, "başta saklı")
	enemy.global_position = player.global_position + Vector2(30.0, 0.0) ## BUMP_RADIUS (56) içinde
	_step_world(DT) ## C++ dışarıdan taşımayı bir sonraki adımda benimser (EnemyQuery C++ konumundan okur)
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_SPOTTED, "Yanına gelen yaratık oyuncuyu görmeli: %d" % player.brush_state)
	_step_world(4.0)
	assert(enemy.global_position.distance_to(player.global_position) < 90.0, "Fark eden yaratık oyuncunun yanında kalmalı")
	_cleanup()


func test_dead_or_indoors_player_is_not_hidden() -> void:
	_setup_brush()
	var player: FakePlayer = _make_player(_inside_pos())
	await get_tree().process_frame
	var mgr: Node = _make_manager()
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_HIDDEN)
	player.is_dead = true
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_NONE, "Ölü oyuncu saklı sayılmamalı")
	player.is_dead = false
	player.is_indoors = true
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_NONE, "İçerideki oyuncu saklı sayılmamalı")
	_cleanup()


func test_hidden_state_is_cleared_when_the_brush_disappears() -> void:
	var layer: TileMapLayer = _setup_brush()
	var player: FakePlayer = _make_player(_inside_pos())
	await get_tree().process_frame
	var mgr: Node = _make_manager()
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_HIDDEN)
	HideBrushScript.set_layer_override(null)
	layer.get_parent().remove_child(layer) ## katman sahneden gitti (ev içi / ana menü)
	_track(layer)
	mgr.tick()
	assert(player.brush_state == HideBrushScript.STATE_NONE, "Katman yoksa durum temizlenmeli")
	_cleanup()
