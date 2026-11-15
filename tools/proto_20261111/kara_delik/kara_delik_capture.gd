extends SceneTree

## HADIME E KARA DELIK prototipleri gerçek oyunda (2026-11-11, kullanıcı: "kara delik yeteneği için 4 adet prototip hazırla,
## şuanki görüntüsünü beğenmiyorum"). Oyun koduna dokunulmaz: E gerçekten basılır (_activate_skill2), doğan deliğin kendi
## sprite'ı gizlenir ve yerine prototip katmanları DELİĞİN ÇOCUĞU olarak eklenir (zemine yerleşim, ömür, çıkış zamanı oyunun
## kendi kodundan). Kare seçimi deliğin kendi saatinden (_t): giriş 8 kare 20 fps, döngü, çıkış 6,0 sn'de 8 kare 16 fps
## (çarpma = çıkışın 4. karesi = 6,25 sn, sesin çöküş vuruşu). D bir shader: BackBufferCopy + Polygon2D (kara_delik_d.gdshader).
## Sayfalar KD_SHEETS (kara_delik_proto.py), kareler KD_DIR'e: <kod>_<nnn>.png (deliğin çevresi) + zamanlar.json + olcu.json.
## Koşturucu: kara_delik_run.ps1 (gizli masaüstü, APPDATA yalıtılır). Birleştirme: kara_delik_gif.py.

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.
const HOLE_GROUP := "hadime_black_holes"
const D_SHADER := "res://tools/proto_20261111/kara_delik/kara_delik_d.gdshader"
## "D1" = ilk turun merkezi (düz kara elips + 1 px halka), karşılaştırma için.
const D_SHADERS := {"D": D_SHADER, "D1": "res://tools/proto_20261111/kara_delik/kara_delik_d_v1.gdshader", "D2": D_SHADER}
## "D2": merkez (küre + disk + yaylar + çarpma parlaması) yaratıkların ÜSTÜNDE ayrı katmanda, zemin shader'ı center_mode 1.
const D_FRONT_SHADER := "res://tools/proto_20261111/kara_delik/kara_delik_d_on.gdshader"
const PRE_ROLL := 0.15
const SEG1_END := 2.0
const SEG2_START := 5.7
const POST_END := 6.8
const WALK_FROM := 0.3
const WALK_TO := 1.05
const MIN_GAP_MS := 30
## Kırpma (dünya birimi, delik merkezine göre)
const CROP := Rect2(-140.0, -92.0, 280.0, 160.0)

var _dir: String = OS.get_environment("KD_DIR")
var _sheets: String = OS.get_environment("KD_SHEETS")
var _codes: Array = []
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _tex: Dictionary = {}      ## "<kod>_<katman>" -> ImageTexture
var _meta: Dictionary = {}     ## kod -> json
var _active: Array = []        ## [{hole, sprites, meta, mat}]
var _times: Dictionary = {}
var _hts: Dictionary = {}
var _marks: Dictionary = {}
var _measure: Dictionary = {}
## Yaratıklı kip (KD_MOBS = sayı, KD_MOB_TIER = kademe rosteri, varsayılan 6): E'den hemen önce deliğin çevresine halka hâlinde
## yaratık doğar (ölmesinler diye can 1e6), silinmez; KD_WALK=0 ise Hadime yerinde durur (kalabalığın ortasına bırakma).
var _mobs: int = int(OS.get_environment("KD_MOBS")) if OS.get_environment("KD_MOBS") != "" else 0
var _walk: bool = OS.get_environment("KD_WALK") != "0"
var _keep_mobs: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _hide_bubble() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sv: Variant = _player.get("shield_visual")
	if sv is CanvasItem and is_instance_valid(sv):
		(sv as CanvasItem).visible = false
	var mfx: Node = _player.get_node_or_null("ManaShieldFx")
	if mfx is CanvasItem:
		(mfx as CanvasItem).visible = false


