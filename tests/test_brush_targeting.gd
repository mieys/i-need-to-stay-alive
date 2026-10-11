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
