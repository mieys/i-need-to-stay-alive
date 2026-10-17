extends Node

## Harita görünümü (scripts/map_color_grade.gd, madde 181, 184): renk ayarı her katmanda, sakin doku değerleri, başıboş düz çimen karolarının
## zeminin altına alınması. Asıl risk OYNANIŞ: gizleme sadece ALTERNATİF karoyu değiştirmeli - hücre/kaynak/atlas ve su/orman/nesne
## collision'ı (terrain_collision.gd, piksel tabanlı) birebir aynı kalmalı; plato tepeleri ("Orman parçaları 2") dokunulmaz.

const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const MapColorGradeScript: GDScript = preload("res://scripts/map_color_grade.gd")
const TerrainCollisionScript: GDScript = preload("res://scripts/terrain_collision.gd")
const GroundTexelPassScript: GDScript = preload("res://scripts/ground_texel_pass.gd")
const GrassSwayScript: GDScript = preload("res://scripts/grass_sway.gd")


func _load() -> Node:
	var h: Node = HaritaScene.instantiate()
	h.name = "Harita"
	add_child(h)
	return h


## katman yolu -> {hücre: Vector4i(kaynak, atlas x, atlas y, alternatif)}
func _snapshot(h: Node) -> Dictionary:
	var out := {}
	for n: Node in h.find_children("*", "TileMapLayer", true, false):
		var layer := n as TileMapLayer
		var cells := {}
		for c: Vector2i in layer.get_used_cells():
			var a: Vector2i = layer.get_cell_atlas_coords(c)
			cells[c] = Vector4i(layer.get_cell_source_id(c), a.x, a.y, layer.get_cell_alternative_tile(c))
		out[str(h.get_path_to(layer))] = cells
	return out


## Orman + nesne + su engel hücreleri (kategori -> sıralı hücre listesi).
func _collision(h: Node) -> Dictionary:
	TerrainCollisionScript.reset()
	TerrainCollisionScript.ensure(h.get_node("Orman parçaları/Orman parçaları"))
	var out := {}
	for cat: String in TerrainCollisionScript.by_category:
		var list: Array = TerrainCollisionScript.by_category[cat].duplicate()
		list.sort()
		out[cat] = list
	TerrainCollisionScript.reset()
	return out


func test_hiding_stray_grass_changes_only_the_alternative_tile_and_keeps_collision() -> void:
	var before_map: Node = _load()
	var before: Dictionary = _snapshot(before_map)
	var before_col: Dictionary = _collision(before_map)
	before_map.free()

	var h: Node = _load()
	var hidden: int = MapColorGradeScript.attach(h)
	assert(hidden > 200, "başıboş düz çimen gizlenmedi: %d" % hidden)
	var after: Dictionary = _snapshot(h)
	var changed := 0
	for path: String in before:
		var b: Dictionary = before[path]
		var a: Dictionary = after[path]
		assert(a.size() == b.size(), "%s hücre sayısı değişti" % path)
		for c: Vector2i in b:
			var vb: Vector4i = b[c]
			var va: Vector4i = a[c]
			assert(Vector3i(va.x, va.y, va.z) == Vector3i(vb.x, vb.y, vb.z), "%s %s karo değişti" % [path, c])
			if va.w != vb.w:
				changed += 1
				assert(path != "Orman parçaları/Orman parçaları 2", "plato tepesi gizlendi: %s" % c)
				var layer := h.get_node(path) as TileMapLayer
				assert(layer.get_cell_tile_data(c).z_index == MapColorGradeScript.STRAY_UNDER_Z, "gizlenen karo zeminin altında değil")
	assert(changed == hidden, "değişen alternatif %d != gizlenen %d" % [changed, hidden])
	assert(_collision(h) == before_col, "collision değişti")
	h.free()


func test_every_map_layer_draws_with_the_color_grade() -> void:
	var h: Node = _load()
	MapColorGradeScript.attach(h)
	for n: Node in h.find_children("*", "TileMapLayer", true, false):
		var sm := (n as TileMapLayer).material as ShaderMaterial
		assert(sm != null and sm.shader != null, "%s materyalsiz" % n.name)
		assert(sm.shader.code.contains("harita_renk"), "%s renk ayarı çağırmıyor (%s)" % [n.name, sm.shader.resource_path])
	h.free()


func test_calm_params_override_the_scene_values() -> void:
	var h: Node = _load()
	MapColorGradeScript.attach(h)
	var tufts := (h.get_node("Yer/Çimler") as TileMapLayer).material as ShaderMaterial
	assert(is_equal_approx(float(tufts.get_shader_parameter("hue_shift_amount")), 0.03))
	var grass := (h.get_node("Yer/Zemin Çimen") as TileMapLayer).material as ShaderMaterial
	assert(is_equal_approx(float(grass.get_shader_parameter("cicek_yogunlugu")), 0.08))
	var dirt := (h.get_node("Yer/Zemin Toprak") as TileMapLayer).material as ShaderMaterial
	assert(is_equal_approx(float(dirt.get_shader_parameter("ince_cakil_sik")), 0.16))
	## İkinci çağrı (ground_texel_pass.gd aynı materyallere yeniden uygular) bir şey bozmaz.
	MapColorGradeScript.apply_calm(grass)
	assert(is_equal_approx(float(grass.get_shader_parameter("cicek_yogunlugu")), 0.08))
	h.free()


