extends SceneTree

## MULTIPLAYER SAVAŞ GÖRSEL KARMAŞA ÖLÇÜMÜ (2026-11-06, kullanıcı: "oyun savaş esnasında multiplayerda aşırı göz yorucu ve karmaşık - analiz + öneri").
## Roller (MP_ROLE): host / client = BAŞSIZ eşler (savaşır, yetenek basar); viewer = PENCERELİ istemci (gerçek renderer, 1920x1080) ekranı kaydeder;
## solo = aynı senaryo tek oyunculu (viewer yalnız - çok oyunculu artışı ayırmak için). Sürücü: tools/buyuk_test/mp_clutter.ps1.
## Viewer ölçümleri: (1) her sn ekrandaki öğe sayısı (kategori başına) + çizim çağrısı, (2) 4 anda "ablation": tree duraklatılıp kategoriler tek tek
## gizlenerek tam kare görüntüsü (rapor: mp_clutter_rapor.py kenar yoğunluğu / doygun piksel / kaplanan alan), (3) 10 sn yanıp sönme/hareket serisi
## (96x54 ışıklılık, kare farkı). Ortam: MP_CHAR, MP_WEAPONS (a,b,c), MP_TIER, MP_N, MP_SECS, MP_PLAYERS, MP_PORT, BT_OUT.

const DROP_GROUPS: Array = ["xp_orbs", "gold_drops", "food_drops", "magnet_drops", "shield_orb_drops", "weapon_shard_drops", "chest_drops"]
const ABLATE: Array = ["hud", "numbers", "drops", "decal", "bars", "weapons_own", "weapons_puppet", "projectile", "player_fx", "enemy_fx", "pets", "summons", "enemy"]
const CAPTURE_AT: Array = [20.0, 32.0, 46.0, 58.0]
const FLICK_FROM := 34.0
const FLICK_TO := 44.0
const ROLE_PHASE := {"host": 0.0, "client": 2.0, "viewer": 4.0, "solo": 4.0}

var _role: String = OS.get_environment("MP_ROLE")
var _char: int = _ei("MP_CHAR", 4)
var _out: String = OS.get_environment("BT_OUT")
var _port: int = _ei("MP_PORT", 7811)
var _secs: float = float(_ei("MP_SECS", 70))
var _n: int = _ei("MP_N", 70)
var _tier: int = _ei("MP_TIER", 8)
var _expected: int = _ei("MP_PLAYERS", 3)
var _weapons: Array = []
var _nm: Node
var _gm: Node
var _player: Node2D
var _spawner: Node
var _next: Dictionary = {}
var _flick: Array = []
var _prev_small: PackedByteArray = PackedByteArray()
var _last_flick_ms: int = 0


