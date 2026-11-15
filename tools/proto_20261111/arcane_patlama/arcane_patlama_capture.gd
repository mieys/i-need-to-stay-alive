extends SceneTree

## BÜYÜCÜ "Arcane Patlama" (E1) patlama efekti prototipleri GERÇEK OYUNDA (2026-11-11, kullanıcı: "arcane patlaması yeteneğinin
## patlama efektleri için 4 yeni prototip hazırla, şuankiler görsel okunurluk açısından kötü"). Oyun koduna dokunulmaz: Büyücü'ye
## E1 evrimi verilir, Arcane Lanet (E) gerçekten basılır (_buyucu_try_activate_variation), sabit duran ölümsüz yaratık kümesinde seker.
## Kod "now" dışında: oyunun doğurduğu iki patlama (fx_mage_passive_burst.gd + fx_arcane_impact'in lanet_burst sayfası) GİZLENİR,
## yerine arcane_patlama_proto.py sayfası (front z 50 + ground z 0) aynı noktada oynatılır; lanet gözü / ayak mührü / lanet ipi aynen.
## Sayfalar AP_SHEETS: <kod>_<katman>.png + <kod>.json. Kareler AP_DIR'e: <kod>_<nnn>.png + zamanlar.json (+ ilk patlamanın ekran
## konumu); birleştirme arcane_patlama_gif.py. Koşturucu arcane_patlama_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.
const MAGE_BURST_PATH := "res://scripts/fx_mage_passive_burst.gd" ## madde 563'te silindi (eski çekimler)
const BLAST_PATH := "res://scripts/fx_arcane_blast.gd" ## oyundaki Yıldız Tozu (madde 563) - "now" kodunda yalnız kaydedilir
const PRE_ROLL := 0.3
const POST := 2.6
const MIN_GAP_MS := 30
## Çekim ~11 kare/sn'de kalıyor (ekran okuma) -> oyun zamanı yavaşlatılır; zamanlar OYUN ms'si olarak yazılır.
const SLOW := 0.25
## Yaratık kümesi (oyuncuya göre dünya birimi): sekme sırası en yakın ziyaret edilmemiş; patlama 75 birimde komşuya da değer.
const MOBS: Array = [Vector2(95, -5), Vector2(150, 35), Vector2(165, -45), Vector2(215, 0), Vector2(270, 40), Vector2(282, -35), Vector2(335, 5)]
const ROSTER: Array = ["slime1", "zombie1", "slime1", "zombie2", "slime1", "zombie1", "slime1"]

var _dir: String = OS.get_environment("AP_DIR")
var _sheets: String = OS.get_environment("AP_SHEETS")
var _codes: Array = []
var _code: String = "now"
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _mobs: Array = []
var _frames: Dictionary = {}   ## "<kod>_<katman>" -> SpriteFrames
var _meta: Dictionary = {}     ## kod -> json
var _seen: Dictionary = {}
var _times: Dictionary = {}
var _marks: Dictionary = {}    ## kod -> E basıldığı kare no
var _blasts: Dictionary = {}   ## kod -> [[ms, dünya x, y (oyuncuya göre)], ...]
var _hits: Dictionary = {}     ## kod -> lanet_burst (gözün çarpması) aynı biçimde - evrimsizde patlama yok, isabet anı bu
var _t0: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0 / Engine.time_scale):
		await process_frame


func _game_ms() -> int:
	return int(float(Time.get_ticks_msec() - _t0) * Engine.time_scale)


func _load_sheets(code: String) -> void:
	var jp: String = _sheets.path_join("%s.json" % code)
	if not FileAccess.file_exists(jp):
		push_error("sayfa yok: " + jp)
		return
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(jp))
	_meta[code] = meta
	for layer in meta["layers"]:
		var img: Image = Image.load_from_file(_sheets.path_join("%s_%s.png" % [code, layer]))
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
		_frames["%s_%s" % [code, layer]] = sf


## Çizimden hemen önce: yeni doğan patlamaları bulur; prototipte gizler ve yerine sayfayı oynatır (lanet_burst bir kare sonra
## call_deferred ile doğar - normal _process'te yakalanırsa bir kare görünürdü). Yaratıklar her karede yerine sabitlenir.
func _pre_draw() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	## bildirim levhaları (main.gd _present_notice, katman 100+) çekimi kapatmasın
	for c in _main.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer >= 100:
			(c as CanvasLayer).visible = false
	for i in _mobs.size():
		var e: Node2D = _mobs[i]
		if is_instance_valid(e) and e.has_method("teleport_to") and _player != null:
			var want: Vector2 = _player.get_meta("ap_origin", _player.global_position) + MOBS[i]
			if e.global_position.distance_to(want) > 0.5:
				e.call("teleport_to", want)
	for c in current_scene.get_children():
		var id: int = c.get_instance_id()
		if _seen.has(id):
			continue
		var sc: Script = c.get_script()
		if sc != null and (sc.resource_path == MAGE_BURST_PATH or sc.resource_path == BLAST_PATH):
			_seen[id] = true
			var at: Vector2 = (c as Node2D).global_position
			## güç (Efsunlu Büyü) = efekt ölçeği x FX_BASE / yarıçap - sabitler oyunun kendisinden (kopya sayı yok, madde 563 yarıçap değişti)
			## madde 563 sonrası efekt fx_arcane_blast: ölçek = yarıçap / DRAWN_RADIUS (eski mühürde FX_BASE 96 idi, sabit silindi)
			var consts: Dictionary = (_player.get_script() as Script).get_script_constant_map()
			var drawn: float = float((load(BLAST_PATH) as Script).get_script_constant_map()["DRAWN_RADIUS"])
			var power: float = (c as Node2D).scale.x * drawn / float(consts["EVO_BUYUCU_ARCANE_BLAST_RADIUS"])
			var o: Vector2 = _player.get_meta("ap_origin", _player.global_position)
			(_blasts[_code] as Array).append([_game_ms(), at.x - o.x, at.y - o.y])
			if _code == "now":
				continue
			(c as CanvasItem).visible = false
			c.set_process(false)
			_spawn_proto(at, power)
		elif c is Sprite2D and (c as Sprite2D).texture != null and (c as Sprite2D).texture.resource_path.ends_with("lanet_burst.png"):
			_seen[id] = true
			var hp: Vector2 = (c as Node2D).global_position
			var ho: Vector2 = _player.get_meta("ap_origin", _player.global_position)
			(_hits[_code] as Array).append([_game_ms(), hp.x - ho.x, hp.y - ho.y])
			if _code != "now":
				(c as CanvasItem).visible = false


