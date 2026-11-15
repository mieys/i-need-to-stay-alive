extends SceneTree

## ATEŞ ASASI ALEV PROTOTİPLERİ 2. TUR A-D gerçek oyunda (2026-11-10). Dünkü ates_alev_capture.gd'nin kopyası + C "Yer Ateşi".
## ates_alev2_proto.py sayfaları (AC_SHEETS) mevcut alev düğümünün (fx_enchant_sprite "flame_fire") SpriteFrames'i yerine takılır;
## oyun koduna dokunulmaz, hasar/menzil/yön aynı. ŞU AN asada (z 9, karakterin üstünde); A-D efekt katmanında (sahne kökü, z 0 =
## oyuncuların altında) ve her karede asanın ucuna bağlanır.
## C: asadaki sayfa yalnız kısa namlu alevi; yerdeki alevcikler (C_alevcik.png) DÖNMEZ - koni içindeki sabit yuvalarda sırayla
## tutuşur (dışa doğru yürüyen dalga), doğduğu dünya noktasında kalır, ayak sırasına (y) göre dizilir.
## Kareler AC_DIR'e: <senaryo>_<kod>_<nn>.png + zamanlar.json; birleştirme ates_alev2_gif.py.
## Koşturucu: tools/proto_20261110/ates_alev2/ates_alev2_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.
var WeaponTip: GDScript = null
## AC_CODES="now" -> yalnız oyunun KENDİ efekti (madde 550 doğrulaması); AC_FINAL=1 -> asa Ejderha Nefesi (final) ile verilir.
var CODES: Array = Array(OS.get_environment("AC_CODES").split(",", false)) if OS.get_environment("AC_CODES") != "" else ["now", "A", "B", "C", "D"]
const NFRAMES := 24

## C yuvaları: [uzaklık (dünya birimi), açı (derece)] - koni 60 derece / 140 birim.
const FL_SLOTS := [
	[20.0, 0.0],
	[38.0, -9.0], [40.0, 10.0],
	[56.0, -15.0], [59.0, 3.0], [55.0, 17.0],
	[75.0, -20.0], [77.0, -5.0], [74.0, 9.0], [76.0, 22.0],
	[94.0, -22.0], [96.0, -8.0], [93.0, 6.0], [95.0, 20.0],
	[112.0, -17.0], [114.0, -2.0], [111.0, 14.0],
	[126.0, -9.0], [127.0, 8.0],
]
const FL_PERIOD := 1.25     ## yuva döngüsü (alevcik ömrü 10 kare / 12 fps = 0,83 sn)
const FL_TRAVEL := 0.45     ## dalganın namludan menzile varışı

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
var _spot: Vector2 = Vector2.ZERO
var _keep: Array = []
var _fl_root: Node2D = null
var _proxy_root: Node2D = null
var _proxy: AnimatedSprite2D = null
var _fl: Array = []          ## [Sprite2D, son döngü no]
var _fl_meta: Dictionary = {}


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


func _build_flamelets() -> void:
	_fl_meta = JSON.parse_string(FileAccess.get_file_as_string(_sheets.path_join("C_alevcik.json")))
	var tex: ImageTexture = ImageTexture.create_from_image(Image.load_from_file(_sheets.path_join("C_alevcik.png")))
	_proxy_root = Node2D.new()
	_proxy_root.z_index = 0
	_proxy_root.visible = false
	_main.add_child(_proxy_root)
	_proxy = AnimatedSprite2D.new()
	_proxy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_proxy_root.add_child(_proxy)
	_fl_root = Node2D.new()
	_fl_root.z_index = 0
	_main.add_child(_fl_root)
	var k: float = float(_fl_meta["world_px"])
	for i in FL_SLOTS.size():
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, float(_fl_meta["w"]), float(_fl_meta["h"]))
		s.offset = Vector2(float(_fl_meta["w"]) * 0.5 - float(_fl_meta["ax"]), float(_fl_meta["h"]) * 0.5 - float(_fl_meta["ay"]))
		s.scale = Vector2(k, k)
		s.flip_h = i % 3 == 1
		s.visible = false
		_fl_root.add_child(s)
		_fl.append([s, -1])


func _update_flamelets(tip: Vector2, aim: float) -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var fps: float = float(_fl_meta["fps"])
	var n: int = int(_fl_meta["frames"])
	for i in _fl.size():
		var s: Sprite2D = _fl[i][0]
		var slot: Array = FL_SLOTS[i]
		var delay: float = float(slot[0]) / 127.0 * FL_TRAVEL + (0.5 * FL_PERIOD if i % 2 == 1 else 0.0)
		var lt: float = now - delay
		var cyc: int = int(floor(lt / FL_PERIOD))
		var t: float = lt - float(cyc) * FL_PERIOD
		if cyc != int(_fl[i][1]):
			_fl[i][1] = cyc
			s.global_position = tip + Vector2(float(slot[0]), 0.0).rotated(aim + deg_to_rad(float(slot[1])))
		var fi: int = int(t * fps)
		s.visible = fi < n
		if s.visible:
			s.region_rect = Rect2(fi * float(_fl_meta["w"]), 0, float(_fl_meta["w"]), float(_fl_meta["h"]))
	var order: Array = _fl_root.get_children()
	order.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
	for j in order.size():
		_fl_root.move_child(order[j], j)


