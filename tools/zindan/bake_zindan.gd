extends SceneTree

## ZİNDANLARI PİŞİR (madde 373): harita/zindan/<id>.tmx -> scenes/zindan/<id>_baked.tscn (görsel) + scenes/zindan/<id>_data.tres (DungeonData:
## Engel katmanı hücre kodları + Etkileşimler nesneleri). bake_ev_ici.gd ile aynı yöntem (YATI TilemapCreator elle). Önce PNG'ler içe aktarılmış olmalı
## (`Godot --headless --path . --import`), yoksa YATI dokuları sahneye GÖMER (madde 310 tuzağı).
## Çalıştır: Godot --headless --path . -s res://tools/zindan/bake_zindan.gd [-- kemik_mahzeni et_kuyusu ...]

const IDS: Array[String] = ["kemik_mahzeni", "et_kuyusu", "boynuzlu_kapi"]
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")
const ENGEL_CODE := {0: 1, 1: 2, 2: 3, 3: 4, 4: 5} ## Engel karo sütunu -> DungeonData.CELL_* (4 su -> CELL_WATER, madde 375)


func _init() -> void:
	var ids: Array = []
	for a: String in OS.get_cmdline_user_args():
		ids.append(a)
	if ids.is_empty():
		ids = IDS.duplicate()
	var failed: int = 0
	for id: String in ids:
		var tmx: String = "res://harita/zindan/%s.tmx" % id
		if not FileAccess.file_exists(tmx):
			print("atlandı (TMX yok): ", tmx)
			continue
		if not _bake(id, tmx):
			failed += 1
	quit(1 if failed > 0 else 0)


func _bake(id: String, tmx: String) -> bool:
	var creator: RefCounted = preload("res://addons/YATI/TilemapCreator.gd").new()
	var map_node: Node = creator.create(tmx) as Node
	if map_node == null:
		printerr("Zindan bake başarısız (YATI boş): ", tmx)
		return false
	var data: Resource = DungeonDataScript.new()
	data.id = id
	var info: Dictionary = _parse_tmx(tmx)
	data.size = info["size"]
	data.title = str(info["props"].get("ad", id))
	data.objects = info["objects"]
	var cells := PackedByteArray()
	cells.resize(data.size.x * data.size.y)
	var engel: TileMapLayer = _find_layer(map_node, "Engel")
	if engel == null:
		printerr("Zindan bake: Engel katmanı yok: ", tmx)
		map_node.free()
		return false
	var counts: Dictionary = {}
	for c: Vector2i in engel.get_used_cells():
		if c.x < 0 or c.y < 0 or c.x >= data.size.x or c.y >= data.size.y:
			continue
		var code: int = int(ENGEL_CODE.get(engel.get_cell_atlas_coords(c).x, 1))
		cells[c.y * data.size.x + c.x] = code
		counts[code] = int(counts.get(code, 0)) + 1
	data.cells = cells
	engel.get_parent().remove_child(engel)
	engel.free()
	var og: Node = map_node.find_child("Etkileşimler", true, false)
	if og != null:
		og.get_parent().remove_child(og)
		og.free()
	map_node.name = "Zindan_" + id
	var packed := PackedScene.new()
	if packed.pack(map_node) != OK:
		printerr("Zindan bake: pack başarısız ", id)
		map_node.free()
		return false
	map_node.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/zindan"))
	if ResourceSaver.save(packed, "res://scenes/zindan/%s_baked.tscn" % id) != OK:
		printerr("Zindan bake: sahne kaydedilemedi ", id)
		return false
	if ResourceSaver.save(data, "res://scenes/zindan/%s_data.tres" % id) != OK:
		printerr("Zindan bake: veri kaydedilemedi ", id)
		return false
	print("Zindan pişirildi: %s %dx%d hücre kodları %s nesne %d" % [id, data.size.x, data.size.y, counts, data.objects.size()])
	return true


func _find_layer(n: Node, name: String) -> TileMapLayer:
	if n is TileMapLayer and n.name == name:
		return n
	for c: Node in n.get_children():
		var r: TileMapLayer = _find_layer(c, name)
		if r != null:
			return r
	return null


## TMX'ten harita boyutu, harita özellikleri ve Etkileşimler nesneleri (XMLParser).
func _parse_tmx(path: String) -> Dictionary:
	var p := XMLParser.new()
	p.open(path)
	var size := Vector2i.ZERO
	var props: Dictionary = {}
	var objects: Array = []
	var cur: Dictionary = {}
	var in_object: bool = false
	var depth_props_map: bool = false
	while p.read() == OK:
		var t: int = p.get_node_type()
		if t == XMLParser.NODE_ELEMENT:
			var n: String = p.get_node_name()
			if n == "map":
				size = Vector2i(int(p.get_named_attribute_value_safe("width")), int(p.get_named_attribute_value_safe("height")))
				depth_props_map = true
			elif n == "layer" or n == "objectgroup" or n == "tileset":
				depth_props_map = false
			elif n == "object":
				in_object = true
				var typ: String = p.get_named_attribute_value_safe("type")
				if typ == "":
					typ = p.get_named_attribute_value_safe("class")
				cur = {"type": typ, "name": p.get_named_attribute_value_safe("name"),
						"rect": Rect2(float(p.get_named_attribute_value_safe("x")), float(p.get_named_attribute_value_safe("y")),
						float(p.get_named_attribute_value_safe("width")), float(p.get_named_attribute_value_safe("height"))), "props": {}}
				if p.is_empty():
					objects.append(cur)
					in_object = false
			elif n == "property":
				var k: String = p.get_named_attribute_value_safe("name")
				var v: String = p.get_named_attribute_value_safe("value")
				if in_object:
					cur["props"][k] = v
				elif depth_props_map:
					props[k] = v
		elif t == XMLParser.NODE_ELEMENT_END:
			if p.get_node_name() == "object" and in_object:
				objects.append(cur)
				in_object = false
	return {"size": size, "props": props, "objects": objects}
