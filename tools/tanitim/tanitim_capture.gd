extends SceneTree

## TANITIM VİDEOSU ÇEKİMİ (2026-11-08, kullanıcı: "oyunumu tanıtacak birkaç trailer, shorts/reels formatında"): GERÇEK main, DİKEY 1080x1920
## (kök viewport CONTENT_SCALE_MODE_VIEWPORT -> Movie Maker viewport dokusunu bu boyda yazar; pencere küçük kalır, ekrana sığar).
## Arayüz (HUD + menü katmanları) gizli, dünya + sis + atmosfer + hasar sayıları görünür; Music bus susturulur (boss müziği videoya girmesin).
## Godot Movie Maker (--write-movie, sabit kare/sn) her kareyi yazar; çekim ARALIKLARI (oyun karesi) TN_DIR/cekimler.json'a yazılır,
## kurgu tools/tanitim/kurgu.py bu aralıkları AVI'den keser (AVI karesi k <-> oyun karesi k + 1, yildirim_video.py ile aynı).
## Planlar (TN_PLAN): deneme (yakınlaştırma karşılaştırması) / dunya (ev açılışı, kuşatma, kalabalık, kademeler, bosslar) / kahraman (14 karakter Q + R).
## Koşturucu: tools/tanitim/cek.ps1 (gizli masaüstü, APPDATA yalıtılır). Oyun koduna dokunmaz.

const SPOT := Vector2(3616, 2000)
const NIGHT := 450.0
const DAY := 150.0
const DUSK := 352.0
const CHARS_ALL: Array = [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15]
const KEEP_LAYER_SCRIPTS: Array = ["atmosphere_overlay.gd", "vision_fog.gd", "sun_clouds.gd"]

var _dir: String = OS.get_environment("TN_DIR")
var _plan: String = OS.get_environment("TN_PLAN")
var _fps: int = int(OS.get_environment("TN_FPS")) if OS.get_environment("TN_FPS") != "" else 60
var _zoom: float = float(OS.get_environment("TN_ZOOM")) if OS.get_environment("TN_ZOOM") != "" else 2.5
var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _spawner: Node = null
var _shots: Array = []
var _cur: Dictionary = {}
var _target_crowd: int = 0
var _crowd_r: float = 520.0
var _roster: Array = []
var _tier: int = 1
var _walk: bool = false
var _walk_t: int = 0
var _walk_pattern: Array = ["move_right", "move_down", "move_left", "move_up"]
var _walk_period: int = 90
var _anchor: Vector2 = SPOT
var _leash: float = 160.0
var _merchant: Node = null
var _rec: bool = false
var _rec_dir: String = ""
var _rec_idx: int = 0


func _initialize() -> void:
	var w: int = int(OS.get_environment("TN_W")) if OS.get_environment("TN_W") != "" else 1080
	var h: int = int(OS.get_environment("TN_H")) if OS.get_environment("TN_H") != "" else 1920
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(w, h)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	_run.call_deferred()


func _hold(sec: float) -> void:
	for i in range(maxi(1, int(round(sec * float(_fps))))):
		await process_frame


func _log(s: String) -> void:
	print("TN ", s)


## GÖRÜNTÜ: Godot 4.7 Movie Maker film boyutunu açılıştaki pencereden alıp dikey kareyi 1920x1080'e KIRPIYOR (boyut_deneme.gd ile
## kanıtlandı) -> çekim sırasında her karede kök viewport dokusu (1080x1920) PNG olarak yazılır. Movie Maker yine sabit kare adımı
## (yavaş yazma oyunu bozmaz) + SES (AVI, oyun karesi k <-> AVI karesi k - 1) için çalışır.
func _begin(nm: String, extra: Dictionary = {}) -> void:
	_cur = {"name": nm, "a": Engine.get_process_frames()}
	_cur.merge(extra)
	_rec_dir = _dir.path_join("kareler").path_join(nm)
	DirAccess.make_dir_recursive_absolute(_rec_dir)
	_rec_idx = 0
	_rec = true
	_log(">> " + nm)


func _end() -> void:
	_rec = false
	_cur["b"] = Engine.get_process_frames()
	_cur["frames"] = _rec_idx
	_shots.append(_cur)
	_log("<< %s %d-%d (%d kare)" % [_cur["name"], _cur["a"], _cur["b"], _rec_idx])
	_cur = {}
	_save()


