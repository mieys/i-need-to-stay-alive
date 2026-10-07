extends Node

## Harita nesnelerinin collision'ı (kullanıcı isteği 2026-10-08: "oyundaki collision shapeleri yeniden hesapla herşey için"; soruyla netleşti: oyuncu + yaratıklar,
## su + evler/demirci + ağaç gövdeleri + maden/düşman üssü). Hesap scripts/terrain_collision.gd (nesne tabanının piksel bandı, ayak hizası için 15 px yukarı
## kaydırılmış), hareket engeli GameManager.is_position_blocked_by_walls, yol bulma/yaratık ızgarası enemy_pathing.gd, C++ EnemyWorld (fog_blocked: görüş SADECE
## orman duvarıyla kesilir). Gerçek harita + gerçek Player/yaratık.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const TerrainCollisionScript: GDScript = preload("res://scripts/terrain_collision.gd")
const DepthScript: GDScript = preload("res://scripts/depth_occluders.gd")
const EnemyPathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")
const SPEED := 120.0
const DT := 0.05

var _harita: Node = null
var _forest: TileMapLayer = null


func _load_map() -> void:
	_harita = HaritaScene.instantiate()
	_harita.name = "Harita"
	(_harita as Node2D).position = Vector2(-2.0, 21.0) ## gerçek oyundaki konum (main.tscn)
	add_child(_harita)
	GameManager._terrain_su_layer = _harita.get_node("Su/Su")
	GameManager._terrain_ev_layer = _harita.get_node("ev/Ev")
	_forest = _harita.get_node("Orman parçaları/Orman parçaları")
	GameManager._terrain_forest_layer = _forest
	GameManager._terrain_layers_searched = true
	TerrainCollisionScript.reset()
	EnemyPathingScript.reset()
	TerrainCollisionScript.ensure(_forest)


func _unload_map() -> void:
	if is_instance_valid(_harita):
		_harita.free()
	_harita = null
	_forest = null
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	TerrainCollisionScript.reset()
	EnemyPathingScript.reset()


func _cell_center(c: Vector2i) -> Vector2:
	return _forest.to_global(_forest.map_to_local(c))


func _blocked_cell(c: Vector2i) -> bool:
	return TerrainCollisionScript.ensure(_forest).has(c) or _forest.get_cell_source_id(c) != -1


func _player(pos: Vector2) -> Node2D:
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	p.global_position = pos
	return p


## Oyuncuyu gerçek hareket engeliyle (player.gd _block_movement_into_terrain) dir yönünde yürütür; ayak = kök + 15.
func _walk(p: Node2D, dir: Vector2, steps: int) -> void:
	for i in range(steps):
		p.velocity = dir.normalized() * SPEED
		p._block_movement_into_terrain()
		p.global_position += p.velocity * DT


func _feet(p: Node2D) -> float:
	return p.global_position.y + 15.0


func test_every_category_is_found_on_the_real_map() -> void:
	_load_map()
	var st: Dictionary = TerrainCollisionScript.stats
	assert(int(st.get("water", 0)) > 1000, "su hücreleri: %s" % str(st))
	assert(int(st.get("houses", 0)) >= 15, "bina tabanı: %s" % str(st))
	assert(int(st.get("trees", 0)) >= 50, "ağaç gövdeleri: %s" % str(st))
	assert(int(st.get("mines", 0)) >= 8, "madenler: %s" % str(st))
	assert(int(st.get("enemy_base", 0)) >= 8, "düşman üssü: %s" % str(st))
	_unload_map()


## Bina: Blacksmith'in duvar tabanı. Önden (güneyden) yürüyen oyuncunun AYAĞI duvar tabanında durur, arkadan (kuzeyden) yürüyen duvar bandına girmez.
func test_player_stops_at_the_smithy_wall_from_the_front_and_from_behind() -> void:
	_load_map()
	var smithy := _harita.get_node("ev/Blacksmith") as TileMapLayer
	var helper: Node = DepthScript.new()
	var bases: Dictionary = helper.building_bases([smithy, _harita.get_node("ev/blacksmith kapı")])[smithy]
	var base: float = 0.0
	var sum_x: float = 0.0
	for c: Vector2i in bases:
		base = maxf(base, float(bases[c]))
		sum_x += smithy.to_global(smithy.map_to_local(c)).x
	var x: float = sum_x / float(bases.size())
	helper.free()
	var front: Node2D = _player(Vector2(x, base - 15.0 + 60.0))
	assert(not GameManager.is_position_blocked_by_walls(front.global_position), "başlangıç noktası serbest olmalı")
	_walk(front, Vector2.UP, 60)
	assert(_feet(front) >= base - 3.0 and _feet(front) <= base + 22.0,
		"önden: ayak duvar tabanında durmalı (taban %s, ayak %s)" % [base, _feet(front)])
	front.free()
	var behind: Node2D = _player(Vector2(x, base - 15.0 - 130.0))
	assert(not GameManager.is_position_blocked_by_walls(behind.global_position), "arka başlangıç noktası serbest olmalı")
	_walk(behind, Vector2.DOWN, 60)
	assert(_feet(behind) < base - 18.0 and _feet(behind) > base - 130.0,
		"arkadan: duvar bandının içine girmemeli (taban %s, ayak %s)" % [base, _feet(behind)])
	behind.free()
	_unload_map()


