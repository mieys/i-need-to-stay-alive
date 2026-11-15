extends SceneTree

## DÜNYA HARİTASI prototipi (2026-11-12, oyuna bağlı DEĞİL) - 1. adım: seçilebilir her haritayı GERÇEK çiziciyle
## (bake_minimap.gd yolu: harita sahnesi SubViewport'ta, parça parça) 1 çizim pikseli = 4 dünya pikseli çizer.
## Çıktı <DUNYA_OUT>/render4_<id>.png (saydam arka plan) + render4_<id>.json (hücre kökeni). Küçültme (kutu filtresi) compose.py'de.
## Pencereli koşar (headless'ta çizim yok): dunya_run.ps1 -Script render.gd

const WORLD_PER_PX := 4.0
const CHUNK_PX := 1024
const MARGIN_CELLS := 28 ## ana harita: oyun alanının çevresinde dış çerçeveden bu kadar hücre
const MapProfiles := preload("res://scripts/map_profiles.gd")


func _initialize() -> void:
	_run.call_deferred()


func _out() -> String:
	var d: String = OS.get_environment("DUNYA_OUT")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261112/dunya_haritasi/out")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _map_nodes(id: String) -> Array:
	if id == "ana":
		var main: Node = load("res://scenes/main.tscn").instantiate()
		var out: Array = []
		for nn in ["Harita", "Node2D"]:
			var n: Node = main.get_node_or_null(nn)
			if n == null:
				continue
			main.remove_child(n)
			n.owner = null
			out.append(n)
		main.free()
		return out
	var p: Dictionary = MapProfiles.get_profile(id)
	var packed: PackedScene = load(str(p.get("sahne", ""))) as PackedScene
	return [packed.instantiate()]


func _used_rect(nodes: Array) -> Rect2i:
	var total := Rect2i()
	var found := false
	for root_n: Node in nodes:
		var stack: Array[Node] = [root_n]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c: Node in n.get_children():
				stack.append(c)
			if not (n is TileMapLayer):
				continue
			var layer: TileMapLayer = n
			var used: Rect2i = layer.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			total = used if not found else total.merge(used)
			found = true
	return total


func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var ids: Array = []
	var only: String = OS.get_environment("DUNYA_HARITALAR")
	for id: String in (only.split(",", false) if only != "" else PackedStringArray(MapProfiles.selectable_ids())):
		ids.append(id)
	for id: String in ids:
		var vp := SubViewport.new()
		vp.size = Vector2i(CHUNK_PX, CHUNK_PX)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		root.add_child(vp)
		var nodes: Array = _map_nodes(id)
		for n: Node in nodes:
			vp.add_child(n)
		if id == "ana":
			preload("res://scripts/shops_flag.gd").strip_building(vp.get_node_or_null("Harita"))
		var cells: Rect2i = _used_rect(nodes)
		if id == "ana":
			cells = Rect2i(-MARGIN_CELLS, -MARGIN_CELLS, 256 + MARGIN_CELLS * 2, 256 + MARGIN_CELLS * 2).intersection(cells)
		var cam := Camera2D.new()
		cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
		cam.zoom = Vector2.ONE / WORLD_PER_PX
		vp.add_child(cam)
		cam.make_current()
		await process_frame
		var world0 := Vector2(cells.position) * 16.0
		var full_px := Vector2i(int(cells.size.x * 16 / WORLD_PER_PX), int(cells.size.y * 16 / WORLD_PER_PX))
		var full := Image.create(full_px.x, full_px.y, false, Image.FORMAT_RGBA8)
		var cy: int = 0
		while cy < full_px.y:
			var cx: int = 0
			while cx < full_px.x:
				cam.position = world0 + Vector2(cx, cy) * WORLD_PER_PX
				for i in 4:
					await RenderingServer.frame_post_draw
				var img: Image = vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				var w: int = mini(CHUNK_PX, full_px.x - cx)
				var h: int = mini(CHUNK_PX, full_px.y - cy)
				full.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(cx, cy))
				cx += CHUNK_PX
			cy += CHUNK_PX
		full.save_png(_out().path_join("render4_%s.png" % id))
		var meta := {"id": id, "cell_x": cells.position.x, "cell_y": cells.position.y, "cells_w": cells.size.x, "cells_h": cells.size.y,
			"ad": str(MapProfiles.get_profile(id).get("ad", id)), "tur": str(MapProfiles.get_profile(id).get("tur", ""))}
		var f := FileAccess.open(_out().path_join("render4_%s.json" % id), FileAccess.WRITE)
		f.store_string(JSON.stringify(meta))
		f.close()
		print("SHOT render4_%s %s cells=%s" % [id, str(full_px), str(cells)])
		vp.queue_free()
		await process_frame
		await process_frame
	quit()