func _ei(k: String, d: int) -> int:
	var v: String = OS.get_environment(k)
	return int(v) if v != "" else d


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MPC[%s] %s" % [_role, s])


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _until(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		paused = false
		await process_frame


func _find_by_method(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find_by_method(c, method)
		if r:
			return r
	return null


func _finish_house_intro() -> void:
	var intro: Node = current_scene.get_node_or_null("HouseInterior/HouseIntro") if current_scene else null
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	root.get_node("GameManager").set("invasion_pending", false)


func _slot_vars(slot: String) -> Array:
	return ["skill_state" if slot == "skill" else slot + "_state", "skill_timer" if slot == "skill" else slot + "_timer"]


func _press(slot: String) -> void:
	Input.action_press(slot)
	await process_frame
	await physics_frame
	await process_frame
	await process_frame
	Input.action_release(slot)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(_out)
	for w in OS.get_environment("MP_WEAPONS").split(","):
		if w.strip_edges() != "":
			_weapons.append(w.strip_edges())
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	_log("basladi char=%d silahlar=%s" % [_char, str(_weapons)])
	if _role == "solo":
		_nm.call("disconnect_from_room")
		_gm.call("reset")
		_gm.set("selected_char_id", _char)
		_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(_char).get("skill", 1))
		_gm.set("selected_start_weapon", "dagger")
		change_scene_to_file("res://scenes/main.tscn")
	elif _role == "host":
		if not _nm.call("host_lan", _port, "Host", _char):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= _expected and _nm.call("all_players_ready"), 60.0)
		if not _nm.call("all_players_ready"):
			_log("HATA istemciler gelmedi"); quit(1); return
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0 + float(ROLE_PHASE.get(_role, 0.0)) * 0.5)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Oyuncu-" + _role, _char):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= _expected, 40.0)
		_nm.call("set_local_ready", true)
	await _until(func(): return current_scene != null and current_scene.name == "Main", 60.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	if _role == "viewer" or _role == "solo":
		DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.5)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	_finish_house_intro()
	await _wait(2.0)
	_player = current_scene.get_node_or_null("Player") as Node2D
	_spawner = current_scene.get_node_or_null("EnemySpawner")
	if _player == null:
		_log("HATA Player yok"); quit(1); return
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	# yükleme: 3 silah, kademe 3 (kontür), seviye 20
	while (_player.get("owned_weapon_nodes") as Array).size() > 0:
		_player.call("remove_owned_weapon", 0)
	await _wait(0.3)
	var ed: GDScript = load("res://scripts/enchant_defs.gd")
	for k in _weapons:
		_player.call("buy_weapon_copy", str(k), 1)
	await _wait(0.4)
	for w in (_player.get("owned_weapon_nodes") as Array):
		var key: String = str(w.get_meta("shop_key", ""))
		var tid: String = str(ed.trait_of(key))
		if tid != "":
			w.call("set_enchant", {"id": tid, "ups": [0, 1], "final": false, "plus": 0})
	_player.set("level", 20)
	if _role != "host" and _role != "solo":
		var off: Vector2 = Vector2(-150.0, 70.0) if _role == "client" else Vector2(150.0, 70.0)
		var p: Vector2 = _player.global_position + off
		for i in 20:
			if not _gm.call("is_position_blocked_by_walls", p):
				break
			p += Vector2(0, 32)
		_player.global_position = p
	if _role != "solo":
		await _until(func(): return get_nodes_in_group("remote_players").size() >= _expected - 1, 30.0)
	await _wait(1.0)
	_gm.set("game_time", float(_tier - 1) * 150.0 + 20.0)
	if _spawner and (_role == "host" or _role == "solo"):
		_spawner.set("_spawn_tier", _tier)
	_log("senaryo basliyor (oyuncu kuklasi: %d)" % get_nodes_in_group("remote_players").size())
	var phase: float = float(ROLE_PHASE.get(_role, 0.0))
	_next = {"skill": 6.0 + phase, "skill2": 9.0 + phase, "skill3": 14.0 + phase}
	var gaps: Dictionary = {"skill": 8.0, "skill2": 14.0, "skill3": 26.0}
	var t0: int = Time.get_ticks_msec()
	var cap_i: int = 0
	var cnt_next: int = 0
	var frame: int = 0
	var roster: Array = []
	if _spawner:
		roster = _spawner.call("_spawnable_roster", _tier)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var viewer: bool = _role == "viewer" or _role == "solo"
	var run_secs: float = _secs if viewer else _secs + 12.0
	while float(Time.get_ticks_msec() - t0) / 1000.0 < run_secs:
		paused = false
		frame += 1
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if _spawner:
			_spawner.set("_spawn_timer", 1.0e9)
		_gm.set("team_xp_needed", 1.0e12) ## seviye ekranı çıkmasın
		_player.set("xp_to_next_level", 1.0e12)
		_player.set("max_health", 1.0e9)
		_player.set("health", 1.0e9)
		_player.set("item_shield_max", 2000.0)
		# hareket: küçük daire (grup birbirinden kopmasın)
		var ph: int = int((el + phase) / 1.5) % 4
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		Input.action_press(["move_right", "move_down", "move_left", "move_up"][ph])
		# yetenekler (kendi bekleme durumunu sıfırlayıp bas: gerçekçi sık kullanım)
		for slot in ["skill", "skill2", "skill3"]:
			if el >= float(_next[slot]):
				_next[slot] = el + float(gaps[slot])
				var sv: Array = _slot_vars(slot)
				_player.set(sv[0], "ready")
				_player.set(sv[1], 0.0)
				_player.set("item_shield_hp", 2000.0)
				_player.set("necro_souls", 25)
				_press(slot)
		# kalabalık (host / solo): oyuncuların ortasına yakın halkadan doğur
		if (_role == "host" or _role == "solo") and _spawner and frame % 6 == 0 and not roster.is_empty():
			var center: Vector2 = _player.global_position
			var cnt: int = 1
			for r in get_nodes_in_group("remote_players"):
				center += (r as Node2D).global_position
				cnt += 1
			center /= float(cnt)
			var near: int = 0
			for e in get_nodes_in_group("enemies"):
				if e is Node2D and (e as Node2D).global_position.distance_squared_to(center) < 900.0 * 900.0:
					near += 1
			for i in mini(8, _n - near):
				var at: Vector2 = center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(300.0, 520.0)
				_spawner.call("debug_spawn_creature", roster[rng.randi() % roster.size()], _tier, 1, at)
		if viewer:
			if el >= float(cnt_next):
				cnt_next += 1
				_count_tick(el)
			if cap_i < CAPTURE_AT.size() and el >= float(CAPTURE_AT[cap_i]):
				await _ablate("m%d" % cap_i)
				cap_i += 1
			elif el >= FLICK_FROM and el < FLICK_TO and Time.get_ticks_msec() - _last_flick_ms >= 33:
				_last_flick_ms = Time.get_ticks_msec()
				await _flick_sample(el)
		await process_frame
	if viewer:
		_flick_report()
	_log("bitti")
	await _wait(3.0)
	quit()


