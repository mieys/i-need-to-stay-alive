extends SceneTree

## Yaratık yeniden yazımı - İKİ GERÇEK SÜREÇLİ çok oyunculu test (LAN ENet, aynı bilgisayar). PLAN §6 / Aşama 5.
## Çalıştırma: tools/enemy_rewrite/run_mp.ps1 (iki süreci aynı anda başlatır). Roller ortam değişkeniyle:
##   MP_ROLE=host|client  MP_DIR=<ortak klasör>  MP_PORT (7791)  MP_N (60)  MP_TIER (3)  MP_SECS (20)
##   MP_NET=lan|epic (epic: gerçek Epic internet odası, eos_credentials.cfg gerekir; MP_TAG oda adı)  ENEMY_WORLD_PUPPET=0|1
## Senaryo: host odayı açar, istemci katılır + HAZIRIM, host başlatır; iki taraf silah kartını otomatik seçer, evden çıkar,
## kendi oyuncusuna tüfek+yay verir, canını çok yükseltir. İstemci oyuncusu host'tan ~400 px sağda durur (yaratıklar iki
## oyuncuya bölünsün). Host MP_N yaratığı iki oyuncunun ortasına yakın doğurur (debug_spawn_creature: istemciye yayınlar).
## Her iki süreç 0,5 sn'de bir {net_id: konum} örneği alır; istemci dosyasını yazar; host sonunda iki dosyayı zamana göre
## eşleyip karşılaştırır ve tek satır yazar:
##   MP_RESULT ew=<0|1> enemies_host=.. enemies_client=.. pos_err_mean=.. pos_err_p95=.. host_dmg=.. client_dmg=..
##             kills=.. kills_by_client=.. client_proj_seen=.. attack_anims_client=..

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7791
var _n: int = int(OS.get_environment("MP_N")) if OS.get_environment("MP_N") != "" else 60
var _tier: int = int(OS.get_environment("MP_TIER")) if OS.get_environment("MP_TIER") != "" else 3
var _secs: float = float(OS.get_environment("MP_SECS")) if OS.get_environment("MP_SECS") != "" else 20.0

var _nm: Node
var _gm: Node
var _samples: Array = [] ## [{t, pos: {net_id: [x, y]}}]
var _dmg: float = 0.0
var _kills: int = 0
var _kills_by_client: int = 0
var _proj_seen: int = 0
var _attack_anim_samples: int = 0


## İstemci süre sondası (render_world.gd deseni): öncelik -1e6 başlangıç, +1e6 bitiş -> bu karedeki TÜM _physics_process
## (fizik) ya da _process (kare) işinin duvar saati süresi.
class Probe extends Node:
	var owner_script: Object
	var is_start: bool = false
	var physics: bool = true
	func _physics_process(_d: float) -> void:
		if physics:
			_mark()
	func _process(_d: float) -> void:
		if not physics:
			_mark()
	func _mark() -> void:
		var key: String = "_ph" if physics else "_pr"
		if is_start:
			owner_script.set(key + "_start", Time.get_ticks_usec())
		else:
			var arr: PackedFloat64Array = owner_script.get(key + "_ticks")
			arr.append(float(Time.get_ticks_usec() - int(owner_script.get(key + "_start"))) / 1000.0)
			owner_script.set(key + "_ticks", arr)

var _ph_start: int = 0
var _ph_ticks := PackedFloat64Array()
var _pr_start: int = 0
var _pr_ticks := PackedFloat64Array()


func _avg(a: PackedFloat64Array) -> float:
	var s: float = 0.0
	for v in a:
		s += v
	return s / maxf(1.0, float(a.size()))


