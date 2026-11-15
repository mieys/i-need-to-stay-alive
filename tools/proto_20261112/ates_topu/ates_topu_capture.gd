extends SceneTree

## ATEŞ ASASI "TUTUŞMA" ATEŞ TOPU PROTOTİPLERİ A-D gerçek oyunda (2026-11-12). Oyun koduna DOKUNULMAZ.
## Lyra ateş asasıyla 3 slime'a bakar; asanın kendi püskürtmesi susturulur (özellik düğümünün tik sayacı her karede ileri atılır,
## nişan yine çalışır). Toplar bu betikte simüle edilir: asanın ÇİZİLİ ucundan çıkar, hedefe gider; hedef yanmıyorsa küçük vuruş
## patlaması + OYUNUN GERÇEK yanma durumu (enemy.apply_burn -> yer alevi), yanıyorsa yanmayı tüketip büyük alevlenme patlaması.
## Sayfalar ates_topu_proto.py (AC_SHEETS): <kod>_top / _vur / _alev. Kareler AC_DIR'e: sag_<kod>_<nn>.png + zamanlar.json.
## Koşturucu: ates_topu_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.
var WeaponTip: GDScript = null
var CODES: Array = Array(OS.get_environment("AC_CODES").split(",", false)) if OS.get_environment("AC_CODES") != "" else ["A", "B", "C", "D"]
const NFRAMES := 70
const FRAME_MS := 50
const SPEED := 330.0
const FIRE_EVERY := 0.55
const ORDER := [0, 1, 0, 2, 1, 2]

var _dir: String = OS.get_environment("AC_DIR")
var _sheets: String = OS.get_environment("AC_SHEETS")
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _variant: String = ""
var _frames: Dictionary = {}
var _meta: Dictionary = {}
var _keep: Array = []
var _times: Dictionary = {}
var _layer: Node2D = null
var _balls: Array = []      ## [AnimatedSprite2D, hedef]
var _bursts: Array = []     ## AnimatedSprite2D
var _sim_on: bool = false
var _shot_i: int = 0
var _next_shot: float = 0.0
var _clock: float = 0.0
var _last_ms: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _purge() -> void:
	if _player == null:
		return
	for e in get_nodes_in_group("enemies"):
		if not _keep.has(e) and not e.is_queued_for_deletion():
			e.queue_free()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		_purge()


func _load(name: String, loop: bool) -> void:
	var img: Image = Image.load_from_file(_sheets.path_join(name + ".png"))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_sheets.path_join(name + ".json")))
	var sf := SpriteFrames.new()
	sf.add_animation(&"a")
	sf.set_animation_loop(&"a", loop)
	sf.set_animation_speed(&"a", float(meta["fps"]))
	for i in int(meta["frames"]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * float(meta["w"]), 0, float(meta["w"]), float(meta["h"]))
		sf.add_frame(&"a", at)
	_frames[name] = sf
	_meta[name] = meta


func _sprite(name: String) -> AnimatedSprite2D:
	var m: Dictionary = _meta[name]
	var s := AnimatedSprite2D.new()
	s.sprite_frames = _frames[name]
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var k: float = float(m["world_px"])
	s.scale = Vector2(k, k)
	s.offset = Vector2(float(m["w"]) * 0.5 - float(m["x0"]), float(m["h"]) * 0.5 - float(m["cy"]))
	_layer.add_child(s)
	s.play(&"a")
	return s


func _slime(pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", 1.0e9)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", 1.0e9)
	return e


func _staff() -> Node:
	for n in _player.get("owned_weapon_nodes"):
		if is_instance_valid(n):
			return n
	return null


func _body(e: Node2D) -> Vector2:
	return e.global_position + Vector2(0.0, -7.0)


