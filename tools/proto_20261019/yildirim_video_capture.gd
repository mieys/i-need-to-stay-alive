extends SceneTree

## Yıldırım Asası vuruş sesi VİDEOSU (2026-10-19, madde 294): GERÇEK main'de Matthew (id 3) yalnız Yıldırım Asası ile, çevresinde 4 sabit
## slime; Godot Movie Maker (--write-movie, sabit 60 kare/sn) görüntü + oyun sesini AVI'ye yazar. Işın uğultusu (fx_lightning_beam Sfx) ve
## oyuncunun ortak ateş sesi (FireSound) SUSTURULUR - dört ses sürümü (şimdiki / A / B / C) sonradan yildirim_video.py'de AYNI görüntünün
## üstüne bindirilir. Kilitlenme / tik / kritik / ışın sonu anları YV_DIR/olaylar.json'a (oyun karesi + hedefin ekran konumu) yazılır.
## Kaçıncı tikin kritik olacağını bu betik seçer (CRITS) ve her slime'ın kaç tikte öleceğini (TICKS_TO_KILL) ayarlar ki videoda hem kritik
## hem hedef değişimi görünsün. Master bus 0 dB (kullanıcı ayarından bağımsız; bindirilen sesler de Master seviyesinde eklenir).
## Koşturucu: tools/proto_20261019/yildirim_video_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

const CRITS := [3, 9, 15, 21] ## genel tik sırası (0'dan)
const TICKS_TO_KILL := [6, 6, 7, 6]
const OFFSETS := [Vector2(95, -35), Vector2(-110, 55), Vector2(-125, -25), Vector2(120, 45)]

var _dir: String = OS.get_environment("YV_DIR")
## YV_REAL=1: hiçbir şey susturulmaz - oyuna BAĞLANMIŞ sesler (madde 294) olduğu gibi kaydedilir (uçtan uca doğrulama).
var _real: bool = OS.get_environment("YV_REAL") == "1"
var _gm: Node = null
var _main: Node = null
var _w: Node = null
var _events: Array = []
var _rec_start: int = 0
var _tick_index: int = 0
var _ticks_on: Dictionary = {} ## slime instance id -> o slime'a atılan tik
var _kill_at: Dictionary = {} ## slime instance id -> öldüğü tik sayısı
var _tick_dmg: float = 1.0
var _beam_script: Script = load("res://scripts/fx_lightning_beam.gd")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _wait_frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _screen_off(pos: Vector2) -> Vector2:
	var vp: Viewport = root
	return vp.get_canvas_transform() * pos - vp.get_visible_rect().size * 0.5


func _log(kind: String, extra: Dictionary = {}) -> void:
	var ev := {"t": kind, "f": Engine.get_process_frames()}
	ev.merge(extra)
	_events.append(ev)
	print("EV ", ev)


func _slime(pos: Vector2, ticks: int) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", _tick_dmg * ticks)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", _tick_dmg * ticks)
	_kill_at[e.get_instance_id()] = ticks
	return e


func _on_node_added(n: Node) -> void:
	if n.get_script() != _beam_script:
		return
	## Uğultu _ready'de başlar -> ready sonrası susturulur (aynı karede, hiç ses çıkmadan).
	if not _real:
		n.ready.connect(_mute_beam.bind(n), CONNECT_ONE_SHOT)
	var target: Node2D = _w.get("_beam_target")
	_log("lock", {"id": n.get_instance_id(), "off": _off_arr(target)})
	## Hedef değişiminde eskisinin "end"i yenisinin "lock"undan SONRA (aynı kare, queue_free) gelir -> kimlikle eşlenir.
	n.tree_exiting.connect(_log.bind("end", {"id": n.get_instance_id()}), CONNECT_ONE_SHOT)


func _mute_beam(n: Node) -> void:
	var s: AudioStreamPlayer2D = n.get("sfx")
	if s:
		s.stop()


func _off_arr(target: Node2D) -> Array:
	if target == null or not is_instance_valid(target):
		return [0.0, 0.0]
	var o: Vector2 = _screen_off(target.global_position)
	return [o.x, o.y]


func _on_fired(_dir_v: Vector2) -> void:
	var target: Node2D = _w.get("_beam_target")
	var crit: bool = CRITS.has(_tick_index)
	_log("tick", {"i": _tick_index, "crit": crit, "off": _off_arr(target)})
	_tick_index += 1
	_w.set("crit_chance", 1.0 if CRITS.has(_tick_index) else 0.0) ## bir SONRAKİ tik
	if target and is_instance_valid(target):
		var id: int = target.get_instance_id()
		_ticks_on[id] = int(_ticks_on.get(id, 0)) + 1
		if int(_ticks_on[id]) >= int(_kill_at.get(id, 99)) - 1 and float(target.get("health")) > 0.0:
			target.set("health", minf(float(target.get("health")), _tick_dmg * 0.5)) ## sonraki tik kesin öldürsün


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 3)
	_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(3).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt yazılmaz (fps_micro._boot ile aynı)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_mute(0, false)
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
	var player: Node2D = _main.get_node("Player")
	var spot := Vector2(float(OS.get_environment("YV_X")) if OS.get_environment("YV_X") != "" else 3616.0,
			float(OS.get_environment("YV_Y")) if OS.get_environment("YV_Y") != "" else 2000.0)
	player.global_position = spot
	if not _real:
		(player.get("fire_sound") as AudioStreamPlayer2D).volume_db = -80.0
	for w in player.get("owned_weapon_nodes").duplicate():
		if is_instance_valid(w):
			w.queue_free()
	player.get("owned_weapon_nodes").clear()
	_gm.set("owned_weapons", [{"key": "lightning_staff", "level": 1}])
	if not player.call("buy_weapon_copy", "lightning_staff", 1):
		print("HATA silah verilemedi")
		quit(1)
		return
	_w = player.get("owned_weapon_nodes")[0]
	_w.set("crit_chance", 0.0)
	_w.connect("fired", _on_fired)
	await _wait(1.0)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(1.0)
	_tick_dmg = maxf(1.0, float(_w.get("damage")) * 0.33 * float(_w.get("rage_multiplier")))
	print("TIK HASARI ~", _tick_dmg)
	node_added.connect(_on_node_added)
	_rec_start = Engine.get_process_frames()
	var slimes: Array = []
	for i in range(OFFSETS.size()):
		slimes.append(_slime(spot + OFFSETS[i], TICKS_TO_KILL[i]))
	var guard: int = 0
	while guard < 60 * 25:
		guard += 1
		await process_frame
		var alive: int = 0
		for s in slimes:
			if is_instance_valid(s) and float(s.get("health")) > 0.0:
				alive += 1
		if alive == 0:
			break
	await _wait_frames(75)
	var end_f: int = Engine.get_process_frames()
	var vp: Vector2 = root.get_visible_rect().size
	var f := FileAccess.open(_dir.path_join("olaylar.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": 60, "rec_start": _rec_start, "end": end_f,
			"tick_dmg": _tick_dmg, "viewport": [vp.x, vp.y], "events": _events}, "\t"))
	f.close()
	print("BITTI kare ", _rec_start, " -> ", end_f, " tik ", _tick_index)
	quit()
