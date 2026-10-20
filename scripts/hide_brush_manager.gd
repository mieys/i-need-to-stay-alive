extends Node

## SAKLANMA ÇALILIĞI kuralları. Alan: hide_brush.gd. main.gd her peer'e bir tane ekler.
## 2026-10-09 ilk kural ("yaratıklar görürken girersek onlar da çalıya girip bizi görebilmeli") madde 283'de (2026-10-19) DEĞİŞTİ - kullanıcı: "oyuncular çalıya girdiğinde
## silahları içine çekilip kapansın; karakterin etrafında yuvarlak bir sınır (LoL Twitch Q gibi), dışındaki yaratıklar onu görmeyecek, içine girenler görüp saldırabilir;
## karakter çalıya girince onu kovalayan yaratıklar kovalamayı durdurup öndekilerin kafası karışacak, üstlerinde soru işareti çıkacak, etrafı arayacaklar (birkaçı çalıya da
## girebilir); halkayı geçen onu görüp herkesin saldırmasını sağlar". Kullanıcı seçimleri: halka ~36 px, sadece ÖNDEKİ kovalayanlar arar, alarm = arayanlar + ~420 px
## çevresi, hasar veren yetenek saklılığı bozar.
##
## KARAR SADECE HOST'TA (tek oyunculuda yerel), 0,1 sn'de bir; yerel oyuncu + uzak oyuncu kuklaları:
##  - ÇALIYA GİRİŞ: oyuncu her zaman SAKLI girer. Onu KOVALAYAN (C++ hedefi bu oyuncu olan) yaratıklardan FRONT_RADIUS içindekiler "arayanlar" olur: C++'ta uyutulur
##    (set_dormant: kimseyi hedeflemez) ve son görülen yerin çevresinde rastgele noktalara yürütülür (set_goal; en yakın BRUSH_SEARCHERS tanesi çalılığın İÇİNDE
##    arar), başlarında "?" (enemy.gd set_brush_search_visual, istemcilere yayınlanır). SEARCH_TIME sonra bırakılır (normal yapay zekâ; saklı oyuncuyu yine hedefleyemez).
##    Geridekiler hiçbir şey yapmaz: C++ stealth onları zaten hedefsiz bırakır (başka oyuncuya gider / dolaşır).
##  - ALGI HALKASI: oyuncunun ayağından RING_RADIUS içine giren HER yaratık (arayan ya da değil) onu GÖRÜR -> ALARM: o yaratık + bu oyuncuyu arayan herkes + görenin
##    ALARM_RADIUS çevresindeki yaratıklar "görenler" listesine yazılır (C++ set_stealth: sadece onlar hedefleyebilir), arama biter, görende "!". Oyuncu "görüldü" (2).
##  - HASAR VEREN YETENEK (hide_brush.gd note_skill_hit -> request_reveal / istemciden NetworkManager.request_brush_reveal): görenler = SPOT_RADIUS içinde görüş hattı açık
##    yaratıklar + arayanlar (aynı alarm).
##  - Arayan yaratık hasar alırsa ya da saklı olmayan bir oyuncu RELEASE_NEAR_PLAYER yakınına gelirse aramayı bırakır (normal savaşa döner).
##  - Çalıdan çıkınca / ölünce / içeri girince: arama biter, kayıt silinir; yeniden girişte yeniden hesaplanır. Bekçiler ("guards", guard_camps.gd kendi aramasını yapar) ve
##    bosslar ARAMAZ (ama halkaya girerlerse görür).
## Durum her peer'in kendi ekranında: saydamlık + can barı simgesi (madde 275) + silahların içe çekilmesi + halka (brush_ring_fx.gd, sadece sahibinde) (NetworkManager.sync_brush_state,
## yalnız değişince + 2 sn'de bir yeniden). BİLİNÇLİ KAPSAM DIŞI: alan hasarı/mermi isabeti, Yeraltı Canavarı uzuv yönetmeni (oyuncu konumlarına bakar).

