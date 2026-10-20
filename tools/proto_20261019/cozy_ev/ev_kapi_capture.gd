extends SceneTree

## Ev ici KAPI + DUVAR derinligi (madde 328) gercek cizicide: KAP_DIR'e yazar
##  kapi.png : sol yatak odasi kapisinda (x 288) karakter farkli y'lerde (kuzeyden guneye) - kapi ustu / duvar basi karakteri ortmeli
##  duvar.png: kapinin yanindaki duvar sutununun arkasi / onu (x 268, x 308)
##  giris.png: ana giris kapisi (alt duvar, x 24-26) onunde / icinde / arkasi
## Gizli masaustunde koşulur (ev_run.ps1).

var _dir: String = OS.get_environment("KAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	var im: Image = vp.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _sheet(imgs: Array, cols: int, path: String) -> void:
	var w: int = imgs[0].get_width()
	var h: int = imgs[0].get_height()
	var rows: int = int(ceil(float(imgs.size()) / cols))
	var out := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		out.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	out.save_png(path)


func _fake(parent: Node, frames: String, clip: String, feet: Vector2) -> Node2D:
	var fp := Node2D.new()
	fp.scale = Vector2(0.5, 0.5)
	fp.z_index = 1
	var spr := AnimatedSprite2D.new()
	spr.name = "AnimatedSprite2D"
	spr.sprite_frames = load(frames)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * 2.2368375 * EntityScale.SIZE
	spr.offset = Vector2(0.0, -5.0)
	fp.add_child(spr)
	fp.add_to_group("remote_players")
	parent.add_child(fp)
	fp.position = feet - Vector2(0.0, 12.75)
	spr.play(clip)
	return fp


func _shots(vp: SubViewport, cam: Camera2D, inner: Node, offset: Vector2, cases: Array, path: String, cols: int) -> void:
	var shots: Array = []
	for c in cases:
		var f: Node2D = _fake(inner, "res://assets/characters/matthew_frames.tres", c[1], c[0])
		cam.position = offset + (c[2] as Vector2)
		await _wait(0.3)
		shots.append(await _grab(vp))
		f.queue_free()
		await process_frame
	_sheet(shots, cols, path)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = Vector2i(240, 240)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var player := CharacterBody2D.new()
	player.set_script(load("res://tests/test_babaanne.gd").FakePlayer)
	player.add_to_group("player")
	vp.add_child(player)
	var house := Node2D.new()
	house.set_script(load("res://scripts/house_interior.gd"))
	vp.add_child(house)
	await process_frame
	house.set_process(false)
	var offset: Vector2 = house.INTERIOR_OFFSET
	player.global_position = offset + Vector2(-5000.0, 0.0)
	var bab = house.get_babaanne()
	bab.set_process(false)
	bab.visible = false
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(4.0, 4.0)
	var inner: Node = house._interior_instance
	var open: bool = OS.get_environment("KAP_OPEN") != "0"
	if open:
		for d: Dictionary in house._room_doors:
			d["frame"] = house.ROOM_DOOR_FRAMES - 1
			for j in 3:
				for i in 2:
					(d["layer"] as TileMapLayer).set_cell((d["origin"] as Vector2i) + Vector2i(i, j), int(d["sid"]), Vector2i(2 * (house.ROOM_DOOR_FRAMES - 1) + i, j))
	# ---------------- yatak odasi kapisi (KAP_X, varsayilan sol kapi 288): guneyden kuzeye yurunurken
	var kx: float = float(OS.get_environment("KAP_X")) if OS.get_environment("KAP_X") != "" else 288.0
	vp.size = Vector2i(240, 270)
	cam.zoom = Vector2(3.0, 3.0)
	var cases: Array = []
	for y: float in [230.0, 222.0, 214.0, 206.0, 198.0, 190.0, 182.0, 174.0, 166.0, 158.0]:
		cases.append([Vector2(kx, y), "walk_up", Vector2(kx, 192.0)])
	await _shots(vp, cam, inner, offset, cases, _dir.path_join("kapi.png"), 5)
	print("KAP kapi tamam")
	quit(0)
