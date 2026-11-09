extends SceneTree

## VAMPİR ÇOCUK YARASA DÖNÜŞÜMÜ efekt prototipleri gerçek oyunda (2026-11-09, kullanıcı: "yarasaya dönüşüp geri dönünceki partikül
## efektini yeniden tasarlar mısın, şuanki kalitesiz"). Oyun koduna dokunulmaz: E gerçekten basılır (_activate_skill2 / iptal),
## oyunun doğurduğu "puff" (vampir_fx.gd) prototipte gizlenir ve yerine vampir_donusum_proto.py sayfası aynı noktada oynatılır.
## Sayfalar VD_SHEETS: <kod>_<faz>_<katman>.png + <kod>_<faz>.json (faz in = insan->yarasa, out = yarasa->insan;
## katman front z 20 = bugünkü puff gibi en üstte, ground z 0 = sahne kökü, haritanın üstü / oyuncunun (z 1) altı).
## Kareler VD_DIR'e: <kod>_<nn>.png (oyuncu çevresi kırpılmış) + zamanlar.json + olcu.json; birleştirme vampir_donusum_gif.py.
## Koşturucu: tools/proto_20261109/vampir_donusum_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.
const VAMPIR_FX_PATH := "res://scripts/vampir_fx.gd"
const PRE_ROLL := 0.3
const POST_IN := 1.0
const HOLD_BAT := 0.6
const POST_OUT := 0.95
const MIN_GAP_MS := 30

var _dir: String = OS.get_environment("VD_DIR")
var _sheets: String = OS.get_environment("VD_SHEETS")
var _codes: Array = []
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _frames: Dictionary = {}   ## "<kod>_<faz>_<katman>" -> SpriteFrames
var _meta: Dictionary = {}     ## "<kod>_<faz>" -> json
var _seen: Array = []
var _times: Dictionary = {}
var _marks: Dictionary = {}    ## kod -> [in kare no, out kare no]
var _measure: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


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


func _purge() -> void:
	for e in get_nodes_in_group("enemies"):
		if not e.is_queued_for_deletion():
			e.queue_free()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		_purge()


func _load_sheets(code: String) -> void:
	for phase in ["in", "out"]:
		var jp: String = _sheets.path_join("%s_%s.json" % [code, phase])
		if not FileAccess.file_exists(jp):
			continue
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(jp))
		_meta["%s_%s" % [code, phase]] = meta
		for layer in meta["layers"]:
			var img: Image = Image.load_from_file(_sheets.path_join("%s_%s_%s.png" % [code, phase, layer]))
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			var sf := SpriteFrames.new()
			sf.add_animation(&"fx")
			sf.set_animation_loop(&"fx", false)
			sf.set_animation_speed(&"fx", float(meta["fps"]))
			for i in int(meta["frames"]):
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(i * float(meta["w"]), 0, float(meta["w"]), float(meta["h"]))
				sf.add_frame(&"fx", at)
			_frames["%s_%s_%s" % [code, phase, layer]] = sf


## Oyunun yeni doğurduğu puff'ı bulur; prototipte gizler ve yerine sayfayı oynatır.
func _swap_puff(code: String, phase: String) -> void:
	for c in current_scene.get_children():
		if _seen.has(c):
			continue
		var sc: Script = c.get_script()
		if sc == null or sc.resource_path != VAMPIR_FX_PATH or str(c.get("kind")) != "puff":
			continue
		_seen.append(c)
		var at: Vector2 = (c as Node2D).global_position
		_measure["puff_" + phase] = [at.x - _player.global_position.x, at.y - _player.global_position.y]
		if code == "now":
			continue
		(c as CanvasItem).visible = false
		c.set_process(false)
		var key: String = "%s_%s" % [code, phase]
		if not _meta.has(key):
			continue
		var m: Dictionary = _meta[key]
		var k: float = float(m["world_px"])
		for layer in m["layers"]:
			var spr := AnimatedSprite2D.new()
			spr.sprite_frames = _frames["%s_%s" % [key, layer]]
			spr.centered = false
			spr.offset = Vector2(-float(m["ax"]), -float(m["ay"]))
			spr.scale = Vector2(k, k)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.z_index = 0 if layer == "ground" else 20
			current_scene.add_child(spr)
			spr.global_position = at
			spr.animation_finished.connect(spr.queue_free)
			spr.play(&"fx")


