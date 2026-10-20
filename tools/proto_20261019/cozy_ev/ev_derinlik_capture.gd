extends SceneTree

## Cozy ev ÇARPIŞMA v2 + DERİNLİK (madde 313) gerçek çizicide: KAP_DIR'e yazar
##  carpisma.png : ev + engel dikdörtgenleri (yarı saydam kırmızı) - eşyaların yalnız taban izi engel mi
##  derinlik.png : kapıdan yatak odasına giren / koltuğun arkasında / yatağın önünde duran karakterler (zoom 4): arkasındaysa eşya/duvar üstte
## Gizli masaüstünde koşulur (tools/fps_micro/hidden_launch.ps1).

var _dir: String = OS.get_environment("KAP_DIR")


class RectOverlay extends Node2D:
	var rects: Array = []

	func _draw() -> void:
		for r in rects:
			draw_rect(r, Color(1.0, 0.1, 0.1, 0.38), true)
			draw_rect(r, Color(1.0, 0.2, 0.2, 0.9), false, 1.0)


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
	fp.add_to_group("remote_players") ## derinlik ön kopyası karakter listesine alsın
	parent.add_child(fp)
	fp.position = feet - Vector2(0.0, 12.75)
	spr.play(clip)
	return fp


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = Vector2i(1320, 720)
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
	# ---------------- çarpışma dikdörtgenleri (zoom 2)
	var ov := RectOverlay.new()
	ov.rects = house.collision_rects()
	ov.z_index = 50
	house._interior_instance.add_child(ov)
	cam.zoom = Vector2(2.0, 2.0)
	cam.position = offset + Vector2(320.0, 184.0)
	await _wait(0.4)
	(await _grab(vp)).save_png(_dir.path_join("carpisma.png"))
	ov.visible = false
	# ---------------- derinlik: kapıda (duvarın arkası), koltuğun arkası, yatağın önü
	var inner: Node = house._interior_instance
	## yatak odası kapıları açık (oyunda yaklaşınca açılır)
	for d: Dictionary in house._room_doors:
		d["frame"] = house.ROOM_DOOR_FRAMES - 1
		for j in 3:
			for i in 2:
				(d["layer"] as TileMapLayer).set_cell((d["origin"] as Vector2i) + Vector2i(i, j), int(d["sid"]), Vector2i(2 * (house.ROOM_DOOR_FRAMES - 1) + i, j))
	var cases: Array = [
		[Vector2(288.0, 200.0), "walk_up", Vector2(288.0, 196.0)],   ## sol yatak odası kapı aralığından içeri giriyor
		[Vector2(266.0, 200.0), "idle_down", Vector2(280.0, 196.0)], ## kapının solundaki duvarın arkasında (oda içinde)
		[Vector2(361.0, 169.0), "idle_down", Vector2(364.0, 160.0)], ## şömine koltuğunun sırtının arkasında (bacakları koltukla örtülmeli)
		[Vector2(288.0, 236.0), "walk_up", Vector2(288.0, 210.0)],   ## kapının önünde (duvarın önü)
	]
	vp.size = Vector2i(420, 300)
	cam.zoom = Vector2(4.0, 4.0)
	var shots: Array = []
	for c in cases:
		var f: Node2D = _fake(inner, "res://assets/characters/matthew_frames.tres", c[1], c[0])
		cam.position = offset + (c[2] as Vector2)
		await _wait(0.35)
		shots.append(await _grab(vp))
		f.queue_free()
		await process_frame
	_sheet(shots, 2, _dir.path_join("derinlik.png"))
	print("KAP derinlik tamam rects=", house.collision_rects().size())
	quit(0)
