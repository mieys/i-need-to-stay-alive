extends SceneTree

## TerrainCollision + object_bases ÖZETİ (madde 371): yükleme hızlandırması sonucu DEĞİŞTİRMEMELİ. Pişmiş haritada TerrainCollision'ı kurar ve engel hücre kümesinin,
## kategori listelerinin, istatistiklerin, her katmanın object_bases sonucunun özetini yazar. Eski kodla ve yeni kodla koşup SNAP satırlarını karşılaştır.
## Kullanım: Godot --headless --path . -s res://tools/fps_micro/terrain_snapshot.gd


func _initialize() -> void:
	_run.call_deferred()


func _hash(lines: PackedStringArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update("\n".join(lines).to_utf8_buffer())
	return ctx.finish().hex_encode()


func _cells_hash(cells: Array) -> String:
	var lines := PackedStringArray()
	for c: Vector2i in cells:
		lines.append("%d,%d" % [c.x, c.y])
	lines.sort()
	return _hash(lines)


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
	var t0: int = Time.get_ticks_usec()
	tc.call("ensure", forest)
	print("SNAP ensure_ms=%.0f" % (float(Time.get_ticks_usec() - t0) / 1000.0))
	var st: Dictionary = tc.get("stats")
	for k: String in st:
		print("SNAP stats.%s=%s" % [k, str(st[k])])
	print("SNAP cells=%d %s" % [(tc.get("_cells") as Dictionary).size(), _cells_hash((tc.get("_cells") as Dictionary).keys())])
	var cat: Dictionary = tc.get("by_category")
	for k: String in cat:
		print("SNAP cat.%s=%d %s" % [k, (cat[k] as Array).size(), _cells_hash(cat[k])])
	var helper: Node = depth.new()
	var layers: Array = h.find_children("*", "TileMapLayer", true, false)
	var t1: int = Time.get_ticks_usec()
	for l: TileMapLayer in layers:
		if l.tile_set == null or l.get_used_cells().is_empty() or l.get_used_cells().size() > 12000:
			continue
		var ob: Dictionary = helper.call("object_bases", l)
		var lines := PackedStringArray()
		for c: Vector2i in ob:
			lines.append("%d,%d:%.3f" % [c.x, c.y, float(ob[c])])
		lines.sort()
		print("SNAP ob.%s=%d %s" % [str(h.get_path_to(l)), ob.size(), _hash(lines)])
	print("SNAP object_bases_ms=%.0f" % (float(Time.get_ticks_usec() - t1) / 1000.0))
	helper.free()
	quit()
