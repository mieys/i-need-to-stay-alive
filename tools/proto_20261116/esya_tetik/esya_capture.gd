extends SceneTree

## TETİKLENEN EŞYA efekt prototipleri GERÇEK OYUNDA (2026-11-16). Oyun koduna dokunulmaz. Talon, gün ışığı, HUD gizli.
## "now" = oyunun bugünkü efekti (player._item_fx / Tanrının Eli kalp sahnesi); A/B = esya_proto_fx.gd oyuncuya bağlı doğar.
## Ürkek Yürek / Kemik Kolye GERÇEK eşya mantığıyla tetiklenir (eşya verilir; can %20'ye inip _item_urkek_check / Q basılır,
## dişleri silah vuruşları harcar). Gündüz ve Gece'de görüş alanı donması da gerçek (_item_freeze_vision_enemies).
## Kareler ET_DIR'e <eşya>_<kod>_<nnn>.png + zamanlar.json (OYUN ms'si, tetik anı). Birleştirme esya_gif.py.
## Ortam: ET_ITEMS=olum,gunes,..  ET_CODES=now,A,B  ET_NIGHT=1
## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.

const PROTO_PATH := "res://tools/proto_20261116/esya_tetik/esya_proto_fx.gd"
const PRE_ROLL := 0.2
const SLOW := 0.4
const MIN_GAP_MS := 25
const PX := 0.903 ## Talon karakter pikseli (2,2368375 x 0,8075 x 0,5)
const POST := {"olum": 1.4, "gunes": 3.1, "anka": 1.6, "urkek": 3.3, "zaman": 2.8, "kemik": 3.9}
const OLD := {"zaman": "time_freeze", "olum": "death_threshold", "gunes": "sun_will"}
const ORDER: Array = ["olum", "gunes", "anka", "urkek", "zaman", "kemik"]
const MOBS: Array = [Vector2(-88, -30), Vector2(92, -44), Vector2(-70, 46), Vector2(100, 34), Vector2(22, -72)]
const ROSTER: Array = ["slime1", "zombie1", "rat2", "iskelet2", "slime1"]

var _dir: String = OS.get_environment("ET_DIR")
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _proto: GDScript = null
var _times: Dictionary = {}
var _trig: Dictionary = {}
var _t0: int = 0
var _home: Vector2 = Vector2.ZERO
var _mobs_spawned: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0 / Engine.time_scale):
		await process_frame


func _game_ms() -> int:
	return int(float(Time.get_ticks_msec() - _t0) * Engine.time_scale)


func _hide_bubble() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sv: Variant = _player.get("shield_visual")
	if sv is CanvasItem and is_instance_valid(sv):
		(sv as CanvasItem).visible = false
	var mfx: Node = _player.get_node_or_null("ManaShieldFx")
	if mfx is CanvasItem:
		(mfx as CanvasItem).visible = false


func _shot(key: String, idx: int, rel: Rect2i) -> int:
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / 1920.0
	var c: Vector2 = (_player.get_viewport().get_canvas_transform() * _player.global_position) * k
	var r := Rect2i(int(c.x) + int(rel.position.x * k), int(c.y) + int(rel.position.y * k), int(rel.size.x * k), int(rel.size.y * k))
	img.get_region(r).save_png(_dir.path_join("%s_%03d.png" % [key, idx]))
	return idx + 1


func _grab_for(key: String, sec: float, idx: int, rel: Rect2i, times: Array) -> int:
	var start: int = Time.get_ticks_msec()
	var last: int = -1000
	while Time.get_ticks_msec() - start < int(sec * 1000.0 / Engine.time_scale):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_msec()
		if now - last < MIN_GAP_MS:
			continue
		last = now
		idx = _shot(key, idx, rel)
		times.append(_game_ms())
	return idx


