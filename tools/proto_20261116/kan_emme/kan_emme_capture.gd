extends SceneTree

## VAMPİR Q "Kan Emme" efekt prototipleri GERÇEK OYUNDA (2026-11-16, kullanıcı: "Vampirin Q yeteneğinin kan emme yeteneği için yeni
## efekt prototipi hazırla"). Oyun koduna dokunulmaz: Q gerçekten basılır (_activate_skill), sabit duran ölümsüz 4 yaratıkta.
## Kod "now" dışında oyunun doğurduğu "drain" (vampir_fx.gd) GİZLENİR, yerine kan_emme_proto_fx.gd aynı points / sink ile doğar.
## Kareler KE_DIR'e <kod>_<nnn>.png (oyuncu çevresi) + zamanlar.json (OYUN ms'si); birleştirme kan_emme_gif.py.
## Koşturucu kan_emme_run.ps1 (gizli masaüstü, APPDATA yalıtılır). Ortam: KE_CODES=now,A,..  KE_NIGHT=1  KE_NUMBERS=1 (hasar sayıları açık).
## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.

const VAMPIR_FX_PATH := "res://scripts/vampir_fx.gd"
const PROTO_PATH := "res://tools/proto_20261116/kan_emme/kan_emme_proto_fx.gd"
const PRE_ROLL := 0.25
const POST := 1.35
const MIN_GAP_MS := 30
## Ekran okuma ~11 kare/sn -> oyun zamanı yavaşlatılır; zamanlar OYUN ms'si olarak yazılır.
const SLOW := 0.25
## Yaratıklar (oyuncuya göre dünya birimi): Q en yakın 4'ü seçer (320 menzil); savaşta tipik 60-130 birim.
const MOBS: Array = [Vector2(-86, -30), Vector2(96, -46), Vector2(-66, 50), Vector2(108, 36)]
const ROSTER: Array = ["slime1", "zombie1", "rat2", "iskelet2"]

var _dir: String = OS.get_environment("KE_DIR")
var _codes: Array = []
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _proto: GDScript = null
var _seen: Array = []
var _times: Dictionary = {}
var _marks: Dictionary = {}
var _t0: int = 0
var _drain_info: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0 / Engine.time_scale):
		await process_frame


func _game_ms() -> int:
	return int(float(Time.get_ticks_msec() - _t0) * Engine.time_scale)


## Kalkan baloncuğu çekimde efekti örtüyor -> her çizimden önce gizlenir (oyunun kendisine dokunulmaz).
func _hide_bubble() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sv: Variant = _player.get("shield_visual")
	if sv is CanvasItem and is_instance_valid(sv):
		(sv as CanvasItem).visible = false
	var mfx: Node = _player.get_node_or_null("ManaShieldFx")
	if mfx is CanvasItem:
		(mfx as CanvasItem).visible = false


## Oyunun yeni doğurduğu drain'i bulur; prototipte gizler ve yerine prototip düğümünü aynı veriyle doğurur.
func _swap_drain(code: String) -> void:
	for c in current_scene.get_children():
		if _seen.has(c):
			continue
		var sc: Script = c.get_script()
		if sc == null or sc.resource_path != VAMPIR_FX_PATH or str(c.get("kind")) != "drain":
			continue
		_seen.append(c)
		var pts: PackedVector2Array = c.get("points")
		var rel: Array = []
		for p in pts:
			rel.append([p.x - _player.global_position.x, p.y - _player.global_position.y])
		_drain_info[code] = rel
		if code == "now":
			continue
		(c as CanvasItem).visible = false
		c.set_process(false)
		var fx: Node2D = _proto.new()
		fx.set("variant", code)
		fx.set("points", pts)
		fx.set("sink", _player)
		current_scene.add_child(fx)
		fx.global_position = _player.global_position


func _shot(code: String, idx: int, rel: Rect2i) -> int:
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / 1920.0
	var c: Vector2 = (_player.get_viewport().get_canvas_transform() * _player.global_position) * k
	var r := Rect2i(int(c.x) + int(rel.position.x * k), int(c.y) + int(rel.position.y * k), int(rel.size.x * k), int(rel.size.y * k))
	img.get_region(r).save_png(_dir.path_join("%s_%03d.png" % [code, idx]))
	return idx + 1


func _grab_for(code: String, sec: float, idx: int, rel: Rect2i, times: Array) -> int:
	var start: int = Time.get_ticks_msec()
	var last: int = -1000
	while Time.get_ticks_msec() - start < int(sec * 1000.0 / Engine.time_scale):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_msec()
		if now - last < MIN_GAP_MS:
			continue
		last = now
		idx = _shot(code, idx, rel)
		times.append(_game_ms())
	return idx


func _spawn_mobs() -> void:
	var o: Vector2 = _player.global_position
	for i in MOBS.size():
		var e: Node2D = (load("res://scenes/creatures/enemy_%s.tscn" % ROSTER[i]) as PackedScene).instantiate()
		e.set("speed", 0.0)
		e.set("max_health", 1.0e9)
		_main.add_child(e)
		e.global_position = o + MOBS[i]
		e.set("health", 1.0e9)


func _run() -> void:
	await process_frame
	var only: String = OS.get_environment("KE_CODES")
	_codes = (only if only != "" else "now,A,B,C,D").split(",")
	_proto = load(PROTO_PATH)
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_char_id", 13)
	_gm.set("selected_character", chars.get_def(13).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	if OS.get_environment("KE_NUMBERS") != "1":
		root.get_node("UISound").set("damage_numbers_mode", 2) ## kayıt yok (yalnız bu süreç)
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
		atmo.call("debug_set_time", 420.0 if OS.get_environment("KE_NIGHT") == "1" else 150.0)
		atmo.call("debug_set_weather", 0)
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	_player = _main.get_node("Player")
	_player.set("_oakley_flower_auto_timer", 1.0e9)
	_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	_player.set("level", 10)
	while (_player.get("owned_weapon_nodes") as Array).size() > 0: ## silahlar efekti örtmesin
		_player.call("remove_owned_weapon", 0)
	await _wait(0.6)
	_spawn_mobs()
	RenderingServer.frame_pre_draw.connect(_hide_bubble)
	await _wait(1.5)
	## Kırpma (1920 genişliğine göre ekran pikseli, oyuncunun ekran konumuna göre): 1 dünya birimi = 2,25 px -> ~276 x 160 dünya.
	var rel := Rect2i(-310, -200, 620, 360)
	Engine.time_scale = SLOW
	for code in _codes:
		_player.set("skill_state", "ready")
		_player.set("skill_timer", 0.0)
		_player.set("health", 1.0e6)
		await _wait(0.9)
		var times: Array = []
		_t0 = Time.get_ticks_msec()
		var idx: int = 0
		idx = await _grab_for(code, PRE_ROLL, idx, rel, times)
		_marks[code] = idx
		_player.call("_activate_skill")
		_swap_drain(code)
		idx = await _grab_for(code, POST, idx, rel, times)
		_times[code] = times
		print("SHOT ", code, " kare=", idx, " hedef=", (_drain_info.get(code, []) as Array).size())
		await _wait(0.5)
	Engine.time_scale = 1.0
	var fa := FileAccess.open(_dir.path_join("zamanlar.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"times": _times, "marks": _marks, "targets": _drain_info, "crop": [rel.position.x, rel.position.y, rel.size.x, rel.size.y]}))
	fa.close()
	print("BITTI")
	quit()
