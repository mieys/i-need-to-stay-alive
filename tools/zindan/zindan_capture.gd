extends SceneTree

## ZİNDAN YAKALAMASI (madde 373): GERÇEK oyun (main.tscn) gizli masaüstünde - tools/zindan/zindan_run.ps1 çalıştırır.
## ZC_ID = zindan (kemik_mahzeni / et_kuyusu / boynuzlu_kapi), ZC_MODE = tur (girişten odalara çekimler) | kovala (avcı + sakinler) | dis (kapı ağzı).
## Çıktı: tools/zindan/out/oyun/<id>_<ad>.png + günlükte "ZC ..." satırları (bölge, engel, ışık, sakin sayıları, istem metni).
## Kullanıcı verisi yalıtılır (APPDATA geçici, debug bayrağı kayıt yolunu kapatır) - fps_micro.gd _boot ile aynı.

var _out: String = ProjectSettings.globalize_path("res://").path_join("tools/zindan/out/oyun")
var _gm: Node
var _main: Node
var _player: Node2D
var _dm: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name_s: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	var p: String = _out.path_join("%s.png" % name_s)
	img.save_png(p)
	print("ZC SHOT ", p)


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_out)
	var id: String = OS.get_environment("ZC_ID")
	if id == "":
		id = "kemik_mahzeni"
	var mode: String = OS.get_environment("ZC_MODE")
	if mode == "":
		mode = "tur"
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	for c in _gm.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("hitch_log.gd"):
			c.set_process(false)
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", int(OS.get_environment("ZC_CHAR")) if OS.get_environment("ZC_CHAR") != "" else 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(int(_gm.get("selected_char_id"))).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		print("ZC BOOTFAIL")
		quit(1)
		return
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(2.0)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	_gm.set("invasion_pending", false)
	_player = _main.get_node_or_null("Player") as Node2D
	_dm = _main.get_node_or_null("DungeonManager")
	if _dm == null or _player == null:
		print("ZC NODM")
		quit(1)
		return
	var dw: GDScript = load("res://scripts/dungeon/dungeon_world.gd")
	var e: Dictionary = dw.entry(id)
	print("ZC KAYIT dungeons=%d rect=%s duvar=%d nesne=%d" % [dw.dungeons().size(), str(e.get("rect", Rect2())), dw.wall_cells().size(), dw.solid_cells().size()])
	if e.is_empty():
		quit(1)
		return
	var tier: int = int(OS.get_environment("ZC_TIER")) if OS.get_environment("ZC_TIER") != "" else 4
	_gm.set("game_time", float(tier - 1) * 150.0 + 20.0)
	_gm.set("run_max_tier", tier)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo and OS.get_environment("ZC_HOUR") != "":
		atmo.call("debug_set_time", float(OS.get_environment("ZC_HOUR")))
	if mode == "dis":
		var gi: int = int(load("res://scripts/dungeon/dungeon_defs.gd").by_id(id)["gate"])
		var mouth: Vector2 = load("res://scripts/deep_forest_fx.gd").gate_mouth(gi)
		_player.global_position = mouth + Vector2(0, 40)
		_player.reset_physics_interpolation()
		await _wait(2.5)
		print("ZC ISTEM dis: '%s'" % str(_dm.call("debug_state")["prompt"]))
		await _shot("%s_dis" % id)
	if mode == "olcum":
		await _wait(3.5)  ## gizli ön kurulum (DungeonManager._warm_tick) bitsin: oyunda zindana dakikalar sonra gelinir
	var te0: int = Time.get_ticks_usec()
	_dm.call("_do_enter", id)
	print("ZC GIRIS_MS %.1f (sahne yükleme + kurulum)" % (float(Time.get_ticks_usec() - te0) / 1000.0))
	if mode == "olcum":
		await _frames("giris_ilk4sn", 4.0, Callable())
	else:
		await _wait(3.0)
	print("ZC GIRIS in_dungeon=%s poz=%s gorunur=%s" % [str(_player.get("in_dungeon")), str(_player.global_position), str(_dm.call("debug_state")["shown"])])
	var cam: Camera2D = root.get_viewport().get_camera_2d()
	print("ZC KAMERA limit=%d,%d,%d,%d" % [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom] if cam else "ZC KAMERA yok")
	## engel denetimi: giriş odasının duvarına yürüyemez
	var probe: Vector2 = _player.global_position + Vector2(0, -400)
	print("ZC ENGEL kuzey400=%s duvar_mi=%s" % [str(probe), str(_gm.call("is_position_blocked_by_walls", probe))])
	var world: Object = null
	var bridge: Node = _main.get_node_or_null("EnemyWorldBridge")
	if bridge:
		world = bridge.get("world")
	if world and world.has_method("get_region_of"):
		print("ZC BOLGE oyuncu=%d" % int(world.call("get_region_of", _player.global_position)))
	await _shot("%s_giris" % id)
	var data: Resource = e["data"]
	var shots: Array = []
	var seen_kinds: Dictionary = {}
	for o: Dictionary in data.objects:
		var t: String = str(o.get("type", ""))
		if t == "sakin":
			var prof: String = str((o.get("props", {}) as Dictionary).get("profil", ""))
			if seen_kinds.has(prof):
				continue
			seen_kinds[prof] = true
			shots.append(["oda_" + prof, (o["rect"] as Rect2).get_center()])
		elif t == "sunak" and not seen_kinds.has("sunak"):
			seen_kinds["sunak"] = true
			shots.append(["sunak", (o["rect"] as Rect2).get_center() + Vector2(0, 10)])
		elif t == "kapi" and not seen_kinds.has("kapi"):
			seen_kinds["kapi"] = true
			shots.append(["kapi", (o["rect"] as Rect2).get_center() + Vector2(0, 30)])
		elif t == "kaynak" and not seen_kinds.has("kaynak"):
			seen_kinds["kaynak"] = true
			shots.append(["kaynak", (o["rect"] as Rect2).get_center() + Vector2(0, 26)])
	var origin: Vector2 = (e["rect"] as Rect2).position
	if OS.get_environment("ZC_SKIP_TOUR") == "1":
		shots.clear()
	for s: Array in shots:
		_player.global_position = origin + (s[1] as Vector2)
		_player.reset_physics_interpolation()
		await _wait(1.6)
		var dm_state: Dictionary = _dm.call("debug_state")
		var near_enemies: int = 0
		for en: Node in get_nodes_in_group("enemies"):
			if is_instance_valid(en) and str(en.get_meta("dungeon", "")) == id:
				near_enemies += 1
		print("ZC CEKIM %s istem='%s' sakin=%d" % [s[0], str(dm_state["prompt"]), near_enemies])
		await _shot("%s_%s" % [id, s[0]])
	if mode == "olcum":
		await _measure(id, e)
	if mode == "kovala":
		await _chase_test(id, e)
	if mode == "etkilesim":
		await _interact_test(id, e)
	## çıkış
	_dm.call("_do_exit")
	await _wait(1.0)
	print("ZC CIKIS in_dungeon='%s' poz=%s" % [str(_player.get("in_dungeon")), str(_player.global_position)])
	print("ZC DONE")
	quit(0)