func _initialize() -> void:	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _run() -> void:
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	var epic: bool = OS.get_environment("MP_NET") == "epic"
	## Epic modunda iki süreç aynı lobi listesinde birbirini bu koşuya özel adla bulur (gerçek Epic, gerçek P2P/relay).
	var tag: String = OS.get_environment("MP_TAG") if OS.get_environment("MP_TAG") != "" else "EWTest"
	if _role == "host":
		if epic:
			await _nm.call("host_online", tag, 9)
			if not bool(_nm.get("is_online_session")):
				_log("HATA host_online"); quit(1); return
		elif not _nm.call("host_lan", _port, "Host", 9):
			_log("HATA host_lan"); quit(1); return
		_log("oda açıldı (%s), istemci bekleniyor" % ("Epic" if epic else "LAN"))
		await _until(func(): return _nm.get("lobby_players").size() >= 2 and _nm.call("all_players_ready"), 40.0)
		if not _nm.call("all_players_ready"):
			_log("HATA istemci gelmedi/hazır değil"); quit(1); return
		_nm.call("start_multiplayer_game")
	else:
		await _wait(1.0)
		if epic:
			var eos: Node = root.get_node("EosOnline")
			var found: Dictionary = {}
			var t_search: int = Time.get_ticks_msec()
			while found.is_empty() and Time.get_ticks_msec() - t_search < 40000:
				var lobbies: Array = await eos.call("search_lobbies_async", "Client")
				for lb: Dictionary in lobbies:
					if str(lb.get("host_name", "")) == tag:
						found = lb
				if found.is_empty():
					await _wait(2.0)
			if found.is_empty():
				_log("HATA Epic lobisi bulunamadı (%s)" % tag); quit(1); return
			_log("Epic lobisi bulundu: %s" % str(found.get("host_id")))
			await _nm.call("join_online", str(found["host_id"]), tag, "Client", 9)
		elif not _nm.call("join_lan", "127.0.0.1", _port, "Client", 9):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
		_nm.call("set_local_ready", true)
		_log("katıldı, hazır")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 40.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main sahnesine geçilmedi"); quit(1); return
	await _wait(1.5)
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
	for k in ["tufek", "yay"]:
		player.call("buy_weapon_copy", k, 3)
	player.set("max_health", 1.0e9)
	player.set("health", 1.0e9)
	if _role == "client":
		var p: Vector2 = player.global_position + Vector2(400, 0)
		for i in 20:
			if not _gm.call("is_position_blocked_by_forest", p):
				break
			p += Vector2(0, 32)
		player.global_position = p
	current_scene.child_entered_tree.connect(func(c: Node) -> void:
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("enemy_projectile.gd"):
			_proj_seen += 1)
	await _wait(1.0)
	if _role == "host":
		_gm.connect("enemy_died", func(_p: Vector2) -> void: _kills += 1)
		var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
		var roster: Array = spawner.call("_spawnable_roster", _tier)
		var remote: Node2D = null
		for rp in get_nodes_in_group("remote_players"):
			remote = rp
		var center: Vector2 = player.global_position + Vector2(200, 0)
		if remote != null:
			center = (player.global_position + remote.global_position) * 0.5
		var rng := RandomNumberGenerator.new(); rng.seed = 777
		var spawned: int = 0
		var guard: int = 0
		while spawned < _n and guard < _n * 4:
			guard += 1
			var id: String = roster[rng.randi() % roster.size()]
			var at: Vector2 = center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(250.0, 450.0)
			spawned += int(spawner.call("debug_spawn_creature", id, _tier, 1, at))
		## Öldürenin kim olduğu (istemci silahının host'taki yetkili yaratığa hasarı ulaşıyor mu)
		for e in get_nodes_in_group("enemies"):
			e.tree_exiting.connect(func() -> void:
				if int(e.get("last_attacker_peer_id")) > 1:
					_kills_by_client += 1)
		_log("yaratık doğdu: %d  EnemyWorld: %s" % [spawned, str(current_scene.get_node_or_null("EnemyWorldBridge") != null)])
	## ölçüm
	for ph in [true, false]:
		var pa := Probe.new(); pa.owner_script = self; pa.is_start = true; pa.physics = ph
		var pb := Probe.new(); pb.owner_script = self; pb.physics = ph
		pa.process_physics_priority = -1000000; pa.process_priority = -1000000
		pb.process_physics_priority = 1000000; pb.process_priority = 1000000
		root.add_child(pa); root.add_child(pb)
	var t0: int = Time.get_ticks_msec()
	var last_hp: float = float(player.get("health"))
	var next_sample: int = 0
	while Time.get_ticks_msec() - t0 < int(_secs * 1000.0):
		paused = false
		var sp: Node = current_scene.get_node_or_null("EnemySpawner") if current_scene else null
		if sp:
			sp.set("_spawn_timer", 1.0e9)
		var hp: float = float(player.get("health"))
		if hp < last_hp:
			_dmg += last_hp - hp
		last_hp = hp
		if Time.get_ticks_msec() - t0 >= next_sample:
			next_sample += 500
			_take_sample()
		await process_frame
	if _role == "client":
		## önce geçici ada yaz, sonra adını değiştir: host yarım dosya okumasın
		var f := FileAccess.open(_dir.path_join("client.tmp"), FileAccess.WRITE)
		f.store_string(JSON.stringify({"samples": _samples, "dmg": _dmg, "proj": _proj_seen, "attack": _attack_anim_samples,
				"count": get_nodes_in_group("enemies").size(), "phys_ms": _avg(_ph_ticks), "proc_ms": _avg(_pr_ticks),
				"bridge": current_scene.get_node_or_null("EnemyWorldBridge") != null}))
		f.close()
		DirAccess.rename_absolute(_dir.path_join("client.tmp"), _dir.path_join("client.json"))
		_log("bitti (hasar %.0f, mermi görüldü %d, saldırı animasyonu örneği %d)" % [_dmg, _proj_seen, _attack_anim_samples])
		await _wait(6.0) ## host karşılaştırırken bağlantı açık kalsın
		quit(); return
	## host: istemci dosyasını bekle, karşılaştır
	var cpath: String = _dir.path_join("client.json")
	var w0: int = Time.get_ticks_msec()
	while not FileAccess.file_exists(cpath) and Time.get_ticks_msec() - w0 < 15000:
		paused = false
		await process_frame
	if not FileAccess.file_exists(cpath):
		_log("HATA istemci sonucu gelmedi"); quit(1); return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(cpath))
	if not (parsed is Dictionary):
		_log("HATA istemci sonucu okunamadı"); quit(1); return
	var cj: Dictionary = parsed
	var errs: Array = []
	for cs: Dictionary in cj["samples"]:
		var best: Dictionary = {}
		var bd: float = INF
		for hs: Dictionary in _samples:
			var d: float = absf(float(hs["t"]) - float(cs["t"]))
			if d < bd:
				bd = d
				best = hs
		if best.is_empty() or bd > 0.3:
			continue
		for id in cs["pos"]:
			if best["pos"].has(id):
				var a: Array = cs["pos"][id]
				var b: Array = best["pos"][id]
				errs.append(Vector2(a[0], a[1]).distance_to(Vector2(b[0], b[1])))
	errs.sort()
	var mean: float = 0.0
	for v in errs:
		mean += v
	mean /= maxf(1.0, float(errs.size()))
	var p95: float = float(errs[int(0.95 * (errs.size() - 1))]) if not errs.is_empty() else -1.0
	var ew: int = 1 if current_scene.get_node_or_null("EnemyWorldBridge") != null else 0
	print("MP_RESULT ew=%d enemies_host=%d enemies_client=%d pos_err_mean=%.1f pos_err_p95=%.1f pairs=%d host_dmg=%.0f client_dmg=%.0f kills=%d kills_by_client=%d client_proj_seen=%d attack_anims_client=%d client_bridge=%s client_phys_ms=%.2f client_proc_ms=%.2f host_phys_ms=%.2f" % [
		ew, get_nodes_in_group("enemies").size(), int(cj["count"]), mean, p95, errs.size(), _dmg, float(cj["dmg"]), _kills,
		_kills_by_client, int(cj["proj"]), int(cj["attack"]), str(cj.get("bridge", false)), float(cj.get("phys_ms", -1.0)),
		float(cj.get("proc_ms", -1.0)), _avg(_ph_ticks)])
	quit()


func _take_sample() -> void:
	var pos: Dictionary = {}
	for e in get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var id: int = int(e.get_meta("network_enemy_id", 0))
		if id <= 0:
			continue
		var p: Vector2 = (e as Node2D).global_position
		pos[str(id)] = [p.x, p.y]
		if _role == "client" and int(e.get("_state")) == 2: ## State.ATTACK
			_attack_anim_samples += 1
	_samples.append({"t": Time.get_unix_time_from_system(), "pos": pos})


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