func test_plateau_tops_use_the_ground_grass_pattern() -> void:
	## madde 186: "Orman parçaları 2" gömülü shader'ı yerine zemin desenini de çizen dosya shader'ı; desen değerleri zeminle aynı.
	var h: Node = _load()
	MapColorGradeScript.attach(h)
	var plateau := (h.get_node("Orman parçaları/Orman parçaları 2") as TileMapLayer).material as ShaderMaterial
	var grass := (h.get_node("Yer/Zemin Çimen") as TileMapLayer).material as ShaderMaterial
	assert(plateau.shader.resource_path == MapColorGradeScript.FOREST_SHADER_PATH)
	assert(plateau.shader.code.contains("cimen_desen"), "plato zemin desenini çağırmıyor")
	for p: String in ["cim_taban", "cim_koyu", "cim_leke_olcegi", "cim_kivrim", "cicek_yogunlugu", "kume_sik"]:
		assert(plateau.get_shader_parameter(p) == grass.get_shader_parameter(p), "plato %s zeminden farklı" % p)
	## eski gömülü desenin değerleri materyalde kalır (cim_efekt 0 -> eski görünüm)
	assert(plateau.get_shader_parameter("dark_grass_color") != null)
	h.free()


func test_ground_detail_toggle_also_switches_the_plateau_pattern() -> void:
	## "Zemin ayrıntısı" kapalıyken zemin desensiz -> plato tepesi de desensiz olmalı (ground_texel_pass.gd, main.gd sırası: attach ÖNCE).
	## Ayar değişkeni doğrudan değiştirilir (set_gfx_option diske yazardı) ve sonda eski hâline döner.
	var h: Node = _load()
	MapColorGradeScript.attach(h)
	GroundTexelPassScript.attach(h)
	var plateau := (h.get_node("Orman parçaları/Orman parçaları 2") as TileMapLayer).material as ShaderMaterial
	var grass_layer := h.get_node("Yer/Zemin Çimen") as TileMapLayer
	var was: bool = UISound.gfx_ground_detail
	UISound.gfx_ground_detail = false
	UISound.graphics_changed.emit()
	assert(is_equal_approx(float(plateau.get_shader_parameter("cim_efekt")), 0.0), "ayrıntı kapalı ama plato desenli")
	assert(grass_layer.material == MapColorGradeScript.plain_material(), "ayrıntı kapalı zemin renk ayarsız")
	UISound.gfx_ground_detail = true
	UISound.graphics_changed.emit()
	assert(is_equal_approx(float(plateau.get_shader_parameter("cim_efekt")), 1.0))
	assert((grass_layer.material as ShaderMaterial).shader.resource_path == MapColorGradeScript.GROUND_GRASS_SHADER_PATH)
	UISound.gfx_ground_detail = was
	UISound.graphics_changed.emit()
	h.free()


func test_plants_under_the_bridge_are_not_drawn_over_the_deck() -> void:
	## madde 189 (kullanıcı: "köprünün üstünde bitki görünüyor"): köprü güvertesine düşen bitki karoları (ve çok karolu çizimin diğer
	## parçaları) ön kopyalarıyla birlikte zeminin altına; köprünün hemen kuzeyindeki AYRI bitki dokunulmaz.
	var h: Node = _load()
	GrassSwayScript.new().setup(h) ## oyundaki gibi "<ad> ön" kopyaları
	MapColorGradeScript.attach(h)
	var deck := {}
	for p: String in MapColorGradeScript.BRIDGE_DECK_LAYERS:
		for c: Vector2i in (h.get_node(p) as TileMapLayer).get_used_cells():
			deck[c] = true
	var checked := 0
	for p: String in MapColorGradeScript.BRIDGE_PLANT_LAYERS:
		var layer := h.get_node(p) as TileMapLayer
		var layers: Array[Node] = [layer]
		layers.append_array(h.find_children(String(layer.name) + " ön", "TileMapLayer", true, false))
		for l: Node in layers:
			for c: Vector2i in (l as TileMapLayer).get_used_cells():
				if deck.has(c):
					assert((l as TileMapLayer).get_cell_tile_data(c).z_index == MapColorGradeScript.STRAY_UNDER_Z, "%s %s köprünün üstünde" % [l.name, c])
					checked += 1
	assert(checked >= 4, "köprüdeki bitkiler bulunamadı (taban + ön kopya): %d" % checked)
	## 2026-10-16 haritası: (60,119)+(60,120) tek uzun bitki -> üst yarısı da gizli; (59,119) ayrı bitki -> görünür.
	var bush := h.get_node("Shader Eklenecek/Çalılar") as TileMapLayer
	if bush.get_cell_atlas_coords(Vector2i(60, 119)) + Vector2i.DOWN == bush.get_cell_atlas_coords(Vector2i(60, 120)):
		assert(bush.get_cell_tile_data(Vector2i(60, 119)).z_index == MapColorGradeScript.STRAY_UNDER_Z, "uzun bitkinin üst yarısı havada")
	if bush.get_cell_source_id(Vector2i(59, 119)) != -1:
		assert(bush.get_cell_tile_data(Vector2i(59, 119)).z_index != MapColorGradeScript.STRAY_UNDER_Z, "köprü dışındaki bitki gizlendi")
	h.free()
