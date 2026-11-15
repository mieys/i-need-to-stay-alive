extends SceneTree

## Çakram (madde 589) GERÇEK ÇİZİCİDE, oyun ölçeğinde (oyuncu kökü 0,5, kamera zoom 2):
##   üstte yerel oyuncu + çakram (gerçek weapon.gd atışı, sağdaki slime'a -> Çelik Kesik + dönüş + yakalama),
##   altta uzak kukla (remote_player.gd) + ağdan gelmiş gibi kozmetik çakram (network_spawned) SOLA boşluğa -> en uzak noktada
##   dönüş parıltısı + yakalama. Kareler BC_CAP_DIR'e f_<ms>.png.
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("BC_CAP_DIR")


func _initialize() -> void:
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
	e.max_health = 600000.0
	e.health = 600000.0
	return e


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
	player.z_index = 1
	scene.add_child(player)
	player.global_position = Vector2(3000, 3000)
	player.set_physics_process(false)
	player.call("buy_weapon_copy", "boomerang", 1)
	_slime(scene, player.global_position + Vector2(120, 6))
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = player.global_position + Vector2(60, 100)
	puppet.set("_target_position", puppet.global_position)
	puppet.call("update_weapon_visuals", ["boomerang"])
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = player.global_position + Vector2(20, 55)
	cam.make_current()
	await _wait(0.8)
	var t0: int = Time.get_ticks_msec()
	var thrown := false
	while Time.get_ticks_msec() - t0 < 3400:
		var ms: int = Time.get_ticks_msec() - t0
		if not thrown and ms > 300:
			thrown = true
			## Ağdan gelen kozmetik kopya (main.gd'nin uzak mermi yolu ile aynı bayrak): hasar vermez, aynı efektleri oynatır.
			var p: Node2D = (load("res://scenes/boomerang_projectile.tscn") as PackedScene).instantiate()
			p.set_meta("network_spawned", true)
			p.set("direction", Vector2.LEFT)
			p.set("player_node", puppet)
			p.set("speed", 368.0 * 0.65)
			p.set("throw_distance", 110.0) ## yalnız çekim: uç nokta kadraja girsin
			p.scale = Vector2(0.5, 0.5)
			scene.add_child(p)
			p.global_position = puppet.global_position + Vector2(0, -20)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var c := Vector2(img.get_width(), img.get_height()) * 0.5
		var rect := Rect2i(int(c.x) - 460, int(c.y) - 250, 920, 500).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(rect).save_png(_dir.path_join("f_%05d.png" % ms))
		await process_frame
	print("BITTI")
	quit()
