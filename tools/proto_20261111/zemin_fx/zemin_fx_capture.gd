extends SceneTree

## Yakın dövüş ZEMİN efektleri görünüyor mu? (2026-11-11, madde 573) - Topuz "Yer Sarsıntısı" (fx_topuz_slam_ground), Tırpan "Kara Hasat"
## (fx_tirpan_ground), Kalkan "Hayalet Kalkan" kırık halkası (fx_kalkan_ring). Oyun koduna dokunulmaz: silah satın alınır, ölümsüz sabit
## yaratık menzile konur, silah kendiliğinden vurur. Zemin efekti doğunca (sahne kökünün yeni çocuğu, scene_file_path) oyun zamanı
## neredeyse durdurulur ve AYNI karede üç görüntü alınır: A efekt açık, B efekt gizli, C yine gizli (gürültü tabanı: su/çimen
## shader'ları TIME ile oynamaya devam eder). "katkı" = A ile B arasında değişen piksel, "gürültü" = B ile C arası. Katkı ~ gürültü ise
## efekt EKRANDA YOK demektir. Ayrıca efektin z'si ve sahne kökündeki sırası ("Harita"nın sırasına göre) yazılır.
## Kareler ZF_DIR'e: <silah>_A.png / _B.png (efekt çevresi kırpılmış). Koşturucu zemin_fx_run.ps1 (gizli masaüstü, APPDATA yalıtılır).
## ZF_OLD=1: düzeltme öncesi yerleşimi taklit eder (kökün sonu + z -1) - aynı karede önce/sonra kıyası için. ZF_AT: animasyon oranı.

## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.
const WEAPONS: Array = [
	["topuz", "res://scenes/fx_topuz_slam_ground.tscn"],
	["pence", "res://scenes/fx_tirpan_ground.tscn"],
	["kalkan", "res://scenes/fx_kalkan_ring.tscn"],
]
const DUMMY_OFFSET := Vector2(58.0, 12.0)
const CROP := Vector2i(420, 300) ## ekran pikseli (1920 genişliğine göre), efektin ekran konumu ortada
const DIFF_T := 10 ## 0-255, kanal farkı bundan büyükse "değişti"
const FREEZE := 0.0005

var _dir: String = OS.get_environment("ZF_DIR")
var _gm: Node = null
var _main: Node2D = null
var _player: Node2D = null
var _dummy: Node2D = null
var _dummy_at: Vector2 = Vector2.ZERO
var _seen: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _pin_dummy() -> void:
	if _dummy != null and is_instance_valid(_dummy) and _dummy.global_position.distance_to(_dummy_at) > 0.5:
		if _dummy.has_method("teleport_to"):
			_dummy.call("teleport_to", _dummy_at)
		else:
			_dummy.global_position = _dummy_at


func _spawn_dummy() -> void:
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()
	await _wait(0.2)
	var ps: PackedScene = load("res://scenes/creatures/enemy_slime1.tscn")
	_dummy = ps.instantiate()
	_dummy.set("speed", 0.0)
	_dummy.set("max_health", 1.0e9)
	_main.add_child(_dummy)
	_dummy_at = _player.global_position + DUMMY_OFFSET
	_dummy.global_position = _dummy_at
	_dummy.set("health", 1.0e9)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _crop(img: Image, world: Vector2) -> Image:
	var k: float = float(img.get_width()) / 1920.0
	var c: Vector2 = (_player.get_viewport().get_canvas_transform() * world) * k
	var w: int = int(CROP.x * k)
	var h: int = int(CROP.y * k)
	var r := Rect2i(int(c.x) - w / 2, int(c.y) - h / 2, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	return img.get_region(r)


func _diff(a: Image, b: Image) -> int:
	var n: int = 0
	var w: int = mini(a.get_width(), b.get_width())
	var h: int = mini(a.get_height(), b.get_height())
	for y in range(h):
		for x in range(w):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) * 255.0 > float(DIFF_T):
				n += 1
	return n


## Sahne kökünün yeni çocukları arasında bu sahneden doğmuş ilk efekt.
func _find_new(path: String) -> Node2D:
	for c in current_scene.get_children():
		var id: int = c.get_instance_id()
		if _seen.has(id):
			continue
		_seen[id] = true
		if c.scene_file_path == path:
			return c as Node2D
	return null


