extends SceneTree

## SU DOKULARI PİŞİRME (madde 214, 2026-10-17) - 1. ADIM: görünen su maskesi, sonra tools/gen_su_dokusu.py'yi (2. adım) kendisi çağırır.
## Çıktı: assets/map/su_mesafe.png (kıyıya uzaklık) + assets/map/su_akis.png (akış + dalgacık doğabilir). Oyunda scripts/water_fx.gd
## bunları scenes/su.gdshader'a verir. Harita yeniden bake edilince (Su / Su collisionsuz / Su ayrıntılar / köprü değişince) çalıştır:
##   Godot --path . --windowed --resolution 320x180 -s tools/gen_su_dokusu.gd
## sonra yeni PNG'ler için `Godot --headless --path . --import` (editör açıksa kendisi içe aktarır).
## Maske (prototip su_capture.gd ile aynı kural): Su + Su collisionsuz karolarının mavi pikselleri - kıyı ayrıntı katmanlarının
## (terrain_collision.gd WATER_DETAIL_LAYERS) mavi OLMAYAN opak pikselleri; 2x2 dünya pikseli = 1 teksel (0..252 kaplama).
## Köprü/iskele: ayrıntı karosu hücrenin suyunun %60+ını örtüyor VE iki yanında (3 hücre içinde, yatay ya da dikey) %60+ AÇIK su var ->
## altı su sayılır (batı köprüsü "Su ayrıntılar 3"te, altı Su collisionsuz; yoksa köprü kıyı sanılır). Kıyı boyunca komşular da örtülü
## olduğundan kıyı hücreleri bu kurala girmez.

const MASK_PATH := "res://tools/_su_maske_gecici.png"
const TEXEL := 2


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var WaterFx: GDScript = load("res://scripts/water_fx.gd")
	var harita: Node = load("res://scenes/harita_baked.tscn").instantiate()
	root.add_child(harita)
	await process_frame
	var TC: GDScript = load("res://scripts/terrain_collision.gd")
	var helper: Node = load("res://scripts/depth_occluders.gd").new()
	var water := harita.get_node(WaterFx.WATER_PATH) as TileMapLayer
	var wofs: Vector2 = helper.cell_origin(water)
	var origin: Vector2 = WaterFx.TEX_ORIGIN
	var wsize: Vector2 = WaterFx.TEX_WORLD_SIZE
	var cell0 := Vector2i(roundi((origin.x - wofs.x) / 16.0), roundi((origin.y - wofs.y) / 16.0))
	var rect := Rect2i(cell0, Vector2i(int(wsize.x) / 16, int(wsize.y) / 16))
	var used: Rect2i = water.get_used_rect()
	if not rect.encloses(used):
		push_error("Su katmanı doku alanının dışına taşıyor: kullanılan %s, doku %s - water_fx.gd TEX_ORIGIN/TEX_WORLD_SIZE büyüt" % [used, rect])
	var w: int = rect.size.x * 8
	var h: int = rect.size.y * 8
	var cache: Dictionary = {}
	## 1. geçiş: hücre (Su ızgarası) -> {base, vis, oran}
	var cells: Dictionary = {}
	for wl: TileMapLayer in [water, harita.get_node(WaterFx.WATER_NOCOL_PATH) as TileMapLayer]:
		var lofs: Vector2 = helper.cell_origin(wl)
		var lshift := Vector2i(roundi((lofs.x - wofs.x) / 16.0), roundi((lofs.y - wofs.y) / 16.0))
		var details: Array = []
		for path: String in TC.WATER_DETAIL_LAYERS:
			var dl := harita.get_node_or_null(path) as TileMapLayer
			if dl != null and dl.tile_set != null and not dl.get_used_cells().is_empty():
				var dofs: Vector2 = helper.cell_origin(dl)
				details.append({"layer": dl, "shift": Vector2i(roundi((dofs.x - lofs.x) / 16.0), roundi((dofs.y - lofs.y) / 16.0))})
		for cell: Vector2i in wl.get_used_cells():
			var base: PackedByteArray = TC._class_mask(helper, wl, cell, cache)
			if base.is_empty():
				continue
			var vis: PackedByteArray = base.duplicate()
			for d: Dictionary in details:
				var dl: TileMapLayer = d["layer"]
				var dc: Vector2i = cell - (d["shift"] as Vector2i)
				if dl.get_cell_source_id(dc) == -1:
					continue
				var over: PackedByteArray = TC._class_mask(helper, dl, dc, cache)
				if over.is_empty():
					continue
				for i in 256:
					if over[i] == 2:
						vis[i] = 0
			var shown := 0
			var blue := 0
			for i in 256:
				shown += int(vis[i] == 1)
				blue += int(base[i] == 1)
			if blue == 0:
				continue
			var key: Vector2i = cell + lshift
			if cells.has(key) and float(cells[key]["oran"]) >= float(shown) / blue:
				continue
			cells[key] = {"base": base, "vis": vis, "oran": float(shown) / blue}
	helper.free()
	## 2. geçiş: köprü/iskele + yazma
	var acc := PackedByteArray()
	acc.resize(w * h)
	var bridged := 0
	for key: Vector2i in cells:
		var c: Dictionary = cells[key]
		var vis: PackedByteArray = c["vis"]
		if float(c["oran"]) < 0.4 and _between_water(cells, key):
			vis = c["base"]
			bridged += 1
		var mc: Vector2i = key - rect.position
		if mc.x < 0 or mc.y < 0 or mc.x * 8 + 8 > w or mc.y * 8 + 8 > h:
			continue
		for y in 16:
			var row: int = (mc.y * 8 + (y >> 1)) * w + mc.x * 8
			for x in 16:
				if vis[y * 16 + x] == 1:
					acc[row + (x >> 1)] = mini(252, acc[row + (x >> 1)] + 63)
	var mask_abs: String = ProjectSettings.globalize_path(MASK_PATH)
	Image.create_from_data(w, h, false, Image.FORMAT_L8, acc).save_png(mask_abs)
	print("su maskesi %dx%d, %d hucre, %d kopru/iskele hucresi su sayildi" % [w, h, cells.size(), bridged])
	var out_dir: String = ProjectSettings.globalize_path("res://assets/map")
	var script_path: String = ProjectSettings.globalize_path("res://tools/gen_su_dokusu.py")
	var output: Array = []
	var code: int = -1
	for py: String in ["python", "py", "python3"]:
		output.clear()
		code = OS.execute(py, [script_path, mask_abs, out_dir], output, true)
		if code != -1 and code != 9009 and not "".join(output).contains("is not recognized"):
			break
	print("".join(output))
	if code != 0:
		push_error("gen_su_dokusu.py çalışmadı (kod %d) - elle: python tools/gen_su_dokusu.py \"%s\" \"%s\"" % [code, mask_abs, out_dir])
	quit()


func _between_water(cells: Dictionary, c: Vector2i) -> bool:
	var horiz: bool = _open_within(cells, c, Vector2i(-1, 0)) and _open_within(cells, c, Vector2i(1, 0))
	var vert: bool = _open_within(cells, c, Vector2i(0, -1)) and _open_within(cells, c, Vector2i(0, 1))
	return horiz or vert


func _open_within(cells: Dictionary, c: Vector2i, step: Vector2i) -> bool:
	for k in range(1, 4):
		var n: Vector2i = c + step * k
		if cells.has(n) and float(cells[n]["oran"]) >= 0.6:
			return true
	return false
