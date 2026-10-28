extends SceneTree

## TerrainCollision._build bölümlerinin süresi (madde 371): su / ev / ağaç / maden / üs / derin orman / props ayrı ayrı ms (aynı çağrılar, aynı sıra).
## Kullanım: Godot --headless --path . -s res://tools/fps_micro/terrain_profil.gd


func _initialize() -> void:
	_run.call_deferred()


func _ms(t0: int) -> String:
	return "%.0f ms" % (float(Time.get_ticks_usec() - t0) / 1000.0)


func _run() -> void:
	var tc: GDScript = load("res://scripts/terrain_collision.gd")
	var depth: GDScript = load("res://scripts/depth_occluders.gd")
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var h: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	h.name = "Harita"
	h.position = Vector2(-2, 21)
	scene.add_child(h)
	await process_frame
	var forest: TileMapLayer = h.get_node("Orman parçaları/Orman parçaları")
	tc.call("reset")
	var helper: Node = depth.new()
	var g0: Vector2 = helper.call("cell_origin", forest)
	var t: int = Time.get_ticks_usec()
	tc.call("_add_water", helper, h, g0)
	print("TP su=", _ms(t))
	t = Time.get_ticks_usec()
	var layers: Array[TileMapLayer] = []
	for path: String in tc.get("HOUSE_WALL_LAYERS"):
		var l := h.get_node_or_null(path) as TileMapLayer
		if l != null and l.tile_set != null and not l.get_used_cells().is_empty():
			layers.append(l)
	var per_layer: Dictionary = helper.call("building_bases", layers)
	print("TP ev building_bases=", _ms(t))
	t = Time.get_ticks_usec()
	var parent: Node = h.get_node_or_null(tc.get("TREE_PARENT"))
	var tree_ms: Array[String] = []
	for child in parent.get_children():
		var l := child as TileMapLayer
		if l != null and l.tile_set != null and String(l.name).begins_with(tc.get("TREE_PREFIX")):
			var t1: int = Time.get_ticks_usec()
			helper.call("object_bases", l)
			tree_ms.append("%s=%s (%d hücre)" % [l.name, _ms(t1), l.get_used_cells().size()])
	print("TP ağaç object_bases toplam=", _ms(t), " ", ", ".join(tree_ms))
	t = Time.get_ticks_usec()
	for path: String in tc.get("DEEP_FOREST_LAYERS"):
		var l := h.get_node_or_null(path) as TileMapLayer
		if l != null:
			var t1: int = Time.get_ticks_usec()
			var g: Array = tc.call("object_groups", helper, l, false)
			print("TP derin orman ", path.get_file(), " object_groups=", _ms(t1), " nesne=", g.size(), " hücre=", l.get_used_cells().size())
	print("TP derin orman toplam=", _ms(t))
	t = Time.get_ticks_usec()
	for path: String in tc.get("PROP_LAYERS"):
		var l := h.get_node_or_null(path) as TileMapLayer
		if l != null:
			var t1: int = Time.get_ticks_usec()
			var ob: Dictionary = helper.call("object_bases", l)
			var t2: int = Time.get_ticks_usec()
			var g: Array = tc.call("object_groups", helper, l)
			print("TP props ", path.get_file(), " object_bases=", _ms(t1), " object_groups(renkli, object_bases dahil)=", _ms(t2), " nesne=", g.size(), " hücre=", l.get_used_cells().size())
	print("TP props toplam=", _ms(t))
	helper.free()
	quit()
