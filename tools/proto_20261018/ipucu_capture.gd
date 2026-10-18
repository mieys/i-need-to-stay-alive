extends SceneTree

## Yetenek ipucu (fareyle yetenek yuvasının üstüne gelince) yakalaması (2026-10-18). Oyuna bağlı DEĞİL.
## Gerçek oyunu (SP, main.tscn) açar, Q/E/R/pasif/F ipuçlarını sırayla açıp ipucu + yetenek panelini kırpıp kaydeder.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261018/ipucu_capture.gd
## IPUCU_TAG=once|sonra (dosya adı öneki), IPUCU_CHAR=<id> (varsayılan 2).

const OUT := "res://tools/proto_20261018/out/ipucu/"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shift(on: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SHIFT
	ev.physical_keycode = KEY_SHIFT
	ev.pressed = on
	Input.parse_input_event(ev)


func _shot(file: String, tip: Control, dock: Rect2) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var r: Rect2 = dock
	if tip and is_instance_valid(tip):
		r = r.merge(tip.get_global_rect())
	r = r.grow(24).intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var crop: Image = img.get_region(Rect2i(r))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	crop.save_png(ProjectSettings.globalize_path(OUT + file))
	print("SHOT %s %dx%d" % [file, crop.get_width(), crop.get_height()])


func _run() -> void:
	var tag: String = OS.get_environment("IPUCU_TAG")
	if tag == "":
		tag = "simdi"
	var char_id: int = int(OS.get_environment("IPUCU_CHAR")) if OS.get_environment("IPUCU_CHAR") != "" else 2
	var gm: Node = root.get_node("GameManager")
	gm.call("reset")
	gm.set("selected_char_id", char_id)
	var def: Dictionary = load("res://scripts/characters.gd").get_def(char_id)
	gm.set("selected_character", def.get("skill", 1))
	gm.set("selected_pet", "peri")
	gm.set("selected_spiritual", "can")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player:
		player.global_position += Vector2(40, 170)
		## Q/E/R kilidi açık olsun + R yuvasında 2 evrim (ipucunun EVRİMLER bölümü görünsün).
		if "level" in player:
			player.set("level", 12)
		var evo: Dictionary = player.get("skill_evolutions") if "skill_evolutions" in player else {}
		var ev_script: GDScript = load("res://scripts/skill_evolutions.gd")
		var r_list: Array = ev_script.call("slot_list", char_id, "skill3")
		for i in mini(2, r_list.size()):
			evo[str(r_list[i]["id"])] = 1
		if "skill_evolutions" in player:
			player.set("skill_evolutions", evo)
		if "cooldown_reduction_percent" in player:
			player.set("cooldown_reduction_percent", 0.15)
	var hud: Node = current_scene.get_node_or_null("HUD")
	if hud:
		hud.call("update_level", 12)
	await _wait(1.0)

	var shots: Array = [["SkillIcon", false], ["Skill2Icon", false], ["Skill3Icon", false], ["PassiveIcon", false], ["SpiritIcon", false], ["SkillIcon", true]]
	for s in shots:
		var icon: Control = hud.find_child(String(s[0]), true, false) as Control if hud else null
		if icon == null:
			print("NO_ICON ", s[0])
			continue
		_shift(bool(s[1]))
		await _wait(0.15)
		icon.call("_on_mouse_entered")
		await _wait(0.4)
		var tip: Control = icon.get("tooltip_panel") as Control
		var dock: Rect2 = icon.get_global_rect()
		var bar: Node = icon.get_parent()
		if bar is Control:
			dock = (bar as Control).get_global_rect()
		await _shot("%s_%s%s.png" % [tag, String(s[0]), "_shift" if bool(s[1]) else ""], tip, dock)
		icon.call("_on_mouse_exited")
		_shift(false)
		await _wait(0.1)
	quit()