# ───────────────────────────── sınıflandırma ─────────────────────────────

func _map(n: Node, puppet_icons: Dictionary, own: Dictionary) -> String:
	if n is CanvasLayer and (n.get_parent() == current_scene or n.get_parent() == root):
		return "hud"
	var id: int = n.get_instance_id()
	if own.has(id):
		return "weapons_own"
	if puppet_icons.has(id):
		return "weapons_puppet"
	if n.is_in_group("enemies"):
		return "enemy"
	if n.is_in_group("enemy_projectiles"):
		return "enemy_fx"
	if n.is_in_group("player") or n.is_in_group("remote_players"):
		return "players"
	if n.is_in_group("summons"):
		return "summons"
	for g in DROP_GROUPS:
		if n.is_in_group(g):
			return "drops"
	var sc: Variant = n.get_script()
	if sc == null:
		return ""
	var b: String = (sc as Script).resource_path.get_file().get_basename()
	if b == "damage_numbers" or b == "floating_text" or b.begins_with("kill_gold") or b.begins_with("gold_gain"):
		return "numbers" if b != "kill_gold_coin" else "drops"
	if b.contains("blood") or b.contains("crack") or b.contains("decal"):
		return "decal"
	if b.contains("overhead_bar") or b.contains("shield_visual") or b.contains("status_icon") or b.contains("elite_bar") or b.begins_with("fx_brush") or b.contains("fear_emote"):
		return "bars"
	if b.begins_with("enemy_") or b.begins_with("fx_enemy") or b.begins_with("creature_"):
		return "enemy_fx"
	if b.contains("pet") or b.contains("kopek") or b.contains("parrot") or b.contains("peri_") or b.contains("kelebek") or b.contains("kirpi"):
		return "pets"
	if b.contains("projectile") or b.contains("bullet") or b.contains("arrow") or b.contains("boomerang") or b.contains("rocket") or b.contains("firework") or b.contains("fisek") or b.contains("lightning_beam") or b.contains("rainbow_beam") or b.contains("bolt"):
		return "projectile"
	if b.begins_with("fx_") or b.contains("_fx") or b.begins_with("staff_tip") or b.begins_with("poison_drip") or b.begins_with("dome_") or b.begins_with("mana_shield") or b.begins_with("totem") or b.begins_with("mission_") or b.begins_with("oakley_") or b.begins_with("melek_") or b.begins_with("buyucu_") or b.begins_with("cadi_") or b.begins_with("shaman_") or b.begins_with("necro") or b.begins_with("matthew_") or b.begins_with("paladin_") or b.begins_with("hadime_") or b.begins_with("weapon_follow") or b.begins_with("weapon_tip") or b.begins_with("yinyang") or b.begins_with("kalkan_") or b.begins_with("dagger_") or b.begins_with("topuz_") or b.begins_with("pence_") or b.begins_with("mizrak_") or b.begins_with("sword_swing"):
		return "player_fx"
	return ""


