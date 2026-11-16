extends SceneTree

## Matthew şimşek efektlerinin hafif parıltısı (2026-11-16) A/B yakalaması: üst sıra ESKİ (malzeme yok), alt sıra YENİ (fx_pixel_glow).
## Gerçek çizicide (Vulkan) shader derlenir mi + görünüş. Oyun kurulmaz, yalnız efekt sprite'ları (matthew_lightning.gd make_sprite,
## fx_matthew_bolt.tscn, iz sayfası) sabit karede dizilir. Kareler MP_DIR'e. Koşturucu: matthew_parilti_run.ps1 (gizli masaüstü).
## -s betikleri autoload'lardan ÖNCE derlenir: oyun betikleri load() ile.

var _dir: String = OS.get_environment("MP_DIR")
var ML: GDScript = null


func _initialize() -> void:
	_run.call_deferred()


func _bg(parent: Node, rect: Rect2, c: Color) -> void:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = c
	parent.add_child(r)


func _sheet(parent: Node2D, kind: String, frame: int, at: Vector2, glow: bool) -> void:
	var spr: AnimatedSprite2D = ML.call("make_sprite", kind, 1.0)
	if not glow:
		spr.material = null
	spr.frame = frame
	spr.position = at
	parent.add_child(spr)


func _bolt(parent: Node2D, at: Vector2, glow: bool, stage: int) -> void:
	var bolt: Node2D = (load("res://scenes/fx_matthew_bolt.tscn") as PackedScene).instantiate()
	parent.add_child(bolt)
	bolt.position = at
	bolt.call("setup", 150.0 * float(ML.get("WORLD_TEXEL")), Color.WHITE)
	bolt.set_process(false)
	bolt.call("_set_stage", stage)
	bolt.scale = Vector2.ONE / float(ML.get("WORLD_TEXEL")) ## 1 doku px = 1 birim
	for t: Array in bolt.get("_tiles"):
		if not glow:
			(t[0] as Sprite2D).material = null


func _trail(parent: Node2D, at: Vector2, glow: bool, strong: bool) -> void:
	var tex: Texture2D = ML.call("sheet_texture", "trail_max" if strong else "trail")
	var tile: Vector2 = ML.get("TRAIL_TILE")
	for i in range(8):
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.region_enabled = true
		spr.region_rect = Rect2(float(clampi(i, 0, 7)) * tile.x, float(i % 3) * tile.y, tile.x, tile.y) ## en yenisi solda (evre 0), sağa doğru söner
		if glow:
			spr.material = ML.call("glow_material", tile)
		spr.position = at + Vector2(float(i) * tile.x, 0.0)
		parent.add_child(spr)


func _scene(glow_rows: bool, which: int) -> Node2D:
	var root := Node2D.new()
	get_root().add_child(root)
	var layer := CanvasLayer.new()
	layer.layer = -1
	root.add_child(layer)
	_bg(layer, Rect2(0, 0, 1920, 540), Color(0.345, 0.47, 0.27)) ## çimen tonu
	_bg(layer, Rect2(0, 540, 1920, 540), Color(0.09, 0.1, 0.11)) ## karanlık zemin
	var world := Node2D.new()
	root.add_child(world)
	world.scale = Vector2.ONE * (3.0 if which == 0 else 1.0)
	for band in range(2): ## 0 çimen, 1 karanlık
		if which == 0: ## küçük efektler: bantta üst = ESKİ, alt = YENİ
			for row in range(2):
				var g: bool = row == 1
				var y: float = (float(band) * 540.0 + 135.0 + float(row) * 270.0) / world.scale.y
				_sheet(world, "impact", 1, Vector2(50, y), g)
				_sheet(world, "impact_ring", 1, Vector2(120, y), g)
				_sheet(world, "ball", 2, Vector2(190, y), g)
				_sheet(world, "form_burst", 1, Vector2(262, y), g)
				_sheet(world, "cast", 2, Vector2(330, y - 10.0), g)
				_bolt(world, Vector2(372, y), g, 1)
				_trail(world, Vector2(530, y), g, true)
		else: ## büyük efektler: bantta sol = ESKİ, sağ = YENİ
			var y2: float = float(band) * 540.0 + 270.0
			_sheet(world, "shield_loop", 3, Vector2(70, y2), false)
			_sheet(world, "shield_loop", 3, Vector2(175, y2), true)
			_sheet(world, "shield_pop", 2, Vector2(330, y2), false)
			_sheet(world, "shield_pop", 2, Vector2(535, y2), true)
			_sheet(world, "nova", 4, Vector2(890, y2), false)
			_sheet(world, "nova", 4, Vector2(1400, y2), true)
	return root


## Büyücü Arcane Patlama (madde 739): zemin + ön sayfa aynı karede üst üste (oyundaki gibi); her bantta sırayla ESKİ / YENİ, 3 kare.
func _arcane_scene() -> Node2D:
	var root := Node2D.new()
	get_root().add_child(root)
	var layer := CanvasLayer.new()
	layer.layer = -1
	root.add_child(layer)
	_bg(layer, Rect2(0, 0, 1920, 540), Color(0.345, 0.47, 0.27))
	_bg(layer, Rect2(0, 540, 1920, 540), Color(0.09, 0.1, 0.11))
	var world := Node2D.new()
	world.scale = Vector2.ONE * 2.0
	root.add_child(world)
	var glow_script: GDScript = load("res://scripts/fx_pixel_glow.gd")
	var old_mat := ShaderMaterial.new()
	old_mat.shader = load("res://shaders/toplamali.gdshader")
	var col: int = 0
	for band in range(2):
		col = 0
		for fr in [2, 5, 8]:
			for g in [false, true]:
				var at := Vector2(80.0 + float(col) * 145.0, (float(band) * 540.0 + 270.0) / 2.0)
				col += 1
				for sheet in ["patlama_ground", "patlama_front"]:
					var s := Sprite2D.new()
					s.texture = load("res://assets/fx/buyucu/%s.png" % sheet)
					s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					s.hframes = 12
					s.frame = fr
					s.position = at
					s.material = glow_script.call("material", Vector2(128, 144), true) if g else old_mat
					world.add_child(s)
	return root


func _run() -> void:
	ML = load("res://scripts/matthew_lightning.gd")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	if OS.get_environment("MP_MODE") == "arcane":
		var r: Node2D = _arcane_scene()
		for _i in range(12):
			await process_frame
		var im: Image = get_root().get_texture().get_image()
		im.save_png(_dir.path_join("arcane.png"))
		print("SHOT arcane ", im.get_size())
		r.queue_free()
		print("BITTI")
		quit(0)
		return
	for which in range(2):
		var root: Node2D = _scene(true, which)
		for _i in range(12):
			await process_frame
		var img: Image = get_root().get_texture().get_image()
		var path: String = _dir.path_join("parilti_%d.png" % which)
		img.save_png(path)
		print("SHOT ", path, " ", img.get_size())
		root.queue_free()
		await process_frame
	print("BITTI")
	quit(0)
