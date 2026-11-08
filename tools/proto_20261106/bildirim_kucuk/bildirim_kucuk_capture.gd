extends SceneTree

## Madde 404 doğrulama çekimi: aynı sahnede aynı bildirimler ESKİ (GameNotice.compact = false) ve YENİ (küçük levha) hâlde.
## (madde 406: aynı sütunda en çok 2 bildirim - küçük levhada uyarı söner, tamamlandı + kademe kalır.) Gerçek SP main.tscn; bildirimler main.gd'nin GERÇEK fonksiyonlarıyla. Çıktı tools/proto_20261106/bildirim_kucuk/out/{once,sonra}.png.
## Kullanım (gizli masaüstü): tools/fps_micro/hidden_launch.ps1 Invoke-GodotHidden -ArgLine '--path . --windowed --resolution 1920x1080 -s <bu>'

const OUT := "res://tools/proto_20261106/bildirim_kucuk/out/"
const CHAR_ID := 2


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
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


func _show_all(main: Node, ppos: Vector2) -> void:
	main.call("_on_world_event_announced", 7, "escort_van", ppos + Vector2(900, -420), 120.0, 60.0, "Konvoyu Koru")
	(load("res://scripts/gold_reward_fx.gd") as GDScript).call("hold", self, 120, &"mission", ppos)
	(load("res://scripts/mission_complete_window.gd") as GDScript).call("open", main, "Bayrağı Ele Geçir")
	main.call("_show_banner_notice", "tier", "KADEME IV", "", 4.0, 4)


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
	var gn: GDScript = load("res://scripts/game_notice.gd")

	gn.call("set_compact", false)
	_show_all(main, ppos)
	await _wait(1.0)
	await _shot("once.png")
	_clear(main)
	await _wait(0.5)

	gn.call("set_compact", true)
	_show_all(main, ppos)
	await _wait(1.0)
	await _shot("sonra.png")
	quit()
