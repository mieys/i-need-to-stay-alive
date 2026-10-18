extends SceneTree

## BİLDİRİMLER (A Ahşap Levha) + BEKLEME (B Ateş Işığı) OYUNDAKİ hâli - doğrulama çekimi (2026-10-18, madde 264).
## Gerçek SP main.tscn açılır; bildirimler main.gd'nin GERÇEK fonksiyonlarıyla gösterilir, bekleme ekranı için NetworkManager'a
## sahte lobi (3 arkadaş, 2'si seçiyor) + 17 sn sayaç yazılır. Çıktı tools/proto_20261018/out/bildirim/sonra_*.png.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261018/bildirim_capture.gd

const OUT := "res://tools/proto_20261018/out/bildirim/"
const CHAR_ID := 2


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float, hold: bool = false) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = hold
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT %s" % name)


func _clear(main: Node) -> void:
	for p in main.get("_active_toast_panels"):
		if is_instance_valid(p) and (p as Node).get_parent():
			(p as Node).get_parent().queue_free()
	for ch in main.get_children():
		var sc: Script = ch.get_script()
		if sc and sc.resource_path.ends_with("mission_complete_window.gd"):
			ch.queue_free()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", CHAR_ID)
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_character", chars.get_def(CHAR_ID).get("skill", 1))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var main: Node = current_scene
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	var ppos: Vector2 = player.global_position if player else Vector2.ZERO

	## 1) görev bitti + uyarı + satıcı (gerçek çağrılar)
	main.call("_on_world_event_announced", 7, "escort_van", ppos + Vector2(900, -420), 120.0, 30.0, "Konvoyu Koru")
	main.call("_on_merchant_spawned", ppos + Vector2(-1100, 600), [])
	(load("res://scripts/gold_reward_fx.gd") as GDScript).call("hold", self, 120, &"mission", ppos)
	(load("res://scripts/mission_complete_window.gd") as GDScript).call("open", main, "Bayrağı Ele Geçir")
	await _wait(1.2)
	await _shot("sonra_oyun.png")
	_clear(main)
	await _wait(0.3)

	## 2) diğer türler: başladı, başarısız, başarım, ayrıldı, sistem + kademe duyurusu
	main.call("_show_notice", "start", "Konvoyu Koru BAŞLADI", String((main.get_script() as GDScript).get_script_constant_map()["MISSION_DESCRIPTIONS"]["escort_van"]), 9.0)
	main.call("_show_notice", "fail", "Ağacı Koru BAŞARISIZ", "Ağaç yok edildi.", 9.0)
	main.call("_show_notice", "ach", "Başarım: Ayakta Kal", "V. Kademe'ye ulaş.", 4.0)
	main.call("_on_player_left_game", "Kerem", 1002)
	main.call("_show_network_toast", "Yeniden başlatma onaylanmadı (süre doldu).")
	main.call("_show_banner_notice", "tier", "KADEME IV", "", 4.0, 4)
	await _wait(0.8)
	await _shot("sonra_katalog.png")
	_clear(main)
	await _wait(0.3)

	## 3) bekleme ekranı: sahte lobi (yerel = 1) + 2 kişi seçiyor + 17 sn
	var lobby: Dictionary = nm.get("lobby_players")
	lobby[1] = {"name": "Ben", "char_id": CHAR_ID}
	lobby[1001] = {"name": "Mira", "char_id": 10}
	lobby[1002] = {"name": "Kerem", "char_id": 5}
	lobby[1003] = {"name": "Deniz", "char_id": 15}
	var busy: Dictionary = nm.get("level_up_busy_peers")
	busy[1001] = true
	busy[1003] = true
	nm.set("level_up_timer_active", true)
	nm.set("level_up_countdown", 17.0)
	var wo: CanvasLayer = (load("res://scripts/wait_overlay.gd") as GDScript).call("open", main, "level_up")
	await _wait(0.6, true)
	await _shot("sonra_bekleme.png")
	wo.queue_free()
	nm.set("chest_countdown_active", true)
	nm.set("chest_countdown", 9.0)
	(nm.get("chest_busy_peers") as Dictionary)[1002] = true
	wo = (load("res://scripts/wait_overlay.gd") as GDScript).call("open", main, "chest")
	await _wait(0.6, true)
	await _shot("sonra_bekleme_sandik.png")
	quit()
