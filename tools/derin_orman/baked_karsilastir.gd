extends SceneTree

## Pişmiş iki harita sahnesini HÜCRE HÜCRE karşılaştırır (madde 372: zemin tileset'i bölününce görüntü birebir aynı mı?): her katmanın kullanılan hücreleri, her hücrenin
## çevirme bayrakları + alternatif kimliği + animasyon kare sayısı/süreleri + HER karenin piksel özeti (doku bölgesinden). Kaynak numaraları farklı olabilir, piksel aynı olmalı.
## Kullanım: Godot --headless --path . -s tools/derin_orman/baked_karsilastir.gd -- res://scenes/_eski_harita.tscn res://scenes/harita_baked_new.tscn


func _initialize() -> void:
	_run.call_deferred()


func _tile_hash(layer: TileMapLayer, cell: Vector2i, cache: Dictionary, imgs: Dictionary) -> String:
	var sid: int = layer.get_cell_source_id(cell)
	var coords: Vector2i = layer.get_cell_atlas_coords(cell)
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	var td: TileData = layer.get_cell_tile_data(cell)
	var flags: String = "%s%s%s%d" % ["h" if td != null and td.flip_h else "-", "v" if td != null and td.flip_v else "-", "t" if td != null and td.transpose else "-", layer.get_cell_alternative_tile(cell)]
	var key := "%d:%d:%d" % [sid, coords.x, coords.y]
	if not cache.has(key):
		var parts := PackedStringArray()
		if src != null and src.texture != null:
			if not imgs.has(src):
				var im: Image = src.texture.get_image()
				if im.is_compressed():
					im.decompress()
				im.convert(Image.FORMAT_RGBA8)
				imgs[src] = im
			var img: Image = imgs[src]
			var n: int = maxi(1, src.get_tile_animation_frames_count(coords))
			for k in range(n):
				var reg: Rect2i = src.get_tile_texture_region(coords, k)
				var data: PackedByteArray = img.get_region(reg).get_data()
				## tamamen saydam piksellerin RGB'si önemsiz (içe aktarmanın alfa kenar düzeltmesi komşu karolardan renk taşır): sıfırla
				for i in range(0, data.size(), 4):
					if data[i + 3] == 0:
						data[i] = 0
						data[i + 1] = 0
						data[i + 2] = 0
				var h := HashingContext.new()
				h.start(HashingContext.HASH_SHA1)
				h.update(data)
				parts.append("%s@%.3f" % [h.finish().hex_encode(), src.get_tile_animation_frame_duration(coords, k) if n > 1 else 0.0])
		cache[key] = ",".join(parts)
	return flags + "|" + String(cache[key])


func _layers(root_node: Node) -> Dictionary:
	var out: Dictionary = {}
	for n in root_node.find_children("*", "TileMapLayer", true, false):
		out[String(root_node.get_path_to(n))] = n
	return out


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var a_root: Node = (load(args[0]) as PackedScene).instantiate()
	var b_root: Node = (load(args[1]) as PackedScene).instantiate()
	root.add_child(a_root)
	root.add_child(b_root)
	var la: Dictionary = _layers(a_root)
	var lb: Dictionary = _layers(b_root)
	var ca: Dictionary = {}
	var cb: Dictionary = {}
	var ia: Dictionary = {}
	var ib: Dictionary = {}
	var bad: int = 0
	var cells: int = 0
	for path: String in la:
		if not lb.has(path):
			print("KARSI YOK ", path)
			bad += 1
			continue
		var A: TileMapLayer = la[path]
		var B: TileMapLayer = lb[path]
		var used_a: Array[Vector2i] = A.get_used_cells()
		var used_b: Array[Vector2i] = B.get_used_cells()
		if used_a.size() != used_b.size():
			print("HÜCRE SAYISI FARKLI ", path, " ", used_a.size(), " ", used_b.size())
			bad += 1
			continue
		var layer_bad: int = 0
		for c: Vector2i in used_a:
			cells += 1
			if B.get_cell_source_id(c) == -1 or _tile_hash(A, c, ca, ia) != _tile_hash(B, c, cb, ib):
				layer_bad += 1
				if layer_bad <= 2:
					print("FARK ", path, " ", c, " ", _tile_hash(A, c, ca, ia), " <> ", _tile_hash(B, c, cb, ib))
		bad += layer_bad
	for path: String in lb:
		if not la.has(path):
			print("YENİ KATMAN ", path)
			bad += 1
	print("BAKED_KARSILASTIRMA ", "BIREBIR AYNI" if bad == 0 else "FARKLI (%d)" % bad, " | katman ", la.size(), " | hücre ", cells, " | tekil karo ", ca.size(), "/", cb.size())
	quit()