func _spawn_mobs() -> void:
	if _mobs_spawned:
		return
	_mobs_spawned = true
	var o: Vector2 = _home
	for i in MOBS.size():
		var e: Node2D = (load("res://scenes/creatures/enemy_%s.tscn" % ROSTER[i]) as PackedScene).instantiate()
		e.set("speed", 0.0)
		e.set("max_health", 1.0e9)
		_main.add_child(e)
		e.global_position = o + MOBS[i]
		e.set("health", 1.0e9)


func _give(key: String) -> void:
	var arr: Array = _gm.get("owned_items")
	arr.append({"key": key})
	_player.call("_rebuild_item_counts")


func _spawn_proto(item: String, code: String) -> void:
	var fx: Node2D = _proto.new()
	fx.set("PX", PX)
	fx.set("item", item)
	fx.set("variant", code)
	fx.set("owner_node", _player)
	_main.add_child(fx)


func _prep(item: String, code: String) -> void:
	_player.global_position = _home
	_player.set("health", float(_player.get("max_health")))
	_player.set("skill_state", "ready")
	_player.set("skill_timer", 0.0)
	match item:
		"zaman", "kemik":
			_spawn_mobs()
		"urkek":
			_player.set("_item_urkek_timer", 0.0)
			_player.set("_item_urkek_cd", 0.0)
			_player.global_position = _home + Vector2(-110, 0)
		_:
			pass
	if item == "kemik":
		_player.set("_item_kemik_cd", 0.0)
		_player.set("_item_kemik_charges", 0)


## ET_MODE=game (madde 742 doğrulaması): OYUNA BAĞLANAN efektler gerçek kod yolundan - yalnız o eşya verilir, can eşiğin altına
## çekilip player._item_after_health_damage() (Gündüz ve Gece / Ölüm Eşiği / Güneşin İradesi / Ürkek Yürek) ya da Q (Kemik Kolye).
const GAME_ITEM := {"zaman": "zaman_kiran", "olum": "olum_esigi", "gunes": "gunesin_iradesi", "urkek": "urkek_yurek", "kemik": "kemik_kolye"}
const GAME_SCENE := {"zaman": "time_freeze", "olum": "death_threshold", "gunes": "sun_will", "urkek": "fear_heart", "kemik": "bone_fangs"}
var _rp: Node2D = null


func _only_item(key: String) -> void:
	var arr: Array = _gm.get("owned_items")
	arr.clear()
	arr.append({"key": key})
	_player.call("_rebuild_item_counts")


func _trigger_game(item: String) -> void:
	_only_item(GAME_ITEM[item])
	var mh: float = float(_player.get("max_health"))
	for cd in ["_item_zaman_cd", "_item_olum_cd", "_item_gunes_cd", "_item_urkek_cd", "_item_kemik_cd"]:
		_player.set(cd, 0.0)
	if float(_player.get("item_shield_max")) <= 0.0:
		_player.set("item_shield_max", 120.0)
	match item:
		"zaman":
			_player.set("health", 5.0)
		"olum":
			_player.set("health", mh * 0.25)
		"gunes":
			_player.set("health", mh * 0.15)
		"urkek":
			_player.set("health", mh * 0.2)
		"kemik":
			_player.call("_activate_skill")
			return
	_player.call("_item_after_health_damage")


## Uzak kukla (RemotePlayer) altında aynı sahne - network_manager "skill_scene" dalı gibi; Kemik'te set_charges geri sayımı.
func _trigger_remote(item: String) -> void:
	if _rp == null:
		_rp = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
		_main.add_child(_rp)
		_rp.call("setup", 99, 1, "Kukla")
	_rp.global_position = _player.global_position + Vector2(48, 0)
	_rp.set("_target_position", _rp.global_position) ## yoksa kukla _ready'deki (0,0) hedefine kayar
	var fx: Node = (load("res://scenes/fx_item_%s.tscn" % GAME_SCENE[item]) as PackedScene).instantiate()
	_rp.add_child(fx)
	if item == "kemik":
		_remote_countdown(fx)


func _remote_countdown(fx: Node) -> void:
	for i in 6:
		await _wait(0.4)
		if is_instance_valid(fx):
			fx.call("set_charges", 5 - i)


