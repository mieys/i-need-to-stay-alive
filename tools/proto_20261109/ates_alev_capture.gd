extends SceneTree

## ATEŞ ASASI YENİ ALEV PROTOTİPLERİ A-D gerçek oyunda (2026-11-09, kullanıcı: "eskisi iyi değil çok göz yoruyor").
## ates_alev_proto.py sayfaları (AC_SHEETS) mevcut alev düğümünün (fx_enchant_sprite "flame_fire") SpriteFrames'i yerine takılır;
## oyun koduna dokunulmaz, hasar/menzil/yön aynı. ŞU AN asada (z 9, karakterin üstünde); A-D efekt katmanında (sahne kökü, z 0 =
## oyuncuların altında, öbür efsun efektleri gibi) ve her karede asanın ucuna bağlanır.
## Kareler AC_DIR'e: <senaryo>_<kod>_<nn>.png (oyuncu çevresi kırpılmış, ~20 kare/sn) + zamanlar.json; birleştirme ates_alev_gif.py.
## Koşturucu: tools/proto_20261109/ates_alev_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME (fx_enchant_sprite NetworkManager'ı görmeyip bozuluyordu).
var WeaponTip: GDScript = null
const CODES := ["now", "A", "B", "C", "D"]
const NFRAMES := 24

var _dir: String = OS.get_environment("AC_DIR")
var _sheets: String = OS.get_environment("AC_SHEETS")
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _variant: String = "now"
var _frames: Dictionary = {}
var _meta: Dictionary = {}
var _tracked: Array = []
var _times: Dictionary = {}
var _keep: Array = [] ## sahnedeki tek yaratıklar: doğuş/kamp yaratığı girerse asa ona dönüyordu -> her karede silinir


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


func _load_sheet(code: String) -> void:
	var img: Image = Image.load_from_file(_sheets.path_join(code + ".png"))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_sheets.path_join(code + ".json")))
	var sf := SpriteFrames.new()
	sf.add_animation(&"loop")
	sf.set_animation_loop(&"loop", true)
	sf.set_animation_speed(&"loop", float(meta["fps"]))
	for i in int(meta["frames"]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * float(meta["w"]), 0, float(meta["w"]), float(meta["h"]))
		sf.add_frame(&"loop", at)
	_frames[code] = sf
	_meta[code] = meta


func _slime(pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", 1.0e9)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", 1.0e9)
	return e


func _set_weapons(keys: Array) -> void:
	for n in _player.get("owned_weapon_nodes"):
		if is_instance_valid(n):
			n.queue_free()
	(_player.get("owned_weapon_nodes") as Array).clear()
	(_gm.get("owned_weapons") as Array).clear()
	await process_frame
	for k in keys:
		## Defter (owned_weapons) silahtan ÖNCE yazılır - buy_weapon_copy özelliği (Ateş Nefesi) defterden takar.
		(_gm.get("owned_weapons") as Array).append((load("res://scripts/enchant_defs.gd") as GDScript).new_weapon_entry(k, 1, 0))
		print("buy ", k, " ", _player.call("buy_weapon_copy", k, 1))


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c.get_script() != null and str(c.get("sheet")) == "flame_fire" and not _tracked.has(c):
			_tracked.append(c)
		_collect(c)


## Her karede çizimden hemen önce (oyunun _process/_refresh'inden SONRA): seçili sayfayı tak, ölçek/ofset, katman ve asa ucu.
func _apply_variant() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_tracked = _tracked.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion())
	_collect(_player)
	for f in _tracked:
		var spr: AnimatedSprite2D = f.get("_spr") as AnimatedSprite2D
		if spr == null or _variant == "now":
			continue
		var sf: SpriteFrames = _frames[_variant]
		if spr.sprite_frames != sf:
			spr.sprite_frames = sf
			spr.play(&"loop")
		var m: Dictionary = _meta[_variant]
		var k: float = float(m["world_px"])
		spr.scale = Vector2(k, k)
		spr.offset = Vector2(float(m["w"]) * 0.5 - float(m["x0"]), float(m["h"]) * 0.5 - float(m["cy"]))
		spr.self_modulate = Color.WHITE
		if f.get_parent() != _main:
			f.reparent(_main, true)
		f.z_index = 0
		f.scale = Vector2.ONE
		var icon: Sprite2D = f.get("follow_icon") as Sprite2D
		if icon and is_instance_valid(icon):
			var fwd: float = float(f.get("follow_fwd_deg"))
			f.global_position = WeaponTip.tip_global(icon, fwd)
			var fr: float = deg_to_rad(fwd)   ## fx_enchant_sprite.icon_aim_angle ile aynı
			f.global_rotation = icon.global_rotation + ((PI - fr) if icon.flip_h else fr) + float(f.get("aim_rot_offset"))


func _grab(sc: String, code: String, rel: Rect2i) -> void:
	var times: Array = []
	var t0: int = Time.get_ticks_msec()
	var last: int = -1000
	var i: int = 0
	while i < NFRAMES:
		await RenderingServer.frame_post_draw
		_purge()
		var now: int = Time.get_ticks_msec()
		if now - last < 48:
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
		if code != "now":
			_load_sheet(code)
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
	RenderingServer.frame_pre_draw.connect(_apply_variant)
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
	## Açık zemin (evin çatısı alevi/yaratıkları örtmesin).
	_player.global_position += Vector2(-170.0, 100.0)
	var spot: Vector2 = _player.global_position
	await _wait(1.5)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	await _set_weapons(["fire_staff"])
	## Kırpma: oyuncunun ekran konumuna göre (2560x1440 pencere pikseli; 1 dünya birimi = 3 px).
	var scenarios: Array = [
		["sag", [Vector2(105.0, -8.0), Vector2(128.0, 26.0), Vector2(118.0, -44.0), Vector2(84.0, 22.0)], Rect2i(-200, -290, 640, 440)],
		## Hedef karakterin ALTINDA: asa karakterin ~55 birim üstünde, alev aşağı doğru karakterin üstünden geçer.
		["asagi", [Vector2(2.0, 46.0), Vector2(30.0, 64.0), Vector2(-26.0, 60.0), Vector2(6.0, 80.0)], Rect2i(-280, -270, 560, 540)],
	]
	for scd in scenarios:
		var sl: Array = []
		for off in scd[1]:
			sl.append(_slime(spot + off))
		_keep = sl.duplicate()
		_variant = "now"
		await _wait(2.0)
		for code in CODES:
			_variant = code
			await _wait(0.7)
			await _grab(scd[0], code, scd[2])
		for s in sl:
			if is_instance_valid(s):
				s.queue_free()
		_variant = "now"
		await _wait(1.0)
	var fa := FileAccess.open(_dir.path_join("zamanlar.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(_times))
	fa.close()
	print("BITTI")
	quit()