## FPS ÖLÇÜMÜ (ZC_MODE=olcum): odalarda + koridorda dur, kare sürelerini topla (ortalama / p95 / p99 / en kötü), çizim çağrısı, ışık ve
## uyanık sakin sayısı. ZC_OFF virgüllü kapatma listesi: isik (zindan PointLight2D'leri + fener), sakin (zindan yaratıkları + kamplar),
## su (Su katmanları), dekor (Eşya/Duvar süsü katmanları), minimap (keşif dokusu), sis (görüş sisi düğümü). ZC_STILL=1 yaratıklar oyuncuyu görmez.
func _measure(id: String, e: Dictionary) -> void:
	var off: PackedStringArray = OS.get_environment("ZC_OFF").split(",", false)
	var data: Resource = e["data"]
	var origin: Vector2 = (e["rect"] as Rect2).position
	var spots: Array = []
	var seen: Dictionary = {}
	for o: Dictionary in data.objects:
		if str(o.get("type", "")) != "sakin":
			continue
		var prof: String = str((o.get("props", {}) as Dictionary).get("profil", ""))
		if seen.has(prof) or spots.size() >= 4:
			continue
		seen[prof] = true
		spots.append([prof, origin + (o["rect"] as Rect2).get_center()])
	spots.push_front(["giris", _player.global_position])
	if OS.get_environment("ZC_STILL") == "1":
		_player.set("is_invisible", true)
	await _wait(2.0)
	_apply_off(id, off)
	if OS.get_environment("ZC_GATE") == "1":
		## KAPI: kapat -> 1 sn kare ölç (yol ızgarası + köprü yeniden yüklemesi), 9 sn sonra açılış anı
		var n_g: int = 0
		for o: Dictionary in data.objects_of("kapi"):
			if n_g >= 3:
				break
			n_g += 1
			_player.global_position = origin + (o["rect"] as Rect2).get_center() + Vector2(0, 48)
			_player.reset_physics_interpolation()
			await _wait(1.0)
			var gk: String = str(o["gate_key"])
			await _frames("kapi_kapan_%s" % gk, 1.0, func(): _dm.call("host_close_gate", gk))
			await _wait(7.5)
			await _frames("kapi_acil_%s" % gk, 2.5, Callable())
		return
	if OS.get_environment("ZC_FIGHT") == "1":
		## DÖVÜŞ: kalabalık odanın ortasında 8 sn dur (sakinler saldırır, silahlar ateş eder)
		for s2: Array in spots.slice(1):
			_player.global_position = s2[1]
			_player.reset_physics_interpolation()
			await _frames("dovus_%s" % s2[0], 8.0, Callable())
		return
	if OS.get_environment("ZC_WALK") == "1":
		## YÜRÜYÜŞ: girişten sırayla noktalara düz çizgide kare başına 2,5 px (duvar yok sayılır; kamera/ışık/minimap/sakin uyanması gerçek)
		for i in range(1, spots.size()):
			var a: Vector2 = spots[i - 1][1]
			var b: Vector2 = spots[i][1]
			var steps: int = int(a.distance_to(b) / 2.5)
			var k: Array = [0]
			_player.global_position = a
			_player.reset_physics_interpolation()
			await _frames("yuru_%s" % spots[i][0], float(steps) / 60.0, func():
				k[0] += 1
				_player.global_position = a.lerp(b, minf(1.0, float(k[0]) / float(maxi(1, steps)))))
		return
	for s: Array in spots:
		_player.global_position = s[1]
		_player.reset_physics_interpolation()
		await _wait(2.0)
		_apply_off(id, off)
		var ft: Array = []
		var proc: float = 0.0
		var draws: int = 0
		var t0: int = Time.get_ticks_usec()
		var last: int = t0
		var n: int = 0
		while Time.get_ticks_usec() - t0 < 4000000:
			_player.set("health", 100000.0)
			await process_frame
			var now: int = Time.get_ticks_usec()
			ft.append(float(now - last) / 1000.0)
			last = now
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			draws += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			n += 1
		ft.sort()
		var avg: float = 0.0
		for v: float in ft:
			avg += v
		avg /= maxf(1.0, ft.size())
		var lights: int = 0
		for l: Node in root.find_children("*", "PointLight2D", true, false):
			if (l as PointLight2D).enabled and (l as PointLight2D).is_visible_in_tree():
				lights += 1
		var awake: int = 0
		for en: Node in get_nodes_in_group("enemies"):
			if is_instance_valid(en) and str(en.get_meta("dungeon", "")) == id:
				awake += 1
		print("ZC OLCUM %s off=%s kare_ort=%.2f p95=%.2f p99=%.2f maks=%.1f islem=%.2f cizim=%d isik=%d sakin=%d" % [s[0], ",".join(off), avg,
				ft[int(ft.size() * 0.95)], ft[int(ft.size() * 0.99)], ft[ft.size() - 1], proc / maxf(1.0, n), draws / maxi(1, n), lights, awake])