func _collect_units() -> Dictionary:
	var out: Dictionary = {}
	var puppet_icons: Dictionary = {}
	for rp in get_nodes_in_group("remote_players"):
		if "_weapon_icons" in rp:
			for ic in rp._weapon_icons:
				if is_instance_valid(ic):
					puppet_icons[ic.get_instance_id()] = true
	var own: Dictionary = {}
	for w in (_player.get("owned_weapon_nodes") as Array):
		if is_instance_valid(w):
			own[w.get_instance_id()] = true
	var rect: Rect2 = (root.get_canvas_transform().affine_inverse() * root.get_visible_rect()).grow(48.0)
	var stack: Array = [current_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var cat: String = _map(n, puppet_icons, own)
		var descend: bool = true
		if cat != "":
			var ok: bool = true
			if n is Node2D:
				ok = rect.has_point((n as Node2D).global_position)
			if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
				ok = false
			if n is CanvasLayer and not (n as CanvasLayer).visible:
				ok = false
			if ok:
				if not out.has(cat):
					out[cat] = []
				(out[cat] as Array).append(n)
			if cat in ["enemy", "drops", "numbers", "decal", "projectile", "enemy_fx", "player_fx", "bars", "pets", "summons", "hud"]:
				descend = false
		if descend:
			for c in n.get_children():
				stack.append(c)
	return out


func _base_of(n: Node) -> String:
	var sc: Variant = n.get_script()
	return (sc as Script).resource_path.get_file().get_basename() if sc != null else n.get_class()


func _count_tick(el: float) -> void:
	var u: Dictionary = _collect_units()
	var parts: PackedStringArray = []
	for c in ["players", "enemy", "enemy_fx", "weapons_own", "weapons_puppet", "projectile", "player_fx", "numbers", "decal", "drops", "bars", "pets", "summons"]:
		parts.append("%s=%d" % [c, (u.get(c, []) as Array).size()])
	print("MPC CNT t=%.0f %s draws=%d objs=%d nodes=%d fps=%d" % [el, " ".join(parts), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Engine.get_frames_per_second())])


# ───────────────────────────── ablation ─────────────────────────────

func _set_vis(nodes: Array, v: bool) -> void:
	for n in nodes:
		if is_instance_valid(n):
			if n is CanvasLayer:
				(n as CanvasLayer).visible = v
			elif n is CanvasItem:
				(n as CanvasItem).visible = v


