extends SceneTree

## OYUNDAKİ yükleme ekranı (madde 411, "Sade") - gerçek akış çekimi. Gizli masaüstünde:
##   powershell -ExecutionPolicy Bypass -File tools/proto_20261106/yukleme_v3/yukleme_v3_run.ps1 -Script yukleme_v3_oyun.gd
## 1) "mp.png": 4 kişilik sahte lobiyle görünüş (yükleyici kapalı; is_multiplayer_active geçici true, sonra geri alınır).
## 2) Tek oyunculu gerçek akış: loading_screen.tscn -> Main; yüklenirken 0,4 sn'de bir kare (out/oyun/k_NN.png, 960x540), ilk kare tam boy
##    (sp_tam.png), Main geldikten sonra 4 kare daha (devir + solma).

const OUT := "res://tools/proto_20261106/yukleme_v3/out/oyun/"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String, full: bool = false) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if not full:
		img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_png(ProjectSettings.globalize_path(OUT + name))


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 2)
	gm.set("selected_start_weapon", "fire_staff")
	gm.set("selected_pet", "kirpi")
	await _wait(0.5)

	## 1) Çok oyunculu görünüş (sahte lobi, yükleyici yok).
	var was_lobby: Dictionary = nm.get("lobby_players")
	nm.set("lobby_players", {1: {"name": "Perva", "char_id": 2}, 2: {"name": "Mieys", "char_id": 3},
		3: {"name": "Kuzgun", "char_id": 7}, 4: {"name": "Demir", "char_id": 4}})
	nm.set("is_multiplayer_active", true)
	var ls: Control = (load("res://scenes/loading_screen.tscn") as PackedScene).instantiate()
	ls.set("autostart_loader", false)
	root.add_child(ls)
	ls.set_process(false)
	(ls.get("progress_bar") as ProgressBar).value = 62.0
	await _wait(0.6)
	await _shot("mp.png", true)
	nm.set("is_multiplayer_active", false)
	nm.set("lobby_players", was_lobby)
	ls.queue_free()
	await _wait(0.3)
	print("SHOT mp")

	## 2) Tek oyunculu gerçek akış.
	change_scene_to_file("res://scenes/loading_screen.tscn")
	await process_frame
	await process_frame
	var t0: int = Time.get_ticks_msec()
	var k: int = 0
	var after_main: int = -1
	while Time.get_ticks_msec() - t0 < 60000:
		await _wait(0.4)
		var sc: Node = current_scene
		if sc and sc.name == "Main" and after_main < 0:
			after_main = 0
			print("DATA Main geldi %.1f sn" % ((Time.get_ticks_msec() - t0) / 1000.0))
		await _shot("k_%02d.png" % k, false)
		if k == 2:
			await _shot("sp_tam.png", true)
		k += 1
		if after_main >= 0:
			after_main += 1
			if after_main > 4:
				break
	print("SHOT akis %d kare" % k)
	quit()
