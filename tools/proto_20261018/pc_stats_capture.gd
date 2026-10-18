extends SceneTree

## PC grup paneli "Hasar Sıralaması" penceresi: verilen + ALINAN hasar (2026-10-18, kullanıcı: "grup istatistiklerinde alınan hasar
## da olmalı hem pc hem mobilde"). GERÇEK main.tscn + gerçek party_panel.gd; 3 sahte takım arkadaşı (bekleme_proto.gd deseni).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261018/pc_stats_capture.gd
## Çıktı: out/mobil/pc_istatistik.png (tam ekran) + pc_istatistik_yakin.png (pencere x2).

const OUT := "res://tools/proto_20261018/out/mobil/"
const TEAM := [
	{"name": "Mira", "char": 10, "dealt": 31800.0, "taken": 2180.0},
	{"name": "Kerem", "char": 5, "dealt": 52740.0, "taken": 7950.0},
	{"name": "Deniz", "char": 15, "dealt": 27110.0, "taken": 9640.0},
]


class FakeAlly extends Node2D:
	var peer_id: int = 0
	var player_name: String = ""
	var char_id: int = 0
	var health: float = 300.0
	var max_health: float = 500.0
	var item_shield_max: float = 120.0
	var item_shield_hp: float = 60.0
	var is_dead: bool = false
	var is_downed: bool = false
	var match_damage_dealt: float = 0.0
	var match_damage_taken: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 2)
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_character", chars.get_def(2).get("skill", 1))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player:
		player.set("match_damage_dealt", 48210.0)
		player.set("match_damage_taken", 4320.0)
	for i in TEAM.size():
		var t: Dictionary = TEAM[i]
		var a := FakeAlly.new()
		a.peer_id = 1000 + i
		a.player_name = t["name"]
		a.char_id = t["char"]
		a.match_damage_dealt = t["dealt"]
		a.match_damage_taken = t["taken"]
		current_scene.add_child(a)
		a.add_to_group("remote_players")
		if player:
			a.global_position = player.global_position + Vector2(-260 + 260 * i, -150)
	await _wait(2.0)
	var panel: Node = get_first_node_in_group(&"party_panel")
	if panel == null:
		print("PC_STATS no party panel")
		quit(1)
		return
	panel.call("_on_stats_button_pressed")
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + "pc_istatistik.png"))
	var pop: Control = panel.get("_stats_popup") as Control
	if pop and pop.visible:
		var r: Rect2 = pop.get_global_rect().grow(16)
		var ri := Rect2i(Vector2i(maxi(0, int(r.position.x)), maxi(0, int(r.position.y))), Vector2i(int(r.size.x), int(r.size.y)))
		ri = ri.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var crop: Image = img.get_region(ri)
		crop.resize(ri.size.x * 2, ri.size.y * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png(ProjectSettings.globalize_path(OUT + "pc_istatistik_yakin.png"))
		print("PC_STATS popup ", ri)
	else:
		print("PC_STATS popup not visible")
	quit()