## Her çizimden önce prototip karelerini deliğin saatine eşitler.
func _sync_protos() -> void:
	_hide_bubble()
	for a in _active:
		if not is_instance_valid(a["hole"]):
			continue
		var hole: Node = a["hole"]
		var t: float = float(hole.get("_t"))
		if a["mat"] != null:
			for mm in a["mat"]:
				(mm as ShaderMaterial).set_shader_parameter("t", t)
			continue
		var m: Dictionary = a["meta"]
		var n_in: int = int(m["n_in"])
		var n_loop: int = int(m["n_loop"])
		var n_out: int = int(m["n_out"])
		var in_len: float = float(n_in) / float(m["fps_in"])
		var fi: int = 0
		if t < in_len:
			fi = mini(n_in - 1, int(t * float(m["fps_in"])))
		elif t < 6.0:
			fi = n_in + int((t - in_len) * float(m["fps_loop"])) % n_loop
		else:
			fi = n_in + n_loop + mini(n_out - 1, int((t - 6.0) * float(m["fps_out"])))
		for s in a["sprites"]:
			(s as Sprite2D).frame = fi


func _purge() -> void:
	if _keep_mobs:
		return
	for e in get_nodes_in_group("enemies"):
		if not e.is_queued_for_deletion():
			e.queue_free()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		_purge()


func _load_sheets(code: String) -> void:
	var jp: String = _sheets.path_join("%s.json" % code)
	if not FileAccess.file_exists(jp):
		return
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(jp))
	_meta[code] = meta
	for layer in meta["layers"]:
		var img: Image = Image.load_from_file(_sheets.path_join("%s_%s.png" % [code, layer]))
		_tex["%s_%s" % [code, layer]] = ImageTexture.create_from_image(img)


func _attach(code: String, hole: Node2D) -> void:
	if code == "now":
		return
	var spr: Variant = hole.get("_sprite")
	if spr is CanvasItem:
		(spr as CanvasItem).visible = false
	if D_SHADERS.has(code):
		var mat: Array = _add_d_nodes(hole, code)
		_active.append({"hole": hole, "sprites": [], "meta": {}, "mat": mat})
		return
	if not _meta.has(code):
		return
	var m: Dictionary = _meta[code]
	var sprites: Array = []
	var nf: int = int(m["n_in"]) + int(m["n_loop"]) + int(m["n_out"])
	var k: float = float(m["world_px"])
	for layer in m["layers"]:
		var s := Sprite2D.new()
		s.texture = _tex["%s_%s" % [code, layer]]
		s.hframes = nf
		s.centered = false
		s.offset = Vector2(-float(m["ax"]), -float(m["ay"]))
		s.scale = Vector2(k, k)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if layer == "front":
			s.z_as_relative = false
			s.z_index = 20
		hole.add_child(s)
		sprites.append(s)
	_active.append({"hole": hole, "sprites": sprites, "meta": m, "mat": null})


## D: ekran kopyası + shader dörtgeni. TUZAK (4.7.2): COPY_MODE_RECT bu bölgeyi yenilemedi -> shader bir önceki karenin
## (atmosfer geçişinin tam ekran kopyası) görüntüsünü okudu, efekt kendi üstüne binip karardı ve oyuncu/can çubuğu içine
## karıştı. COPY_MODE_VIEWPORT doğru (su prototipi madde 209 aynı sonuç).
func _add_d_nodes(parent: Node2D, code: String) -> Array:
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	parent.add_child(bb)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-130, -70), Vector2(130, -70), Vector2(130, 70), Vector2(-130, 70)])
	var mat := ShaderMaterial.new()
	mat.shader = load(D_SHADERS[code])
	poly.material = mat
	poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(poly)
	var mats: Array = [mat]
	if code == "D2":
		mat.set_shader_parameter("center_mode", 1)
		var fp := Polygon2D.new()
		fp.polygon = PackedVector2Array([Vector2(-34, -30), Vector2(34, -30), Vector2(34, 16), Vector2(-34, 16)])
		var fm := ShaderMaterial.new()
		fm.shader = load(D_FRONT_SHADER)
		fp.material = fm
		fp.z_as_relative = false
		fp.z_index = 20
		parent.add_child(fp)
		mats.append(fm)
	return mats


