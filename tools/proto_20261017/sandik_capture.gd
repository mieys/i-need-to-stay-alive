extends SceneTree

## "B Işık Sütunu" sandıkları (madde 242) GERÇEK ÇİZİCİDE: 1) oyun ölçeği (oyuncu kökü 0,5, kamera zoom 2) - gerçek chest_drop.tscn
## normal + elit, bekleme döngüsü, sonra dünyadaki açılış (_open_chest_for, ödülsüz); 2) ödül ekranı - gerçek chest_open_anim.gd
## (nadirlik 2 + elit) karartılmış katmanda. Kareler SC_CAP_DIR'e w_<ms>.png / r_<ms>.png.
## Kullanım (pencere açar, ~7 sn): Godot --path . -s tools/proto_20261017/sandik_capture.gd   (SC_CAP_DIR ortam değişkeni)
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("SC_CAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


## rect: görüntü MERKEZİNE göre (pencere görüntüsü mantıksal 1920x1080'den farklı boyutta olabilir).
func _shot(prefix: String, ms: int, rect: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c := Vector2i(img.get_width() / 2, img.get_height() / 2)
	var r := Rect2i(rect.position + c, rect.size).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(r).save_png(_dir.path_join("%s_%05d.png" % [prefix, ms]))


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 5
	gm.selected_character = 16
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.global_position = Vector2(3000, 3000)
	player.set_physics_process(false)
	## SC_NIGHT=1: gerçek gün-gece sistemi (main.gd gibi atmosfer + renk katmanı), derin gece kilidi, açık hava -> sandık gece ışığı
	## (madde 243). Atmosfer sandıklardan ÖNCE eklenir (node_added ile ışık takılsın). Bu kipte ödül ekranı çekilmez.
	var night: bool = OS.get_environment("SC_NIGHT") == "1"
	if night:
		var atmo: Node2D = (load("res://scripts/atmosphere.gd") as GDScript).new()
		atmo.name = "Atmosphere"
		scene.add_child(atmo)
		scene.add_child(atmo.create_overlay_layer())
		atmo.set("weather", 0)
		atmo.set("rain_intensity", 0.0)
		atmo.set("wind_intensity", 0.0)
		atmo.set("storm_intensity", 0.0)
		atmo.set("cycle_time", 465.0)
		atmo.call("set_night_lock", true)
	var chests: Array = []
	for i in 2:
		var c: Area2D = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
		c.is_elite = i == 1
		scene.add_child(c)
		c.global_position = player.global_position + Vector2(70 + 80 * i, 4)
		c.set_deferred("monitoring", false)
		chests.append(c)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = player.global_position + Vector2(70, -14)
	cam.make_current()
	await _wait(0.6)
	var vs: Vector2 = Vector2(root.get_visible_rect().size)
	var wrect := Rect2i(-260, -170, 520, 300)
	var t0: int = Time.get_ticks_msec()
	var opened := [false, false]
	while Time.get_ticks_msec() - t0 < 3600:
		var ms: int = Time.get_ticks_msec() - t0
		for i in 2:
			if not opened[i] and ms > 2400 + 250 * i and is_instance_valid(chests[i]):
				opened[i] = true
				chests[i].call("_open_chest_for", null, false)
		await _shot("w", ms, wrect)
		await process_frame
	if night:
		print("BITTI")
		quit()
		return
	## 2) ödül ekranı
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.08, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var ChestOpenAnim: GDScript = load("res://scripts/chest_open_anim.gd")
	for i in 2:
		var a: Control = ChestOpenAnim.new()
		a.setup(i == 1, 2)
		a.chime_on_burst = false
		layer.add_child(a)
		a.size = a.custom_minimum_size
		a.position = Vector2(vs.x * 0.5 - 420 + 460 * i, vs.y * 0.5 - 150)
	var rrect := Rect2i(-470, -470, 940, 720)
	print("goruntu: ", root.get_texture().get_image().get_size(), " mantiksal: ", vs)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2400:
		await _shot("r", Time.get_ticks_msec() - t0, rrect)
		await process_frame
	print("BITTI")
	quit()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
