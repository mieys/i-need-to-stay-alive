extends SceneTree

## Doğrulama (madde 364): pişmiş haritada TerrainCollision'ı kurar, kategori sayılarını ve sahne nesnesi (props) sınıflamasını yazar; her katmandan
## katı / katı DEĞİL nesneleri (sınır kutusu, piksel, yeşil payı) listeler -> tools/derin_orman/out/engel_raporu.txt + engel_katalog.png
## (her nesne: kırmızı çerçeve = engel, gri = engel değil). Kullanım: Godot --headless --path . -s tools/derin_orman/engel_raporu.gd


func _initialize() -> void:
	_run.call_deferred()


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
	var t0: int = Time.get_ticks_usec()
	tc.call("reset")
	tc.call("ensure", forest)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var lines := PackedStringArray()
	lines.append("kurulum %.0f ms | %s" % [ms, str(tc.get("stats"))])
	var helper: Node = depth.new()
	for path: String in tc.get("PROP_LAYERS"):
		var l := h.get_node_or_null(path) as TileMapLayer
		if l == null:
			lines.append("YOK " + path)
			continue
		var groups: Array = tc.call("object_groups", helper, l)
		var solid: int = 0
		for g: Dictionary in groups:
			if tc.call("is_solid_prop", g):
				solid += 1
		lines.append("%s: nesne %d, engel %d" % [path, groups.size(), solid])
		for g: Dictionary in groups:
			var c: Vector2i = (g["bases"] as Dictionary).keys()[0]
			lines.append("   %s %s w%d h%d px%d yesil%.2f atla%s" % ["ENGEL" if tc.call("is_solid_prop", g) else "-    ", str(c), int(g["w"]), int(g["h"]),
				int(g["px"]), float(g["green"]), str(g["skip"])])
	## katalog: katman başına tekil nesneler (aynı karo deseni bir kez), kırmızı çerçeve = engel
	var cat := Image.create(1600, 1400, false, Image.FORMAT_RGBA8)
	cat.fill(Color(0.47, 0.55, 0.4))
	var cx: int = 4
	var cy: int = 4
	var row_h: int = 0
	for path: String in tc.get("PROP_LAYERS"):
		var l := h.get_node_or_null(path) as TileMapLayer
		if l == null:
			continue
		var seen: Dictionary = {}
		for g: Dictionary in tc.call("object_groups", helper, l):
			var cells: Array = (g["bases"] as Dictionary).keys()
			var mn := Vector2i(1 << 20, 1 << 20)
			var mx := Vector2i(-(1 << 20), -(1 << 20))
			for c: Vector2i in cells:
				mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
				mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
			var sig := PackedStringArray()
			for c: Vector2i in cells:
				sig.append("%d,%d:%d:%s" % [c.x - mn.x, c.y - mn.y, l.get_cell_source_id(c), str(l.get_cell_atlas_coords(c))])
			sig.sort()
			var key: String = ";".join(sig)
			if seen.has(key):
				continue
			seen[key] = true
			var w: int = (mx.x - mn.x + 1) * 16
			var hh: int = (mx.y - mn.y + 1) * 16
			if cx + w + 6 > 1600:
				cx = 4
				cy += row_h + 6
				row_h = 0
			if cy + hh + 4 > 1400:
				break
			for c: Vector2i in cells:
				var src := l.tile_set.get_source(l.get_cell_source_id(c)) as TileSetAtlasSource
				if src == null or src.texture == null:
					continue
				var img: Image = helper._image_of(src.texture)
				var reg: Rect2i = src.get_tile_texture_region(l.get_cell_atlas_coords(c))
				var tile: Image = img.get_region(reg)
				tile.convert(Image.FORMAT_RGBA8)
				cat.blend_rect(tile, Rect2i(Vector2i.ZERO, Vector2i(16, 16)), Vector2i(cx + (c.x - mn.x) * 16, cy + (c.y - mn.y) * 16))
			var col: Color = Color(1, 0.1, 0.1) if tc.call("is_solid_prop", g) else Color(0.3, 0.3, 0.3)
			for x in range(cx - 1, cx + w + 1):
				cat.set_pixel(clampi(x, 0, 1599), clampi(cy - 1, 0, 1399), col)
				cat.set_pixel(clampi(x, 0, 1599), clampi(cy + hh, 0, 1399), col)
			for y in range(cy - 1, cy + hh + 1):
				cat.set_pixel(clampi(cx - 1, 0, 1599), clampi(y, 0, 1399), col)
				cat.set_pixel(clampi(cx + w, 0, 1599), clampi(y, 0, 1399), col)
			cx += w + 6
			row_h = maxi(row_h, hh)
		cx = 4
		cy += row_h + 14
		row_h = 0
	cat.save_png(ProjectSettings.globalize_path("res://").path_join("tools/derin_orman/out/engel_katalog.png"))
	helper.free()
	var f := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("tools/derin_orman/out/engel_raporu.txt"), FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	print("\n".join(lines.slice(0, 8)))
	quit()
