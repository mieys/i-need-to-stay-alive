extends SceneTree

## depth_occluders._image_of (Texture2D.get_image + decompress) maliyeti: harita TileSet'indeki her kaynak için ms (madde 371, collision yükleme süresi dökümü).
## Kullanım: Godot --headless --path . -s res://tools/fps_micro/image_of_olcum.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var h: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	root.add_child(h)
	await process_frame
	var forest: TileMapLayer = h.get_node("Orman parçaları/Orman parçaları")
	var ts: TileSet = forest.tile_set
	var helper: Node = (load("res://scripts/depth_occluders.gd") as GDScript).new()
	var total: float = 0.0
	var rows: Array = []
	for i in range(ts.get_source_count()):
		var sid: int = ts.get_source_id(i)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null or src.texture == null:
			continue
		var t0: int = Time.get_ticks_usec()
		var img: Image = helper.call("_image_of", src.texture)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		rows.append([ms, "%s %dx%d fmt=%d" % [src.texture.resource_path.get_file(), img.get_width(), img.get_height(), img.get_format()]])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 10):
		print("IO %.1f ms  %s" % [r[0], r[1]])
	print("IO toplam %.0f ms (%d kaynak)" % [total, rows.size()])
	helper.free()
	quit()