func _shot_full(nm: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		print("MPC SHOTFAIL %s" % nm)
		return
	img.save_jpg(_out.path_join(nm + ".jpg"), 0.88)


func _ablate(tag: String) -> void:
	var u: Dictionary = _collect_units()
	# envanter: kategori:betik -> adet
	var tally: Dictionary = {}
	for c in u:
		for n in (u[c] as Array):
			var k: String = "%s:%s" % [c, _base_of(n)]
			tally[k] = int(tally.get(k, 0)) + 1
	var items: Array = []
	for k in tally:
		items.append([tally[k], k])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var parts: PackedStringArray = []
	for i in range(mini(40, items.size())):
		parts.append("%s=%d" % [items[i][1], items[i][0]])
	print("MPC INV %s %s" % [tag, " ".join(parts)])
	paused = true
	await _shot_full("%s_00_base" % tag)
	for cat in ABLATE:
		var arr: Array = u.get(cat, [])
		if arr.is_empty():
			continue
		_set_vis(arr, false)
		await _shot_full("%s_%s" % [tag, cat])
		_set_vis(arr, true)
	# birleşik: tüm "efekt" kategorileri kapalı (yalnız dünya + yaratıklar + oyuncular + HUD)
	var fx_cats: Array = ["numbers", "drops", "decal", "weapons_puppet", "projectile", "player_fx", "enemy_fx", "pets", "summons"]
	var all_fx: Array = []
	for c in fx_cats:
		all_fx.append_array(u.get(c, []))
	_set_vis(all_fx, false)
	await _shot_full("%s_zz_efektsiz" % tag)
	_set_vis(all_fx, true)
	# yalnız dünya (karşılaştırma tabanı): oyuncular + yaratıklar + her şey gizli (HUD hariç)
	var everything: Array = []
	for c in u:
		if c != "hud":
			everything.append_array(u[c])
	_set_vis(everything, false)
	await _shot_full("%s_zzz_bos_dunya" % tag)
	_set_vis(everything, true)
	paused = false
	print("MPC ABL %s ok" % tag)


# ───────────────────────────── yanıp sönme / hareket ─────────────────────────────

func _flick_sample(el: float) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img == null or img.is_empty():
		return
	img.resize(96, 54, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGB8)
	var d: PackedByteArray = img.get_data()
	var n: int = d.size() / 3
	var lum_sum: float = 0.0
	var sat_hi: int = 0
	var diff_sum: float = 0.0
	var diff_hi: int = 0
	var has_prev: bool = _prev_small.size() == d.size()
	for i in range(n):
		var r: int = d[i * 3]
		var g: int = d[i * 3 + 1]
		var b: int = d[i * 3 + 2]
		var mx: int = maxi(r, maxi(g, b))
		var mn: int = mini(r, mini(g, b))
		var lum: float = (3.0 * r + 6.0 * g + b) / 10.0
		lum_sum += lum
		if mx > 150 and mx > 0 and float(mx - mn) / float(mx) > 0.55:
			sat_hi += 1
		if has_prev:
			var pl: float = (3.0 * _prev_small[i * 3] + 6.0 * _prev_small[i * 3 + 1] + _prev_small[i * 3 + 2]) / 10.0
			var ad: float = absf(lum - pl)
			diff_sum += ad
			if ad > 40.0:
				diff_hi += 1
	_prev_small = d
	_flick.append([el, lum_sum / n, diff_sum / n if has_prev else -1.0, float(diff_hi) / n if has_prev else -1.0, float(sat_hi) / n])


func _flick_report() -> void:
	var lums: Array = []
	var diffs: Array = []
	var his: Array = []
	var sats: Array = []
	var jumps: Array = []
	var prev_lum: float = -1.0
	for s in _flick:
		lums.append(s[1])
		sats.append(s[4])
		if float(s[2]) >= 0.0:
			diffs.append(s[2])
			his.append(s[3])
		if prev_lum >= 0.0:
			jumps.append(absf(float(s[1]) - prev_lum))
		prev_lum = float(s[1])
	var f := FileAccess.open(_out.path_join("flick_%s.csv" % _role), FileAccess.WRITE)
	f.store_line("t,lum,diff,diff_hi,sat")
	for s in _flick:
		f.store_line("%.3f,%.2f,%.3f,%.4f,%.4f" % [s[0], s[1], s[2], s[3], s[4]])
	f.close()
	var sj: Array = jumps.duplicate()
	sj.sort()
	print("MPC FLICK n=%d lum_mean=%.1f lum_std=%.2f lum_jump_mean=%.2f lum_jump_p95=%.2f diff_mean=%.2f diff_hi_frac=%.4f sat_frac=%.4f" % [_flick.size(), _mean(lums), _std(lums), _mean(jumps), sj[mini(sj.size() - 1, int(sj.size() * 0.95))] if not sj.is_empty() else 0.0, _mean(diffs), _mean(his), _mean(sats)])


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: float = 0.0
	for v in a:
		s += float(v)
	return s / a.size()


func _std(a: Array) -> float:
	if a.size() < 2:
		return 0.0
	var m: float = _mean(a)
	var s: float = 0.0
	for v in a:
		s += (float(v) - m) * (float(v) - m)
	return sqrt(s / a.size())
