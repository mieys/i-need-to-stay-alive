extends SceneTree

## SAKLANMA ÇALILIĞI prototipleri (madde 274) GERÇEK ÇİZİCİDE: gerçek harita (harita_baked, main.tscn'deki (-2, 21) ofset, adı "Harita") + main.gd'nin
## kurduğu harita görselleri (GrassSway, TreeSway, DepthOccluders -> hide_brush_visual, ForestCanopy, MapShadows, MapColorGrade, WaterFx, GroundTexelPass).
## CALI_ATLAS verilirse "Saklanma Çalılığı" katmanının atlas dokusu (harita/saklanma_calilik.png, 256x64, karo düzeni AYNI) o PNG ile değiştirilir -
## prototip oyunun kendi shader'ı, ön kopyası (içerideki karakterin bacak örtüsü) ve renk ayarıyla çizilir.
## Çalılık katmanının ekrana sığan en büyük parçası seçilir; içine 2 karakter (saklı durum), dışına 1 karakter konur. Kamera zoom 2 (oyun kamerası).
## Kullanım: Godot --path . --windowed --resolution 1280x720 -s tools/proto_20261019/calilik_capture.gd
##   ortam: CALI_ATLAS (mutlak PNG yolu; boş = şu anki atlas), CALI_OUT (çıktı PNG), CALI_PICK (kaçıncı uygun parça, varsayılan 0), CALI_AT ("x,y" hücresini içeren parça)
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

const MAX_W := 26
const MAX_H := 13
const MARGIN := 3

var _out: String = OS.get_environment("CALI_OUT")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


## 4-komşulu bağlı parçalar (hücre listeleri).
func _components(cells: Dictionary) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for c: Vector2i in cells:
		if seen.has(c):
			continue
		var comp: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c]
		seen[c] = true
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			comp.append(p)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if cells.has(q) and not seen.has(q):
					seen[q] = true
					stack.append(q)
		out.append(comp)
	return out


func _bbox(comp: Array) -> Rect2i:
	var r := Rect2i(comp[0], Vector2i.ONE)
	for c: Vector2i in comp:
		r = r.expand(c).expand(c + Vector2i.ONE)
	return r


func _depth(cells: Dictionary, c: Vector2i) -> int:
	for k in range(1, 6):
		for dy in range(-k, k + 1):
			for dx in range(-k, k + 1):
				if not cells.has(c + Vector2i(dx, dy)):
					return k - 1
	return 5


func _place(n: Node2D, feet: Vector2, offset: float) -> void:
	n.global_position = feet - Vector2(0, offset)