func _spawn_mobs(center: Vector2, n: int) -> void:
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner == null:
		return
	var tier: int = int(OS.get_environment("KD_MOB_TIER")) if OS.get_environment("KD_MOB_TIER") != "" else 6
	var rosters: Dictionary = (spawner.get_script() as GDScript).get_script_constant_map().get("TIER_ROSTER", {})
	var roster: Array = Array(rosters.get(tier, rosters.get(1, ["slime1"])))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in n:
		var before: Array = get_nodes_in_group("enemies")
		spawner.call("debug_spawn_creature", roster[i % roster.size()], tier, 1, center)
		for e in get_nodes_in_group("enemies"):
			if before.has(e) or not (e is Node2D):
				continue
			var ang: float = TAU * float(i) / float(n) + rng.randf_range(-0.25, 0.25)
			var rr: float = rng.randf_range(45.0, 125.0)
			(e as Node2D).global_position = center + Vector2(cos(ang) * rr, sin(ang) * rr * 0.6)
			e.set("max_health", 1.0e6)
			e.set("health", 1.0e6)
	print("MOBS ", get_nodes_in_group("enemies").size(), " kademe=", tier, " ", roster)


func _world_to_shot(img_w: int, wp: Vector2) -> Vector2:
	var k: float = float(img_w) / 1920.0
	return (_player.get_viewport().get_canvas_transform() * wp) * k


func _shot(code: String, idx: int, center: Vector2) -> int:
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / 1920.0
	var s: float = _player.get_viewport().get_canvas_transform().get_scale().x * k
	var c: Vector2 = _world_to_shot(img.get_width(), center)
	var r := Rect2i(int(c.x + CROP.position.x * s), int(c.y + CROP.position.y * s), int(CROP.size.x * s), int(CROP.size.y * s))
	img.get_region(r).save_png(_dir.path_join("%s_%03d.png" % [code, idx]))
	return idx + 1


