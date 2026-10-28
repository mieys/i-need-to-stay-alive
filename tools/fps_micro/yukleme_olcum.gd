extends SceneTree

## HARİTA YÜKLEME DÖKÜMÜ (madde 371): baked haritayı yükleme / örnekleme / çarpışma kurulumu / ağaç sallanma verisi ayrı ayrı ms. --headless'ta çalışır (çizici gerekmez).
## Kullanım: Godot --headless --path . -s res://tools/fps_micro/yukleme_olcum.gd   (iki ayrı proje kopyasında koş: güncel / HEAD tabanı)


func _initialize() -> void:
	_run.call_deferred()


func _ms(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0


func _run() -> void:
	var t: int = Time.get_ticks_usec()
	var ps: PackedScene = ResourceLoader.load("res://scenes/harita_baked.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	print("YM load_1=%.0f ms (disk + ayrıştırma + doku)" % _ms(t))
	t = Time.get_ticks_usec()
	ps = ResourceLoader.load("res://scenes/harita_baked.tscn", "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	print("YM load_2=%.0f ms (önbellekli dokular)" % _ms(t))
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	t = Time.get_ticks_usec()
	var h: Node2D = ps.instantiate()
	h.name = "Harita"
	h.position = Vector2(-2, 21)
	print("YM instantiate=%.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	scene.add_child(h)
	print("YM add_child=%.0f ms" % _ms(t))
	var layers: int = 0
	var cells: int = 0
	var sources: int = 0
	var tiles: int = 0
	var seen_ts: Dictionary = {}
	for n in h.find_children("*", "TileMapLayer", true, false):
		layers += 1
		cells += (n as TileMapLayer).get_used_cells().size()
		var ts: TileSet = (n as TileMapLayer).tile_set
		if ts != null and not seen_ts.has(ts):
			seen_ts[ts] = true
			for i in range(ts.get_source_count()):
				var src := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
				if src != null:
					sources += 1
					tiles += src.get_tiles_count()
	print("YM katman=%d hücre=%d tileset_kaynak=%d tanımlı_karo=%d" % [layers, cells, sources, tiles])
	await process_frame
	var tc: GDScript = load("res://scripts/terrain_collision.gd")
	var forest: TileMapLayer = h.get_node("Orman parçaları/Orman parçaları")
	tc.call("reset")
	t = Time.get_ticks_usec()
	tc.call("ensure", forest)
	print("YM terrain_collision.ensure=%.0f ms %s" % [_ms(t), str(tc.get("stats"))])
	var sway: Node = load("res://scripts/tree_sway.gd").new()
	t = Time.get_ticks_usec()
	sway.call("setup", h)
	print("YM tree_sway.setup=%.0f ms" % _ms(t))
	var depth: Node = load("res://scripts/depth_occluders.gd").new()
	t = Time.get_ticks_usec()
	depth.call("setup", h)
	print("YM depth_occluders.setup=%.0f ms" % _ms(t))
	var grade: GDScript = load("res://scripts/map_color_grade.gd")
	t = Time.get_ticks_usec()
	grade.call("attach", h)
	print("YM map_color_grade.attach=%.0f ms" % _ms(t))
	quit()