## Ağaç gövdesi: gövde hücresine doğru yürüyen oyuncu hücreye girmez.
func test_player_cannot_walk_into_a_tree_trunk() -> void:
	_load_map()
	var cells: Array = TerrainCollisionScript.by_category.get("trees", [])
	var checked: int = 0
	for c: Vector2i in cells:
		var below: Vector2i = c + Vector2i(0, 4)
		if _blocked_cell(below) or _blocked_cell(c + Vector2i(0, 3)) or _blocked_cell(c + Vector2i(0, 2)) or _blocked_cell(c + Vector2i(0, 1)):
			continue ## altı serbest bir gövde hücresi (düz yaklaşma)
		var p: Node2D = _player(_cell_center(below))
		_walk(p, Vector2.UP, 40)
		var fc: Vector2i = _forest.local_to_map(_forest.to_local(p.global_position))
		assert(not _blocked_cell(fc) and fc.y > c.y, "gövde hücresine %s girildi: oyuncu hücresi %s" % [str(c), str(fc)])
		p.free()
		checked += 1
		if checked >= 12:
			break
	assert(checked >= 5, "yeterli gövde hücresi denenemedi: %d" % checked)
	_unload_map()


## Su: kıyıdan suya doğru yürüyen oyuncu suya girmez; köprü güvertesinin hücreleri engel DEĞİL (köprüden yürünür).
func test_player_stops_at_the_water_and_bridge_decks_stay_open() -> void:
	_load_map()
	var water: Array = TerrainCollisionScript.by_category.get("water", [])
	var checked: int = 0
	for c: Vector2i in water:
		var ok: bool = true
		for k in range(1, 5):
			if _blocked_cell(c + Vector2i(0, k)):
				ok = false
		if not ok:
			continue
		var p: Node2D = _player(_cell_center(c + Vector2i(0, 4)))
		_walk(p, Vector2.UP, 30)
		var fc: Vector2i = _forest.local_to_map(_forest.to_local(p.global_position))
		assert(not _blocked_cell(fc) and fc.y > c.y, "suya girildi: su hücresi %s, oyuncu hücresi %s" % [str(c), str(fc)])
		p.free()
		checked += 1
		if checked >= 12:
			break
	assert(checked >= 5, "yeterli kıyı noktası denenemedi: %d" % checked)
	var bridge := _harita.get_node("Köprü/Köprü alt") as TileMapLayer
	var open_cells: int = 0
	var cells: Dictionary = TerrainCollisionScript.ensure(_forest)
	for c: Vector2i in bridge.get_used_cells():
		assert(not cells.has(c + Vector2i(0, -1)), "köprü güvertesi hücresi engel kalmış: %s" % str(c))
		open_cells += 1
	assert(open_cells > 20, "köprü katmanı bulunamadı/boş")
	_unload_map()


## Yaratık spawnı, ışınlanma vb. is_position_blocked_by_terrain ile bu nesnelerin üstüne düşmez; mermi/görüş sorgusu (orman) bunlardan etkilenmez.
func test_terrain_query_includes_objects_but_forest_query_does_not() -> void:
	_load_map()
	for cat in ["water", "houses", "trees", "mines", "enemy_base"]:
		var list: Array = TerrainCollisionScript.by_category.get(cat, [])
		assert(not list.is_empty(), "%s boş" % cat)
		var c: Vector2i = list[0]
		var pos: Vector2 = _cell_center(c)
		assert(GameManager.is_position_blocked_by_walls(pos) and GameManager.is_position_blocked_by_terrain(pos), "%s hücresi engel olmalı: %s" % [cat, str(c)])
		if _forest.get_cell_source_id(c) == -1:
			assert(not GameManager.is_position_blocked_by_forest(pos), "%s hücresi ORMAN sorgusunda engel olmamalı (mermi/görüş)" % cat)
	_unload_map()


## Yol bulma/yaratık ızgarası: _blocked = orman + nesneler, _fog_blocked = SADECE orman (görüş sis kesilmesin).
func test_pathing_grid_has_objects_but_the_fog_grid_is_forest_only() -> void:
	_load_map()
	assert(EnemyPathingScript.prepare(), "yol bulma ızgarası kurulmalı")
	var blocked: int = 0
	var fog: int = 0
	for i in range(EnemyPathingScript._blocked.size()):
		blocked += 1 if EnemyPathingScript._blocked[i] != 0 else 0
		fog += 1 if EnemyPathingScript._fog_blocked[i] != 0 else 0
	assert(fog == _forest.get_used_cells().size(), "fog ızgarası tam orman hücreleri olmalı: %d / %d" % [fog, _forest.get_used_cells().size()])
	assert(blocked > fog + 3000, "hareket ızgarası orman + su/bina/ağaç/maden içermeli: %d / %d" % [blocked, fog])
	var w: Vector2i = TerrainCollisionScript.by_category["water"][0]
	assert(EnemyPathingScript._is_solid(w), "su hücresi yol bulma ızgarasında engel olmalı")
	_unload_map()


