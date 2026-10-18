extends SceneTree

## TELEFON EKRANLARI gerçek oyunda (madde 276+): main.tscn telefon kipinde (2400x1080, --mobile-ui), istenen ekranlar sırayla
## açılıp yakalanır. Ekran listesi MOBIL_EKRAN ortam değişkeninden (virgüllü): level, sandik, duraklat, ... (bkz. _open).
## Kullanım: $env:MOBIL_EKRAN="level"; Godot --path . --windowed --resolution 2400x1080 -s tools/proto_20261018/mobil_ekran_capture.gd -- --mobile-ui
## Çıktı: tools/proto_20261018/out/mobil/oyun_<ekran>.png

const OUT := "res://tools/proto_20261018/out/mobil/"
const WAITS := {"sandik": 4.5}
## Takım arkadaşları (duraklatma TAKIM listesi / oyun bitti hasar sırası dolu görünsün; biri yerde).
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
	await _wait(1.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	gm.set("gold", 1240)
	gm.set("run_kills", 1204)
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
	## Çantada birkaç eşya (envanter / satıcı tarifleri dolu görünsün): 3 parça, 2 epik, 1 efsanevi.
	var owned: Array = gm.get("owned_items")
	var want := {1: 3, 2: 2, 3: 1}
	for k in Items.KEYS:
		var kd: int = Items.kademe(str(k))
		if int(want.get(kd, 0)) > 0:
			owned.append({"key": str(k)})
			want[kd] = int(want[kd]) - 1
	var list: String = OS.get_environment("MOBIL_EKRAN")
	if list == "":
		list = "level"
	var screens: PackedStringArray = list.split(",", false)
	for i in screens.size():
		var scr: String = screens[i].strip_edges()
		var node: Node = _open(scr)
		await _wait(float(WAITS.get(scr, 1.6)))
		await _shot("oyun_" + scr)
		if node and is_instance_valid(node):
			node.queue_free()
		## Envanter / özellikler HUD'un kendi panelleri: sıradaki ekran özellikler değilse kapat (açık kalınca sonraki yakalamaların
		## üstünde kalıyordu).
		var nxt: String = screens[i + 1].strip_edges() if i + 1 < screens.size() else ""
		if scr in ["envanter", "ozellik"] and nxt != "ozellik":
			var hud: Node = current_scene.get_node_or_null("HUD")
			var inv: Variant = hud.get("inventory_panel_instance") if hud else null
			if inv and (inv as CanvasItem).visible:
				hud.call("_on_envanter_toggle")
		await _wait(0.4)
	quit()


func _open(scr: String) -> Node:
	match scr:
		"level":
			var s: Node = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
			current_scene.add_child(s)
			return s
		"sandik":
			var c: Node = (load("res://scenes/chest_menu.tscn") as PackedScene).instantiate()
			current_scene.add_child(c)
			c.call("setup", current_scene.get_node_or_null("Player"), 3, true)
			return c
		"seyyar":
			var stock: Array = []
			for kd in [1, 2, 3]:
				var n: int = 0
				for k in Items.KEYS:
					if Items.kademe(str(k)) == kd and n < 4:
						stock.append({"type": "item", "key": str(k)})
						n += 1
			var m: Node = load("res://scripts/merchant_shop_screen.gd").new()
			current_scene.add_child(m)
			m.call("setup", current_scene.get_node_or_null("Player"), stock, null)
			return m
		"demirci":
			var w: Node = load("res://scripts/weapon_shop_screen.gd").new()
			w.name = "WeaponShopScreen"
			current_scene.add_child(w)
			w.call("setup", current_scene.get_node_or_null("Player"))
			return w
		"envanter":
			var hud: Node = current_scene.get_node_or_null("HUD")
			if hud:
				hud.call("_on_envanter_toggle")
			return null
		"ozellik":
			var hud2: Node = current_scene.get_node_or_null("HUD")
			if hud2:
				hud2.call("_ph_set_inv_tab", 1)
			return null
		"duraklat":
			var pm: Node = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
			current_scene.add_child(pm)
			return pm
		"ayarlar":
			var pm2: Node = (load("res://scenes/pause_menu.tscn") as PackedScene).instantiate()
			current_scene.add_child(pm2)
			pm2.call("_on_settings_pressed")
			var st: Node = pm2.call("get_settings_screen")
			if st:
				st.call("_set_category", 3, false) ## Cat.DOKUNMATIK
			return pm2
		"izleyici", "oyunbitti", "oyunbitti_hasar", "oyunbitti_odul":
			## Kayıt YAZILMAZ: _run_end_recorded önceden true (kullanıcının rekor / Ruh Kıymığı dosyalarına dokunulmaz).
			var main: Node = current_scene
			var my_id: int = main.multiplayer.get_unique_id() if main.multiplayer.has_multiplayer_peer() else 0
			var stats := {my_id: {"name": "Sen", "dealt": 48210.0, "taken": 4320.0, "kills": 612}}
			for i in TEAM.size():
				stats[1000 + i] = {"name": TEAM[i]["name"], "dealt": TEAM[i]["dealt"], "taken": TEAM[i]["taken"], "kills": 520 - i * 80}
			main.set("_match_stats_by_peer", stats)
			main.set("_run_end_recorded", true)
			main.set("_run_results", {"shards": 86, "records": [], "achievements": []})
			var gm: Node = root.get_node("GameManager")
			gm.set("run_max_tier", 9)
			gm.set("team_level", 17)
			main.call("_show_death_overlay", scr != "izleyici")
			var ph: Node = main.find_child("PhoneGameOver", true, false)
			if ph and scr.begins_with("oyunbitti_"):
				ph.set("_tab", 1 if scr == "oyunbitti_hasar" else 2)
				ph.set("_sig", "")
				ph.call("_refresh")
			return null
	print("MOBIL_EKRAN bilinmeyen ekran: ", scr)
	return null
