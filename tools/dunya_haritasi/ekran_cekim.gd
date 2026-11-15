extends SceneTree

## DÜNYA HARİTASI ekran çekimi (madde 606, "B - Atlas Defteri"): gerçek tek oyunculu karakter seçimi -> OYUNU BAŞLAT -> dünya haritası;
## başka satır seçimi; izleyici (çok oyunculu istemci) kipi. Çıktı tools/dunya_haritasi/out/ekran_*.png.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/dunya_haritasi/uret.ps1 -Script ekran_cekim.gd

func _initialize() -> void:
	_run.call_deferred()


func _out() -> String:
	var d: String = OS.get_environment("DUNYA_OUT")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/dunya_haritasi/out")
	return d


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_out().path_join(name))
	print("SHOT %s" % name)


func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	AudioServer.set_bus_mute(0, true)
	root.get_node("UISound").set("show_fps", false)
	root.get_node("GameManager").set("selected_map", "ana")
	root.get_node("GameManager").set("selected_char_id", 4)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(3.0)
	var cs: Node = current_scene
	cs.call("_on_character_pressed", 4)
	await _wait(0.5)
	cs.call("_on_start_pressed")
	await _wait(1.0)
	await _shot("ekran_1_ana.png")
	var wm: Control = cs.get("_world_map")
	wm.call("_select", "batik_nekropol", true)
	await _wait(0.3)
	await _shot("ekran_2_nekropol.png")
	wm.queue_free()
	cs.set("_world_map", null)
	## çok oyunculu OYLAMA kipi (madde 620): 4 oyuncu, 3'ü oy vermiş; sonra kazanan gösterimi
	var nm: Node = root.get_node("NetworkManager") ## -s betiği autoload adlarını derlemede bilmez
	nm.set("lobby_players", {
		1: {"name": "Ahmet", "char_id": 4}, 2: {"name": "Ece", "char_id": 1},
		3: {"name": "Can", "char_id": 7}, 4: {"name": "Deniz", "char_id": 2}})
	var voter: Control = (load("res://scripts/world_map_screen.gd") as GDScript).new()
	voter.set("voting", true)
	voter.set("initial_map", "col")
	cs.add_child(voter)
	await _wait(0.5)
	voter.call("set_votes", {1: "col", 2: "bataklik", 3: "col"}, 1, 4)
	await _wait(0.5)
	await _shot("ekran_4_oylama.png")
	voter.call("set_votes", {1: "col", 2: "bataklik", 3: "col", 4: "bataklik"}, 1, 4)
	voter.call("show_winner", "bataklik", true)
	await _wait(0.5)
	await _shot("ekran_5_kazanan.png")
	nm.set("lobby_players", {})
	quit()
