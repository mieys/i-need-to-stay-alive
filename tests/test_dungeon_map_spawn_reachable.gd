extends Node

## BATIK NEKROPOL "ÇOK AZ YARATIK" (2026-11-14, kullanıcı: "yaratık az spawnlanıyor, çok sıkıcı"): normal doğuş (enemy_spawner.gd _random_spawn_position) zindan
## haritasında yalnız DUVAR hücresini eliyordu; harita dışı (halka noktalarının %17'si), su (%4) ve nesne (%1) hücresi kabul edilip yaratıkların ~üçte biri
## oyuncuya hiç ulaşamayan yere doğuyordu (tavanı dolduruyor). Artık doğuş / pusu / takılı yaratık kurtarma yalnız doğuştan yürünerek ulaşılabilir zeminde.
## Ana haritada (MissionSpots.active() false) davranış değişmez.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const SpotsScript: GDScript = preload("res://scripts/mission_spots.gd")
const DungeonWorldScript: GDScript = preload("res://scripts/dungeon/dungeon_world.gd")
const DUNGEON_MAP := "batik_nekropol"

var _made: Array[Node] = []


func _spawner() -> Node:
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	_made.append(sp)
	return sp


func _enter_dungeon_mode(map_id: String = DUNGEON_MAP) -> String:
	var prev: String = str(GameManager.selected_map)
	GameManager.selected_map = map_id
	DungeonWorldScript.reset()
	DungeonWorld.test_origin_px = Vector2.ZERO
	SpotsScript.reset()
	return prev


func _leave_dungeon_mode(prev: String) -> void:
	GameManager.selected_map = prev
	DungeonWorld.test_origin_px = null
	DungeonWorldScript.reset()
	SpotsScript.reset()
	for n in _made:
		if is_instance_valid(n):
			n.queue_free()
	_made.clear()


func test_ring_spawns_are_always_on_reachable_floor_in_dungeon_map() -> void:
	var prev: String = _enter_dungeon_mode()
	assert(SpotsScript.active(), "zindan biçimli harita kipi")
	var sp: Node = _spawner()
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var checked: int = 0
	for _p in range(40):
		var center: Vector2 = SpotsScript.pick(rng, 24.0)
		assert(center != Vector2.ZERO, "oyuncu konumu bulundu")
		for _i in range(30):
			var pos: Vector2 = sp._random_spawn_position(center, false, Vector2.ZERO)
			assert(SpotsScript.is_reachable_world(pos), "doğuş ulaşılabilir zeminde olmalı (harita dışı / su / nesne / duvar değil): %s (oyuncu %s)" % [str(pos), str(center)])
			## halka (480-640) ya da yürüme mesafesi yedeği (en çok 640 x 1,3): ekranın dışında, ama uzağa savrulmaz
			var d: float = pos.distance_to(center)
			assert(d >= sp.min_spawn_distance * 0.5 and d <= sp.max_spawn_distance * 1.4, "doğuş mesafesi makul: %.0f" % d)
			checked += 1
	assert(checked == 1200)
	_leave_dungeon_mode(prev)


func test_boss_ring_spawns_are_reachable_too() -> void:
	var prev: String = _enter_dungeon_mode()
	var sp: Node = _spawner()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _p in range(20):
		var center: Vector2 = SpotsScript.pick(rng, 24.0)
		for _i in range(15):
			var pos: Vector2 = sp._random_spawn_position(center, true, Vector2.ZERO)
			assert(SpotsScript.is_reachable_world(pos), "boss doğuşu da ulaşılabilir zeminde: %s" % str(pos))
	_leave_dungeon_mode(prev)


func test_map_edge_player_never_spawns_creatures_outside_the_map() -> void:
	var prev: String = _enter_dungeon_mode()
	var sp: Node = _spawner()
	## haritanın kenarına en yakın yürünür hücreler: eski kural halkanın büyük kısmını harita DIŞINA düşürüyordu
	var data: Resource = load("res://scenes/zindan/%s_data.tres" % DUNGEON_MAP)
	var w: int = data.size.x
	var best: Vector2 = Vector2.ZERO
	var best_x: int = 9999
	for y in range(data.size.y):
		for x in range(w):
			if int(data.cells[y * w + x]) == 0 and x < best_x and SpotsScript.is_reachable_world(Vector2(x, y) * 16.0 + Vector2(8.0, 8.0)):
				best_x = x
				best = Vector2(x, y) * 16.0 + Vector2(8.0, 8.0)
	assert(best != Vector2.ZERO, "kenar hücresi bulundu")
	for _i in range(200):
		var pos: Vector2 = sp._random_spawn_position(best, false, Vector2.ZERO)
		assert(pos.x >= 0.0 and pos.y >= 0.0 and pos.x < 214.0 * 16.0 and pos.y < 214.0 * 16.0, "harita dışına doğmamalı: %s" % str(pos))
		assert(SpotsScript.is_reachable_world(pos), "kenar oyuncusunun doğuşu da ulaşılabilir zeminde: %s" % str(pos))
	_leave_dungeon_mode(prev)


func test_ambush_and_pack_positions_use_the_same_rule() -> void:
	var prev: String = _enter_dungeon_mode()
	var sp: Node = _spawner()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for _p in range(30):
		var center: Vector2 = SpotsScript.pick(rng, 24.0)
		var base: Vector2 = sp._random_spawn_position(center, false, Vector2.ZERO)
		for k in range(1, 4):
			var m: Vector2 = sp._ambush_pack_member_position(base, k)
			assert(m == base or SpotsScript.is_reachable_world(m), "paket üyesi ulaşılabilir zeminde (ya da noktanın kendisinde): %s" % str(m))
		var amb: Variant = sp._ambush_spawn_position(center, Vector2.RIGHT)
		if amb != null:
			assert(SpotsScript.is_reachable_world(Vector2(amb)), "pusu noktası ulaşılabilir zeminde: %s" % str(amb))
	_leave_dungeon_mode(prev)


func test_main_map_spawn_rule_is_unchanged() -> void:
	var prev: String = str(GameManager.selected_map)
	GameManager.selected_map = "ana"
	DungeonWorldScript.reset()
	SpotsScript.reset()
	assert(not SpotsScript.active(), "ana haritada zindan kipi yok")
	var sp: Node = _spawner()
	var center := Vector2(1000.0, 1000.0)
	for _i in range(60):
		var pos: Vector2 = sp._random_spawn_position(center, false, Vector2.ZERO)
		var d: float = pos.distance_to(center)
		assert(d >= sp.min_spawn_distance - 0.5 and d <= sp.max_spawn_distance + 0.5, "ana haritada doğuş yine 480-640 halkasında: %.1f" % d)
		assert(not sp._spawn_point_invalid(pos), "engel yokken geçerli")
	GameManager.selected_map = prev
	DungeonWorldScript.reset()
	SpotsScript.reset()
	for n in _made:
		if is_instance_valid(n):
			n.queue_free()
	_made.clear()