## Kare süresi dizisi (Callable her karede çağrılır, ör. yürüyüş adımı) -> "ZC KARE ad ort p95 p99 maks + 20 ms üstü kare sayısı".
func _frames(label: String, sec: float, step: Callable) -> void:
	var ft: Array = []
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var worst_at: float = 0.0
	while Time.get_ticks_usec() - t0 < int(sec * 1000000.0):
		_player.set("health", 100000.0)
		if step.is_valid():
			step.call()
		await process_frame
		var now: int = Time.get_ticks_usec()
		var d: float = float(now - last) / 1000.0
		if ft.is_empty() or d > ft.max():
			worst_at = float(now - t0) / 1000000.0
		ft.append(d)
		last = now
	var sorted: Array = ft.duplicate()
	sorted.sort()
	var avg: float = 0.0
	var spikes: int = 0
	for v: float in ft:
		avg += v
		if v > 20.0:
			spikes += 1
	avg /= maxf(1.0, ft.size())
	print("ZC KARE %s n=%d ort=%.2f p95=%.2f p99=%.2f maks=%.1f (%.2f sn) >20ms=%d" % [label, ft.size(), avg, sorted[int(sorted.size() * 0.95)],
			sorted[int(sorted.size() * 0.99)], sorted[sorted.size() - 1], worst_at, spikes])