func _trigger(item: String, code: String) -> void:
	if code == "game":
		_trigger_game(item)
		return
	if code == "uzak":
		_trigger_remote(item)
		return
	match item:
		"olum", "gunes", "zaman":
			if item == "zaman":
				_player.call("_item_freeze_vision_enemies")
			if code == "now":
				_player.call("_item_fx", OLD[item])
			else:
				_spawn_proto(item, code)
		"anka":
			if code == "now":
				_player.call("_play_and_broadcast_skill_fx", load("res://scenes/fx_revive_heart.tscn"))
			else:
				_spawn_proto(item, code)
		"urkek":
			_player.set("health", float(_player.get("max_health")) * 0.2)
			_player.call("_item_urkek_check")
			_spawn_proto(item, code)
		"kemik":
			_player.call("_activate_skill")
			_spawn_proto(item, code)


func _run() -> void:
	await process_frame
	var only_items: String = OS.get_environment("ET_ITEMS")
	var items: Array = ORDER if only_items == "" else Array(only_items.split(","))
	var only_codes: String = OS.get_environment("ET_CODES")
	_proto = load(PROTO_PATH)
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_char_id", 1)
	_gm.set("selected_character", chars.get_def(1).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	root.get_node("UISound").set("damage_numbers_mode", 2) ## hasar sayıları kapalı (yalnız bu süreç, kayıt yok)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene as Node2D
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(2.5)
	var intro: Node = _main.get_node_or_null("HouseInterior/HouseIntro")
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	_gm.set("invasion_pending", false)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 420.0 if OS.get_environment("ET_NIGHT") == "1" else 150.0)
		atmo.call("debug_set_weather", 0)
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	_player = _main.get_node("Player")
	_player.set("_oakley_flower_auto_timer", 1.0e9)
	_player.global_position += Vector2(-170.0, 100.0)
	_home = _player.global_position
	_player.set("level", 10)
	_give("urkek_yurek")
	_give("kemik_kolye")
	RenderingServer.frame_pre_draw.connect(_hide_bubble)
	await _wait(1.0)
	print("ORIGIN ", _home, " PX ", PX)
	## Kırpma (1920 genişliğine göre ekran pikseli, oyuncunun ekran konumuna göre): 1 dünya birimi = 2,25 px -> ~267 x 178 dünya.
	var rel := Rect2i(-300, -230, 600, 400)
	for item in items:
		var codes: Array = ["A", "B"] if item in ["urkek", "kemik"] else ["now", "A", "B"]
		if OS.get_environment("ET_MODE") == "game":
			codes = ["game", "uzak"] if item in ["kemik", "gunes"] else ["game"]
		if only_codes != "":
			codes = codes.filter(func(c: String) -> bool: return c in only_codes.split(","))
		for code in codes:
			var key: String = "%s_%s" % [item, code]
			_prep(item, code)
			if item == "urkek":
				Input.action_press("move_right", 1.0)
			await _wait(0.9 if item != "kemik" else 1.2)
			var times: Array = []
			Engine.time_scale = SLOW
			_t0 = Time.get_ticks_msec()
			var idx: int = 0
			idx = await _grab_for(key, PRE_ROLL, idx, rel, times)
			_trig[key] = _game_ms()
			_trigger(item, code)
			idx = await _grab_for(key, float(POST[item]), idx, rel, times)
			Engine.time_scale = 1.0
			_times[key] = times
			if item == "urkek":
				Input.action_release("move_right")
			print("SHOT ", key, " kare=", idx, " oyuncu=", _player.global_position - _home, " kemik=", _player.get("_item_kemik_charges"))
			## donma 5 sn sürer, sonraki çekim temiz başlasın; Ürkek Yürek hızı da sönsün
			await _wait(5.3 if item == "zaman" else (3.0 if item == "urkek" else 0.4))
	var fa := FileAccess.open(_dir.path_join("zamanlar.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"times": _times, "trig": _trig, "crop": [rel.position.x, rel.position.y, rel.size.x, rel.size.y]}))
	fa.close()
	print("BITTI")
	quit()
