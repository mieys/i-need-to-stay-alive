extends SceneTree

## Cozy ev + BABAANNE gerçek çizicide (madde 310): ev genel görünüşü + babaannenin her işi yakından (kazan, toz, okuma koltuğu, şömine,
## yatak) + oyuncu boyu karşılaştırması (Matthew). BAB_CAP_DIR'e genel.png ve isler.png yazar.
## Gizli masaüstünde koşulur (tools/fps_micro/hidden_launch.ps1), kullanıcıya pencere açılmaz.

var _dir: String = OS.get_environment("BAB_CAP_DIR")


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


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = Vector2i(1320, 700)
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
	player.global_position = offset + Vector2(-5000.0, 0.0) ## evde kimse yok: babaanne işine dalsın
	var bab = house.get_babaanne()
	bab.set_process(false)
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()
	# ---------------- genel görünüş (zoom 2): babaanne kazan başında
	bab._clock_override = 15.0
	bab._switch_activity(bab.Act.COOK, true)
	cam.zoom = Vector2(2.0, 2.0)
	cam.position = offset + Vector2(320.0, 184.0)
	await _wait(0.5)
	(await _grab(vp)).save_png(_dir.path_join("genel.png"))
	# ---------------- işler yakından (zoom 5)
	vp.size = Vector2i(500, 340)
	cam.zoom = Vector2(5.0, 5.0)
	var shots: Array = []
	## [iş, gün saati, gün] - saat programla aynı olmalı yoksa babaanne programdaki işe döner
	var acts: Array = [[bab.Act.COOK, 15.0, 0], [bab.Act.WIPE, 60.0, 0], [bab.Act.WIPE, 60.0, 0], [bab.Act.WIPE, 60.0, 0],
		[bab.Act.READ, 120.0, 0], [bab.Act.FIRE_SIT, 260.0, 0], [bab.Act.FIRE_READ, 400.0, 1], [bab.Act.SLEEP, 480.0, 0]]
	for i in acts.size():
		bab._clock_override = acts[i][1]
		bab._day_override = acts[i][2]
		bab._switch_activity(acts[i][0], true)
		for k in 12:
			bab._process(0.1) ## oturma geçişi -> poz
		bab.set_process(false)
		cam.position = bab.global_position + Vector2(0.0, -4.0)
		await _wait(0.35)
		shots.append(await _grab(vp))
	_sheet(shots, 4, _dir.path_join("isler.png"))
	# ---------------- selam + çorba: oyuncu (Matthew) içeri girer, canı eksik
	var ref := AnimatedSprite2D.new()
	ref.sprite_frames = load("res://assets/characters/matthew_frames.tres")
	ref.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ref.scale = Vector2.ONE * 2.2368375 * EntityScale.SIZE * 0.5
	ref.offset = Vector2(0.0, -5.0)
	ref.play("idle_up")
	player.add_child(ref)
	player.health = 40.0
	bab._clock_override = 60.0
	bab._switch_activity(bab.Act.COOK, true)
	player.global_position = offset + Vector2(150.0, 150.0)
	bab.set_process(true)
	var feed_shots: Array = []
	cam.zoom = Vector2(3.0, 3.0)
	vp.size = Vector2i(600, 400)
	for k in 4:
		await _wait(0.9)
		cam.position = (bab.global_position + player.global_position) * 0.5
		feed_shots.append(await _grab(vp))
	_sheet(feed_shots, 2, _dir.path_join("corba.png"))
	print("BAB_CAP tamam can=", player.health)
	quit(0)