func _on_post_draw() -> void:
	if not _rec:
		return
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	if _rec_idx == 0:
		_cur["f0"] = Engine.get_process_frames() ## ilk PNG'nin oyun karesi (ses hizası)
	img.save_png(_rec_dir.path_join("%05d.png" % _rec_idx))
	_rec_idx += 1


func _save() -> void:
	var f := FileAccess.open(_dir.path_join("cekimler.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": _fps, "zoom": _zoom, "size": [root.content_scale_size.x, root.content_scale_size.y],
			"shots": _shots}, "\t"))
	f.close()


func _still(nm: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img and not img.is_empty():
		img.save_png(_dir.path_join(nm + ".png"))
		_log("still %s %s" % [nm, str(img.get_size())])


# ───────────────────────────── kare başı bakım ─────────────────────────────

func _on_frame() -> void:
	paused = false
	_hide_ui()
	_no_merchant()
	if _player == null or not is_instance_valid(_player):
		return
	_player.set("xp_to_next_level", 1.0e12)
	if _gm != null:
		_gm.set("team_xp_needed", 1.0e12)
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		cam = _player.get("death_camera") as Camera2D
	if cam != null and is_instance_valid(cam):
		cam.zoom = Vector2(_zoom, _zoom)
	if _target_crowd > 0 and _spawner != null and Engine.get_process_frames() % 6 == 0 and not _roster.is_empty():
		var near: int = 0
		var pp: Vector2 = _player.global_position
		for e in get_nodes_in_group("enemies"):
			if e is Node2D and (e as Node2D).global_position.distance_squared_to(pp) < 800.0 * 800.0:
				near += 1
		if near < _target_crowd:
			## Kadrajın hemen dışında (debug_spawn_creature 60-220 rastgele saçar -> halka o kadar dışarıda): içeride belirme olmasın.
			var rx: float = 540.0 / _zoom + 60.0
			var ry: float = 960.0 / _zoom + 60.0
			for i in mini(6, _target_crowd - near):
				for _try in range(6):
					var a: float = randf() * TAU
					var p: Vector2 = pp + Vector2(cos(a) * rx, sin(a) * ry)
					if _spawn_ok(p):
						_spawn_at(_roster[randi() % _roster.size()], _tier, p)
						break
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if _walk:
		_walk_t += 1
		var act: String = _walk_pattern[int(_walk_t / _walk_period) % _walk_pattern.size()]
		## Kayıp gitmesin: çapa noktasından uzaklaşınca ona doğru yürü.
		var d: Vector2 = _anchor - _player.global_position
		if d.length() > _leash:
			act = ("move_right" if d.x > 0.0 else "move_left") if absf(d.x) > absf(d.y) else ("move_down" if d.y > 0.0 else "move_up")
		Input.action_press(act)


## Seyyar satıcı gelmesin: güvenli bölgesi (madde 325) oyuncunun zamanını dondurur, bosslar giremez (ilk dünya çekiminin boss sahneleri bozuldu).
func _no_merchant() -> void:
	if _main == null or not is_instance_valid(_main) or Engine.get_process_frames() % 30 != 0:
		return
	if _merchant == null or not is_instance_valid(_merchant):
		_merchant = null
		for n in _main.find_children("*", "", true, false):
			var sc: Variant = n.get_script()
			if sc != null and str((sc as Script).resource_path).ends_with("traveling_merchant.gd"):
				_merchant = n
				break
	if _merchant != null:
		_merchant.set("_cooldown_timer", 1.0e9)


func _hide_ui() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	if Engine.get_process_frames() % 10 != 0:
		return
	for n in root.find_children("*", "CanvasLayer", true, false):
		var cl: CanvasLayer = n as CanvasLayer
		if cl.follow_viewport_enabled:
			continue
		var sc: Variant = cl.get_script()
		var keep: bool = false
		if sc != null:
			var p: String = str((sc as Script).resource_path)
			for k in KEEP_LAYER_SCRIPTS:
				if p.ends_with(k):
					keep = true
		if not keep and cl.visible:
			cl.visible = false


# ───────────────────────────── açılış ─────────────────────────────

func _boot(char_id: int, start_weapon: String, sky: float = DAY, exit_house: bool = true) -> bool:
	_target_crowd = 0
	_walk = false
	_player = null
	_main = null
	_merchant = null
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	for c in _gm.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("hitch_log.gd"):
			c.set_process(false)
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", char_id)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(char_id).get("skill", 1))
	_gm.set("selected_start_weapon", start_weapon)
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt (Ruh Kıymığı/rekor) yazılmasın
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	var mb: int = AudioServer.get_bus_index("Music")
	if mb >= 0:
		AudioServer.set_bus_mute(mb, true)
	AudioServer.set_bus_volume_db(0, 0.0)
	AudioServer.set_bus_mute(0, false)
	if not process_frame.is_connected(_on_frame):
		process_frame.connect(_on_frame)
	_player = _main.get_node_or_null("Player") as Node2D
	_spawner = _main.get_node_or_null("EnemySpawner")
	_sky(sky)
	## Yükleme katmanı kalkana kadar bekle (gerçek zaman: yükleme iş parçacığı).
	t0 = Time.get_ticks_msec()
	while get_first_node_in_group("loading_overlay") != null and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	await _hold(0.5)
	_sky(sky)
	if exit_house:
		await _leave_house()
	return _player != null


func _leave_house() -> void:
	var house: Node = _main.get_node_or_null("HouseInterior")
	Engine.time_scale = 4.0
	await _hold(1.0)
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	## Açılışın (huzur + deprem + geri sayım) sonuna kadar hızlı geç: deprem sarsıntısı çekime girmesin.
	var intro: Node = _main.find_child("HouseIntro", true, false)
	var t0: int = Engine.get_process_frames()
	while intro and is_instance_valid(intro) and int(intro.get("phase")) < 3 and Engine.get_process_frames() - t0 < _fps * 12:
		await process_frame
	await _hold(0.5)
	Engine.time_scale = 1.0
	if _spawner:
		_spawner.set("_spawn_timer", 1.0e9)


func _sky(t: float) -> void:
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", t)
		atmo.call("debug_set_weather", 0)


func _clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.queue_free()


func _arm(keys: Array, level: int) -> void:
	for k in keys:
		var ok: Variant = _player.call("buy_weapon_copy", k, level)
		_log("silah %s L%d -> %s" % [k, level, str(ok)])


func _teleport(p: Vector2) -> void:
	_player.global_position = p
	_anchor = p
	var cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()


func _crowd(tier: int, n: int) -> void:
	var scm: Dictionary = (_spawner.get_script() as GDScript).get_script_constant_map()
	var rosters: Dictionary = scm.get("TIER_ROSTER", {})
	_tier = tier
	_roster = Array(rosters.get(tier, rosters.get(1, [])))
	_gm.set("game_time", float(tier - 1) * 150.0 + 20.0)
	_spawner.set("_spawn_tier", tier)
	_target_crowd = n


func _press(slot: String) -> void:
	Input.action_press(slot)
	await process_frame
	await physics_frame
	await process_frame
	await process_frame
	Input.action_release(slot)


func _slot_ready(slot: String) -> void:
	var sv: Array = ["skill_state" if slot == "skill" else slot + "_state", "skill_timer" if slot == "skill" else slot + "_timer"]
	_player.set(sv[0], "ready")
	_player.set(sv[1], 0.0)
	_player.set("item_shield_max", 300.0)
	_player.set("item_shield_hp", 300.0)
	_player.set("necro_souls", 25)


# ───────────────────────────── planlar ─────────────────────────────

func _run() -> void:
	await process_frame
	match _plan:
		"deneme":
			await _plan_deneme()
		"dunya":
			await _plan_dunya()
		"kahraman":
			await _plan_kahraman()
		"boss":
			await _plan_boss()
		_:
			_log("HATA bilinmeyen plan " + _plan)
	_save()
	_log("BITTI")
	quit()


func _plan_deneme() -> void:
	if not await _boot(4, "fire_staff"):
		_log("HATA boot")
		return
	_arm(["gokkusagi", "lightning_staff"], 5)
	_player.set("level", 20)
	_teleport(SPOT)
	_crowd(5, 30)
	_walk = true
	await _hold(3.0)
	for z in [2.0, 2.5, 3.0]:
		_zoom = z
		_begin("z%d" % int(z * 10.0), {"zoom": z})
		await _hold(2.0)
		await _still("deneme_z%d" % int(z * 10.0))
		_end()


func _plan_dunya() -> void:
	var cid: int = int(OS.get_environment("TN_CHAR")) if OS.get_environment("TN_CHAR") != "" else 4
	## Açılış evin içinde, gece: huzur -> deprem (house_intro evreleri).
	if not await _boot(cid, "fire_staff", NIGHT, false):
		_log("HATA boot")
		return
	var intro: Node = _main.get_node_or_null("HouseIntro")
	if intro == null:
		intro = _main.find_child("HouseIntro", true, false)
	_log("intro faz %s" % str(intro.get("phase") if intro else -1))
	_zoom = 3.0
	var t0: int = Engine.get_process_frames()
	while intro and int(intro.get("phase")) < 1 and Engine.get_process_frames() - t0 < 60 * 30:
		await process_frame
	_begin("ev_huzur")
	t0 = Engine.get_process_frames()
	while intro and int(intro.get("phase")) < 2 and Engine.get_process_frames() - t0 < _fps * 10:
		await process_frame
	_end()
	_begin("ev_deprem")
	await _hold(5.5)
	_end()
	## Geri sayımın kalanı hızlı geçer; kuşatma başlayınca evin önünde.
	Engine.time_scale = 4.0
	t0 = Engine.get_process_frames()
	while intro and int(intro.get("phase")) < 3 and Engine.get_process_frames() - t0 < _fps * 30:
		await process_frame
	Engine.time_scale = 1.0
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _hold(0.3)
	_zoom = 2.5
	_player.set("level", 20)
	_arm(["gokkusagi", "lightning_staff", "uzunkilic"], 3)
	_sky(NIGHT)
	## (Kuşatma sahnesi ilk turda zayıf çıktı: ev önünde birkaç yaratık -> çekilmiyor.)
	if _spawner:
		_spawner.set("_spawn_timer", 1.0e9)
	_clear_enemies()
	## Kalabalık: gece + gündüz.
	_teleport(SPOT)
	_walk = true
	_sky(NIGHT)
	_crowd(8, 70)
	await _hold(5.0)
	_begin("kalabalik_gece")
	await _hold(7.0)
	_end()
	_clear_enemies()
	_sky(DUSK)
	_crowd(4, 50)
	await _hold(4.0)
	_begin("kalabalik_aksam")
	await _hold(6.0)
	_end()
	## Kademeler: az -> çok.
	for spec in [[1, 6], [5, 30], [10, 60], [15, 100]]:
		_clear_enemies()
		_sky(DAY if int(spec[0]) < 10 else NIGHT)
		_crowd(int(spec[0]), int(spec[1]))
		await _hold(4.0)
		_begin("kademe_%02d" % int(spec[0]), {"tier": spec[0], "n": spec[1]})
		await _hold(4.0)
		_end()
	await _boss_shots()


## Doğuş noktası oyunun kendi kuralıyla (enemy_spawner._mission_wave_spot): arazi (su/ev) + duvar (kaya, plato yamacı, ağaç gövdesi).
## Kullanıcı (2026-11-09): "yaratıklar duvarın altında kalmış" - debug_spawn_creature denetimsiz + 60-220 px saçıyordu, yerinden kıpırdamayan
## kum solucanları kaya duvarının / platonun içinde kaldı. Büyük gövdeler için noktanın çevresi de yoklanır.
func _spawn_ok(p: Vector2) -> bool:
	for o in [Vector2.ZERO, Vector2(18, 0), Vector2(-18, 0), Vector2(0, 14), Vector2(0, -14)]:
		var q: Vector2 = p + o
		if _gm.call("is_position_blocked_by_terrain", q) or _gm.call("is_position_blocked_by_walls", q):
			return false
	return true


## Sıradan yaratık TAM bu noktada (enemy_spawner'ın görev dalgasıyla aynı kurulum; çok oyunculuda istemcilere duyurulur).
func _spawn_at(id: String, tier: int, pos: Vector2) -> Node2D:
	var nid: int = int(_spawner.get("_next_network_enemy_id"))
	_spawner.set("_next_network_enemy_id", nid + 1)
	var e: Node2D = _spawner.call("_spawn_creature", id, pos, nid)
	if e == null:
		return null
	e.set_meta("spawn_tier", tier)
	if e.has_method("apply_tier_scaling"):
		e.call("apply_tier_scaling", tier)
	_spawner.call("_enable_regular_shield", e, tier)
	_spawner.call("_apply_global_buff", e)
	if root.get_node("NetworkManager").get("is_multiplayer_active"):
		_spawner.call("_announce_spawn", e, id, pos, tier, false, nid, false, false)
	return e


## Boss tam yerinde doğar (debug_spawn_creature 60-220 px saçıyordu, kadraj dışına düşüyordu): aynı kurulum, sabit konum.
func _spawn_boss(id: String, tier: int, pos: Vector2) -> Node2D:
	var nid: int = int(_spawner.get("_next_network_enemy_id"))
	_spawner.set("_next_network_enemy_id", nid + 1)
	var e: Node2D = _spawner.call("_spawn_creature", id, pos, nid)
	if e == null:
		_log("HATA boss doğmadı " + id)
		return null
	e.add_to_group("boss")
	_spawner.call("_setup_boss_enemy", e, id, tier)
	return e


func _boss_shots() -> void:
	_walk = false
	for spec in [["minotaur1", 3, DAY], ["underground1", 5, DAY], ["balkabagi1", 8, DUSK], ["wendigo1", 12, NIGHT], ["banshee1", 15, NIGHT], ["ucansetan1", 15, NIGHT]]:
		_target_crowd = 0
		_clear_enemies()
		for b in get_nodes_in_group("boss"):
			if is_instance_valid(b):
				b.queue_free()
		_teleport(SPOT)
		await _hold(0.4)
		_sky(float(spec[2]))
		_crowd(int(spec[1]), 10)
		_spawn_boss(str(spec[0]), int(spec[1]), SPOT + Vector2(0, -190))
		await _hold(1.2)
		_begin("boss_" + str(spec[0]), {"tier": spec[1]})
		await _hold(7.0)
		_end()
	_target_crowd = 0


func _plan_boss() -> void:
	if not await _boot(4, "fire_staff"):
		_log("HATA boot")
		return
	_zoom = 2.5
	_player.set("level", 20)
	_arm(["gokkusagi", "lightning_staff", "uzunkilic"], 3)
	_spawner.set("_spawn_timer", 1.0e9)
	await _boss_shots()


func _plan_kahraman() -> void:
	var ids: Array = CHARS_ALL
	if OS.get_environment("TN_CHARS") != "":
		ids = []
		for s in OS.get_environment("TN_CHARS").split(","):
			ids.append(int(s))
	var skies: Array = [DAY, DUSK, DAY, NIGHT]
	var sets: Array = [["mizrak", "yay"], ["pompali", "buz_asasi"], ["topuz", "arcane"], ["kalkan", "gokkusagi"], ["pence", "tufek"],
			["boomerang", "fire_staff"], ["dagger", "crossbow"], ["uzunkilic", "lightning_staff"]]
	_zoom = 3.0
	var i: int = 0
	for cid in ids:
		var sky: float = skies[i % skies.size()]
		var ws: Array = sets[i % sets.size()]
		i += 1
		if not await _boot(int(cid), str(ws[0]), sky):
			_log("HATA boot %d" % int(cid))
			continue
		_player.set("level", 20)
		_arm([ws[1]], 4)
		_teleport(SPOT)
		_crowd(6, 26)
		_walk = true
		await _hold(4.0)
		_walk = false
		for slot in ["skill", "skill3"]:
			_slot_ready(slot)
			_begin("c%d_%s" % [int(cid), slot], {"char": cid, "slot": slot})
			await _hold(0.8)
			_cur["cast"] = Engine.get_process_frames()
			await _press(slot)
			await _hold(4.2 if slot == "skill3" else 2.6)
			_end()
			var st: String = str(_player.get("skill_state" if slot == "skill" else slot + "_state"))
			if st == "active" or st == "on":
				await _press(slot)
			await _hold(1.0)