## HIŞIRTI kaydı (CALI_WALK=1): oyuncu çalının içinde 80 px/sn (yürüme hızı) sağa yürür, durur, sola döner; konum GERÇEK geçen süreyle ilerler
## (hide_brush_visual hızı kare süresinden hesaplar - kare kaydı yavaşlatsa da hız doğru kalır). Her kare CALI_OUT klasörüne f_###.png, zamanlar times.txt.
func _walk(player: Node2D, mid: Vector2) -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	var anim: AnimatedSprite2D = player.get("anim") as AnimatedSprite2D
	var xf: Transform2D = root.get_final_transform() * root.get_canvas_transform()
	var half := Vector2(110, 56)
	var a: Vector2 = xf * (mid + Vector2(0, -6) - half)
	var b: Vector2 = xf * (mid + Vector2(0, -6) + half)
	var times := PackedStringArray()
	var t0: int = Time.get_ticks_msec()
	var i: int = 0
	var last_dir: int = 0
	while true:
		var t: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if t > 4.0:
			break
		## 0-0,4 dur, 0,4-1,9 sağa (-60 -> +60), 1,9-2,4 dur, 2,4-3,9 sola, sonra dur
		var x: float
		var dir: int = 0
		if t < 0.4:
			x = -60.0
		elif t < 1.9:
			x = -60.0 + (t - 0.4) * 80.0
			dir = 1
		elif t < 2.4:
			x = 60.0
		elif t < 3.9:
			x = 60.0 - (t - 2.4) * 80.0
			dir = -1
		else:
			x = -60.0
		player.global_position = mid + Vector2(x, 0)
		if anim != null and dir != last_dir:
			var nm: String = "walk_right" if dir > 0 else ("walk_left" if dir < 0 else ("idle_right" if last_dir > 0 else "idle_left"))
			if anim.sprite_frames.has_animation(nm):
				anim.play(nm)
			last_dir = dir
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var rect := Rect2i(Vector2i(a), Vector2i(b - a)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(rect).save_png(_out.path_join("f_%03d.png" % i))
		times.append(str(t))
		i += 1
	var f := FileAccess.open(_out.path_join("times.txt"), FileAccess.WRITE)
	f.store_string("\n".join(times))
	f.close()
	print("SHOT walk ", i, " kare")


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 1
	gm.selected_character = 1
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var harita: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	harita.name = "Harita"
	harita.position = Vector2(-2, 21)
	scene.add_child(harita)
	var hb: GDScript = load("res://scripts/hide_brush.gd")
	var layer: TileMapLayer = hb.find_layer(harita)
	var atlas_path: String = OS.get_environment("CALI_ATLAS")
	if atlas_path != "":
		var tex := ImageTexture.create_from_image(Image.load_from_file(atlas_path))
		var ts: TileSet = layer.tile_set
		for i in range(ts.get_source_count()):
			var src := ts.get_source(ts.get_source_id(i)) as TileSetAtlasSource
			if src != null and src.texture != null and src.texture.resource_path.find("saklanma_calilik") >= 0:
				src.texture = tex
				print("atlas degisti: ", atlas_path)
	await process_frame
	load("res://scripts/grass_sway.gd").new().setup(harita)
	load("res://scripts/tree_sway.gd").new().setup(harita)
	load("res://scripts/depth_occluders.gd").new().setup(harita)
	load("res://scripts/forest_canopy.gd").new().setup(harita)
	load("res://scripts/map_shadows.gd").attach(harita)
	load("res://scripts/map_color_grade.gd").attach(harita)
	load("res://scripts/water_fx.gd").attach(harita)
	load("res://scripts/ground_texel_pass.gd").attach(harita)

	var cells: Dictionary = {}
	for c: Vector2i in layer.get_used_cells():
		cells[c] = true
	var fits: Array = []
	for comp: Array in _components(cells):
		var bb: Rect2i = _bbox(comp)
		if bb.size.x <= MAX_W and bb.size.y <= MAX_H and comp.size() >= 40:
			fits.append(comp)
	fits.sort_custom(func(a: Array, b: Array) -> bool: return a.size() > b.size())
	var comp: Array = fits[clampi(int(OS.get_environment("CALI_PICK")) if OS.get_environment("CALI_PICK") != "" else 0, 0, fits.size() - 1)]
	## CALI_AT="x,y": o hücreyi içeren parça (madde 281 ek çalılıklarına bakmak için; boyut süzgeci yok)
	if OS.get_environment("CALI_AT") != "":
		var at_s: PackedStringArray = OS.get_environment("CALI_AT").split(",")
		var at := Vector2i(int(at_s[0]), int(at_s[1]))
		for c2: Array in _components(cells):
			if c2.has(at):
				comp = c2
	var bb: Rect2i = _bbox(comp)
	var cen := Vector2(bb.get_center())
	var to_world := func(c: Vector2i) -> Vector2: return layer.to_global(layer.map_to_local(c))
	## en derin hücre (merkeze yakın) + alt kenara yakın, merkezden yatayda uzak bir hücre
	var deep: Vector2i = comp[0]
	var best: float = -1e9
	for c: Vector2i in comp:
		var s: float = float(_depth(cells, c)) * 10.0 - Vector2(c).distance_to(cen)
		if s > best:
			best = s
			deep = c
	var edge: Vector2i = deep
	best = -1e9
	for c: Vector2i in comp:
		## alt kenara yakın (altında tek sıra çalı), iki yanı en az 2 hücre çalı; derin hücreden yatayda ~5 hücre uzakta
		if cells.has(c + Vector2i(0, 1)) and not cells.has(c + Vector2i(0, 2)) and cells.has(c + Vector2i(-2, 0)) and cells.has(c + Vector2i(2, 0)) 				and cells.has(c + Vector2i(-1, 0)) and cells.has(c + Vector2i(1, 0)):
			var s2: float = -absf(absf(float(c.x - deep.x)) - 5.0)
			if s2 > best:
				best = s2
				edge = c
	var feet_off: float = float(hb.FEET_OFFSET)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.set_physics_process(false)
	var own_cam: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	player.facing = "down"
	_place(player, to_world.call(deep) + Vector2(0, 4), feet_off)
	var ally: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(ally)
	ally.setup(77, 8, "")
	_place(ally, to_world.call(edge) + Vector2(0, 2), feet_off)
	ally.set("_target_position", ally.global_position)
	## dışarıda duran karşılaştırma karakteri: parçanın altında/yanında, çalılıkta olmayan ilk hücre
	var outside: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(outside)
	outside.setup(78, 3, "")
	var out_cell := Vector2i(bb.end.x + 1, int(cen.y))
	for cand: Vector2i in [Vector2i(bb.end.x + 1, int(cen.y)), Vector2i(bb.position.x - 2, int(cen.y)), Vector2i(int(cen.x) + 3, bb.end.y + 1),
			Vector2i(int(cen.x) - 3, bb.end.y + 1), Vector2i(int(cen.x), bb.position.y - 2)]:
		var wp: Vector2 = to_world.call(cand)
		if not cells.has(cand) and not bool(gm.call("is_position_blocked_by_walls", wp)):
			out_cell = cand
			break
	_place(outside, to_world.call(out_cell), feet_off)
	outside.set("_target_position", outside.global_position)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	var r_world := Rect2(to_world.call(bb.position) - Vector2(8, 8), Vector2(bb.size * 16))
	cam.global_position = r_world.get_center()
	cam.make_current()
	await _frames(40)
	player.call("set_brush_state", 1)
	## CALI_ALLY_STATE=2: arkadaş "görüldü" durumunda (saklanma göstergesi, madde 275)
	ally.call("set_brush_state", int(OS.get_environment("CALI_ALLY_STATE")) if OS.get_environment("CALI_ALLY_STATE") != "" else 1)
	await _frames(30)
	if OS.get_environment("CALI_WALK") != "":
		await _walk(player, to_world.call(deep) + Vector2(0, 4) - Vector2(0, feet_off))
		quit()
		return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var xf: Transform2D = root.get_final_transform() * root.get_canvas_transform()
	var a: Vector2 = xf * (r_world.position - Vector2(MARGIN * 16, MARGIN * 16))
	var b: Vector2 = xf * (r_world.end + Vector2(MARGIN * 16, MARGIN * 16))
	var rect := Rect2i(Vector2i(a), Vector2i(b - a)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_out)
	print("SHOT ", _out, " parca=", comp.size(), " bb=", bb, " deep=", deep, " edge=", edge, " out=", out_cell)
	quit()
