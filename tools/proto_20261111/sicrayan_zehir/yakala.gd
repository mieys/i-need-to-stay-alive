extends SceneTree

## SIÇRAYAN ZEHİR (Zehir Asası özelliği, madde 592) GERÇEK OYUNDA çekimi (2026-11-11, kullanıcı: "Evet, göster").
## Oyun koduna dokunulmaz. Büyücü Kız'a yalnız Zehir Asası verilir; önünde sabit duran bir yaratık sırası:
##   A (ilk hedef, ölümsüz can) + B, C, D (canı bir damla hasarından az: damla varınca ölür -> zincir kendiliğinden sürer).
## Asa A'yı gerçekten vurur ve zehirler; ikinci atış A'ya değdikten 0,3 sn sonra A çekim betiğiyle öldürülür ("kim öldürürse öldürsün"
## kuralının yerine geçer - örn. başka bir silah). Ölümden sonra A -> B -> C -> D damlaları (zincir 3) oyunun kendi koduyla akar.
## Kareler SZ_DIR'e: kare_<nnn>.png + zamanlar.json (oyun ms'si). Birleştirme gif.py, koşturucu yakala.ps1 (gizli masaüstü).

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.
const SLOW := 0.25 ## ekran okuma ~11 kare/sn -> oyun zamanı yavaşlatılır, zamanlar OYUN ms'si
const MIN_GAP_MS := 30
const MOBS: Array = [Vector2(95, 0), Vector2(160, 18), Vector2(225, -8), Vector2(290, 14)]
const AFTER_LAND := 0.3 ## ikinci atış A'ya değdikten sonra (oyun sn) A ölür
const POST := 2.0 ## A öldükten sonra çekim (oyun sn)
const MAX_GAME := 7.0

var _dir: String = OS.get_environment("SZ_DIR")
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _mobs: Array = []
var _t0: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0 / Engine.time_scale):
		await process_frame


func _game_ms() -> int:
	return int(float(Time.get_ticks_msec() - _t0) * Engine.time_scale)


func _pre_draw() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	for c in _main.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 100:
			(c as CanvasLayer).visible = false
	for i in _mobs.size():
		var e = _mobs[i] ## tipsiz: ölüp silinen yaratık "previously freed" atamasın
		if is_instance_valid(e) and e.get("is_dead") != true and e.has_method("teleport_to") and _player != null:
			var want: Vector2 = _player.get_meta("sz_origin", _player.global_position) + MOBS[i]
			if e.global_position.distance_to(want) > 0.5:
				e.call("teleport_to", want)


func _shot(idx: int, rel: Rect2i) -> int:
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / 1920.0
	var o: Vector2 = _player.get_meta("sz_origin", _player.global_position)
	var c: Vector2 = (_player.get_viewport().get_canvas_transform() * o) * k
	var r := Rect2i(int(c.x) + int(rel.position.x * k), int(c.y) + int(rel.position.y * k), int(rel.size.x * k), int(rel.size.y * k))
	img.get_region(r).save_png(_dir.path_join("kare_%03d.png" % idx))
	return idx + 1


func _stacks(e: Node) -> int:
	if not is_instance_valid(e):
		return 0
	return (e.get("_poison_stack_time") as PackedFloat32Array).size()


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_char_id", 4)
	_gm.set("selected_character", chars.get_def(4).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
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
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	_player = _main.get_node("Player")
	_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.4)
	## Defter önce yazılır (oyunda da öyle): _apply_enchant_to_weapon kaydı sıradan okur -> doğuştan Sıçrayan Zehir.
	_gm.set("owned_weapons", [(load("res://scripts/enchant_defs.gd") as GDScript).call("new_weapon_entry", "tuftuf", 1, 0)])
	if not bool(_player.call("buy_weapon_copy", "tuftuf", 1)):
		push_error("Zehir Asası verilemedi")
	var w: Node = (_player.get("owned_weapon_nodes") as Array)[0]
	var beh: Node = w.get("enchant_behavior")
	print("SHOT davranis=", beh.get_script().resource_path if beh else "YOK")
	var ap: float = float(_player.get("damage_bonus"))
	## yaratıklar
	var o: Vector2 = _player.global_position
	_player.set_meta("sz_origin", o)
	for i in MOBS.size():
		var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
		e.set("speed", 0.0)
		var hp: float = 1.0e9 if i == 0 else ap * 0.5 * 0.6
		e.set("max_health", hp)
		_main.add_child(e)
		e.global_position = o + MOBS[i]
		e.set("health", hp)
		e.set("item_shield_max", 0.0)
		e.set("item_shield_hp", 0.0)
		_mobs.append(e)
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	## İlk atış A'ya değsin (normal hızda), sonra ikinci atıştan ~0,5 sn önce yavaşlat ve çekmeye başla.
	var a: Node2D = _mobs[0]
	var tw: int = Time.get_ticks_msec()
	while _stacks(a) < 1 and Time.get_ticks_msec() - tw < 8000:
		await process_frame
	await _wait(1.4)
	var rel := Rect2i(-90, -230, 860, 400) ## oyuncunun ekran konumuna göre (1920 genişliği), 1 dünya birimi ~2,25 px
	Engine.time_scale = SLOW
	_t0 = Time.get_ticks_msec()
	var idx: int = 0
	var times: Array = []
	var marks: Dictionary = {}
	var prev: int = _stacks(a)
	var land_ms: int = -1
	var kill_ms: int = -1
	var last: int = -1000
	while _game_ms() < int(MAX_GAME * 1000.0):
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_msec()
		if now - last >= MIN_GAP_MS:
			last = now
			idx = _shot(idx, rel)
			times.append(_game_ms())
		if land_ms < 0 and _stacks(a) > prev:
			land_ms = _game_ms()
			marks["isabet"] = idx
		if land_ms >= 0 and kill_ms < 0 and _game_ms() - land_ms >= int(AFTER_LAND * 1000.0):
			kill_ms = _game_ms()
			marks["olum"] = idx
			a.call("die")
		if kill_ms >= 0 and _game_ms() - kill_ms >= int(POST * 1000.0):
			break
	Engine.time_scale = 1.0
	var dead: Array = []
	for e in _mobs:
		dead.append(is_instance_valid(e) and e.get("is_dead") == true)
	print("SHOT kare=", idx, " isabet=", land_ms, " olum=", kill_ms, " damla=", int(beh.get("leaps")) if beh else -1, " olu=", dead)
	var fa := FileAccess.open(_dir.path_join("zamanlar.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"times": times, "marks": marks, "leaps": int(beh.get("leaps")) if beh else -1, "dead": dead}))
	fa.close()
	print("BITTI")
	quit()
