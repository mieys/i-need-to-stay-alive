extends SceneTree

## XP kristali SADE prototipleri GERÇEK MAIN'de (2026-10-21, oyuna bağlı DEĞİL): çayırda oyuncunun sağına satır satır
## ŞU AN (gerçek xp_orb_frames.tres + xp_orb.gd nefes ölçeği) ve A-D (xp_sade_proto.py sayfaları) dizilir; her satırda
## 5 kademe ızgarası + sağında karışık bir "öldürme yığını". Kristaller Area2D değil düz AnimatedSprite2D (toplanmasın),
## gerçekteki gibi Harita'nın hemen üstüne taşınır (EnemyAbilities.place_on_ground), ölçek ORB_TEXEL 0,5.
## Çekimler (XS_DIR): gun_00..19.png (0,1 sn arayla, kırpılmış) + meta.json; XS_REAL=1 iken gerçek xp_orb.tscn satırı gercek_00..05.png (kırpma + satır y'leri).
## Koşturucu: tools/proto_20261021/xp_sade_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

const ROWS := ["SU AN", "A", "B", "C", "D"]
const VARIANTS := {"A": [1, 1.0], "B": [1, 1.0], "C": [16, 6.0], "D": [1, 1.0]} ## xp_sade_proto.py VARIANTS ile aynı
const COLORS := ["green", "blue", "purple", "yellow", "red"]
const ORB_TEXEL := 0.5
const COL_W := 18.0
const ROW_H := 21.0
## Öldürme yığını: (kademe, x, y) dünya birimi, ızgaranın sağında
const PILE := [[1, 0.0, 0.0], [1, 9.0, 4.0], [1, 3.0, 9.0], [2, 15.0, -2.0], [2, 20.0, 7.0], [1, 26.0, 1.0], [3, 12.0, 11.0], [4, 31.0, 8.0]]

var _dir: String = OS.get_environment("XS_DIR")
var _gm: Node = null
var _main: Node = null
var _pulsers: Array = [] ## [sprite, faz] - ŞU AN satırının nefes ölçeği


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		_tick_pulse()


## xp_orb.gd _process ile aynı: 1,0 .. 1,16 (PULSE_SPEED 3, PULSE_AMPLITUDE 0,08)
func _tick_pulse() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for p in _pulsers:
		var s: AnimatedSprite2D = p[0]
		var k: float = 1.0 + (sin((t + float(p[1])) * 3.0) * 0.5 + 0.5) * 2.0 * 0.08
		s.scale = Vector2(ORB_TEXEL, ORB_TEXEL) * k


func _frames_for(v: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var n: int = int(VARIANTS[v][0])
	for c in COLORS:
		var path: String = _dir.path_join("sheets/%s_%s.png" % [v, c])
		var tex := ImageTexture.create_from_image(Image.load_from_file(path))
		sf.add_animation(c)
		sf.set_animation_speed(c, float(VARIANTS[v][1]))
		sf.set_animation_loop(c, true)
		for f in n:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * 32, 0, 32, 32)
			sf.add_frame(c, at)
	return sf


func _orb(sf: SpriteFrames, tier: int, pos: Vector2, pulse: bool) -> void:
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.sprite_frames = sf
	s.scale = Vector2(ORB_TEXEL, ORB_TEXEL)
	_main.add_child(s)
	s.global_position = pos
	(load("res://scripts/enemy_abilities.gd") as GDScript).call("place_on_ground", self, s)
	var anim: String = COLORS[tier - 1]
	s.play(anim)
	s.frame = randi() % maxi(1, sf.get_frame_count(anim)) ## xp_orb.gd: hepsi aynı fazda parıldamasın
	if pulse:
		_pulsers.append([s, randf() * TAU])


