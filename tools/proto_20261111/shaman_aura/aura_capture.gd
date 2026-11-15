extends SceneTree

## PROTOTİP yakalama (oyuna bağlı DEĞİL): Shaman E (Kalkan Totemi) AURA SINIRI A-D, GERÇEK OYUNDA (Main, ana harita, evin önündeki
## çayır, gündüz; HUD gizli). Shaman gerçek E'yi diker (_skill_shaman_shield_totem: gerçek rün taşı + gerçek kalkan şeritleri), sınır
## düğümü (aura_variant.gd) taşın kardeşi olarak zemin yuvasına eklenir. Sahne: alanın içinde duran Elara kuklası (şeritli), dışarıdan
## yürüyüp sınırı geçen Büyücü Kız kuklası (içeri girince şerit bağlanır = sınırın anlamı), Shaman taşın yanında.
## Kareler AU_DIR'e (15 fps): <kod>_g_NNN.png (bütün daire, x0,45 küçültülmüş), <kod>_y_NNN.png (geçiş noktası yakın, 1:1),
## <kod>_tam_acilis.png / _tam_dongu.png (bütün daire 1:1), gece_<kod>.png; olcu.json. AU_MOBS=n: E'den önce alana n yaratık.
## Koşturucu: aura_run.ps1 (gizli masaüstü, APPDATA yalıtılır). Birleştirme: aura_gif.py.
## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME (load() çalışma anında).

const VARIANT_SCRIPT := "res://tools/proto_20261111/shaman_aura/aura_variant.gd"
const CODE_INDEX := {"A": 0, "B": 1, "C": 2, "D": 3, "OYUN": -1}
const LOOP_END := 5.4
const FADE_AT := 4.8
const WALK_FROM := 0.9
const WALK_TO := 3.0
const OVERVIEW_K := 0.45
## Dünya düzeni (taşa göre)
const SHAMAN_OFF := Vector2(58, 22)
const ALLY_IN := Vector2(118, -84)
## Büyücü Kız sağ alttaki açık çimenden çapraz yürüyüp sınırı geçer (geçiş ~ (165, 146); sol taraf büyük ağacın arkasında kalıyordu)
const WALK_A := Vector2(262, 232)
const WALK_B := Vector2(130, 118)
const WALK_ANIM := "walk_left"
const IDLE_ANIM := "idle_left"
## Yakın kırpma (taşa göre dünya): geçiş noktası + yürüyüşün başı/sonu
const CLOSE := Rect2(100.0, 62.0, 200.0, 190.0)
const RING_MARGIN := 34.0

var _dir: String = OS.get_environment("AU_DIR")
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _ally_in: Node2D = null
var _walker: Node2D = null
var _measure: Dictionary = {}
var _mobs: int = int(OS.get_environment("AU_MOBS")) if OS.get_environment("AU_MOBS") != "" else 0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _xf() -> Transform2D:
	return root.get_final_transform() * root.get_canvas_transform()


func _rect_on_screen(img: Image, world: Rect2) -> Rect2i:
	var a: Vector2 = _xf() * world.position
	var b: Vector2 = _xf() * world.end
	return Rect2i(Vector2i(a.round()), Vector2i((b - a).round())).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))


func _ring_rect(c: Vector2, r: float) -> Rect2:
	var h: float = r + RING_MARGIN
	return Rect2(c - Vector2(h, h), Vector2(h, h) * 2.0)


func _kukla(peer: int, char_id: int, nm: String, pos: Vector2) -> Node2D:
	var k: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	_main.add_child(k)
	k.call("setup", peer, char_id, nm)
	k.call("snap_to_network_position", pos)
	return k


func _hide_hud() -> void:
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false


func _new_totem() -> Node2D:
	var seen: Array = get_nodes_in_group("shaman_totems")
	_player.call("_skill_shaman_shield_totem")
	for t in get_nodes_in_group("shaman_totems"):
		if not seen.has(t) and t is Node2D:
			return t
	return null


