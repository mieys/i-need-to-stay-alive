extends Node

## Kullanıcı bildirimi: "yaratıklar collision shapelerin etrafından dolanıp beni
## bulmayı akıl edemiyor" - bkz. scripts/enemy_pathing.gd (yerel AStarGrid2D) ve
## enemy.gd _route_direction. Testler GERÇEK yaratığın _physics_process'ini adım adım
## çalıştırıp (sahte bir "player" hedefiyle) davranışı ölçer; yol bulma KAPALIYKEN
## aynı senaryoda yaratığın takıldığı da doğrulanır (test anlamlı olsun diye).

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const PathingScript: GDScript = preload("res://scripts/enemy_pathing.gd")
const WallLayerFactory: GDScript = preload("res://tests/wall_layer_factory.gd")

const DT := 1.0 / 30.0
const CELL := 16.0
## Yaratık hedefe temas mesafesinde (enemy.gd min_separation, ~46 px) durur; "ulaştı" eşiği.
const REACH := 70.0

var _spawned: Array[Node] = []


func _track(node: Node) -> Node:
	_spawned.append(node)
	return node


func _cleanup() -> void:
	PathingScript.set_enabled(true)
	PathingScript.reset()
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


func _inject_layer(layer: TileMapLayer) -> void:
	GameManager._terrain_forest_layer = layer
	GameManager._terrain_layers_searched = true
	PathingScript.reset()
	PathingScript.set_enabled(true)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL + Vector2(CELL * 0.5, CELL * 0.5)


## Sahte oyuncu hedefi: "player" grubunda düz bir Node2D (enemy.gd sadece
## global_position/has_method/get kullanıyor).
func _make_target(pos: Vector2) -> Node2D:
	var target := Node2D.new()
	target.add_to_group("player")
	add_child(target)
	target.global_position = pos
	_track(target)
	return target


func _make_enemy(pos: Vector2) -> Node2D:
	var enemy: Node2D = EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = pos
	## Sahnedeki agac1 çok yavaş (~28 px/s); testler makul sürede bitsin diye enemy.gd'nin
	## varsayılan hızı (90). Davranış (yol izleme) hızdan bağımsız.
	enemy.speed = 90.0
	_track(enemy)
	return enemy


## İki faz arasında yaratığın yol/sıkışma durumunu sıfırlar.
func _reset_enemy(enemy: Node2D, pos: Vector2, target: Node2D) -> void:
	enemy.global_position = pos
	enemy._route = PackedVector2Array()
	enemy._route_index = 0
	enemy._route_line_blocked = false
	enemy._route_line_timer = 0.0
	enemy._route_replan_timer = 0.0
	enemy._route_active = false
	enemy._is_stuck = false
	enemy._stuck_check_pos = pos
	enemy._stuck_check_timer = 0.0
	## Testte fizik kare sayacı ilerlemediği için enemy.gd'nin 4 karede bir hedef yenilemesi
	## tetiklenmez (oyunda ilerler) - hedefi doğrudan veriyoruz.
	enemy.set("_cached_target_player", target)


## Yaratığı hedefe doğru sürer; hedefin `reach` yakınına gelirse kaç saniyede geldiğini,
## gelmezse -1 döner.
func _simulate(enemy: Node2D, target: Node2D, max_seconds: float, reach: float) -> float:
	var t: float = 0.0
	while t < max_seconds:
		PathingScript.reset_budget()
		enemy._physics_process(DT)
		t += DT
		if enemy.global_position.distance_to(target.global_position) <= reach:
			return t
	return -1.0


## U şeklinde bir cep: açıklık YUKARI bakıyor, hedef cebin ALTINDA -> düz çizgi alt
## duvara çarpar, yaratık önce yukarı çıkıp yandan dolanmalı.
func _u_pocket_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = WallLayerFactory.rect_cells(10, 10, 10, 20) ## sol duvar
	cells.append_array(WallLayerFactory.rect_cells(20, 10, 20, 20)) ## sağ duvar
	cells.append_array(WallLayerFactory.rect_cells(10, 20, 20, 20)) ## alt duvar
	return cells


func test_line_blocked_matches_the_walls() -> void:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, _u_pocket_cells())
	_track(layer)
	_inject_layer(layer)
	assert(PathingScript.prepare(), "Izgara kurulabilmeli")
	assert(PathingScript.line_blocked(_cell_center(Vector2i(15, 15)), _cell_center(Vector2i(15, 30))),
		"Cebin içinden alt duvarın ötesine çizgi engelli olmalı")
	assert(not PathingScript.line_blocked(_cell_center(Vector2i(15, 15)), _cell_center(Vector2i(15, 5))),
		"Cebin açıklığından yukarı çizgi açık olmalı")
	assert(not PathingScript.line_blocked(_cell_center(Vector2i(2, 2)), _cell_center(Vector2i(4, 30))),
		"Cebin dışındaki açık çizgi engelli sayılmamalı")
	## Başlangıç/bitiş hücreleri sayılmaz: duvarın içindeki hedefe açık bir çizgi engelli değil.
	assert(not PathingScript.line_blocked(_cell_center(Vector2i(15, 5)), _cell_center(Vector2i(10, 10))),
		"Hedef duvar hücresindeyse o hücre çizgiyi engellemiş sayılmamalı")
	assert(PathingScript.line_blocked(_cell_center(Vector2i(15, 5)), _cell_center(Vector2i(10, 12))),
		"Çizgi hedef duvar hücresine varmadan ÖNCE başka bir duvar hücresinden geçiyorsa engelli olmalı")
	_cleanup()


