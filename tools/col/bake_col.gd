extends SceneTree

## ALTIN KUMLAR (çöl) bake'i (2026-11-09): res://harita/col.tmx (tools/col/gen_col.py --write üretir) -> YATI -> res://scenes/col_baked.tscn.
## Kara Bataklık bake'i (tools/bataklik/bake_bataklik.gd) gibi: eski sahneden isimle taşıma YOK, Godot tarafındaki her ayar burada (yeniden
## bake her seferinde aynı sahneyi verir; elle eklenmek istenen bir şey bu betiğe yazılmalı):
##  - "Yer/Zemin Toprak" + "Yer/Zemin Çimen" + kıyı "Su/Su ayrıntılar 2": scenes/col_zemin.gdshader (kum rüzgâr kıvrımları + çimen tutamları);
##  - "Su/Su": scenes/col_su.gdshader (karo düz mavi; collision mavi pikseli su sayar);
##  - ağaç / ot / çiçek / y-sıralı nesne katmanları + "Shader Eklenecek" grubu: ana haritanın AYNI adlı düğümlerinin materyali + görünüm
##    özellikleri; "Ağaç 1..7" ana haritanın "Ağaç 0"ınkini, "Kayalar 1..3" "Animasyonsuz çalılar"ınkini alır;
##  - "Orman parçaları/Orman parçaları" görünmez engel katmanı: visible = false.
## Kullanım: Godot --headless --path . -s tools/col/bake_col.gd   (önce yeni PNG'ler için --headless --import)

const TMX_PATH := "res://harita/col.tmx"
const OUT_PATH := "res://scenes/col_baked.tscn"
const MAIN_BAKED := "res://scenes/harita_baked.tscn"
const GROUND_SHADER := "res://scenes/col_zemin.gdshader"
const WATER_SHADER := "res://scenes/col_su.gdshader"
const CARRY_FROM_MAIN: PackedStringArray = ["Shader Eklenecek", "Shader Eklenecek/Çiçekler 1", "Shader Eklenecek/Çalılar",
	"Shader Eklenecek/Çalılar1", "Shader Eklenecek/Animasyonsuz çalılar", "Orman parçaları/Saklanma Çalılığı"]
const OBJECT_EXTRA: PackedStringArray = ["Shader Eklenecek/Kayalar 1", "Shader Eklenecek/Kayalar 2", "Shader Eklenecek/Kayalar 3"]
const CARRY_PROPS: PackedStringArray = ["y_sort_enabled", "z_index", "z_as_relative", "texture_filter", "light_mask"]


func _init() -> void:
	var creator: RefCounted = (preload("res://addons/YATI/TilemapCreator.gd") as GDScript).new()
	var root: Node = creator.create(TMX_PATH) as Node
	if root == null:
		printerr("Çöl bake başarısız: TilemapCreator boş döndü")
		quit(1)
		return
	root.name = "Harita"
	var main_root: Node = (load(MAIN_BAKED) as PackedScene).instantiate()
	var carried := 0
	for path: String in CARRY_FROM_MAIN:
		carried += _carry(main_root.get_node_or_null(path), root.get_node_or_null(path))
	var obj_src: Node = main_root.get_node_or_null("Shader Eklenecek/Animasyonsuz çalılar")
	for path: String in OBJECT_EXTRA:
		carried += _carry(obj_src, root.get_node_or_null(path))
	var tree_src: Node = main_root.get_node_or_null("Shader Eklenecek/Ağaç 0")
	var trees := root.get_node_or_null("Shader Eklenecek")
	if trees != null:
		for child in trees.get_children():
			if String(child.name).begins_with("Ağaç"):
				carried += _carry(tree_src, child)
	var gm := ShaderMaterial.new()
	gm.shader = load(GROUND_SHADER)
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
		printerr("Çöl bake başarısız: pack %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_PATH)
	if err != OK:
		printerr("Çöl bake başarısız: kayıt %s" % err)
		quit(1)
		return
	print("Çöl bake tamamlandı: %s (ana haritadan taşınan materyal/özellik: %d)" % [OUT_PATH, carried])
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


func _set_owner(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_set_owner(c, owner_node)