func _one(key: String, path: String) -> void:
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.3)
	for c in current_scene.get_children(): ## önceki silahın efektleri sayılmasın
		_seen[c.get_instance_id()] = true
	await _spawn_dummy()
	if not bool(_player.call("buy_weapon_copy", key, 1)):
		print("ZF FAIL %s buy_weapon_copy" % key)
		return
	var fx: Node2D = null
	var t0: int = Time.get_ticks_msec()
	while fx == null and Time.get_ticks_msec() - t0 < 12000:
		await process_frame
		_pin_dummy()
		fx = _find_new(path)
	if fx == null:
		print("ZF FAIL %s zemin efekti doğmadı" % key)
		return
	if OS.get_environment("ZF_OLD") == "1": ## madde 573 öncesi yerleşimi taklit: sahne kökünün SONU + z -1 (eski add_child + tscn z -1)
		fx.z_index = -1
		current_scene.move_child(fx, -1)
	## efekt animasyonun ortasına kadar oynasın (ilk karelerde küçük; ZF_AT: kare oranı, varsayılan 0,45)
	var spr: AnimatedSprite2D = fx as AnimatedSprite2D
	var at_ratio: float = float(OS.get_environment("ZF_AT")) if OS.get_environment("ZF_AT") != "" else 0.45
	var want: int = 2
	if spr != null and spr.sprite_frames != null:
		want = maxi(2, int(float(spr.sprite_frames.get_frame_count(spr.animation)) * at_ratio))
	var t1: int = Time.get_ticks_msec()
	while is_instance_valid(fx) and spr != null and spr.frame < want and Time.get_ticks_msec() - t1 < 1500:
		await process_frame
		_pin_dummy()
	if not is_instance_valid(fx):
		print("ZF FAIL %s efekt erken silindi" % key)
		return
	Engine.time_scale = FREEZE
	var harita: Node = current_scene.get_node_or_null("Harita")
	var at: Vector2 = fx.global_position
	var info: String = "z=%d mutlak=%d sira=%d harita_sirasi=%d cocuk=%d kare=%d" % [fx.z_index, _abs_z(fx), fx.get_index(),
		harita.get_index() if harita else -1, current_scene.get_child_count(), spr.frame if spr else -1]
	var dummy_idx: int = _dummy.get_index() if is_instance_valid(_dummy) else -1
	await _grab()
	var a: Image = _crop(await _grab(), at)
	(fx as CanvasItem).visible = false
	await _grab()
	var b: Image = _crop(await _grab(), at)
	var c2: Image = _crop(await _grab(), at)
	(fx as CanvasItem).visible = true
	Engine.time_scale = 1.0
	var contrib: int = _diff(a, b)
	var noise: int = _diff(b, c2)
	a.save_png(_dir.path_join("%s_A.png" % key))
	b.save_png(_dir.path_join("%s_B.png" % key))
	print("ZF %s katki=%d gurultu=%d | %s yaratik_sirasi=%d oyuncu_sirasi=%d" % [key, contrib, noise, info, dummy_idx, _player.get_index()])
	await _wait(0.5)


func _abs_z(n: Node) -> int:
	var z: int = 0
	var cur: Node = n
	while cur != null:
		if cur is CanvasItem:
			z += (cur as CanvasItem).z_index
			if not (cur as CanvasItem).z_as_relative:
				break
		cur = cur.get_parent()
	return z


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_char_id", 2)
	_gm.set("selected_character", chars.get_def(2).get("skill", 1))
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
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
	for c in _main.get_children(): ## bildirim levhaları
		if c is CanvasLayer and (c as CanvasLayer).layer >= 100:
			(c as CanvasLayer).visible = false
	_player = _main.get_node("Player")
	_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	_player.set("level", 10)
	await _wait(0.6)
	var only: String = OS.get_environment("ZF_WEAPONS")
	for w in WEAPONS:
		if only != "" and not (only.split(",") as Array).has(w[0]):
			continue
		await _one(str(w[0]), str(w[1]))
	print("BITTI")
	quit()
