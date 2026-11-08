extends SceneTree

## Madde 413 doğrulaması (GERÇEK ÇİZİCİ, oyun ölçeği: oyuncu kökü 0,5, kamera zoom 2; oyuna bağlı DEĞİL): üstte yerel oyuncu Yay + Arbalet +
## Uzunkılıç (karşılaştırma), altta uzak kukla Yay + Arbalet; sağda dayanıklı bir slime. Yay gerçekten ateş eder -> çekiş karelerinin
## farklı anları. Çıktı SG_CAP_DIR/yay_arbalet_<n>.png (n = 0..5). Kullanım: Godot --path . -s tools/proto_20261106/yay_arbalet_capture.gd
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok.


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


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
	var p0 := Vector2(2900, 3000)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	player.z_index = 1
	scene.add_child(player)
	player.global_position = p0 + Vector2(0, -40)
	player.set_physics_process(false)
	for k in ["yay", "crossbow", "uzunkilic"]:
		player.call("buy_weapon_copy", k, 1)
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	puppet.set("peer_id", 4244)
	scene.add_child(puppet)
	puppet.global_position = p0 + Vector2(0, 60)
	puppet.set("_target_position", p0 + Vector2(0, 60)) ## ağ hedefi yok: yerinde dursun
	puppet.set("_interp_prev_pos", p0 + Vector2(0, 60))
	puppet.call("update_weapon_visuals", ["yay", "crossbow"])
	var slime: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(slime)
	slime.global_position = p0 + Vector2(150, 0)
	slime.set("speed", 0.0)
	slime.max_health = 600000.0
	slime.health = 600000.0
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = p0 + Vector2(60, 0)
	cam.make_current()
	await _wait(1.6)
	var dir: String = OS.get_environment("SG_CAP_DIR")
	for n in 6:
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var c := Vector2(img.get_width(), img.get_height()) * 0.5
		var rect := Rect2i(int(c.x) - 200, int(c.y) - 380, 400, 560).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(rect).save_png(dir.path_join("yay_arbalet_%d.png" % n))
		await _wait(0.17)
	print("BITTI")
	quit()