func _run() -> void:
	await process_frame
	var only: String = OS.get_environment("KD_CODES")
	_codes = (only if only != "" else "now,A,B,C,D").split(",")
	for code in _codes:
		if code != "now" and not D_SHADERS.has(code):
			_load_sheets(code)
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_char_id", 14)
	_gm.set("selected_character", chars.get_def(14).get("skill", 1))
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
	RenderingServer.frame_pre_draw.connect(_sync_protos)
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	var night: bool = OS.get_environment("KD_NIGHT") == "1"
	if atmo:
		atmo.call("debug_set_time", 420.0 if night else 150.0)
		atmo.call("debug_set_weather", 0)
	_player = _main.get_node("Player")
	## Ana haritada evin önündeki açık çayır; başka harita (HARITA=col / batik_nekropol ...) doğuş noktasında kalır.
	if OS.get_environment("HARITA") == "":
		_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	await _wait(1.5)
	var home: Vector2 = _player.global_position
	## D shader'ını ısıt (ilk kullanımda derleme yüzünden giriş kareleri boş çıkıyordu): t = -1 -> hiçbir şey çizmez.
	for dcode in D_SHADERS:
		if not _codes.has(dcode):
			continue
		var warm := Node2D.new()
		_main.add_child(warm)
		warm.global_position = home
		for wm in _add_d_nodes(warm, dcode):
			(wm as ShaderMaterial).set_shader_parameter("t", -1.0)
		await _wait(0.6)
		warm.queue_free()
	var ct: Transform2D = _player.get_viewport().get_canvas_transform()
	_measure["canvas_scale"] = ct.get_scale().x
	for code in _codes:
		_player.global_position = home
		if _player.has_method("reset_physics_interpolation"):
			_player.call("reset_physics_interpolation")
		await _wait(1.2)
		_player.set("skill2_state", "ready")
		_player.set("skill2_timer", 0.0)
		var smax: Variant = _player.get("item_shield_max")
		if smax != null:
			_player.set("item_shield_hp", float(smax))
		await _wait(0.3)
		var times: Array = []
		var hts: Array = []
		var idx: int = 0
		var center: Vector2 = _player.to_global(Vector2(0, 30))
		if _mobs > 0:
			_keep_mobs = true
			_spawn_mobs(center, _mobs)
			await _wait(0.5)
		var start: int = Time.get_ticks_msec()
		var last: int = -1000
		## ön kayıt
		while Time.get_ticks_msec() - start < int(PRE_ROLL * 1000.0):
			await RenderingServer.frame_post_draw
			_purge()
			var now0: int = Time.get_ticks_msec()
			if now0 - last < MIN_GAP_MS:
				continue
			last = now0
			idx = _shot(code, idx, center)
			times.append(now0 - start)
			hts.append(-1.0)
		var seen: Array = get_nodes_in_group(HOLE_GROUP)
		_player.call("_activate_skill2")
		var hole: Node2D = null
		for h in get_nodes_in_group(HOLE_GROUP):
			if not seen.has(h):
				hole = h
		if hole == null:
			_player.call("_skill_hadime_black_hole")
			for h in get_nodes_in_group(HOLE_GROUP):
				if not seen.has(h):
					hole = h
		if hole == null:
			print("ERROR delik doğmadı ", code)
			continue
		center = hole.global_position
		_measure["hole_off_" + code] = [center.x - home.x, center.y - home.y]
		_attach(code, hole)
		var mark: int = idx
		var cast: int = Time.get_ticks_msec()
		var walking: bool = false
		var walked: bool = false
		while true:
			await RenderingServer.frame_post_draw
			_purge()
			var now: int = Time.get_ticks_msec()
			var rel: float = float(now - cast) / 1000.0
			if _walk and not walked and not walking and rel >= WALK_FROM:
				Input.action_press("move_left")
				walking = true
			if walking and rel >= WALK_TO:
				Input.action_release("move_left")
				walking = false
				walked = true
			if rel > POST_END:
				break
			if rel > SEG1_END and rel < SEG2_START:
				continue
			if now - last < MIN_GAP_MS:
				continue
			last = now
			idx = _shot(code, idx, center)
			times.append(now - start)
			hts.append(float(hole.get("_t")) if is_instance_valid(hole) else 99.0)
		Input.action_release("move_left")
		_times[code] = times
		_hts[code] = hts
		_marks[code] = [mark, cast - start]
		print("SHOT ", code, " kare=", idx)
		_active.clear()
		_keep_mobs = false
		_purge()
		await _wait(0.5)
	var zp: String = _dir.path_join("zamanlar.json")
	var prev: Dictionary = {"times": {}, "hts": {}, "marks": {}}
	if FileAccess.file_exists(zp):
		var pv: Variant = JSON.parse_string(FileAccess.get_file_as_string(zp))
		if pv is Dictionary:
			prev = pv
	for c in _times:
		prev["times"][c] = _times[c]
		prev.get_or_add("hts", {})[c] = _hts[c]
		prev["marks"][c] = _marks[c]
	var fa := FileAccess.open(zp, FileAccess.WRITE)
	fa.store_string(JSON.stringify(prev))
	fa.close()
	var fm := FileAccess.open(_dir.path_join("olcu.json"), FileAccess.WRITE)
	fm.store_string(JSON.stringify(_measure, "  "))
	fm.close()
	print("OLCU ", JSON.stringify(_measure))
	print("BITTI")
	quit()
