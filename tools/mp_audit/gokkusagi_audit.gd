extends SceneTree

## Çok oyunculu denetim: GÖKKUŞAĞI ASASI (madde 306) - kaster HOST OLMAYAN oyuncu (CLAUDE.md). İstemci asayı alır; host, istemcinin asa
## ucundan (tepe slotu) aşağı-sağa uzanan hatta 3 dayanıklı, kımıldamayan yaratık doğurur. 0-11 sn TEMEL (ışın ilk yaratıkta durur, 3 sn'de
## kamaşma), 12. sn'de istemci FİNALE geçer (Gökkuşağı Mızrağı: hat delinir, 2 sn'de kamaşma).
## Ölçülenler - istemci: kendi ışını (açılış), delinen ek hedef var mı, kamaşma (beam_glow >= 2); host: kuklada "rbeam" ışını, kuklanın
## ışını delme kipinde mi, kuklanın vuruş patlamaları ("rbeam_hit"), host'taki GERÇEK yaratıklarda sersemleme (istemcinin "stun" isteği
## host'a ulaştı mı), kamaşma sayfası (EnchantFx "sprite" rainbow_dazzle) host'ta doğdu mu.
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode gokkusagi

## preload YOK: -s betikleri autoload'lardan önce derlenir - adlar düz yazıldı.
const HADIME := 14
const CLIENT_CHAR := 2
const SLOT_TOP := Vector2(0.0, -62.5) ## player.gd WEAPON_ICON_SLOTS[0] x 0,5 (asa ucunun kabaca yeri)

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _events: Array = []
var _t0: int = 0
var _count: Dictionary = {}
var _prev: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _now() -> float:
	return snappedf(float(Time.get_ticks_msec() - _t0) / 1000.0, 0.01)


func _edge(key: String, on: bool) -> void:
	if on and not bool(_prev.get(key, false)):
		_count[key] = int(_count.get(key, 0)) + 1
		_events.append([_now(), key, int(_count[key])])
	_prev[key] = on


func _rise(key: String, value: int) -> void:
	var last: int = int(_prev.get(key, 0))
	if value > last:
		_count[key] = int(_count.get(key, 0)) + (value - last)
	_prev[key] = value


func _staff(player: Node) -> Node:
	for w in player.get("owned_weapon_nodes"):
		if is_instance_valid(w) and String(w.get("beam_net_kind")) == "rbeam":
			return w
	return null


