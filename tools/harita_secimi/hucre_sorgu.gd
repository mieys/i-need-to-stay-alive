extends SceneTree
## HÜCRE SORGUSU (2026-11-08, ana harita doğu kenarındaki renk farkı): oyunu (HARITA ortamıyla) açar, HUCRELER="x,y;x,y" hücrelerinde dolu her
## TileMapLayer'ı (yol, kaynak + atlas + alternatif, malzeme shader'ı, görünürlük, z, visibility_layer) ve hücrenin üstündeki Sprite/Canvas
## düğümlerini yazar. Kullanım: $env:HUCRELER="250,58;257,58"; Godot --headless --path . -s res://tools/harita_secimi/hucre_sorgu.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 1)
	gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	for i in range(60):
		await process_frame
	var h: Node = current_scene.get_node("Harita")
	for item: String in OS.get_environment("HUCRELER").split(";", false):
		var xy: PackedStringArray = item.split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		print("HUCRE ", cell)
		for n: Node in h.find_children("*", "TileMapLayer", true, false):
			var l := n as TileMapLayer
			if l.get_cell_source_id(cell) == -1:
				continue
			var mat: Material = l.material
			var sh: String = ""
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
				sh = (mat as ShaderMaterial).shader.resource_path
				if sh == "":
					sh = "(gömülü)"
			var src: TileSetSource = l.tile_set.get_source(l.get_cell_source_id(cell)) if l.tile_set else null
			var tex: String = ""
			if src is TileSetAtlasSource and (src as TileSetAtlasSource).texture:
				tex = (src as TileSetAtlasSource).texture.resource_path.get_file()
			print("  %s | kaynak %d %s atlas %s alt %d | malzeme %s | görünür %s z %d vl %d" % [String(h.get_path_to(l)), l.get_cell_source_id(cell), tex,
				str(l.get_cell_atlas_coords(cell)), l.get_cell_alternative_tile(cell), sh if sh != "" else ("yok" if mat == null else mat.get_class()),
				str(l.is_visible_in_tree()), l.z_index, l.visibility_layer])
		if OS.get_environment("PARAMLAR") != "":
			for n2: Node in h.find_children("*", "TileMapLayer", true, false):
				var l2 := n2 as TileMapLayer
				if l2.get_cell_source_id(cell) == -1 or not (l2.material is ShaderMaterial):
					continue
				var sm: ShaderMaterial = l2.material
				var vals: Array = []
				for k: String in OS.get_environment("PARAMLAR").split(",", false):
					vals.append("%s=%s" % [k, str(sm.get_shader_parameter(k))])
				print("  PARAM %s | %s" % [String(h.get_path_to(l2)), " ".join(vals)])
			print("  AYAR gfx_ground_detail=", root.get_node("UISound").get("gfx_ground_detail"))
		## karo dışı çizimler (Sprite2D / Polygon2D / ColorRect / Node2D _draw): dünya noktası hücre merkezi
		var wp: Vector2 = (h as Node2D).to_global(Vector2(cell) * 16.0 + Vector2(8, 8))
		for n: Node in current_scene.find_children("*", "", true, false):
			if n is Sprite2D and (n as Sprite2D).is_visible_in_tree() and (n as Sprite2D).texture != null:
				var s2: Sprite2D = n
				var r: Rect2 = s2.get_rect()
				var local: Vector2 = s2.to_local(wp)
				if r.has_point(local):
					print("  SPRITE %s doku %s boyut %s" % [String(current_scene.get_path_to(s2)), s2.texture.resource_path.get_file(), str(r.size)])
			elif n is ColorRect and (n as ColorRect).is_visible_in_tree():
				var cr: ColorRect = n
				if cr.get_global_rect().has_point(wp):
					print("  COLORRECT %s renk %s" % [String(current_scene.get_path_to(cr)), str(cr.color)])
	quit(0)