## "OYUN" = oyuna alınan gerçek sınır (totem_aura_border.gd, totemin kendisi kurar) - prototip eklenmez. Diğer kodlarda gerçek sınır
## silinir ve yerine prototip düğümü konur.
func _attach(code: String, totem: Node2D) -> Node2D:
	var real: Variant = totem.call("aura_border") if totem.has_method("aura_border") else null
	if code == "OYUN":
		return null
	if real is Node:
		(real as Node).queue_free()
	var n := Node2D.new()
	n.set_script(load(VARIANT_SCRIPT))
	n.set("variant", int(CODE_INDEX[code]))
	n.set("totem", totem)
	(load(VARIANT_SCRIPT) as GDScript).call("place_in_map", n, _main)
	return n


func _place_player(pos: Vector2) -> void:
	_player.global_position = pos
	if _player.has_method("reset_physics_interpolation"):
		_player.call("reset_physics_interpolation")


func _spawn_mobs(center: Vector2, n: int) -> void:
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner == null or n <= 0:
		return
	var rosters: Dictionary = (spawner.get_script() as GDScript).get_script_constant_map().get("TIER_ROSTER", {})
	var roster: Array = Array(rosters.get(4, rosters.get(1, ["slime1"])))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in n:
		var before: Array = get_nodes_in_group("enemies")
		spawner.call("debug_spawn_creature", roster[i % roster.size()], 4, 1, center)
		for e in get_nodes_in_group("enemies"):
			if before.has(e) or not (e is Node2D):
				continue
			var ang: float = TAU * float(i) / float(n) + rng.randf_range(-0.3, 0.3)
			var rr: float = rng.randf_range(150.0, 260.0)
			(e as Node2D).global_position = center + Vector2(cos(ang) * rr, sin(ang) * rr)
			e.set("max_health", 1.0e6)
			e.set("health", 1.0e6)


func _shot_frames(code: String, idx: int, c: Vector2, r: float) -> void:
	var img: Image = root.get_texture().get_image()
	var g: Image = img.get_region(_rect_on_screen(img, _ring_rect(c, r)))
	g.resize(int(round(g.get_width() * OVERVIEW_K)), int(round(g.get_height() * OVERVIEW_K)), Image.INTERPOLATE_LANCZOS)
	g.save_png(_dir.path_join("%s_g_%03d.png" % [code, idx]))
	img.get_region(_rect_on_screen(img, Rect2(c + CLOSE.position, CLOSE.size))).save_png(_dir.path_join("%s_y_%03d.png" % [code, idx]))


func _shot_full(name: String, c: Vector2, r: float) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.get_region(_rect_on_screen(img, _ring_rect(c, r))).save_png(_dir.path_join(name))


