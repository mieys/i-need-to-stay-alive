extends SceneTree

## Yakın dövüş ZİNCİRİ önce/sonra yakalaması (madde 347): 6 yakın dövüş silahı x saldırı hızı katları (YZ_RATES, "1,2,4"), GERÇEK
## weapon.gd atışı, oyundaki ölçek (oyuncu kökü 0,5, kamera zoom 2). Kareler bölüm boyunca bellekte toplanır (disk yazımı kare hızını
## bozmasın), bölüm sonunda YZ_DIR/<silah>_x<kat>/f_<sıra>_<ms>.png. GIF: yakin_zincir_gif.py.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261020/yakin_zincir_run.ps1 -Tag once|sonra (gizli masaüstü)
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

const KEYS := ["uzunkilic", "dagger", "topuz", "pence", "mizrak", "kalkan"]
const CROP := Vector2i(480, 260)

var _dir: String = OS.get_environment("YZ_DIR")
var _rates: Array = []
var _keys: Array = KEYS
var _dur: float = float(OS.get_environment("YZ_DUR")) if OS.get_environment("YZ_DUR") != "" else 0.0 ## 0 = kata göre
var _player: Node2D = null


func _initialize() -> void:
	var r: String = OS.get_environment("YZ_RATES")
	for s in (r if r != "" else "1,2,4").split(","):
		_rates.append(float(s))
	if OS.get_environment("YZ_KEYS") != "":
		_keys = Array(OS.get_environment("YZ_KEYS").split(","))
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _slime(scene: Node2D, pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 6000000.0
	e.health = 6000000.0
	return e


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 1
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var ed: GDScript = load("res://scripts/enchant_defs.gd")
	gm.set("owned_weapons", [ed.call("new_weapon_entry", _keys[0], 1, 0)])
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5)
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.make_current()
	for key: String in _keys:
		for w in (_player.get("owned_weapon_nodes") as Array).duplicate():
			if is_instance_valid(w):
				w.free()
		(_player.get("owned_weapon_nodes") as Array).clear()
		gm.set("owned_weapons", [ed.call("new_weapon_entry", key, 1, 0)])
		_player.call("buy_weapon_copy", key, 3)
		var w: Node = (_player.get("owned_weapon_nodes") as Array)[0]
		if w.has_method("set_enchant_glow_tier"):
			w.call("set_enchant_glow_tier", 3)
		if w.has_method("_apply_tier_art"):
			w.call("_apply_tier_art", 3)
		var reach: float = float(w.get("attack_range"))
		var e1: Node2D = _slime(scene, _player.global_position + Vector2(minf(78.0, reach * 0.6), 10.0))
		var e2: Node2D = _slime(scene, e1.global_position + Vector2(30.0, -18.0))
		cam.global_position = _player.global_position + Vector2(minf(78.0, reach * 0.6) * 0.5 + 6.0, -12.0)
		for rate: float in _rates:
			w.call("set_fire_rate_mult", 1.0 / rate)
			print("Z ", key, " x", rate, " range=", reach, " wait=", w.call("_effective_fire_wait"), " speed=", w.call("_melee_effect_speed_scale"))
			await _wait(1.0)
			var dur: float = _dur if _dur > 0.0 else clampf(3.4 / rate + 0.3, 1.3, 3.6)
			var frames: Array = []
			var stamps: Array = []
			var t0: int = Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < int(dur * 1000.0):
				await RenderingServer.frame_post_draw
				var img: Image = root.get_texture().get_image()
				var c := Vector2i(img.get_width(), img.get_height()) / 2
				var rect := Rect2i(c.x - CROP.x / 2, c.y - CROP.y / 2, CROP.x, CROP.y).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
				frames.append(img.get_region(rect))
				stamps.append(Time.get_ticks_msec() - t0)
			var sub: String = _dir.path_join("%s_x%s" % [key, str(rate)])
			DirAccess.make_dir_recursive_absolute(sub)
			for i in range(frames.size()):
				(frames[i] as Image).save_png(sub.path_join("f_%04d_%05d.png" % [i, int(stamps[i])]))
			print("SHOT ", key, " x", rate, " frames=", frames.size())
		e1.queue_free()
		e2.queue_free()
		await process_frame
	print("BITTI")
	quit()