func _slime(pos: Vector2) -> Node2D:
	## AC_ENEMY=agac1 gibi: hedef yaratık türü (madde 551 yer alevi ayak hizası denetimi); varsayılan slime1.
	var kind: String = OS.get_environment("AC_ENEMY") if OS.get_environment("AC_ENEMY") != "" else "slime1"
	var e: Node2D = (load("res://scenes/creatures/enemy_%s.tscn" % kind) as PackedScene).instantiate()
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
		var entry: Dictionary = (load("res://scripts/enchant_defs.gd") as GDScript).new_weapon_entry(k, 1, 0)
		if OS.get_environment("AC_FINAL") == "1" and entry.has("enchant"):
			entry["enchant"]["final"] = true
		(_gm.get("owned_weapons") as Array).append(entry)
		print("buy ", k, " ", _player.call("buy_weapon_copy", k, 1))


func _collect(n: Node) -> void:
	for c in n.get_children():
		if c.get_script() != null and str(c.get("sheet")) == "flame_fire" and not _tracked.has(c):
			_tracked.append(c)
		_collect(c)


## Her karede çizimden hemen önce (oyunun _process/_refresh'inden SONRA).
## Oyunun alev düğümüne DOKUNULMAZ (yerinden oynatılırsa _live anahtarı düşer, her tikte yeni düğüm doğar, eskisi solarken
## üst üste iki alev görünür - dünkü çekimlerdeki "hayalet kopya" buydu). A-D için oyunun sprite'ı gizlenir, yerine sahne
## kökündeki (z 0 = oyuncuların altı) vekil sprite asa ucuna + bakış yönüne konur; saydamlığı oyunun düğümünden alınır.
func _apply_variant() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_tracked = _tracked.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion())
	_collect(_player)
	var shown: bool = false
	var fl_on: bool = false
	for f in _tracked:
		var spr: AnimatedSprite2D = f.get("_spr") as AnimatedSprite2D
		if spr == null:
			continue
		spr.visible = _variant == "now"
		if _variant == "now" or shown:
			continue
		var icon: Sprite2D = f.get("follow_icon") as Sprite2D
		if icon == null or not is_instance_valid(icon):
			continue
		shown = true
		var sf: SpriteFrames = _frames[_variant]
		if _proxy.sprite_frames != sf:
			_proxy.sprite_frames = sf
			_proxy.play(&"loop")
		var m: Dictionary = _meta[_variant]
		var k: float = float(m["world_px"])
		_proxy.scale = Vector2(k, k)
		_proxy.offset = Vector2(float(m["w"]) * 0.5 - float(m["x0"]), float(m["h"]) * 0.5 - float(m["cy"]))
		var fwd: float = float(f.get("follow_fwd_deg"))
		var fr: float = deg_to_rad(fwd)   ## fx_enchant_sprite.icon_aim_angle ile aynı
		_proxy_root.global_position = WeaponTip.tip_global(icon, fwd)
		_proxy_root.global_rotation = icon.global_rotation + ((PI - fr) if icon.flip_h else fr) + float(f.get("aim_rot_offset"))
		_proxy_root.modulate.a = f.modulate.a
		if _variant == "C":
			fl_on = true
			_update_flamelets(_proxy_root.global_position, _proxy_root.global_rotation)
	_proxy_root.visible = shown
	_fl_root.visible = fl_on


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
		## Madde 640 "donus": 3. karede hedef sağdan sol alta geçer -> asa döner, alevin bükülmesi çekilir.
		if sc == "donus" and i == 3:
			for old_e in _keep:
				if is_instance_valid(old_e):
					old_e.queue_free()
			_keep = [_slime(_spot + Vector2(-60.0, 100.0))]
	_times["%s_%s" % [sc, code]] = times
	print("SHOT ", sc, " ", code, " ", times[-1], " ms")
	print("DBG ", code, " alev dugumu=", _tracked.size())


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
	_build_flamelets()
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
	_spot = spot
	await _wait(1.5)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	await _set_weapons(["fire_staff"])
	## Kırpma: oyuncunun ekran konumuna göre (pencere pikseli).
	var scenarios: Array = [
		["sag", [Vector2(105.0, -8.0), Vector2(128.0, 26.0), Vector2(118.0, -44.0), Vector2(84.0, 22.0)], Rect2i(-200, -290, 640, 440)],
		## Madde 639: sola bakan flamethrower dikey aynalanır (bulut yine yukarıda).
		["donus", [Vector2(120.0, -20.0)], Rect2i(-320, -300, 640, 600)],
		["sol", [Vector2(-105.0, -8.0), Vector2(-128.0, 26.0), Vector2(-118.0, -44.0), Vector2(-84.0, 22.0)], Rect2i(-440, -290, 640, 440)],
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
			await _wait(1.6)
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