func _sample(player: Node2D) -> void:
	if _role == "client":
		var w: Node = _staff(player)
		if w == null:
			return
		var fx: Node = w.get("_beam_fx")
		var on: bool = fx != null and is_instance_valid(fx)
		_edge("own.isin", on)
		_edge("own.delme", on and (w.get("_beam_extra_targets") as Array).size() > 0)
		var beh: Node = w.get("enchant_behavior")
		var tgt: Node = w.get("_beam_target")
		_edge("own.kamasma", on and beh != null and is_instance_valid(tgt) and float(beh.call("beam_glow", tgt)) >= 2.0)
	else:
		for rp in get_nodes_in_group("remote_players"):
			var fx: Node = rp.get("_rbeam_fx")
			var on: bool = fx != null and is_instance_valid(fx)
			_edge("pup.isin", on)
			_edge("pup.delme", on and fx.get("pierce") == true)
			var vis: int = 0
			if on:
				for rec in (fx.get("_impacts") as Array):
					if is_instance_valid(rec[0]) and (rec[0] as CanvasItem).visible:
						vis += 1
			_rise("pup.vurus_patlamasi", vis)
		var stunned: int = 0
		for e in get_nodes_in_group("enemies"):
			if is_instance_valid(e) and e.get("is_stunned") == true:
				stunned += 1
		_rise("host.sersem_yaratik", stunned)
		var dz: int = 0
		for n in current_scene.get_children():
			if n.get("sheet") == "rainbow_dazzle":
				dz += 1
		_rise("host.kamasma_sayfasi", dz)


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		if not _nm.call("host_lan", _port, "Host", HADIME):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", CLIENT_CHAR):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
		_nm.call("set_local_ready", true)
	await _until(func(): return current_scene != null and current_scene.name == "Main", 60.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	await _wait(2.0)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player == null:
		_log("HATA Player yok"); quit(1); return
	if _role == "client":
		## tek silah: yalnız asa (başlangıç silahı yaratıkları başka hedefe kilitlemesin)
		for w in (player.get("owned_weapon_nodes") as Array).duplicate():
			if is_instance_valid(w):
				w.queue_free()
		(player.get("owned_weapon_nodes") as Array).clear()
		## defter önce (çağıranlar gibi): _apply_enchant_to_weapon kayıttan özelliği takar (EnchantDefs.ensure_trait)
		_gm.set("owned_weapons", [{"key": "gokkusagi", "level": 1}])
		player.call("buy_weapon_copy", "gokkusagi", 1)
	await _until(func(): return get_nodes_in_group("remote_players").size() >= 1, 20.0)
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	_log("karakter %s, silahlar %s" % [str(_gm.get("selected_char_id")), str(_gm.get("owned_weapons"))])
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	_t0 = Time.get_ticks_msec()
	var did: Dictionary = {}
	var total: float = 22.0
	while true:
		paused = false
		var el: float = float(Time.get_ticks_msec() - _t0) / 1000.0
		if el >= total:
			break
		if spawner:
			spawner.set("_spawn_timer", 1.0e9)
		var rp: Node2D = null
		for r in get_nodes_in_group("remote_players"):
			rp = r as Node2D
		if _role == "client" and int(el) in [3, 15] and not did.has("dbg%d" % int(el)):
			did["dbg%d" % int(el)] = true
			var sw: Node = _staff(player)
			var near: int = 0
			for e in get_nodes_in_group("enemies"):
				if (e as Node2D).global_position.distance_to(player.global_position) < 170.0:
					near += 1
			_log("dbg t=%d asa=%s hedef=%s yakin=%d mode=%s ench=%s" % [int(el), str(sw != null), str(sw.call("_get_target_enemy") if sw else null), near,
				str(sw.process_mode if sw else -1), str(sw.get("enchant_stats").get("id", "") if sw else "")])
			if sw:
				var mz: Node2D = sw.get("muzzle")
				var a: Vector2 = mz.global_position
				var b: Vector2 = sw.get("_beam_end")
				var lst: Array = []
				for e in get_nodes_in_group("enemies"):
					var p: Vector2 = (e as Node2D).global_position
					if p.distance_to(player.global_position) < 250.0:
						lst.append("%s d=%.1f" % [str(p - a), p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))])
				_log("dbg uc=%s son=%s ek=%d pierce=%s yaratiklar=%s" % [str(a - player.global_position), str(b - a), (sw.get("_beam_extra_targets") as Array).size(),
					str(sw.get("enchant_behavior").call("flag", "beam_pierce")), str(lst)])
		if _role == "client":
			player.set("item_shield_max", 4000.0)
			player.set("item_shield_hp", 4000.0)
			player.set("max_health", 100000.0)
			player.set("health", 100000.0)
			if el > 12.0 and not did.has("final"):
				did["final"] = true
				var ow: Array = _gm.get("owned_weapons")
				for i in ow.size():
					if str(ow[i].get("key", "")) == "gokkusagi":
						ow[i]["enchant"] = {"id": "goz_kamastiran", "ups": [0, 1, 2, 3], "final": true}
						player.call("_apply_enchant_to_weapon", i)
				_events.append([el, "ev.final", 1])
		elif el > 1.0 and not did.has("setup") and rp != null:
			## host: istemcinin asa ucundan aşağı-sağa giden hatta 3 yaratık (temelde ilki, finalde hepsi)
			did["setup"] = true
			player.global_position = rp.global_position + Vector2(-90.0, 0.0)
			## çevredeki eski yaratıklar uzağa (asa hattaki ilk yaratığı hedeflesin)
			for e in get_nodes_in_group("enemies"):
				if (e as Node2D).global_position.distance_to(rp.global_position) < 700.0:
					(e as Node2D).global_position += Vector2(0.0, 2600.0)
			if spawner:
				var roster: Array = spawner.call("_spawnable_roster", 1)
				var tip: Vector2 = rp.global_position + SLOT_TOP
				var dir: Vector2 = Vector2(1.0, 0.75).normalized()
				var placed: Array = []
				for d in [70.0, 105.0, 140.0]:
					var pt: Vector2 = tip + dir * d
					spawner.call("debug_spawn_creature", roster[0], 1, 1, pt)
					## doğuş noktası kayabilir: bu noktaya en yakın (henüz yerleşmemiş) yaratık tam hatta
					var best: Node2D = null
					for e in get_nodes_in_group("enemies"):
						if placed.has(e):
							continue
						if best == null or (e as Node2D).global_position.distance_to(pt) < best.global_position.distance_to(pt):
							best = e as Node2D
					if best:
						best.global_position = pt
						placed.append(best)
				_events.append([el, "ev.yaratik", get_nodes_in_group("enemies").size()])
			for e in get_nodes_in_group("enemies"):
				e.set("max_health", 1.0e7)
				e.set("health", 1.0e7)
				e.set("speed", 0.0)
		_sample(player)
		await process_frame
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "events": _events, "count": _count}))
	out.close()
	var keys: Array = _count.keys()
	keys.sort()
	for k in keys:
		_log("ÖZET sayı %-28s %d" % [str(k), int(_count[k])])
	_log("bitti: %d olay" % _events.size())
	await _wait(2.0)
	quit()


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