func _shot(name: String, rect: Rect2i) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().get_region(rect).save_png(_dir.path_join("cap/" + name))


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_dir.path_join("cap"))
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 2)
	_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(2).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt yazılmaz (fps_micro._boot ile aynı)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene
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
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
		atmo.call("debug_set_time_scale", 0.0)
	var player: Node2D = _main.get_node("Player")
	var spot := Vector2(float(OS.get_environment("XS_X")) if OS.get_environment("XS_X") != "" else 3616.0,
			float(OS.get_environment("XS_Y")) if OS.get_environment("XS_Y") != "" else 2000.0)
	player.global_position = spot
	await _wait(1.0)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	for n in _main.get_children():
		if n is CanvasLayer:
			(n as CanvasLayer).visible = false
	if OS.get_environment("XS_WIDE") == "1": ## yer seçimi: kristalsiz tam ekran
		await _wait(0.5)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_dir.path_join("cap/genis.png"))
		print("BITTI")
		quit()
		return
	if OS.get_environment("XS_REAL") == "1": ## oyuna alınan sürüm: GERÇEK xp_orb.tscn (Area2D + xp_orb.gd), toplama menzili dışında
		await _real_row(player, spot)
		quit()
		return
	## Oyuncu yalnız ölçek için solda; kristaller sağında
	var origin := spot + Vector2(28.0, -2.0 * ROW_H)
	var cur: SpriteFrames = load("res://assets/pickups/xp_orb/xp_orb_frames.tres")
	for r in ROWS.size():
		var v: String = ROWS[r]
		var sf: SpriteFrames = cur if v == "SU AN" else _frames_for(v)
		var y: float = origin.y + r * ROW_H
		for t in 5:
			_orb(sf, t + 1, Vector2(origin.x + t * COL_W, y), v == "SU AN")
		for p in PILE:
			_orb(sf, int(p[0]), Vector2(origin.x + 5.0 * COL_W + 6.0 + float(p[1]), y - 5.0 + float(p[2]) * 0.6), v == "SU AN")
	await _wait(1.5)
	## Dünya -> ekran: kırpma = oyuncunun solundan yığının sağına, ilk satırın üstünden son satırın altına
	var xf: Transform2D = root.get_final_transform() * root.canvas_transform
	var tl: Vector2 = xf * (spot + Vector2(-22.0, -2.0 * ROW_H - 26.0))
	var br: Vector2 = xf * (Vector2(origin.x + 5.0 * COL_W + 50.0, origin.y + 4.0 * ROW_H + 16.0))
	var rect := Rect2i(Vector2i(tl.floor()), Vector2i((br - tl).ceil()))
	var rows_y: Array = []
	for r in ROWS.size():
		rows_y.append(int((xf * Vector2(0.0, origin.y + r * ROW_H)).y) - rect.position.y)
	var f := FileAccess.open(_dir.path_join("cap/meta.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "rows_y": rows_y,
			"zoom": xf.get_scale().x}))
	f.close()
	print("RECT ", rect, " zoom ", xf.get_scale())
	for i in 20:
		await _shot("gun_%02d.png" % i, rect)
		await _wait(0.1)
	print("BITTI")
	quit()


func _real_row(player: Node2D, spot: Vector2) -> void:
	var scene: PackedScene = load("res://scenes/xp_orb.tscn")
	var origin := spot + Vector2(28.0, 0.0)
	player.global_position = spot + Vector2(-150.0, 0.0)
	var placed: Array = []
	for t in 5:
		placed.append([t + 1, origin + Vector2(t * COL_W, 0.0)])
	for p in PILE:
		placed.append([int(p[0]), origin + Vector2(5.0 * COL_W + 6.0 + float(p[1]), -5.0 + float(p[2]) * 0.6)])
	var orbs: Array = []
	for e in placed:
		var o: Node2D = scene.instantiate()
		o.set("xp_tier", int(e[0]))
		_main.add_child(o)
		o.global_position = e[1]
		orbs.append(o)
	await _wait(1.5)
	var xf: Transform2D = root.get_final_transform() * root.canvas_transform
	var tl: Vector2 = xf * (origin + Vector2(-14.0, -18.0))
	var br: Vector2 = xf * (origin + Vector2(5.0 * COL_W + 50.0, 16.0))
	var rect := Rect2i(Vector2i(tl.floor()), Vector2i((br - tl).ceil()))
	for i in 6:
		await _shot("gercek_%02d.png" % i, rect)
		await _wait(0.15)
	var moved: int = 0
	for i in orbs.size():
		if not is_instance_valid(orbs[i]) or (orbs[i] as Node2D).global_position.distance_to(placed[i][1]) > 0.5:
			moved += 1
	var o0: Node2D = orbs[0]
	var spr: AnimatedSprite2D = o0.get_node("AnimatedSprite2D")
	print("GERCEK kure=", orbs.size(), " yer_degisen=", moved, " olcek=", spr.scale, " kare_sayisi=", spr.sprite_frames.get_frame_count(spr.animation),
			" process=", o0.is_processing())
	print("BITTI")
