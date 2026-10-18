extends SceneTree

## TELEFON HUD'u v2 (madde 273) gerçek oyunda: main.tscn telefon kipinde (2400x1080, --mobile-ui), 3 sahte takım arkadaşı
## (biri yerde), iki sohbet mesajı. Hâller: normal (grup açık) / grup katlı + hızlı sohbet / istatistik penceresi / demirci
## kapısında (etkileşim düğmesi).
## Kullanım: Godot --path . --windowed --resolution 2400x1080 -s tools/proto_20261018/mobil_hud_capture.gd -- --mobile-ui
## Çıktı: tools/proto_20261018/out/mobil/oyun_hud_{takim,sohbet,istatistik,demirci}.png

const OUT := "res://tools/proto_20261018/out/mobil/"
const TEAM := [
	{"name": "Mira", "char": 10, "hp": 340.0, "mhp": 520.0, "sh": 60.0, "msh": 120.0, "down": false, "dealt": 31800.0, "taken": 2180.0},
	{"name": "Kerem", "char": 5, "hp": 90.0, "mhp": 480.0, "sh": 0.0, "msh": 100.0, "down": false, "dealt": 52740.0, "taken": 7950.0},
	{"name": "Deniz", "char": 15, "hp": 0.0, "mhp": 450.0, "sh": 0.0, "msh": 0.0, "down": true, "dealt": 27110.0, "taken": 9640.0},
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


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + n + ".png"))
	print("SHOT ", n, " ", img.get_size())


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
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	for i in TEAM.size():
		var t: Dictionary = TEAM[i]
		var a := FakeAlly.new()
		a.peer_id = 1000 + i
		a.player_name = t["name"]
		a.char_id = t["char"]
		a.health = t["hp"]
		a.max_health = t["mhp"]
		a.item_shield_hp = t["sh"]
		a.item_shield_max = t["msh"]
		a.is_downed = t["down"]
		a.match_damage_dealt = t["dealt"]
		a.match_damage_taken = t["taken"]
		current_scene.add_child(a)
		a.add_to_group("remote_players")
		if player:
			a.global_position = player.global_position + Vector2(-260 + 260 * i, -150 + 90 * i)
	if player:
		player.set("match_damage_dealt", 48210.0)
		player.set("match_damage_taken", 4320.0)
	var hud: Node = current_scene.get_node_or_null("HUD")
	if hud == null:
		print("MOBIL_HUD no HUD")
		quit(1)
		return
	hud.call("append_chat_message", "Mira", "sandık bende, gelin")
	hud.call("append_chat_message", "Kerem", "can az, Melek iyileştir")
	await _wait(2.5)
	await _shot("oyun_hud_takim")
	## Grup katlı + hızlı sohbet penceresi.
	hud.call("_toggle_mobile_party")
	hud.call("_ph_toggle_quick_chat")
	await _wait(0.8)
	await _shot("oyun_hud_sohbet")
	hud.call("_ph_toggle_quick_chat")
	hud.call("_toggle_mobile_party")
	await _wait(0.6)
	## İstatistik penceresi (grup panelinin alt düğmesi).
	var party: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel")
	if party:
		party.call("_on_stats_button_pressed")
	await _wait(0.8)
	await _shot("oyun_hud_istatistik")
	if party:
		party.call("_hide_stats_popup")
	## Demirci kapısında: etkileşim düğmesi.
	var smith: Node = current_scene.get_node_or_null("WeaponShop")
	if smith and player and smith.has_method("get_exterior_anchor_pos"):
		player.global_position = smith.call("get_exterior_anchor_pos")
		await _wait(1.5)
		await _shot("oyun_hud_demirci")
	quit()