func _run() -> void:
	await process_frame
	var only: String = OS.get_environment("AU_CODES")
	var codes: PackedStringArray = (only if only != "" else "A,B,C,D").split(",")
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_char_id", 12)
	_gm.set("selected_character", chars.get_def(12).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	## Seyyar satıcı çekim sırasında gelip sahneye (araba + koruma alanı kubbesi) karışmasın; ayrıca koruma alanında totem durur.
	(load("res://scripts/shops_flag.gd") as GDScript).call("set_merchant_enabled", false)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene as Node2D
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
		spawner.set_process(false)
		spawner.set_physics_process(false)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	_player = _main.get_node("Player")
	if OS.get_environment("HARITA") == "":
		_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	_hide_hud()
	await _wait(1.0)
	var home: Vector2 = _player.global_position
	_ally_in = _kukla(902, 8, "Elara", home + ALLY_IN)
	_walker = _kukla(903, 4, "Büyücü Kız", home + WALK_A)
	await _wait(1.2)
	_measure["canvas_scale"] = _xf().get_scale().x
	_measure["window"] = [root.get_texture().get_image().get_width(), root.get_texture().get_image().get_height()]
	## Shader'ı ısıt (ilk kullanımda derleme takılmasıyla açılış kareleri boş çıkmasın): alfa 0 ile bir kez çiz.
	var warm := Node2D.new()
	warm.set_script(load(VARIANT_SCRIPT))
	warm.set("totem", _player)
	(load(VARIANT_SCRIPT) as GDScript).call("place_in_map", warm, _main)
	warm.set("modulate", Color(1, 1, 1, 0.004))
	await _wait(0.5)
	warm.queue_free()
	for code in codes:
		_hide_hud()
		for e in get_nodes_in_group("enemies"):
			if e is Node and is_instance_valid(e):
				(e as Node).queue_free()
		_place_player(home)
		_walker.call("snap_to_network_position", home + WALK_A)
		_walker.call("update_position_and_anim_from_net", home + WALK_A, IDLE_ANIM)
		_ally_in.call("update_position_and_anim_from_net", home + ALLY_IN, "idle_left")
		await _wait(0.8)
		var totem: Node2D = _new_totem()
		if totem == null:
			print("ERROR totem dogmadi ", code)
			continue
		var c: Vector2 = totem.global_position
		if _mobs > 0:
			_spawn_mobs(c, _mobs)
		_place_player(home + SHAMAN_OFF)
		var node: Node2D = _attach(code, totem)
		var r: float = float(totem.get("totem_radius"))
		_measure["radius"] = r
		## --fixed-fps 30: süre KARE SAYACINDAN (yakalama yavaş olsa da oyun saati kare başı 1/30 sn; her 2. kare kaydedilir = 15 fps)
		var f0: int = Engine.get_process_frames()
		var idx: int = 0
		var stopped: bool = false
		var took_open: bool = false
		var took_loop: bool = false
		while true:
			await RenderingServer.frame_post_draw
			var fr: int = Engine.get_process_frames() - f0
			var rel: float = float(fr) / 30.0
			if rel > LOOP_END:
				break
			## Büyücü Kız soldan yürüyüp sınırı geçer (ağ kuklası: hedef konum + yürüme klibi, kendisi yumuşatır)
			if rel >= WALK_FROM and rel <= WALK_TO + 0.1:
				var k: float = clampf((rel - WALK_FROM) / (WALK_TO - WALK_FROM), 0.0, 1.0)
				_walker.call("update_position_and_anim_from_net", (home + WALK_A).lerp(home + WALK_B, k), WALK_ANIM if k < 1.0 else IDLE_ANIM)
			if not stopped and rel >= FADE_AT:
				stopped = true
				if is_instance_valid(node):
					node.call("stop")
				elif code == "OYUN" and is_instance_valid(totem):
					totem.call("_on_expire") ## gerçek süre dolumu: çöküş tozu + sınır kendiliğinden söner
			if fr % 2 != 0:
				continue
			_shot_frames(code, idx, c, r)
			idx += 1
			if not took_open and rel >= 0.22:
				took_open = true
				await _shot_full("%s_tam_acilis.png" % code, c, r)
			if not took_loop and rel >= 3.9:
				took_loop = true
				await _shot_full("%s_tam_dongu.png" % code, c, r)
		_measure["frames_" + code] = idx
		print("SHOT ", code, " kare=", idx)
		if is_instance_valid(node):
			node.queue_free()
		if is_instance_valid(totem):
			totem.queue_free()
		for e in get_nodes_in_group("enemies"):
			if e is Node and is_instance_valid(e):
				(e as Node).queue_free()
		await _wait(0.6)
	## Gece: aynı sahnenin tek karesi (sınır gece zemin gibi kararır mı)
	if atmo and OS.get_environment("AU_NIGHT") != "0":
		atmo.call("debug_set_time", 420.0)
		await _wait(1.5)
		for code in codes:
			_hide_hud()
			_place_player(home)
			_walker.call("snap_to_network_position", home + WALK_B)
			await _wait(0.4)
			var totem2: Node2D = _new_totem()
			if totem2 == null:
				continue
			_place_player(home + SHAMAN_OFF)
			var n2: Node2D = _attach(code, totem2)
			await _wait(1.6)
			await _shot_full("gece_%s.png" % code, totem2.global_position, float(totem2.get("totem_radius")))
			if is_instance_valid(n2):
				n2.queue_free()
			totem2.queue_free()
			await _wait(0.5)
	var fm := FileAccess.open(_dir.path_join("olcu.json"), FileAccess.WRITE)
	fm.store_string(JSON.stringify(_measure, "  "))
	fm.close()
	print("OLCU ", JSON.stringify(_measure))
	print("BITTI")
	quit()
