extends SceneTree

## Çok oyunculu denetim: PvPvE MODU Aşama 1 (madde 607). Host + istemci (ENet), istemci HOST OLMAYAN oyuncu.
## Host odayı "2v2 Takım" kurar (GameMode.set_room_mode, oda kur düğmesinin yaptığı) -> istemci modu + takımını host'tan almalı (PvpNet._rpc_state).
## Oyun başlayınca host üsleri seçer, istemci aynı üsleri almalı (_rpc_bases), herkes kendi takımının kampında başlamalı, açılış evi olmamalı.
## Sonra istemci rakip (host'un) üssüne doğru 2,5 sn yürür: sınırda durmalı (move_blockers çemberi yalnız rakipte).
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/mp_audit/run_audit.ps1 -Mode pvp

const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")
const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")
const HOST_CHAR := 2
const CLIENT_CHAR := 10

var _role: String = OS.get_environment("MP_ROLE")
var _dir: String = OS.get_environment("MP_DIR")
var _port: int = int(OS.get_environment("MP_PORT")) if OS.get_environment("MP_PORT") != "" else 7861
var _nm: Node
var _gm: Node
var _checks: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _log(s: String) -> void:
	print("MP[%s] %s" % [_role, s])


func _run() -> void:
	OS.set_environment("PVP_PREP", "0") ## Aşama 2: hazırlık süresi yok (pvp_rules.gd prep_seconds, yalnız editör); rakibe hasar hemen denenir
	OS.set_environment("PVP_DEATH", "3") ## Aşama 4: ölüm süresi 3 sn (pvp_rules.gd death_seconds, yalnız editör); üste doğuş hızlı denenir
	await process_frame
	_nm = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	if _role == "host":
		GameModeScript.set_room_mode(GameModeScript.PVP)
		if not _nm.call("host_lan", _port, "Host", HOST_CHAR):
			_log("HATA host_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 40.0)
		## madde 608: istemci lobide takım değiştirir (host'un görmesi + geri dönüş); host'un kendi başlangıç takımı 0
		var client_peer: int = 0
		for pid in _nm.get("lobby_players"):
			if int(pid) != 1:
				client_peer = int(pid)
		_checks["host_takimi"] = TeamsScript.team_of(1)
		await _until(func(): return TeamsScript.team_of(client_peer) == 0, 20.0)
		_checks["host_istemcinin_gecisini_gordu"] = TeamsScript.team_of(client_peer) == 0
		await _until(func(): return TeamsScript.team_of(client_peer) == 1 and _nm.call("all_players_ready"), 40.0)
		_checks["host_geri_donusu_gordu"] = TeamsScript.team_of(client_peer) == 1
		_nm.call("start_multiplayer_game")
	else:
		GameModeScript.set_room_mode(GameModeScript.COOP) ## istemci kendi başına coop sanar; host'tan PvP almalı
		await _wait(1.0)
		if not _nm.call("join_lan", "127.0.0.1", _port, "Client", CLIENT_CHAR):
			_log("HATA join_lan"); quit(1); return
		await _until(func(): return _nm.get("lobby_players").size() >= 2, 30.0)
		_checks["lobide_mod"] = GameModeScript.room_mode
		_checks["lobide_takimlar"] = str(TeamsScript.by_peer)
		## madde 608: host'un takımına (0) geç, host'a ulaşmasını bekle, geri dön; sonra hazır ol
		var net: Node = root.get_node("NetworkManager/PvpNet")
		var my_peer: int = root.multiplayer.get_unique_id()
		net.call("request_team", 0)
		await _until(func(): return TeamsScript.team_of(my_peer) == 0, 10.0)
		_checks["gecis_0_istemcide"] = TeamsScript.team_of(my_peer) == 0
		await _wait(0.8) ## host'un bir kare görmesi için
		net.call("request_team", 1)
		await _until(func(): return TeamsScript.team_of(my_peer) == 1, 10.0)
		_checks["gecis_geri_istemcide"] = TeamsScript.team_of(my_peer) == 1
		_nm.call("set_local_ready", true)
	await _until(func(): return current_scene != null and current_scene.name == "Main", 60.0)
	if current_scene == null or current_scene.name != "Main":
		_log("HATA Main yok"); quit(1); return
	await _until(func(): return BaseZonesScript.active.size() == 2, 20.0)
	await _wait(1.5)
	var ws: Node = _find_by_method(current_scene, "_auto_pick_random_card")
	if ws:
		ws.call("_auto_pick_random_card")
	var me: int = root.multiplayer.get_unique_id()
	_checks["is_pvp"] = GameModeScript.is_pvp()
	_checks["takimim"] = TeamsScript.team_of(me)
	_checks["takimlar"] = str(TeamsScript.by_peer)
	_checks["ev_yok"] = current_scene.get_node_or_null("HouseInterior") == null
	var centers: Array = []
	for b: Dictionary in BaseZonesScript.active:
		centers.append([snappedf((b["center"] as Vector2).x, 1.0), snappedf((b["center"] as Vector2).y, 1.0)])
	_checks["usler"] = centers
	var kamp: int = 0
	for n: Node in current_scene.get_children():
		if str(n.name).begins_with("Kamp_"):
			kamp += 1
	_checks["kamp_parcasi"] = kamp
	var p: Node2D = current_scene.get_node_or_null("Player") as Node2D
	_checks["kendi_ussunde"] = p != null and BaseZonesScript.in_own_base(p.global_position, TeamsScript.team_of(me))
	if _role == "client":
		## madde 608: oyun başladıktan sonra takım değişmez (üsler / doğuşlar o atamayla kuruldu)
		var late_net: Node = root.get_node("NetworkManager/PvpNet")
		late_net.call("request_team", 1 - TeamsScript.team_of(me))
		await _wait(1.0)
		_checks["oyunda_takim_kilitli"] = TeamsScript.team_of(me) == int(_checks["takimim"])
	if _role == "host":
		FileAccess.open(_dir.path_join("ready.flag"), FileAccess.WRITE).close()
	else:
		await _until(func(): return FileAccess.file_exists(_dir.path_join("ready.flag")), 30.0)
	## Aşama 2 (madde 615): rakibe hasar - iki oyuncu açık bir yerde yan yana, istemci host'un kuklasının vekiline vurur, host hasarı almalı
	if p != null:
		await _pvp_damage_phase(p, me)
	## istemci: rakip üssün sınırının 40 birim dışına konup merkeze doğru 2,5 sn yürür
	if _role == "client" and p != null:
		var enemy_c: Vector2 = BaseZonesScript.center_of(1 - TeamsScript.team_of(me))
		var dir: Vector2 = Vector2(1, 0)
		var start: Vector2 = enemy_c - dir * (BaseZonesScript.radius + 40.0) - Vector2(0, 12.75)
		p.global_position = start
		p.reset_physics_interpolation()
		await _wait(0.3)
		Input.action_press("move_right")
		await _wait(2.5)
		Input.action_release("move_right")
		var feet: Vector2 = p.global_position + Vector2(0, 12.75)
		_checks["rakip_use_yurudu_uzaklik"] = snappedf(feet.distance_to(enemy_c), 0.1)
		_checks["rakip_use_giremedi"] = feet.distance_to(enemy_c) > BaseZonesScript.radius - 20.0
		_checks["yurudu_mu"] = snappedf(feet.distance_to(start + Vector2(0, 12.75)), 0.1)
		FileAccess.open(_dir.path_join("walk_done.flag"), FileAccess.WRITE).close()
	## Aşama 4 (madde 617): ölüm -> öldürme skoru + altın + bildirim -> üste doğuş -> doğuş koruması -> kalıcı ölüm -> eleme -> maç sonu
	if p != null:
		await _pvp_death_phase(p, me)
	var out := FileAccess.open(_dir.path_join(_role + ".json"), FileAccess.WRITE)
	out.store_string(JSON.stringify({"role": _role, "checks": _checks}))
	out.close()
	_log("denetim: %s" % JSON.stringify(_checks))
	if _role == "client":
		FileAccess.open(_dir.path_join("client_done.flag"), FileAccess.WRITE).close()
	else:
		## host istemci yürüyüşünü bitirene kadar odada kalır (erken kapanırsa istemci kopar, sahnesi silinir)
		await _until(func(): return FileAccess.file_exists(_dir.path_join("client_done.flag")), 40.0)
	_log("bitti")
	await _wait(2.0)
	quit()


func _pvp_damage_phase(p: Node2D, _me: int) -> void:
	var rect: Rect2 = _gm.call("get_map_world_rect")
	var spot: Vector2 = rect.get_center()
	if BaseZonesScript.near_any(spot, 400.0):
		spot += Vector2(0, 900.0)
	var client_peer: int = 0
	for pid in _nm.get("lobby_players"):
		if int(pid) != 1:
			client_peer = int(pid)
	if _role == "host":
		p.global_position = spot
		p.reset_physics_interpolation()
		FileAccess.open(_dir.path_join("host_in_place.flag"), FileAccess.WRITE).close()
		await _until(func(): return FileAccess.file_exists(_dir.path_join("hit_done.flag")), 40.0)
		await _wait(0.5)
		_checks["pvp_hasar_aldi"] = float(p.get("match_damage_taken")) > 0.0 and int(p.get("last_pvp_attacker_peer")) == client_peer
		_checks["pvp_alinan_hasar"] = snappedf(float(p.get("match_damage_taken")), 0.1)
		return
	await _until(func(): return FileAccess.file_exists(_dir.path_join("host_in_place.flag")), 30.0)
	p.global_position = spot + Vector2(180, 0)
	p.reset_physics_interpolation()
	var found: Array = [] ## lambda yerel değişkeni DEĞERLE yakalar: sonucu diziyle taşı
	await _until(func():
		var all: Array = get_nodes_in_group("pvp_targets")
		if all.is_empty():
			return false
		var cand: Node2D = all[0] as Node2D
		if cand != null and cand.global_position.distance_to(spot) < 120.0 and not cand.has_meta(&"untargetable"):
			found.append(cand)
			return true
		return false, 15.0)
	var proxy: Node2D = found[0] as Node2D if not found.is_empty() else null
	var diag: Array = []
	for t: Node in get_nodes_in_group("pvp_targets"):
		diag.append("%s konum=%s hedef_degil=%s olu=%s" % [t.name, str((t as Node2D).global_position.round()), t.has_meta(&"untargetable"), t.get("is_dead")])
	var rp_list: Array = []
	for r: Node in get_nodes_in_group("remote_players"):
		rp_list.append("%s peer=%s konum=%s" % [r.name, str(r.get("peer_id")), str((r as Node2D).global_position.round())])
	_checks["pvp_tani"] = "vekiller=%s uzaklar=%s spot=%s savasta=%s" % [str(diag), str(rp_list), str(spot.round()), str(preload("res://scripts/pvp/pvp_rules.gd").fighting())]
	_checks["pvp_vekil_var"] = proxy != null
	_checks["pvp_vekil_hedeflenebilir"] = proxy != null and not proxy.has_meta(&"untargetable")
	var sent: Array = []
	var net: Node = root.get_node("NetworkManager/PvpNet")
	net.connect("hit_sent", func(v: int, a: float, _c: bool) -> void: sent.append([v, a]))
	if proxy != null:
		for i in range(3):
			proxy.call("take_damage", 40.0)
			await _wait(0.35)
	_checks["pvp_vurus_gitti"] = sent.size() == 3
	_checks["pvp_vurus_tutari"] = str(sent)
	FileAccess.open(_dir.path_join("hit_done.flag"), FileAccess.WRITE).close()


func _flag(name: String) -> void:
	FileAccess.open(_dir.path_join(name), FileAccess.WRITE).close()


func _has_flag(name: String) -> bool:
	return FileAccess.file_exists(_dir.path_join(name))


## İstemci: host'un kuklasının hedeflenebilir vekilini `spot` yakınında bulur (null = bulunamadı).
func _find_proxy(spot: Vector2, timeout: float) -> Node2D:
	var found: Array = []
	await _until(func():
		for cand: Node in get_nodes_in_group("pvp_targets"):
			if (cand as Node2D).global_position.distance_to(spot) < 160.0 and not cand.has_meta(&"untargetable"):
				found.append(cand)
				return true
		return false, timeout)
	return found[0] as Node2D if not found.is_empty() else null


func _pvp_death_phase(p: Node2D, me: int) -> void:
	var rect: Rect2 = _gm.call("get_map_world_rect")
	var spot: Vector2 = rect.get_center()
	if BaseZonesScript.near_any(spot, 400.0):
		spot += Vector2(0, 900.0)
	var net: Node = root.get_node("NetworkManager/PvpNet")
	var my_team: int = TeamsScript.team_of(me)
	if _role == "host":
		await _until(func(): return _has_flag("walk_done.flag"), 40.0)
		p.global_position = spot
		p.reset_physics_interpolation()
		await _wait(1.0)
		p.set("health", 4.0)
		p.set("item_shield_hp", 0.0) ## mana kalkanı darbeyi emmesin
		_flag("death_ready.flag")
		await _until(func(): return _has_flag("kill1_done.flag"), 30.0)
		await _wait(0.6)
		_checks["host_tani"] = "can=%s kalkan=%s olu=%s yerde=%s son_vuran=%s alinan=%s konum=%s revives=%s" % [str(p.get("health")), str(p.get("item_shield_hp")), str(p.get("is_dead")), str(p.get("is_downed")),
				str(p.get("last_pvp_attacker_peer")), str(p.get("match_damage_taken")), str(p.global_position.round()), str(_gm.call("get_peer_revives", me))]
		var cp: int = 0
		for pid in _nm.get("lobby_players"):
			if int(pid) != 1:
				cp = int(pid)
		var vc: Variant = net.call("victim_check", cp)
		var att: Node2D = null
		for rp: Node in get_nodes_in_group("remote_players"):
			if int(rp.get("peer_id")) == cp:
				att = rp as Node2D
		_checks["host_dogrulama"] = "vc=%s savasta=%s mesafe=%s limbo=%s korumali=%s" % [str(vc), str(preload("res://scripts/pvp/pvp_rules.gd").fighting()),
				str(att.global_position.distance_to(p.global_position) if att != null else -1.0), str(p.get("in_limbo")),
				str(preload("res://scripts/pvp/pvp_rules.gd").respawn_protect_pending)]
		_checks["host_alinan_vuruslar"] = str(net.get("hit_log"))
		_checks["olum_yerde"] = bool(p.get("is_downed"))
		_checks["olum_sayaci"] = float(p.call("get_downed_remaining_seconds")) > 0.0
		_checks["host_skor_ilk"] = str(net.get("team_kills"))
		await _until(func(): return not bool(p.get("is_downed")), 15.0)
		_checks["dogdu"] = not bool(p.get("is_downed")) and not bool(p.get("is_dead"))
		_checks["dogdu_tam_can"] = absf(float(p.get("health")) - float(p.get("max_health"))) < 0.5
		_checks["dogdu_ussunde"] = BaseZonesScript.in_own_base(p.global_position, my_team)
		## doğuş koruması: üsten çıkınca 3 sn rakip hasarı yok
		p.global_position = spot
		p.reset_physics_interpolation()
		var dmg0: float = float(p.get("match_damage_taken"))
		_flag("host_out.flag")
		await _until(func(): return _has_flag("prot_hit_done.flag"), 30.0)
		await _wait(0.5)
		_checks["dogus_korumasi_hasar_yok"] = absf(float(p.get("match_damage_taken")) - dmg0) < 0.01
		await _wait(3.6)
		_flag("prot_over.flag")
		await _until(func(): return _has_flag("post_hit_done.flag"), 30.0)
		await _wait(0.5)
		_checks["koruma_sonrasi_hasar_var"] = float(p.get("match_damage_taken")) > dmg0 + 0.01
		## kalıcı ölüm -> eleme: kalpler 0, can 4, istemci bir kez daha vurur
		var pr: Dictionary = _gm.get("peer_revives")
		pr[me] = 0
		p.set("health", 4.0)
		p.set("item_shield_hp", 0.0) ## mana kalkanı darbeyi emmesin
		await _wait(3.4) ## doğuş dokunulmazlığı (3 sn) dolsun
		p.set("health", 4.0)
		p.set("item_shield_hp", 0.0) ## mana kalkanı darbeyi emmesin
		_flag("elim_ready.flag")
		await _until(func(): return int(net.get("winner_team")) != -1, 20.0)
		_checks["host_mac_bitti"] = int(net.get("winner_team"))
		_checks["host_game_over"] = bool(_gm.get("is_game_over"))
		_checks["host_bitis_nedeni"] = str(net.get("end_reason"))
		return
	await _until(func(): return _has_flag("death_ready.flag"), 60.0)
	p.global_position = spot + Vector2(180, 0)
	p.reset_physics_interpolation()
	await _wait(2.5) ## host'taki kuklam ışınlanmayı yumuşakça izler: hemen vurursam host "mesafe çok uzak" diye reddeder (victim_check)
	var proxy: Node2D = await _find_proxy(spot, 20.0)
	_checks["olum_vekil_var"] = proxy != null
	var gold0: int = int(_gm.get("gold"))
	var feed: Array = []
	net.connect("kill_feed", func(k: int, v: int, g: int) -> void: feed.append([k, v, g]))
	var hit_log: Array = []
	net.connect("hit_sent", func(v: int, a: float, _c: bool) -> void: hit_log.append([v, snappedf(a, 0.1)]))
	if proxy != null:
		_checks["olum_tani_oncesi"] = "hittable=%s peer=%s savasta=%s" % [str(proxy.call("_hittable")), str(proxy.get("peer")), str(preload("res://scripts/pvp/pvp_rules.gd").fighting())]
		proxy.call("take_damage", 40.0)
	await _wait(1.2)
	_checks["olum_tani_sonrasi"] = str(hit_log)
	_checks["istemci_skor_ilk"] = str(net.get("team_kills"))
	_checks["istemci_altin_geldi"] = int(_gm.get("gold")) - gold0
	_checks["istemci_bildirim"] = feed.size() >= 1 and int(feed[0][0]) == me
	_flag("kill1_done.flag")
	await _until(func(): return _has_flag("host_out.flag"), 40.0)
	await _wait(0.6)
	proxy = await _find_proxy(spot, 15.0)
	if proxy != null:
		proxy.call("take_damage", 40.0)
		await _wait(0.3)
		proxy.call("take_damage", 40.0)
	_flag("prot_hit_done.flag")
	await _until(func(): return _has_flag("prot_over.flag"), 40.0)
	if proxy != null and is_instance_valid(proxy):
		proxy.call("take_damage", 40.0)
		await _wait(0.3)
		proxy.call("take_damage", 40.0)
	_flag("post_hit_done.flag")
	await _until(func(): return _has_flag("elim_ready.flag"), 40.0)
	await _wait(0.4)
	proxy = await _find_proxy(spot, 10.0)
	if proxy != null:
		proxy.call("take_damage", 40.0)
	await _until(func(): return int(net.get("winner_team")) != -1, 20.0)
	_checks["istemci_mac_bitti"] = int(net.get("winner_team"))
	_checks["istemci_kazandi"] = int(net.get("winner_team")) == my_team
	_checks["istemci_game_over"] = bool(_gm.get("is_game_over"))


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
