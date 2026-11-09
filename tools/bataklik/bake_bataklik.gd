extends SceneTree

## KARA BATAKLIK bake'i (yeni harita, 2026-11-09): res://harita/bataklik.tmx (tools/bataklik/gen_bataklik.py --write üretir) -> YATI ->
## res://scenes/bataklik_baked.tscn. Ana haritanın bake_harita.gd'sinden farkı: eski sahneden "isimle taşıma" YOK - Godot tarafındaki her
## ayar burada açıkça kurulur (yeniden bake her seferinde aynı sahneyi verir; elle eklemek istenen bir şey bu betiğe yazılmalı):
##  - "Yer/Zemin Toprak" + "Yer/Zemin Çimen" + kıyı "Su/Su ayrıntılar 2": scenes/bataklik_zemin.gdshader (çimen "B - Ot Tutamları",
##    madde 526; çamur: ana haritanın toprak deseni, ton oranları bataklık tabanına taşınır - SWAMP_GROUND);
##  - "Su/Su": scenes/bataklik_su.gdshader (karo düz mavi; collision mavi pikseli su sayar);
##  - ağaç / ot / çiçek katmanları + "Shader Eklenecek" grubu: ana haritanın (scenes/harita_baked.tscn) AYNI adlı düğümlerinin materyali +
##    görünüm özellikleri (y_sort_enabled, texture_filter...) - sallanma parametreleri ana haritayla aynı; "Ağaç 3..7" "Ağaç 0"ınkini alır;
##  - "Orman parçaları/Orman parçaları" görünmez engel katmanı (saydam karolar): visible = false (hücre sorguları çalışır, çizim maliyeti yok).
## Kullanım: Godot --headless --path . -s tools/bataklik/bake_bataklik.gd   (önce yeni PNG'ler için --headless --import)

const TMX_PATH := "res://harita/bataklik.tmx"
const OUT_PATH := "res://scenes/bataklik_baked.tscn"
const MAIN_BAKED := "res://scenes/harita_baked.tscn"
const GROUND_SHADER := "res://scenes/bataklik_zemin.gdshader"
const WATER_SHADER := "res://scenes/bataklik_su.gdshader"
const MAIN_GRASS_SHADER := "res://scenes/çimen yaprak.gdshader"
const MAIN_DIRT_SHADER := "res://scenes/toprak kir.gdshader"
const CARRY_FROM_MAIN: PackedStringArray = ["Shader Eklenecek", "Shader Eklenecek/Çiçekler 1", "Shader Eklenecek/Çalılar",
	"Shader Eklenecek/Çalılar1", "Shader Eklenecek/Animasyonsuz çalılar", "Orman parçaları/Saklanma Çalılığı"]
const CARRY_PROPS: PackedStringArray = ["y_sort_enabled", "z_index", "z_as_relative", "texture_filter", "light_mask"]
## Bataklık zemin tabanları (karoların düz rengi) ve desene özel ayarlar.
const GRASS_BASE := Color8(144, 163, 71)
const MUD_BASE := Color8(124, 117, 56)
const MUD_RATIO_KEYS: PackedStringArray = ["toprak_koyu", "toprak_acik", "toprak_kuru", "catlak_rengi", "catlak_kenar", "cakil_acik",
	"cakil_orta", "cakil_koyu", "cakil_dip", "iri_isik"]
const SWAMP_GROUND := {
	"catlak_esik": 0.0, ## ıslak çamur: çatlak yok
	"ince_cakil_seyrek": 0.02, "ince_cakil_sik": 0.10, "iri_cakil_yogunlugu": 0.04,
}


