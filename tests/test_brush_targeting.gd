extends Node

## Saklanma çalılığı hedef kuralı (2026-10-10): silahın sahibi çalılıktaysa SADECE çalılıktaki yaratıkları hedefler (weapon.gd _can_target).

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const WeaponScene: PackedScene = preload("res://scenes/weapon_tabanca.tscn")
const HideBrushScript: GDScript = preload("res://scripts/hide_brush.gd")

var _spawned: Array[Node] = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	HideBrushScript.set_layer_override(null)
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _brush_layer(cells: Array) -> TileMapLayer:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://harita/saklanma_calilik.png")
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	var l := TileMapLayer.new()
	l.tile_set = ts
	add_child(l)
	_track(l)
	for c: Vector2i in cells:
		l.set_cell(c, 0, Vector2i.ZERO)
	HideBrushScript.set_layer_override(l)
	return l


func test_weapon_in_brush_only_targets_creatures_in_brush() -> void:
	## çalılık: x 1000-1160, y 1000-1160 (10x10 hücre)
	var cells: Array = []
	for x in range(62, 72):
		for y in range(62, 72):
			cells.append(Vector2i(x, y))
	_brush_layer(cells)
	var owner_char := Node2D.new()
	add_child(owner_char)
	_track(owner_char)
	owner_char.global_position = Vector2(1080, 1070) ## ayağı çalılıkta
	var w: Node2D = WeaponScene.instantiate()
	owner_char.add_child(w)
	var outside: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(outside)
	outside.global_position = Vector2(1080, 1200) ## çalılığın dışında, daha yakın
	var inside: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(inside)
	inside.global_position = Vector2(1010, 1010) ## çalılıkta, daha uzak
	for i in range(3):
		await get_tree().physics_frame
	assert(not w.call("_can_target", outside), "çalıdaki silah dışarıdaki yaratığı hedefleyemez")
	assert(w.call("_can_target", inside), "çalıdaki yaratık hedeflenebilir")
	## sahip çalıdan çıkınca kural kalkar
	owner_char.global_position = Vector2(1300, 1300)
	assert(w.call("_can_target", outside), "çalı dışında her şey hedeflenebilir")
	_cleanup()


class HidingOwner extends Node2D:
	var brush_state: int = 0


## madde 283: SAKLI (durum 1) sahibin silahı hiçbir yaratığı hedef almaz (silahlar içe çekili); görülünce (durum 2) çalı kuralı geri gelir.
func test_hidden_owner_targets_nothing_until_spotted() -> void:
	var cells: Array = []
	for x in range(62, 72):
		for y in range(62, 72):
			cells.append(Vector2i(x, y))
	_brush_layer(cells)
	var owner_char := HidingOwner.new()
	add_child(owner_char)
	_track(owner_char)
	owner_char.global_position = Vector2(1080, 1070)
	var w: Node2D = WeaponScene.instantiate()
	owner_char.add_child(w)
	var inside: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(inside)
	inside.global_position = Vector2(1010, 1010)
	for i in range(3):
		await get_tree().physics_frame
	owner_char.brush_state = HideBrushScript.STATE_HIDDEN
	assert(not w.call("_can_target", inside), "saklıyken çalıdaki yaratık bile hedeflenmez")
	owner_char.brush_state = HideBrushScript.STATE_SPOTTED
	assert(w.call("_can_target", inside), "görülünce çalıdaki yaratık yine hedeflenir")
	_cleanup()


## madde 283 düzeltmesi (kullanıcı: "silahlar görünmüyor ancak hâlâ ateş edebiliyorlar"): saklıyken HİÇBİR ateş yolu çalışmaz - zamanlayıcı, baktığı yöne ateş
## (fire_in_facing_direction), doğrudan _fire_at (gecikmeli/yankı/salvo). Atış = silahın "fired" sinyali.
func test_hidden_owner_cannot_fire_by_any_path() -> void:
	var cells: Array = []
	for x in range(62, 72):
		for y in range(62, 72):
			cells.append(Vector2i(x, y))
	_brush_layer(cells)
	var owner_char := HidingOwner.new()
	add_child(owner_char)
	_track(owner_char)
	owner_char.global_position = Vector2(1080, 1070)
	var w: Node2D = WeaponScene.instantiate()
	owner_char.add_child(w)
	var inside: Node2D = _track(EnemyScene.instantiate()) as Node2D
	add_child(inside)
	inside.global_position = Vector2(1040, 1060)
	for i in range(3):
		await get_tree().physics_frame
	var shots: Array = [0]
	w.connect("fired", func(_d: Vector2) -> void: shots[0] += 1)
	owner_char.brush_state = HideBrushScript.STATE_HIDDEN
	w.call("_on_fire_timer_timeout")
	w.call("_fire_at", inside)
	w.set("fire_in_facing_direction", true)
	w.call("_on_fire_timer_timeout")
	for i in range(10):
		await get_tree().process_frame
	assert(shots[0] == 0, "saklıyken hiç atış olmamalı: %d" % shots[0])
	## kontrol: görülünce (durum 2) ateş eder
	owner_char.brush_state = HideBrushScript.STATE_SPOTTED
	w.set("fire_in_facing_direction", false)
	w.call("_fire_at", inside)
	for i in range(3):
		await get_tree().process_frame
	assert(shots[0] >= 1, "görülünce ateş edebilmeli")
	_cleanup()