func _apply_off(id: String, off: PackedStringArray) -> void:
	var droot: Node = (_dm.get("_roots") as Dictionary).get(id)
	if "isik" in off:
		for l: Node in root.find_children("*", "PointLight2D", true, false):
			(l as PointLight2D).enabled = false
	if "sakin" in off:
		var gc: Node = _main.get_node_or_null("GuardCamps")
		if gc:
			gc.set_process(false)
			gc.set_physics_process(false)
		for en: Node in get_nodes_in_group("enemies"):
			if is_instance_valid(en) and str(en.get_meta("dungeon", "")) == id:
				en.queue_free()
	if droot != null:
		for c: Node in droot.find_children("*", "TileMapLayer", true, false):
			var nm: String = String(c.name)
			if ("su" in off and nm.begins_with("Su")) or ("dekor" in off and (nm.begins_with("Eşya") or nm == "Duvar süsü")):
				(c as CanvasItem).visible = false
	if "minimap" in off:
		_dm.set("_mm_acc", -1.0e9)
	if "sis" in off:
		for f: Node in root.find_children("*VisionFog*", "", true, false):
			if f is CanvasItem:
				(f as CanvasItem).visible = false
			f.set_process(false)


func _interact_test(id: String, e: Dictionary) -> void:
	var data: Resource = e["data"]
	var origin: Vector2 = (e["rect"] as Rect2).position
	## sakinleri uzaklaştır (çekimler temiz kalsın)
	for en: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(en) and str(en.get_meta("dungeon", "")) == id:
			en.queue_free()
	await _wait(0.3)
	var kinds: Dictionary = {}
	for o: Dictionary in data.objects:
		var t: String = str(o.get("type", ""))
		if t == "kapi":
			var st: String = str((o.get("props", {}) as Dictionary).get("stil", ""))
			if kinds.has(st):
				continue
			kinds[st] = true
			_player.global_position = origin + (o["rect"] as Rect2).get_center() + Vector2(0, 40 if st != "diken" and st != "barikat" and st != "kristal" else 0) + (Vector2(40, 0) if st in ["diken", "barikat", "kristal"] else Vector2.ZERO)
			_player.reset_physics_interpolation()
			await _wait(0.8)
			await _shot("%s_kapi_%s_acik" % [id, st])
			_dm.call("host_close_gate", str(o["gate_key"]))
			await _wait(1.0)
			print("ZC KAPI %s kapali=%s engel=%s" % [st, str(load("res://scripts/dungeon/dungeon_world.gd").is_gate_closed(str(o["gate_key"]))),
					str(_gm.call("is_position_blocked_by_walls", origin + (o["rect"] as Rect2).get_center()))])
			await _shot("%s_kapi_%s_kapali" % [id, st])
	var nodes: Array = data.objects_of("kaynak")
	if not nodes.is_empty():
		var o2: Dictionary = nodes[0]
		_player.global_position = origin + (o2["rect"] as Rect2).get_center() + Vector2(0, 30)
		_player.reset_physics_interpolation()
		await _wait(1.0)
		await _shot("%s_kaynak_dolu" % id)
		_dm.call("host_harvest", str(o2["node_key"]), 1)
		await _wait(1.2)
		var res: String = str(e["def"]["resource"])
		print("ZC KAYNAK %s = %d" % [res, int(_gm.call("get_dungeon_resource", res))])
		await _shot("%s_kaynak_bos" % id)
	var traps: Array = data.objects_of("tuzak")
	if not traps.is_empty():
		var o3: Dictionary = traps[0]
		_player.global_position = origin + (o3["rect"] as Rect2).get_center() + Vector2(60, 0)
		_player.reset_physics_interpolation()
		for k in range(3):
			await _wait(0.6)
			await _shot("%s_tuzak_%d" % [id, k])
	## minimap keşfi: odaları dolaş
	for o4: Dictionary in data.objects_of("sakin").slice(0, 6):
		_player.global_position = origin + (o4["rect"] as Rect2).get_center()
		_player.reset_physics_interpolation()
		await _wait(0.5)
	await _shot("%s_minimap" % id)
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	print("ZC FPS %.0f" % fps)


func _chase_test(id: String, e: Dictionary) -> void:
	var hunters: Array = []
	for en: Node in get_nodes_in_group("enemies"):
		if is_instance_valid(en) and en.has_meta("dungeon_hunter") and str(en.get_meta("dungeon", "")) == id:
			hunters.append(en)
	print("ZC AVCI sayi=%d" % hunters.size())
	if hunters.is_empty():
		return
	var h: Node2D = hunters[0]
	_player.global_position = h.global_position + Vector2(140, 0)
	_player.reset_physics_interpolation()
	await _wait(2.0)
	var gc: Node = _main.get_node_or_null("GuardCamps")
	print("ZC AVCI durum=%d mesafe=%.0f" % [int(gc.call("state_of", h)) if gc else -1, h.global_position.distance_to(_player.global_position)])
	await _shot("%s_avci" % id)
