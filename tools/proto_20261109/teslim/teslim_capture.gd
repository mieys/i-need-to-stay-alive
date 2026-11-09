extends SceneTree

## TESLİM OYLAMASI görsel denetimi (madde 540): gerçek main.tscn (tek oyunculu, 1920x1080) üstünde oylama paneli (oy vermeden / evet
## dedikten sonra / geçmedi), ESC menüsündeki TESLİM OL öğesi (normal + onay) ve "TESLİM OLUNDU" oyun bitti ekranı.
## Panel tek oyunculuda kurulmadığı için elle eklenir; NetworkManager'ın işlemesi kapatılır (yoksa tek oyunculu kipte oylamayı siler).
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261109/teslim/teslim_run.ps1 -> out/*.png

var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float, unpause: bool = true) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		if unpause:
			paused = false
		await process_frame


func _shot(n: String, region: Rect2i = Rect2i(), half: bool = false) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if region.size != Vector2i.ZERO:
		img = img.get_region(region)
	if half:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out.path_join(n + ".png"))
	print("SHOT ", n, " ", img.get_size())


func _run() -> void:
	_out = OS.get_environment("TESLIM_DIR")
	DirAccess.make_dir_recursive_absolute(_out)
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	gm.call("reset")
	gm.set("selected_char_id", 2)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	gm.set("invasion_pending", false)
	await _wait(2.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)

	## 1) Oylama paneli: Mira başlattı, 3 oyuncu, kimse daha oy vermedi (biz dahil).
	nm.process_mode = Node.PROCESS_MODE_DISABLED
	nm.set("lobby_players", {1001: {"name": "Mira"}, 1002: {"name": "Kerem"}, 1: {"name": "Sen"}})
	var panel: CanvasLayer = (load("res://scripts/surrender_vote_panel.gd") as GDScript).new()
	current_scene.add_child(panel)
	nm.set("surrender_vote_active", true)
	nm.set("surrender_vote_initiator", 1001)
	nm.set("surrender_voters", PackedInt32Array([1, 1001, 1002]))
	nm.set("surrender_votes", {1001: true})
	nm.set("_surrender_time_left", 21.4)
	nm.emit_signal("surrender_vote_changed")
	await _wait(0.5)
	var crop := Rect2i(0, 0, 640, 520)
	await _shot("1_panel_oy_bekliyor", crop)
	## 2) Biz evet dedik + Kerem hayır demeden önce.
	nm.set("surrender_votes", {1001: true, 1: true})
	nm.emit_signal("surrender_vote_changed")
	await _wait(0.4)
	await _shot("2_panel_evet_dedin", crop)
	## 3) Geçmedi.
	nm.set("surrender_vote_active", false)
	nm.emit_signal("surrender_vote_ended", false, 2, 3)
	await _wait(0.4)
	await _shot("3_panel_gecmedi", crop)
	panel.queue_free()
	nm.call("reset_surrender_vote")
	nm.set("lobby_players", {})
	nm.process_mode = Node.PROCESS_MODE_ALWAYS
	await _wait(0.3)

	## 4) ESC menüsü (tek oyunculu): TESLİM OL öğesi, sonra ilk basış = onay.
	current_scene.call("_toggle_pause")
	await _wait(0.8, false)
	await _shot("4_esc_menu", Rect2i(), true)
	var pm: Node = current_scene.get("pause_menu_instance")
	var btn: Button = pm.find_child("SurrenderButton", true, false) as Button if pm else null
	if btn == null:
		print("!! SurrenderButton yok")
		quit(1)
		return
	btn.grab_focus()
	btn.pressed.emit()
	await _wait(0.5, false)
	await _shot("5_esc_onay", Rect2i(0, 200, 960, 700), false)
	## 6) İkinci basış: TESLİM OLUNDU.
	btn.pressed.emit()
	await _wait(1.5)
	await _shot("6_teslim_olundu", Rect2i(), true)
	print("VERI is_game_over=", gm.get("is_game_over"), " run_surrendered=", gm.get("run_surrendered"))
	quit()