## Her karede çizimden hemen önce: asanın püskürtmesini sustur + topları/patlamaları ilerlet.
func _tick() -> void:
	var now: int = Time.get_ticks_msec()
	var dt: float = clampf(float(now - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now
	if _player == null or not is_instance_valid(_player):
		return
	var w: Node = _staff()
	if w:
		var b: Object = w.get("enchant_behavior")
		if b and is_instance_valid(b):
			b.set("_tick_t", 1.0e9)
	if not _sim_on or w == null:
		return
	_clock += dt
	if _clock >= _next_shot and _shot_i < ORDER.size():
		_next_shot += FIRE_EVERY
		var tgt: Node2D = _keep[ORDER[_shot_i]]
		_shot_i += 1
		var icon: Sprite2D = w.get("icon_sprite") as Sprite2D
		var ball: AnimatedSprite2D = _sprite(_variant + "_top")
		ball.global_position = WeaponTip.tip_global(icon, float(w.get("sprite_forward_angle_deg")))
		ball.z_index = 5
		_balls.append([ball, tgt])
	for it in _balls.duplicate():
		var ball: AnimatedSprite2D = it[0]
		var tgt: Node2D = it[1]
		var to: Vector2 = _body(tgt) - ball.global_position
		var step: float = SPEED * dt
		if to.length() <= step + 3.0:
			_hit(tgt)
			ball.queue_free()
			_balls.erase(it)
			continue
		ball.global_position += to.normalized() * step
		ball.global_rotation = to.angle()
	for s in _bursts.duplicate():
		if not s.is_playing():
			s.queue_free()
			_bursts.erase(s)


func _hit(tgt: Node2D) -> void:
	var big: bool = bool(tgt.call("is_burning"))
	var s: AnimatedSprite2D = _sprite(_variant + ("_alev" if big else "_vur"))
	s.global_position = _body(tgt)
	s.z_index = 6
	_bursts.append(s)
	if big:
		tgt.set("burn_time_left", 0.0)
		tgt.set("burn_tick_damage", 0.0)
		tgt.call("_remove_burn_status_fx")
	else:
		tgt.call("apply_burn", 0.0001, 3.0)


func _grab(sc: String, code: String, rel: Rect2i) -> void:
	var times: Array = []
	var t0: int = Time.get_ticks_msec()
	var last: int = -1000
	var i: int = 0
	while i < NFRAMES:
		await RenderingServer.frame_post_draw
		_purge()
		var now: int = Time.get_ticks_msec()
		if now - last < FRAME_MS:
			continue
		last = now
		var img: Image = root.get_texture().get_image()
		var k: float = float(img.get_width()) / 1920.0
		var c: Vector2 = (_player.get_viewport().get_canvas_transform() * _player.global_position) * k
		var r := Rect2i(int(c.x) + rel.position.x, int(c.y) + rel.position.y, rel.size.x, rel.size.y)
		img.get_region(r).save_png(_dir.path_join("%s_%s_%02d.png" % [sc, code, i]))
		times.append(now - t0)
		i += 1
	_times["%s_%s" % [sc, code]] = times
	print("SHOT ", sc, " ", code, " ", times[-1], " ms")


func _run() -> void:
	await process_frame
	for code in CODES:
		_load(code + "_top", true)
		_load(code + "_vur", false)
		_load(code + "_alev", false)
	WeaponTip = load("res://scripts/weapon_tip.gd")
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 2)
	_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(2).get("skill", 1))
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
	_layer = Node2D.new()
	_main.add_child(_layer)
	_last_ms = Time.get_ticks_msec()
	RenderingServer.frame_pre_draw.connect(_tick)
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	_player = _main.get_node("Player")
	_player.set("_oakley_flower_auto_timer", 1.0e9)
	_player.global_position += Vector2(-170.0, 100.0)
	var spot: Vector2 = _player.global_position
	await _wait(1.5)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	for n in _player.get("owned_weapon_nodes"):
		if is_instance_valid(n):
			n.queue_free()
	(_player.get("owned_weapon_nodes") as Array).clear()
	(_gm.get("owned_weapons") as Array).clear()
	await process_frame
	(_gm.get("owned_weapons") as Array).append((load("res://scripts/enchant_defs.gd") as GDScript).new_weapon_entry("fire_staff", 1, 0))
	print("buy ", _player.call("buy_weapon_copy", "fire_staff", 1))
	_keep = [_slime(spot + Vector2(120.0, -18.0)), _slime(spot + Vector2(150.0, 22.0)), _slime(spot + Vector2(95.0, 46.0))]
	await _wait(4.0)
	for code in CODES:
		_variant = code
		for e in _keep:
			e.set("burn_time_left", 0.0)
			e.call("_remove_burn_status_fx")
		_shot_i = 0
		_clock = 0.0
		_next_shot = 0.15
		_sim_on = true
		await _grab("sag", code, Rect2i(-120, -290, 760, 560))
		_sim_on = false
		await _wait(1.2)
	var fa := FileAccess.open(_dir.path_join("zamanlar.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(_times))
	fa.close()
	print("BITTI")
	quit()