func test_find_path_goes_around_the_wall_and_never_enters_it() -> void:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, _u_pocket_cells())
	_track(layer)
	_inject_layer(layer)
	var from: Vector2 = _cell_center(Vector2i(15, 15))
	var to: Vector2 = _cell_center(Vector2i(15, 30))
	var path: PackedVector2Array = PathingScript.find_path(from, to)
	assert(not path.is_empty(), "Cepten hedefe bir yol bulunmalı")
	assert(path[path.size() - 1].distance_to(to) < CELL, "Yol hedef hücresinde bitmeli")
	## Her dönüş noktası boş hücrede, ardışık noktalar arası düz çizgi de duvarsız olmalı.
	var prev: Vector2 = from
	for wp: Vector2 in path:
		assert(layer.get_cell_source_id(layer.local_to_map(layer.to_local(wp))) == -1, "Dönüş noktası duvar hücresinde: %s" % str(wp))
		assert(not PathingScript.line_blocked(prev, wp), "Dönüş noktaları arası çizgi duvara giriyor: %s -> %s" % [str(prev), str(wp)])
		prev = wp
	## Dolanma: yol cebin açıklığına (üstüne, y<10 hücre) çıkmalı.
	var went_above: bool = false
	for wp: Vector2 in path:
		if wp.y < 10.0 * CELL:
			went_above = true
	assert(went_above, "Yol cebin açıklığından dışarı çıkıp dolanmalı")
	_cleanup()


func test_enemy_stuck_without_pathing_reaches_target_with_pathing() -> void:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, _u_pocket_cells())
	_track(layer)
	_inject_layer(layer)
	var target: Node2D = _make_target(_cell_center(Vector2i(15, 30)))
	var enemy: Node2D = _make_enemy(_cell_center(Vector2i(15, 15)))
	_reset_enemy(enemy, _cell_center(Vector2i(15, 15)), target)

	## 1) Yol bulma KAPALI: eski davranış - alt duvara yaslanıp takılır.
	PathingScript.set_enabled(false)
	var t_off: float = _simulate(enemy, target, 25.0, REACH)
	assert(t_off < 0.0, "Yol bulma kapalıyken yaratık hedefe ulaşmamalıydı (test anlamsız olur), süre: %s" % t_off)

	## 2) Yol bulma AÇIK: aynı senaryoda hedefe ulaşmalı.
	PathingScript.set_enabled(true)
	PathingScript.reset()
	_reset_enemy(enemy, _cell_center(Vector2i(15, 15)), target)
	var t_on: float = _simulate(enemy, target, 25.0, REACH)
	assert(t_on > 0.0, "Yol bulma açıkken yaratık cepten çıkıp hedefe ulaşmalı (25 sn içinde), konum: %s" % str(enemy.global_position))
	_cleanup()


func test_open_field_behaviour_is_unchanged() -> void:
	## Aradaki duvar YOKSA yol bulma devreye girmemeli: yaratık düz çizgide yürür.
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, WallLayerFactory.rect_cells(60, 60, 70, 60))
	_track(layer)
	_inject_layer(layer)
	var target: Node2D = _make_target(_cell_center(Vector2i(20, 5)))
	var enemy: Node2D = _make_enemy(_cell_center(Vector2i(5, 5)))
	var dir_direct: Vector2 = (target.global_position - enemy.global_position).normalized()
	var dir: Vector2 = enemy._route_direction(dir_direct, target.global_position, 0.3)
	assert(dir == dir_direct, "Duvar yokken yön doğrudan hedefe olmalı: %s" % str(dir))
	assert(not enemy._route_active, "Duvar yokken rota izleme aktif olmamalı")
	_cleanup()


func test_path_budget_and_unreachable_targets_are_bounded() -> void:
	## Kapalı cep: hedef tamamen duvarla çevrili -> yol boş, bütçe kare başına sınırlı.
	var cells: Array[Vector2i] = WallLayerFactory.rect_cells(30, 30, 40, 30)
	cells.append_array(WallLayerFactory.rect_cells(30, 40, 40, 40))
	cells.append_array(WallLayerFactory.rect_cells(30, 30, 30, 40))
	cells.append_array(WallLayerFactory.rect_cells(40, 30, 40, 40))
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, cells)
	_track(layer)
	_inject_layer(layer)
	var sealed: Vector2 = _cell_center(Vector2i(35, 35))
	var outside: Vector2 = _cell_center(Vector2i(10, 10))
	var path: PackedVector2Array = PathingScript.find_path(outside, sealed)
	assert(path.is_empty(), "Kapalı cebe yol bulunamamalı")
	## Bütçe: kare başına MAX_NEW_PATHS_PER_FRAME kadar istek.
	PathingScript.reset_budget()
	var granted: int = 0
	for i: int in range(PathingScript.MAX_NEW_PATHS_PER_FRAME + 5):
		if PathingScript.can_request():
			granted += 1
			PathingScript.find_path(outside, sealed)
	assert(granted == PathingScript.MAX_NEW_PATHS_PER_FRAME, "Kare bütçesi tam MAX kadar olmalı, verilen: %d" % granted)
	## Duvarın İÇİNDEKİ yaratık için yol aranmaz (eski "içerideyse serbest" güvenlik ağı).
	PathingScript.reset_budget()
	assert(PathingScript.find_path(_cell_center(Vector2i(30, 35)), outside).is_empty(), "Duvar içindeki yaratık için yol aranmamalı")
	_cleanup()