func _spawn_proto(at: Vector2, power: float) -> void:
	if not _meta.has(_code):
		return
	var m: Dictionary = _meta[_code]
	var k: float = float(m["world_px"]) * power
	for layer in m["layers"]:
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = _frames["%s_%s" % [_code, layer]]
		spr.centered = false
		spr.offset = Vector2(-float(m["ax"]), -float(m["ay"]))
		spr.scale = Vector2(k, k)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		## Zemin: yaratıklar ve harita z 0 - aynı z'de sonradan eklenen sayfa yaratıkların ÜSTÜNE çiziliyordu, z -1 ise haritanın
		## ALTINDA kalıp hiç görünmedi. Doğrusu z 0 + sahne sırasında "Harita"nın hemen arkası (haritanın üstü, yaratıkların altı).
		spr.z_index = 0 if layer == "ground" else 50
		if str(m.get("blend", "mix")) == "add": ## A4: toplamalı ışık (renk zemine eklenir)
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			spr.material = mat
		current_scene.add_child(spr)
		if layer == "ground":
			var map_node: Node = current_scene.get_node_or_null("Harita")
			if map_node:
				current_scene.move_child(spr, map_node.get_index() + 1)
		spr.global_position = at
		spr.animation_finished.connect(spr.queue_free)
		spr.play(&"fx")


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
	_player.set_meta("ap_origin", o)
	for i in MOBS.size():
		var ps: PackedScene = load("res://scenes/creatures/enemy_%s.tscn" % ROSTER[i])
		var e: Node2D = ps.instantiate()
		e.set("speed", 0.0)
		e.set("max_health", 1.0e9)
		_main.add_child(e)
		e.global_position = o + MOBS[i]
		e.set("health", 1.0e9)
		_mobs.append(e)


func _run() -> void:
	await process_frame
	var only: String = OS.get_environment("AP_CODES")
	_codes = (only if only != "" else "now,A,B,C,D").split(",")
	for code in _codes:
		if code != "now":
			_load_sheets(code)
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
		intro.call("_set_phase", 3, 0.0) ## açılış (huzur + geri sayım) bitmiş say - tools/buyuk_test/mp_clutter.gd ile aynı
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
		atmo.call("debug_set_time", 420.0 if OS.get_environment("AP_NIGHT") == "1" else 150.0)
		atmo.call("debug_set_weather", 0)
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	_player = _main.get_node("Player")
	_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	_player.set("level", 10)
	_player.set("item_shield_max", 5000.0)
	_player.set("item_shield_hp", 5000.0)
	if OS.get_environment("AP_EVO") != "0": ## AP_EVO=0: evrimsiz temel Arcane Lanet (patlama yok, yalnız çarpma efekti)
		(_player.get("skill_evolutions") as Dictionary)["buyucu_e1"] = true
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.6)
	_spawn_mobs()
	RenderingServer.frame_pre_draw.connect(_pre_draw)
	await _wait(1.5)
	## Kırpma (1920 genişliğine göre ekran pikseli, oyuncunun ekran konumuna göre): 1 dünya birimi = 2,25 px.
	var rel := Rect2i(-100, -300, 1040, 600)
	Engine.time_scale = SLOW
	for code in _codes:
		_code = code
		_blasts[code] = []
		_hits[code] = []
		(_player.get("_buyucu_variation_cooldowns") as Array)[0] = 0.0
		_player.set("item_shield_hp", 5000.0)
		await _wait(0.8)
		var times: Array = []
		_t0 = Time.get_ticks_msec()
		var idx: int = 0
		idx = await _grab_for(code, PRE_ROLL, idx, rel, times)
		_marks[code] = idx
		_player.call("_buyucu_try_activate_variation")
		idx = await _grab_for(code, POST, idx, rel, times)
		_times[code] = times
		print("SHOT ", code, " kare=", idx, " patlama=", (_blasts[code] as Array).size())
		await _wait(0.8)
	Engine.time_scale = 1.0
	var fa := FileAccess.open(_dir.path_join("zamanlar.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify({"times": _times, "marks": _marks, "blasts": _blasts, "hits": _hits, "crop": [rel.position.x, rel.position.y, rel.size.x, rel.size.y]}))
	fa.close()
	print("BITTI")
	quit()
