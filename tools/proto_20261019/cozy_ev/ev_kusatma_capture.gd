extends SceneTree

## EV KUŞATMASI + AÇILIŞ (madde 313) gerçek çizicide: KAP_DIR'e yazar
##  mutfak.png  : babaanne kazanı dibinde karıştırır / tezgahta doğrar (zoom 5)
##  acilis.png  : açılış - oturan/duran oyuncular + depremde korku balonları, babaanne pencereden bakıp konuşur (zoom 2)
##  hasar.png   : ev canı %20 - duvar çatlakları + tavandan dökülen parçalar (zoom 2)
##  disari.png  : yıkılınca dışarıdaki babaanne: can çubuğu + korku (zoom 4)
## Gizli masaüstünde koşulur (tools/fps_micro/hidden_launch.ps1), kullanıcıya pencere açılmaz.

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


func _fake(parent: Node, frames: String, clip: String) -> Node2D:
	var fp := Node2D.new()
	fp.scale = Vector2(0.5, 0.5)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load(frames)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * 2.2368375 * EntityScale.SIZE
	spr.offset = Vector2(0.0, -5.0)
	spr.name = "AnimatedSprite2D"
	fp.add_child(spr)
	parent.add_child(fp)
	spr.play(clip)
	fp.z_index = 1
	return fp


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
	player.global_position = offset + Vector2(-5000.0, 0.0)
	var bab = house.get_babaanne()
	bab.set_process(false)
	var intro = house.get_intro()
	intro.set_process(false)
	var siege = house.get_siege()
	siege.set_process(false)
	var fx = house.get_damage_fx()
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()
	# ---------------- mutfak: karıştırma + doğrama (zoom 5)
	vp.size = Vector2i(500, 380)
	cam.zoom = Vector2(5.0, 5.0)
	var kshots: Array = []
	bab._clock_override = 15.0
	bab._switch_activity(bab.Act.COOK, true)
	## KAP_STIR_DY: "a,b,c" -> kazan noktasını bu kadar dikey kaydırarak ek kareler (yakınlık karşılaştırması)
	var dys: Array = [0.0]
	for v in OS.get_environment("KAP_STIR_DY").split(",", false):
		dys.append(float(v))
	var cooks: Array = []
	for dy in dys:
		cooks.append({"feet": bab.stir_spot["feet"] + Vector2(0.0, dy), "face": "up", "pose": "stir"})
	cooks.append({"feet": bab.chop_spot["feet"], "face": "up", "pose": "chop"})
	for t in cooks:
		bab._target = t
		bab._start_pose()
		cam.position = offset + Vector2(120.0, 100.0)
		await _wait(0.4)
		kshots.append(await _grab(vp))
	_sheet(kshots, mini(kshots.size(), 4), _dir.path_join("mutfak.png"))
	# ---------------- açılış (zoom 2): oyuncular yerlerinde, deprem -> korku, babaanne pencerede
	vp.size = Vector2i(1100, 600)
	cam.zoom = Vector2(2.0, 2.0)
	cam.position = offset + Vector2(390.0, 190.0)
	var chars: Array = ["matthew", "assasin", "elara", "korsan", "sovalye", "melek"]
	var fakes: Array = []
	for i in chars.size():
		var sp: Dictionary = house.intro_spot(i)
		var clip: String = ("ride_" if sp["seat"] else "idle_") + String(sp["face"])
		var fp: Node2D = _fake(house._interior_instance, "res://assets/characters/%s_frames.tres" % chars[i], clip)
		fp.position = (sp["feet"] as Vector2) - Vector2(0.0, 12.75)
		fakes.append(fp)
	intro._set_phase(intro.Phase.PEACE, 0.0)
	bab._switch_activity(bab.Act.COOK, true)
	await _wait(0.4)
	var ashots: Array = [await _grab(vp)]
	intro._set_phase(intro.Phase.COUNTDOWN, 0.0) ## deprem: toz + korku (balonlar sadece gerçek oyunculara - burada elle)
	for i in fakes.size():
		if i % 3 != 2:
			load("res://scripts/fear_emote.gd").show_on(fakes[i], [0, 2, 1][i % 3], 4.0)
	bab._switch_activity(bab.Act.WORRY, true)
	bab.set_process(true)
	await _wait(0.9)
	ashots.append(await _grab(vp))
	bab.set_process(false)
	intro._set_phase(intro.Phase.COUNTDOWN, 8.0)
	bab._switch_activity(bab.Act.WINDOW, true)
	for k in 25:
		bab._process(0.1)
	await _wait(0.3)
	ashots.append(await _grab(vp))
	for k in 45:
		bab._process(0.1)
	await _wait(0.3)
	ashots.append(await _grab(vp))
	_sheet(ashots, 2, _dir.path_join("acilis.png"))
	for fp in fakes:
		fp.queue_free()
	# ---------------- hasar: can %20 + dökülen parçalar
	intro._set_phase(intro.Phase.DONE, 0.0)
	siege.hp = 0.2 * siege.MAX_HP
	fx._process(0.3)
	for i in 6:
		fx.debris_burst(fx._random_floor_point(), 4, true)
	await _wait(0.25)
	var hshots: Array = [await _grab(vp)]
	await _wait(1.3)
	hshots.append(await _grab(vp))
	_sheet(hshots, 1, _dir.path_join("hasar.png"))
	# ---------------- ev canı çubuğu (HUD) + kapıdan kıymıklar (oyuncu içeride, ev saldırı altında)
	player.is_indoors = true
	player.global_position = offset + Vector2(408.0, 250.0)
	siege.hp = 0.55 * siege.MAX_HP
	siege.under_attack = true
	vp.size = Vector2i(900, 520)
	cam.zoom = Vector2(3.0, 3.0)
	cam.position = offset + Vector2(408.0, 268.0)
	for i in 6:
		house._hp_bar._process(0.1)
	fx.door_hit(0.55)
	await _wait(0.22)
	var dshots: Array = [await _grab(vp)]
	fx.door_hit(0.55)
	await _wait(1.4)
	dshots.append(await _grab(vp))
	_sheet(dshots, 1, _dir.path_join("kapi_can.png"))
	siege.under_attack = false
	player.is_indoors = false
	player.global_position = offset + Vector2(-5000.0, 0.0)
	# ---------------- dışarıda babaanne
	var world := Node2D.new()
	vp.add_child(world)
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.52, 0.27)
	bg.size = Vector2(400, 300)
	bg.position = Vector2(800.0, 850.0)
	bg.z_index = -10
	world.add_child(bg)
	bab.go_outside(world, Vector2(1000.0, 1000.0))
	bab.set_process(true)
	bab.take_damage(35.0, null)
	vp.size = Vector2i(400, 300)
	cam.zoom = Vector2(4.0, 4.0)
	cam.position = Vector2(1000.0, 985.0)
	await _wait(0.6)
	(await _grab(vp)).save_png(_dir.path_join("disari.png"))
	print("KAP tamam slots=", fx.crack_slots().size(), " cracks=", fx.visible_crack_count(), " granny=", siege.granny_hp)
	quit(0)