func _init() -> void:
	var creator: RefCounted = (preload("res://addons/YATI/TilemapCreator.gd") as GDScript).new()
	var root: Node = creator.create(TMX_PATH) as Node
	if root == null:
		printerr("Bataklık bake başarısız: TilemapCreator boş döndü")
		quit(1)
		return
	root.name = "Harita"
	var main_root: Node = (load(MAIN_BAKED) as PackedScene).instantiate()
	var carried := 0
	for path: String in CARRY_FROM_MAIN:
		carried += _carry(main_root.get_node_or_null(path), root.get_node_or_null(path))
	## Ağaç katmanları: ana haritanın Ağaç 0 materyali (sallanma parametreleri; TreeSway çalışma anında katman başına kopyalar)
	var tree_src: Node = main_root.get_node_or_null("Shader Eklenecek/Ağaç 0")
	var trees := root.get_node_or_null("Shader Eklenecek")
	if trees != null:
		for child in trees.get_children():
			if String(child.name).begins_with("Ağaç"):
				carried += _carry(tree_src, child)
	var gm := _ground_material()
	## kıyı karolarının çimeni de aynı desende (madde 526; eskiden düz materyalde desensiz şeritti)
	for path: String in ["Yer/Zemin Toprak", "Yer/Zemin Çimen", "Su/Su ayrıntılar 2"]:
		var l := root.get_node_or_null(path) as TileMapLayer
		if l != null:
			l.material = gm
			l.use_parent_material = false
	var water := root.get_node_or_null("Su/Su") as TileMapLayer
	if water != null:
		var wm := ShaderMaterial.new()
		wm.shader = load(WATER_SHADER)
		water.material = wm
		water.use_parent_material = false
		water.modulate = Color.WHITE
		water.self_modulate = Color.WHITE
	var wall := root.get_node_or_null("Orman parçaları/Orman parçaları") as TileMapLayer
	if wall != null:
		wall.visible = false
	for l: Node in root.find_children("*", "TileMapLayer", true, false):
		(l as TileMapLayer).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	main_root.free()
	_set_owner(root, root)
	var packed := PackedScene.new()
	var err: Error = packed.pack(root)
	root.free()
	if err != OK:
		printerr("Bataklık bake başarısız: pack %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_PATH)
	if err != OK:
		printerr("Bataklık bake başarısız: kayıt %s" % err)
		quit(1)
		return
	print("Bataklık bake tamamlandı: %s (ana haritadan taşınan materyal/özellik: %d)" % [OUT_PATH, carried])
	quit(0)


func _carry(src: Node, dst: Node) -> int:
	if src == null or dst == null:
		return 0
	var n := 0
	if ("material" in src) and src.material != null:
		dst.material = (src.material as Material).duplicate()
		dst.use_parent_material = false
		n += 1
	for p: String in CARRY_PROPS:
		if (p in src) and (p in dst):
			dst.set(p, src.get(p))
	return n


## Çamur: ana haritanın toprak deseni tonlarını bataklık tabanına oranla taşır (toprak_desen ton = karo x hedef/taban). Çimen deseni
## (shaders/bataklik_cimen.gdshaderinc) kendi paletini taşır, yalnız cim_taban.
func _ground_material() -> ShaderMaterial:
	var sh: Shader = load(GROUND_SHADER)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var main_mud: Color = _default_color(sh, "toprak_taban")
	mat.set_shader_parameter("cim_taban", GRASS_BASE)
	mat.set_shader_parameter("toprak_taban", MUD_BASE)
	for k: String in MUD_RATIO_KEYS:
		mat.set_shader_parameter(k, _ratio(_default_color(sh, k), main_mud, MUD_BASE))
	for k: String in SWAMP_GROUND:
		mat.set_shader_parameter(k, SWAMP_GROUND[k])
	return mat


func _default_color(sh: Shader, name: String) -> Color:
	var v: Variant = RenderingServer.shader_get_parameter_default(sh.get_rid(), name)
	if v is Color:
		return v
	if v is Vector4:
		return Color(v.x, v.y, v.z, v.w)
	if v is Vector3:
		return Color(v.x, v.y, v.z)
	printerr("varsayılan renk okunamadı: ", name, " ", v)
	return Color.WHITE


func _ratio(tone: Color, base: Color, new_base: Color) -> Color:
	return Color(
		clampf(new_base.r * tone.r / maxf(base.r, 0.001), 0.0, 1.0),
		clampf(new_base.g * tone.g / maxf(base.g, 0.001), 0.0, 1.0),
		clampf(new_base.b * tone.b / maxf(base.b, 0.001), 0.0, 1.0), 1.0)


func _set_owner(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner(c, owner_node)