## Oyuncu sprite'ının o anki opak dikdörtgeni (dünya, oyuncu konumuna göre) - prototip sayfası çapası için.
func _sprite_box(tag: String) -> void:
	var anim: AnimatedSprite2D = _player.get("anim") as AnimatedSprite2D
	if anim == null:
		return
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	var img: Image = tex.get_image()
	var used: Rect2i = img.get_used_rect()
	var sz: Vector2 = Vector2(img.get_size())
	var top_left: Vector2 = (-sz * 0.5 if anim.centered else Vector2.ZERO) + anim.offset
	var a: Vector2 = anim.global_transform * (top_left + Vector2(used.position))
	var b: Vector2 = anim.global_transform * (top_left + Vector2(used.end))
	var p: Vector2 = _player.global_position
	_measure[tag] = {"anim": str(anim.animation), "x0": a.x - p.x, "y0": a.y - p.y, "x1": b.x - p.x, "y1": b.y - p.y,
		"world_px": anim.global_transform.get_scale().x}


func _shot(code: String, idx: int, rel: Rect2i) -> int:
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / 1920.0
	var c: Vector2 = (_player.get_viewport().get_canvas_transform() * _player.global_position) * k
	var r := Rect2i(int(c.x) + int(rel.position.x * k), int(c.y) + int(rel.position.y * k), int(rel.size.x * k), int(rel.size.y * k))
	img.get_region(r).save_png(_dir.path_join("%s_%03d.png" % [code, idx]))
	return idx + 1


## sec saniye boyunca karelerini alır (her kare arası en az MIN_GAP_MS); idx sürer.
func _grab_for(code: String, sec: float, idx: int, rel: Rect2i, times: Array, t0: int) -> int:
	var start: int = Time.get_ticks_msec()
	var last: int = -1000
	while Time.get_ticks_msec() - start < int(sec * 1000.0):
		await RenderingServer.frame_post_draw
		_purge()
		var now: int = Time.get_ticks_msec()
		if now - last < MIN_GAP_MS:
			continue
		last = now
		idx = _shot(code, idx, rel)
		times.append(now - t0)
	return idx


func _ready_skill() -> void:
	_player.set("skill2_state", "ready")
	_player.set("skill2_timer", 0.0)


func _run() -> void:
	await process_frame
	var only: String = OS.get_environment("VD_CODES")
	_codes = (only if only != "" else "now,A,B,C,D").split(",")
	for code in _codes:
		if code != "now":
			_load_sheets(code)
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_char_id", 13)
	_gm.set("selected_character", chars.get_def(13).get("skill", 1))
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
	RenderingServer.frame_pre_draw.connect(_hide_bubble)
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	var night: bool = OS.get_environment("VD_NIGHT") == "1"
	if atmo:
		atmo.call("debug_set_time", 420.0 if night else 150.0)
		atmo.call("debug_set_weather", 0)
	_player = _main.get_node("Player")
	_player.set("_oakley_flower_auto_timer", 1.0e9)
	_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	await _wait(1.5)
	_sprite_box("human")
	## Kırpma (1920 genişliğine göre ekran pikseli, oyuncunun ekran konumuna göre): 1 dünya birimi = 2,25 px.
	var rel := Rect2i(-150, -170, 300, 250)
	for code in _codes:
		_ready_skill()
		await _wait(0.8)
		var times: Array = []
		var tt: int = Time.get_ticks_msec()
		var idx: int = 0
		idx = await _grab_for(code, PRE_ROLL, idx, rel, times, tt)
		var mark_in: int = idx
		_player.call("_activate_skill2")
		_swap_puff(code, "in")
		idx = await _grab_for(code, POST_IN, idx, rel, times, tt)
		if code == _codes[0]:
			_sprite_box("bat")
		idx = await _grab_for(code, HOLD_BAT, idx, rel, times, tt)
		var mark_out: int = idx
		_player.call("_vampir_cancel_bat_form")
		_swap_puff(code, "out")
		idx = await _grab_for(code, POST_OUT, idx, rel, times, tt)
		_times[code] = times
		_marks[code] = [mark_in, mark_out]
		print("SHOT ", code, " kare=", idx)
		await _wait(0.6)
	var fa := FileAccess.open(_dir.path_join("zamanlar.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"times": _times, "marks": _marks}))
	fa.close()
	var fm := FileAccess.open(_dir.path_join("olcu.json"), FileAccess.WRITE)
	fm.store_string(JSON.stringify(_measure, "  "))
	fm.close()
	print("OLCU ", JSON.stringify(_measure))
	print("BITTI")
	quit()
