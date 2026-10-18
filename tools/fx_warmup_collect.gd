extends SceneTree

## FX ısınma listesi toplayıcı: her karakterin Q/E/R yeteneğine ve her silahın ilk ateşine basar, aralarına "FXW MARK <etiket>" / "FXW END" satırı yazar.
## Godot --verbose ile çalıştırılınca günlük ("Loading resource: res://...") bu işaretlerin arasındaki YÜKLEMELERİ gösterir = oyunda o yeteneğin ilk
## kullanımında diskten okunan kaynaklar (ses örnekleri, doku sayfaları, SpriteFrames, FX sahneleri/betikleri). tools/gen_fx_warmup_list.ps1 bu çıktıyı
## scripts/fx_warmup_list.gd'ye çevirir; scripts/fx_warmup.gd oyun açılırken bunları arka planda yükleyip TUTAR (ilk kullanımda takılma olmasın).
## Elle çalıştırma gerekmez: powershell -ExecutionPolicy Bypass -File tools/gen_fx_warmup_list.ps1
## Ortam: FXW_CHARS=1,2,... (varsayılan hepsi), FXW_WEAPONS=a,b (varsayılan hepsi).

const ALL_CHARS: Array = [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const ALL_WEAPONS: Array = ["dagger", "fire_staff", "lightning_staff", "tabanca", "tuftuf", "tufek", "arcane", "yay", "crossbow", "boomerang", "buz_asasi", "fisek", "pence", "topuz", "uzunkilic"]
const DUMMY_ROSTER: Array = ["slime1", "zombie1", "zombie2", "iskelet2", "ork1"]

var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _dummies: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _boot(char_id: int, start_weapon: String) -> bool:
	_player = null
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", char_id)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(char_id).get("skill", 1))
	_gm.set("selected_start_weapon", start_weapon)
	_gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	_player = _main.get_node_or_null("Player") as Node2D
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	if _player == null:
		return false
	_player.set("level", 20)
	await _wait(0.5)
	return true


func _spawn_dummies(count: int) -> void:
	for d in _dummies:
		if is_instance_valid(d):
			d.queue_free()
	_dummies.clear()
	var pp: Vector2 = _player.global_position
	for i in range(count):
		var ps: PackedScene = load("res://scenes/creatures/enemy_%s.tscn" % DUMMY_ROSTER[i % DUMMY_ROSTER.size()])
		var e: Node2D = ps.instantiate()
		e.set("speed", 0.0)
		e.set("max_health", 1.0e9)
		_main.add_child(e)
		var a: float = randf() * TAU
		e.global_position = pp + Vector2(cos(a), sin(a)) * randf_range(70.0, 230.0)
		e.set("health", 1.0e9)
		_dummies.append(e)
	await _wait(1.0)


func _clear_weapons() -> void:
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.3)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var chars: Array = ALL_CHARS
	if OS.get_environment("FXW_CHARS") != "":
		chars = []
		for t in OS.get_environment("FXW_CHARS").split(","):
			chars.append(int(t))
	var weapons: Array = ALL_WEAPONS
	if OS.get_environment("FXW_WEAPONS") != "":
		weapons = Array(OS.get_environment("FXW_WEAPONS").split(","))
	for cid in chars:
		if not await _boot(cid, "dagger"):
			print("FXW BOOTFAIL char=%d" % cid)
			continue
		await _spawn_dummies(30)
		await _wait(2.0)
		for slot in ["skill", "skill2", "skill3"]:
			var st_key: String = "skill_state" if slot == "skill" else slot + "_state"
			var tm_key: String = "skill_timer" if slot == "skill" else slot + "_timer"
			_player.set(st_key, "ready")
			_player.set(tm_key, 0.0)
			_player.set("item_shield_max", 300.0)
			_player.set("item_shield_hp", 300.0)
			_player.set("necro_souls", 25)
			await _wait(0.5)
			print("FXW MARK char=%d slot=%s" % [cid, slot])
			Input.action_press(slot)
			for f in range(4):
				await process_frame
			Input.action_release(slot)
			await _wait(2.0)
			print("FXW END")
			## Cadı R her basışta rastgele bir iksir atar (5 tür, her birinin kendi alan/patlama sayfası): tek basış listeyi koşudan koşuya
			## değiştirirdi (Don / Patlama / Korku sayfaları eksik kalmıştı) -> 5 iksiri sırayla zorla.
			if cid == 15 and slot == "skill3":
				for potion in range(5):
					_player.set("_cadi_next_potion", potion)
					_player.set("cadi_r_charges", 5) ## 5 yük: ilk basış + 5 zorlama yük bitirirdi
					_player.set("item_shield_hp", 300.0)
					_player.set(st_key, "ready")
					_player.set(tm_key, 0.0)
					await _wait(0.5)
					print("FXW MARK char=%d slot=%s potion=%d" % [cid, slot, potion])
					Input.action_press(slot)
					for f in range(4):
						await process_frame
					Input.action_release(slot)
					await _wait(2.0)
					print("FXW END")
			var st: String = str(_player.get(st_key))
			if st == "active" or st == "on":
				Input.action_press(slot) ## aç/kapa yetenekleri kapat
				await process_frame
				await process_frame
				Input.action_release(slot)
			await _wait(1.0)
	if not weapons.is_empty():
		if await _boot(2, "dagger"):
			await _clear_weapons()
			await _spawn_dummies(30)
			await _wait(2.0)
			for k in weapons:
				await _clear_weapons()
				await _wait(0.5)
				print("FXW MARK weapon=%s" % k)
				_player.call("buy_weapon_copy", k, 1)
				await _wait(4.5)
				print("FXW END")
	print("FXW DONE")
	quit()