const HideBrushScript := preload("res://scripts/hide_brush.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const TICK := 0.1
const RESYNC := 2.0
## Yetenekle açığa çıkınca "gören" yaratık mesafesi (oyuncunun görüş elipsi 250 x 1,4 = 350; guard_camps.gd SIGHT ile aynı) VE görüş hattı açık olmalı.
const SPOT_RADIUS := 340.0
const RING_RADIUS := HideBrushScript.RING_RADIUS
## "Öndeki kovalayanlar" (kullanıcı seçimi): girişte seni kovalayıp bu mesafedeki yaratıklar arar.
const FRONT_RADIUS := 300.0
## Alarm: halkada gören yaratığın bu çevresindeki yaratıklar da saldırır (guard_camps.gd ALERT_RADIUS ile aynı).
const ALARM_RADIUS := 420.0
const SEARCH_TIME_MIN := 6.0
const SEARCH_TIME_MAX := 8.5
const SEARCH_SPEED := 0.75 ## C++ goal_mult (temkinli arama)
const BRUSH_SEARCHERS := 2 ## en yakın bu kadar arayan çalılığın İÇİNDE arar ("birkaç tanesi çalıya da girebilir")
const SEARCH_NEAR := Vector2(40.0, 130.0) ## çalı dışı arama noktası: son görülen yerden uzaklık aralığı
const SEARCH_IN_BRUSH := Vector2(18.0, 80.0)
const GOAL_EVERY := Vector2(1.3, 2.4)
const ARRIVE_DIST := 10.0
const RELEASE_NEAR_PLAYER := 160.0
const MAX_ALERT_MARKS := 6 ## alarmda en çok bu kadar yaratığın başında "!"

var _acc: float = 0.0
var _resync: float = 0.0
var _clock: float = 0.0
## anahtar (peer id; tekli oyunda 0) -> {"inside", "spotters": {düğüm kimliği: true}, "searchers": {düğüm kimliği: {"until", "goal_t", "goal", "in_brush", "hp"}},
## "last": Vector2 (girişteki ayak noktası), "reveal": bool, "state": int, "node": Node2D}
var _entries: Dictionary = {}
var _stealth_active: bool = false


func _ready() -> void:
	add_to_group("hide_brush_manager")
	NetworkManager.brush_state_received.connect(_apply_state)
	NetworkManager.brush_reveal_requested.connect(request_reveal)


func _exit_tree() -> void:
	if NetworkManager.brush_state_received.is_connected(_apply_state):
		NetworkManager.brush_state_received.disconnect(_apply_state)
	if NetworkManager.brush_reveal_requested.is_connected(request_reveal):
		NetworkManager.brush_reveal_requested.disconnect(request_reveal)
	for key: int in _entries.keys():
		_end_search(_entries[key])


func _is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func _local_key() -> int:
	return multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active else 0


func _physics_process(delta: float) -> void:
	if not _is_authority():
		return
	_acc += delta
	if _acc < TICK:
		return
	var dt: float = _acc
	_acc = 0.0
	_resync += dt
	tick(dt)


## Hasar veren yetenek: bu oyuncunun saklılığı bir sonraki adımda bozulur (sadece host; istemci NetworkManager.request_brush_reveal ile gelir - anahtar = gönderen peer).
func request_reveal(key: int) -> void:
	if not _is_authority():
		return
	if _entries.has(key):
		_entries[key]["reveal"] = true


func request_reveal_local() -> void:
	request_reveal(_local_key())


## Bir kural adımı (testler doğrudan çağırır).
func tick(dt: float = TICK) -> void:
	_clock += dt
	var tree: SceneTree = get_tree()
	if HideBrushScript.layer(tree) == null:
		if not _entries.is_empty() or _stealth_active:
			_clear_all()
		return
	var seen: Dictionary = {}
	var resend: bool = _resync >= RESYNC
	if resend:
		_resync = 0.0
	var players: Array = _players(tree)
	for pair: Array in players:
		var node: Node2D = pair[0]
		var key: int = pair[1]
		seen[key] = true
		var e: Dictionary = _entries.get(key, {"inside": false, "spotters": {}, "searchers": {}, "last": Vector2.ZERO, "reveal": false, "state": 0, "node": node})
		e["node"] = node
		var feet: Vector2 = node.global_position + Vector2(0.0, HideBrushScript.FEET_OFFSET)
		var inside: bool = _eligible(node) and HideBrushScript.contains(tree, feet)
		if inside:
			if not e["inside"]:
				e["spotters"] = {}
				e["last"] = feet
				_start_search(tree, e, node)
			_step_search(tree, e, dt, players)
			if e["reveal"]:
				var all: Dictionary = _spot(tree, feet)
				for id: int in (e["searchers"] as Dictionary).keys():
					all[id] = true
				_alarm(e, all, null)
			for id: int in _spot(tree, feet, RING_RADIUS, false).keys():
				if not (e["spotters"] as Dictionary).has(id):
					_detect(tree, e, id)
			_prune(e["spotters"])
		else:
			if e["inside"]:
				_end_search(e)
			e["spotters"] = {}
		e["reveal"] = false
		e["inside"] = inside
		var state: int = HideBrushScript.STATE_NONE
		if inside:
			state = HideBrushScript.STATE_SPOTTED if not (e["spotters"] as Dictionary).is_empty() else HideBrushScript.STATE_HIDDEN
		if state != int(e["state"]) or (resend and state != 0):
			e["state"] = state
			_publish(key, state)
		_entries[key] = e
	for key: int in _entries.keys():
		if not seen.has(key):
			_end_search(_entries[key])
			if int(_entries[key]["state"]) != 0:
				_publish(key, 0)
			_entries.erase(key)
	_push_stealth()


## ---------- arama ----------

## Girişte: bu oyuncuyu kovalayan (C++ hedefi) ve FRONT_RADIUS içindeki yaratıklar arar; en yakın BRUSH_SEARCHERS tanesi çalının içinde.
func _start_search(tree: SceneTree, e: Dictionary, node: Node2D) -> void:
	var world: Object = EnemyWorldBridgeScript.fog_world(tree)
	var bridge: Node = EnemyWorldBridgeScript._instance
	if world == null or bridge == null or not is_instance_valid(bridge):
		return
	var center: Vector2 = node.global_position
	var found: Array = [] ## [mesafe, yaratık]
	for c: Variant in EnemyQueryScript.candidates(tree, center, FRONT_RADIUS):
		if not _searchable(c):
			continue
		var slot: int = int(c.get("_ew_slot"))
		var ti: int = int(world.get_target(slot))
		if ti < 0 or bridge.target_node(ti) != node:
			continue
		var d: float = center.distance_to((c as Node2D).global_position)
		if d <= FRONT_RADIUS:
			found.append([d, c])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var searchers: Dictionary = e["searchers"]
	for k in found.size():
		var c: Node2D = found[k][1]
		var s: Dictionary = {"until": _clock + randf_range(SEARCH_TIME_MIN, SEARCH_TIME_MAX), "goal_t": 0.0, "goal": Vector2.INF,
				"in_brush": k < BRUSH_SEARCHERS, "hp": float(c.get("health")) if c.get("health") != null else 0.0}
		searchers[c.get_instance_id()] = s
		world.set_dormant(int(c.get("_ew_slot")), true)
		_new_goal(tree, world, c, s, e["last"])
		if c.has_method("set_brush_search_visual"):
			c.set_brush_search_visual(true)


func _searchable(c: Variant) -> bool:
	if c == null or not is_instance_valid(c) or not (c is Node2D) or c.get("is_dead") == true:
		return false
	if not (c as Node).is_in_group("enemies") or (c as Node).is_in_group("guards") or c.get("is_boss") == true:
		return false
	var v: Variant = c.get("_ew_slot")
	return v != null and int(v) >= 0


func _step_search(tree: SceneTree, e: Dictionary, _dt: float, players: Array) -> void:
	var searchers: Dictionary = e["searchers"]
	if searchers.is_empty():
		return
	var world: Object = EnemyWorldBridgeScript.fog_world(tree)
	for id: int in searchers.keys():
		var c: Object = instance_from_id(id)
		if c == null or not is_instance_valid(c) or c.get("is_dead") == true or int(c.get("_ew_slot")) < 0:
			searchers.erase(id)
			continue
		var s: Dictionary = searchers[id]
		var hp: Variant = c.get("health")
		var hurt: bool = hp != null and float(hp) < float(s["hp"]) - 0.01
		if _clock >= float(s["until"]) or hurt or _visible_player_near(c as Node2D, players):
			_release(c)
			searchers.erase(id)
			continue
		var g: Vector2 = s["goal"]
		if _clock >= float(s["goal_t"]) or (g != Vector2.INF and (c as Node2D).global_position.distance_to(g) <= ARRIVE_DIST):
			if world != null:
				_new_goal(tree, world, c as Node2D, s, e["last"])


## Saklı olmayan bir oyuncu yakındaysa arayan ona döner (yoksa arkadaşın dibinde "?" ile dolaşırdı).
func _visible_player_near(c: Node2D, players: Array) -> bool:
	for pair: Array in players:
		var p: Node2D = pair[0]
		var k: int = pair[1]
		if _entries.has(k) and bool(_entries[k]["inside"]):
			continue
		if not _eligible(p):
			continue
		if c.global_position.distance_to(p.global_position) <= RELEASE_NEAR_PLAYER:
			return true
	return false


## Arama noktası: çalının içinde arayanlar son görülen yerin çevresindeki çalılık hücrelerine, diğerleri çalının dışına (duvar/çalı olmayan) yürür.
func _new_goal(tree: SceneTree, world: Object, c: Node2D, s: Dictionary, last: Vector2) -> void:
	s["goal_t"] = _clock + randf_range(GOAL_EVERY.x, GOAL_EVERY.y)
	var want_in: bool = bool(s["in_brush"])
	var rng: Vector2 = SEARCH_IN_BRUSH if want_in else SEARCH_NEAR
	var p: Vector2 = Vector2.INF
	for _i in 10:
		var q: Vector2 = last + Vector2.from_angle(randf() * TAU) * randf_range(rng.x, rng.y)
		if GameManager.is_position_blocked_by_walls(q):
			continue
		if HideBrushScript.contains(tree, q) != want_in:
			continue
		p = q
		break
	if p == Vector2.INF:
		p = last + Vector2.from_angle(randf() * TAU) * randf_range(SEARCH_NEAR.x, SEARCH_NEAR.y)
		if GameManager.is_position_blocked_by_walls(p):
			p = c.global_position
	s["goal"] = p
	world.set_goal(int(c.get("_ew_slot")), p.x, p.y, SEARCH_SPEED)


func _release(c: Object) -> void:
	if c == null or not is_instance_valid(c):
		return
	var world: Object = EnemyWorldBridgeScript.fog_world(get_tree()) if is_inside_tree() else null
	var v: Variant = c.get("_ew_slot")
	if world != null and v != null and int(v) >= 0:
		world.set_goal(int(v), 0.0, 0.0, 0.0)
		world.set_dormant(int(v), false)
	if c.has_method("set_brush_search_visual"):
		c.set_brush_search_visual(false)


func _end_search(e: Dictionary) -> void:
	var searchers: Dictionary = e.get("searchers", {})
	for id: int in searchers.keys():
		_release(instance_from_id(id))
	searchers.clear()


## ---------- görme / alarm ----------

## `id` yaratığı halkaya girdi: o + arayanlar + ALARM_RADIUS çevresi görenler olur; görende "!".
func _detect(tree: SceneTree, e: Dictionary, id: int) -> void:
	var det: Object = instance_from_id(id)
	if det == null or not is_instance_valid(det):
		return
	var all: Dictionary = {id: true}
	for sid: int in (e["searchers"] as Dictionary).keys():
		all[sid] = true
	for nid: int in _spot(tree, (det as Node2D).global_position, ALARM_RADIUS, false).keys():
		all[nid] = true
	_alarm(e, all, det)


func _alarm(e: Dictionary, ids: Dictionary, detector: Object) -> void:
	var spotters: Dictionary = e["spotters"]
	var fresh: Array = []
	for id: int in ids.keys():
		if not spotters.has(id):
			spotters[id] = true
			fresh.append(id)
	_end_search(e)
	var marks: int = 0
	if detector != null and is_instance_valid(detector) and detector.has_method("show_brush_alert"):
		detector.show_brush_alert()
		marks += 1
	for id: int in fresh:
		if marks >= MAX_ALERT_MARKS:
			break
		var o: Object = instance_from_id(id)
		if o == detector or o == null or not is_instance_valid(o) or not o.has_method("show_brush_alert"):
			continue
		o.show_brush_alert()
		marks += 1


## [[düğüm, anahtar], ...]: yerel oyuncu + (çok oyunculuda) uzak oyuncu kukları.
func _players(tree: SceneTree) -> Array:
	var out: Array = []
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p is Node2D and is_instance_valid(local_p):
		out.append([local_p, _local_key()])
	if NetworkManager.is_multiplayer_active:
		for rp: Node in tree.get_nodes_in_group("remote_players"):
			if rp is Node2D and is_instance_valid(rp) and int(rp.get("peer_id")) != 0:
				out.append([rp, int(rp.get("peer_id"))])
	return out


func _eligible(n: Node) -> bool:
	if n.get("is_dead") == true or n.get("is_downed") == true:
		return false
	if n.has_method("is_indoors_now") and n.is_indoors_now():
		return false
	if n.get("is_indoors") == true:
		return false
	return true


## `center` çevresindeki canlı yaratıkların düğüm kimlikleri (anahtar listesi).
func _spot(tree: SceneTree, center: Vector2, radius: float = SPOT_RADIUS, need_los: bool = true) -> Dictionary:
	var out: Dictionary = {}
	var r2: float = radius * radius
	var world: Object = EnemyWorldBridgeScript.fog_world(tree) if need_los else null
	for e: Variant in EnemyQueryScript.candidates(tree, center, radius):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true or not (e as Node).is_in_group("enemies"):
			continue
		if center.distance_squared_to((e as Node2D).global_position) <= r2:
			if world != null and world.has_method("is_los_clear") and not world.is_los_clear((e as Node2D).global_position, center):
				continue
			out[(e as Node).get_instance_id()] = true
	return out


func _prune(spotters: Dictionary) -> void:
	for id: int in spotters.keys():
		var o: Object = instance_from_id(id)
		if o == null or not is_instance_valid(o) or o.get("is_dead") == true:
			spotters.erase(id)


func _publish(key: int, state: int) -> void:
	_apply_state(key, state)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		NetworkManager.sync_brush_state.rpc(key, state)


## C++ hedefleme kaydı: saklı/görülmüş oyuncu -> görebilen yaratıklar. Çalıda kimse yoksa bir kez boşaltılır.
func _push_stealth() -> void:
	var world: Object = EnemyWorldBridgeScript.fog_world(get_tree())
	if world == null or not world.has_method("set_stealth"):
		return
	var ids := PackedInt64Array()
	var reveals: Array = []
	for key: int in _entries.keys():
		var e: Dictionary = _entries[key]
		if int(e["state"]) == HideBrushScript.STATE_NONE or not is_instance_valid(e["node"]):
			continue
		ids.append((e["node"] as Node).get_instance_id())
		var arr := PackedInt64Array()
		for id: int in (e["spotters"] as Dictionary).keys():
			arr.append(id)
		reveals.append(arr)
	if ids.is_empty() and not _stealth_active:
		return
	world.call("set_stealth", ids, reveals)
	_stealth_active = not ids.is_empty()


func _clear_all() -> void:
	for key: int in _entries.keys():
		_end_search(_entries[key])
		if int(_entries[key]["state"]) != 0:
			_publish(key, 0)
	_entries.clear()
	_push_stealth()


## Durumu karaktere yaz (host kendisi + herkesin ağdan aldığı); anahtar yerel oyuncununsa Player, değilse o peer'in kuklası.
func _apply_state(key: int, state: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if key == _local_key():
		var p: Node = tree.get_first_node_in_group("player")
		if p != null and p.has_method("set_brush_state"):
			p.set_brush_state(state)
		return
	for rp: Node in tree.get_nodes_in_group("remote_players"):
		if int(rp.get("peer_id")) == key and rp.has_method("set_brush_state"):
			rp.set_brush_state(state)