func _step_bridge(frames: int, each: Callable = Callable()) -> void:
	var b: Node = EnemyWorldBridgeScript._instance
	b.set_physics_process(false)
	for i in frames:
		b._physics_process(1.0 / 60.0)
		if each.is_valid():
			each.call()
	b.set_physics_process(true)


## C++ yaratığı: sudan geçmez (is_solid_at su hücresinde true, yürürken hiç içine girmez).
func test_creature_does_not_walk_into_water() -> void:
	_load_map()
	var water: Array = TerrainCollisionScript.by_category.get("water", [])
	var pick: Vector2i = Vector2i.ZERO
	var found: bool = false
	for c: Vector2i in water:
		var clear: bool = true
		for k in range(1, 7):
			if _blocked_cell(c + Vector2i(0, k)):
				clear = false
		if clear:
			pick = c
			found = true
			break
	assert(found, "açık kıyı bulunamadı")
	var target := Node2D.new()
	target.add_to_group("player")
	add_child(target)
	target.global_position = _cell_center(pick) + Vector2(0.0, -48.0) ## suyun öte yanında
	var enemy: Node2D = EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = _cell_center(pick + Vector2i(0, 4))
	await get_tree().process_frame
	var world: Object = enemy._ew_world
	assert(world != null, "yaratık C++'a kaydolmalı")
	assert(bool(world.call("is_solid_at", _cell_center(pick))), "C++ ızgarasında su hücresi engel olmalı")
	var entered: Array = [0]
	_step_bridge(180, func() -> void:
		if bool(world.call("is_solid_at", enemy.global_position)):
			entered[0] += 1)
	assert(entered[0] == 0, "yaratık suya/engele girdi (%d kare)" % entered[0])
	target.free()
	enemy.free()
	_unload_map()


## GÖRÜŞ: su/bina/ağaç görüşü KESMEZ (kıyıdan suyun öte yanındaki yaratık görünür), orman duvarı keser (duvarın arkasındaki gizli).
func test_water_does_not_cut_the_fog_but_forest_walls_still_do() -> void:
	_load_map()
	var cells: Dictionary = TerrainCollisionScript.ensure(_forest)
	## Yatay bir su şeridi: [sol ucu serbest][>= 4 su hücresi][sağ ucu serbest], hiç orman yok.
	var src: Vector2 = Vector2.INF
	var dst: Vector2 = Vector2.INF
	for c: Vector2i in TerrainCollisionScript.by_category.get("water", []):
		var left: Vector2i = c + Vector2i(-1, 0)
		if cells.has(left) or _forest.get_cell_source_id(left) != -1:
			continue
		var run: int = 0
		while run < 10 and cells.has(c + Vector2i(run, 0)) and _forest.get_cell_source_id(c + Vector2i(run, 0)) == -1:
			run += 1
		var right: Vector2i = c + Vector2i(run, 0)
		if run >= 4 and run <= 8 and not _blocked_cell(right):
			src = _cell_center(left)
			dst = _cell_center(right)
			break
	assert(src != Vector2.INF, "su şeridi bulunamadı")
	var enemy: Node2D = EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = dst
	await get_tree().process_frame
	var world: Object = enemy._ew_world
	assert(world != null, "yaratık C++'a kaydolmalı")
	_step_bridge(1)
	world.call("fog_update", PackedVector2Array([src]), 400.0, 1.4, 0.2, 0.05, 1, 1)
	assert(enemy.visible, "suyun öte yanındaki yaratık görünür kalmalı (su görüşü kesmez), uzaklık %s" % src.distance_to(dst))
	## Kontrol: aynı yaratık orman duvarının arkasındaysa gizlenir.
	var wall: Dictionary = {}
	for c: Vector2i in _forest.get_used_cells():
		if _forest.get_cell_source_id(c + Vector2i(0, -1)) != -1 or cells.has(c + Vector2i(0, -1)):
			continue
		var k: int = 1
		while k < 8 and _forest.get_cell_source_id(c + Vector2i(0, k)) != -1:
			k += 1
		if k >= 2 and k < 8 and not _blocked_cell(c + Vector2i(0, k)):
			wall = {"src": _cell_center(c + Vector2i(0, -1)), "dst": _cell_center(c + Vector2i(0, k))}
			break
	assert(not wall.is_empty(), "orman duvarı bulunamadı")
	enemy.global_position = wall["dst"]
	_step_bridge(1)
	world.call("fog_reset")
	world.call("fog_update", PackedVector2Array([wall["src"]]), 400.0, 1.4, 0.2, 0.05, 1, 2)
	assert(not enemy.visible, "orman duvarının arkasındaki yaratık gizlenmeli")
	enemy.free()
	_unload_map()
