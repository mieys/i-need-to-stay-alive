extends SceneTree

## Demirci (örs başında + raf bakışı) ve seyyar satıcı (dükkan noktası / dinlenme / düşünme) GERÇEK çizicide, oyundaki gerçek ölçekle (madde 112).
## NPC_CAP_DIR'e smith.png ve merchant.png yazar. Pencere kısa süre açılır.

var _dir: String = OS.get_environment("NPC_CAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()


func _grab_root() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _sheet(imgs: Array, cols: int, path: String) -> void:
	var w: int = imgs[0].get_width()
	var h: int = imgs[0].get_height()
	var rows: int = int(ceil(float(imgs.size()) / cols))
	var out := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i in imgs.size():
		var im: Image = imgs[i]
		im.convert(Image.FORMAT_RGBA8)
		out.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	out.save_png(path)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	# ---------------- demirci
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var shop := Node2D.new()
	shop.set_script(load("res://scripts/weapon_shop.gd"))
	vp.add_child(shop)
	await process_frame
	var interior: Node2D = shop._interior
	interior.visible = true
	var smith: Node2D = shop.get_smith()
	smith.set_process(false)
	# oyuncu boyu karşılaştırması: Matthew (gerçek ölçek: kök 0,5 * karakter ölçeği * SIZE)
	var ref := AnimatedSprite2D.new()
	ref.sprite_frames = load("res://assets/characters/matthew_frames.tres")
	ref.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ref.scale = Vector2.ONE * 1.968417 * EntityScale.SIZE * 0.5
	ref.offset = Vector2(0, -5)
	ref.z_index = 1
	interior.add_child(ref)
	ref.position = Vector2(-96, -20) - Vector2(0, smith.FEET_OFFSET)
	ref.play("idle_down")
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.global_position = shop.INTERIOR_OFFSET + Vector2(-48, -50)
	cam.zoom = Vector2(4, 4)
	cam.make_current()
	smith.set_feet(smith.work_feet())
	smith.lock_clip("strike", "down")
	var shots: Array = []
	for i in 4:
		await _wait(0.16)
		shots.append(await _grab(vp))
	# raf bakışı: ocak başı (yukarı) ve silah rafı (aşağı)
	smith.unlock_clip()
	smith.set_feet(Vector2(24, -24))
	smith.play_idle("up")
	cam.global_position = shop.INTERIOR_OFFSET + Vector2(24, -30)
	await _wait(0.3)
	shots.append(await _grab(vp))
	smith.set_feet(Vector2(104, 8))
	smith.play_idle("down")
	smith.say("Hoş geldin, dostum!")
	cam.global_position = shop.INTERIOR_OFFSET + Vector2(104, 0)
	await _wait(0.3)
	shots.append(await _grab(vp))
	_sheet(shots, 3, _dir.path_join("smith.png"))
	vp.queue_free()
	await process_frame
	# ---------------- seyyar satici (ana pencerede: current_scene kökün DOĞRUDAN çocuğu olmalı)
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var bg := ColorRect.new()
	bg.color = Color8(126, 176, 84)
	bg.position = Vector2(-1000, -1000)
	bg.size = Vector2(6000, 6000)
	bg.z_index = -10
	world.add_child(bg)
	var tm: Node2D = (load("res://scripts/traveling_merchant.gd") as GDScript).new()
	tm.set_process(false)
	world.add_child(tm)
	tm._spawn_visual(Vector2(1000, 1000))
	var npc: Node2D = tm._visual.get_node("MerchantNpc")
	npc.set_process(false)
	var cam2 := Camera2D.new()
	world.add_child(cam2)
	cam2.global_position = Vector2(1010, 1020)
	cam2.zoom = Vector2(4, 4)
	cam2.make_current()
	var shots2: Array = []
	npc.set_feet(npc.SERVICE_POST)
	npc.play_idle("down")
	await _wait(0.3)
	shots2.append(await _grab_root())
	npc.set_feet(npc.REST_SPOTS[0])
	npc.lock_clip("think", "down")
	cam2.global_position = Vector2(1000, 1030)
	await _wait(0.3)
	shots2.append(await _grab_root())
	npc.set_feet(npc.SERVICE_POST)
	npc.unlock_clip()
	npc.play_idle("right")
	npc.say("Merhaba, yolcu!")
	cam2.global_position = Vector2(1010, 1010)
	await _wait(0.3)
	shots2.append(await _grab_root())
	_sheet(shots2, 3, _dir.path_join("merchant.png"))
	print("BITTI")
	quit()