func test_target_standing_inside_a_wall_gets_a_path_to_the_nearest_free_cell() -> void:
	var layer: TileMapLayer = WallLayerFactory.make_layer(self, WallLayerFactory.rect_cells(20, 20, 30, 30))
	_track(layer)
	_inject_layer(layer)
	var from: Vector2 = _cell_center(Vector2i(5, 25))
	var inside: Vector2 = _cell_center(Vector2i(25, 25)) ## 11x11 bloğun tam ortası (en yakın boş hücre 6 uzakta)
	## Ortadaki hücre bloğun içinde ve en yakın boş hücre GOAL_SEARCH_RADIUS'tan uzak -> yol yok
	assert(PathingScript.find_path(from, inside).is_empty(), "Çok derindeki hedef için yol beklenmez")
	PathingScript.reset_budget()
	var edge: Vector2 = _cell_center(Vector2i(20, 25)) ## bloğun kenarındaki duvar hücresi
	var path: PackedVector2Array = PathingScript.find_path(from, edge)
	assert(not path.is_empty(), "Kenardaki duvar hücresindeki hedef için en yakın boş hücreye yol bulunmalı")
	_cleanup()


## GERÇEK harita: duvarın ardındaki rastgele yaratık-oyuncu çiftlerinde başarı oranı.
func test_real_map_enemies_reach_targets_behind_cliffs() -> void:
	var harita: Node2D = HaritaScene.instantiate()
	harita.position = Vector2(-2.0, 21.0) ## main.tscn'deki gibi
	add_child(harita)
	_track(harita)
	var forest: TileMapLayer = harita.get_node("Orman parçaları/Orman parçaları")
	_inject_layer(forest)
	assert(PathingScript.prepare(), "Gerçek haritada ızgara kurulabilmeli")

	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var pairs: Array = []
	var used: Array[Vector2i] = forest.get_used_cells()
	var attempts: int = 0
	while pairs.size() < 20 and attempts < 4000:
		attempts += 1
		var base: Vector2i = used[rng.randi_range(0, used.size() - 1)]
		var a: Vector2i = base + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var ang: float = rng.randf() * TAU
		var d: float = rng.randf_range(14.0, 30.0)
		var b: Vector2i = a + Vector2i(int(cos(ang) * d), int(sin(ang) * d))
		var pa: Vector2 = forest.to_global(forest.map_to_local(a))
		var pb: Vector2 = forest.to_global(forest.map_to_local(b))
		if forest.get_cell_source_id(a) != -1 or forest.get_cell_source_id(b) != -1:
			continue
		if not PathingScript.line_blocked(pa, pb):
			continue
		if PathingScript.find_path(pa, pb).is_empty():
			continue ## (haritada tek bağlı bölge var, yine de kenar durumları eleyelim)
		PathingScript.reset_budget()
		pairs.append([pa, pb])
	assert(pairs.size() >= 10, "Yeterli 'duvarın ardındaki' çift bulunamadı: %d" % pairs.size())

	var target: Node2D = _make_target(Vector2.ZERO)
	var enemy: Node2D = _make_enemy(Vector2.ZERO)
	var arrived_on: int = 0
	var arrived_off: int = 0
	for pair: Array in pairs:
		target.global_position = pair[1]
		for mode: int in [0, 1]:
			PathingScript.set_enabled(mode == 1)
			PathingScript.reset()
			_reset_enemy(enemy, pair[0], target)
			var t: float = _simulate(enemy, target, 45.0, REACH)
			if t >= 0.0:
				if mode == 1:
					arrived_on += 1
				else:
					arrived_off += 1
	print("[gerçek harita] duvarın ardındaki %d çift: yol bulma KAPALI ulaşan=%d, AÇIK ulaşan=%d" % [pairs.size(), arrived_off, arrived_on])
	assert(arrived_on >= int(ceil(pairs.size() * 0.9)),
		"Yol bulma açıkken çiftlerin en az %%90'ı ulaşmalı: %d/%d" % [arrived_on, pairs.size()])
	assert(arrived_on > arrived_off, "Yol bulma ulaşma oranını artırmalı: açık=%d kapalı=%d" % [arrived_on, arrived_off])
	_cleanup()
