extends SceneTree

## Madde 410 doğrulaması (GERÇEK ÇİZİCİ, oyun ölçeği: oyuncu kökü 0,5, kamera zoom 2): Zehir Asası tek silah, sağda slime; atış aralığı
## 0,6 sn'ye çekilir (görmek için). İlk 2,4 sn'de 60 ms'de bir kare -> ZC_CAP_DIR/z_<ms>.png (oyuncu + slime çevresi).
## Kullanım: Godot --path . -s tools/proto_20261106/zehir_capture.gd (gizli masaüstünde: tools/fps_micro/hidden_launch.ps1).
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok.


func _initialize() -> void:
	_run.call_deferred()


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
	bg.name = "Harita" ## enemy_abilities.place_on_ground gölcük katmanını bunun hemen arkasına alır (oyundaki gibi yaratıkların altı)
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var p0 := Vector2(2900, 3000)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	player.z_index = 1
	scene.add_child(player)
	player.global_position = p0
	player.set_physics_process(false)
	for w in player.get("owned_weapon_nodes"):
		w.queue_free()
	(player.get("owned_weapon_nodes") as Array).clear()
	player.call("buy_weapon_copy", "tuftuf", 1)
	await process_frame
	for w in player.get("owned_weapon_nodes"):
		w.set("fire_rate", 0.6)
		(w.get("fire_timer") as Timer).wait_time = 0.6
	var slime: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(slime)
	slime.global_position = p0 + Vector2(130, 10)
	slime.set("speed", 0.0)
	slime.max_health = 600000.0
	slime.health = 600000.0
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = p0 + Vector2(65, -25)
	cam.make_current()
	var dir: String = OS.get_environment("ZC_CAP_DIR")
	var t0: int = Time.get_ticks_msec()
	var last: int = -1000
	while Time.get_ticks_msec() - t0 < 3000:
		var ms: int = Time.get_ticks_msec() - t0
		await RenderingServer.frame_post_draw
		if ms - last >= 60 and ms > 600:
			last = ms
			var img: Image = root.get_texture().get_image()
			var c := Vector2(img.get_width(), img.get_height()) * 0.5
			var rect := Rect2i(int(c.x) - 260, int(c.y) - 170, 520, 340).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
			img.get_region(rect).save_png(dir.path_join("z_%05d.png" % ms))
		await process_frame
	print("BITTI")
	quit()
