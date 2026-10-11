extends Node

## KENAR BEKÇİLERİ (2026-10-09, kullanıcı: "bazı yaratıkların haritanın kenarlarında olmasını istiyorum; özellikle sağ alt kenarında daha tehlikeli sayıda olmalılar.
## Oyuncuları görünce agrolanmalılar. Yerini görünce takip etmeliler; görüş alanının dışına çıkınca bir süre takip etmeli ve bulmaya çalışmalılar").
## Haritanın kenarlarındaki KAMPLARDA (CAMPS; sağ alt = düşman üssü çevresi, 3 büyük kamp) duran yaratıklar. Karar SADECE host/tekli oyunda; main.gd her peer'e ekler ama
## istemcide hiçbir şey yapmaz (yaratıklar ağdan kukla olarak gelir).
##
## Durumlar (yaratık başına): IDLE (kampında gezinir; C++ "uykuda": hiçbir oyuncuyu hedeflemez) -> oyuncuyu GÖRÜNCE (SIGHT içinde + C++ görüş hattı açık, saklı oyuncu sayılmaz)
## CHASE (uykudan çıkar: normal yaratık gibi en yakın oyuncuyu kovalar; aynı kamptaki ALERT_RADIUS içindeki arkadaşlarını da uyandırır) -> kimseyi göremeden MEMORY sn sonra
## SEARCH (son görülen konuma koşar, orada SEARCH_TIME sn dolanıp arar; görürse yine CHASE) -> RETURN (kampa döner; varınca canı dolar) -> IDLE. Kampından LEASH'ten uzağa giden
## kovalamayı bırakıp döner. Hareket C++ EnemyWorld'de (set_dormant + set_goal: uykudaki yaratık hedef noktaya yürür), bu betik sadece karar verir.
## Kamp boşalınca REFILL_DELAY sonra (oyuncular CLEAR_RADIUS dışındayken) o anki kademeden yeniden dolar. Bekçiler "guards" grubundadır: doğuş tavanını doldurmaz,
## kademe kapısını tutmaz (spawn_tier meta'sı yok). Elit değil.

const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

## Kamplar: hücre (Harita karo koordinatı; tools/ analizinde açık alan, yarıçap >= 6 hücre boşluk), bekçi sayısı, dağılma yarıçapı (px), yeniden dolma süresi (sn).
const CAMPS: Array = [
	{"name": "GD-A", "cell": Vector2i(219, 225), "count": 12, "radius": 90.0, "refill": 150.0},   ## düşman üssü çevresi (en tehlikeli)
	{"name": "GD-B", "cell": Vector2i(205, 236), "count": 9, "radius": 80.0, "refill": 150.0},
	{"name": "GD-C", "cell": Vector2i(244, 182), "count": 8, "radius": 80.0, "refill": 150.0},
	{"name": "K", "cell": Vector2i(125, 10), "count": 4, "radius": 60.0, "refill": 210.0},
	{"name": "KB", "cell": Vector2i(19, 13), "count": 4, "radius": 60.0, "refill": 210.0},
	{"name": "KD", "cell": Vector2i(239, 31), "count": 4, "radius": 60.0, "refill": 210.0},
	{"name": "D", "cell": Vector2i(248, 128), "count": 4, "radius": 60.0, "refill": 210.0},
	{"name": "B", "cell": Vector2i(8, 95), "count": 4, "radius": 60.0, "refill": 210.0},
	{"name": "GB", "cell": Vector2i(22, 232), "count": 4, "radius": 60.0, "refill": 210.0},
	{"name": "G", "cell": Vector2i(120, 236), "count": 5, "radius": 60.0, "refill": 210.0},
	{"name": "B2", "cell": Vector2i(8, 170), "count": 4, "radius": 60.0, "refill": 210.0},
]

const TICK := 0.2
const SIGHT := 340.0          ## oyuncuyu görme mesafesi (oyuncunun görüş elipsi ~350)
const ALERT_RADIUS := 420.0   ## uyanan bekçinin kampından uyandırdığı arkadaşların mesafesi
const MEMORY := 4.5           ## kimseyi göremeden kovalamaya devam (sn), sonra SEARCH
const SEARCH_TIME := 7.0      ## son görülen yerde arama süresi (sn); varış en çok ARRIVE_TIMEOUT beklenir
const ARRIVE_TIMEOUT := 6.0
const LEASH := 1000.0         ## kampından bu kadar uzaktaki kovalamayı bırakır
const RETURN_WARP_AFTER := 45.0   ## kampına dönemeyip takılan bekçi (kimse görmüyorsa) buraya ışınlanır
const PATROL_RADIUS := 85.0
const IDLE_SPEED := 0.35
const SEARCH_SPEED := 1.0
const RETURN_SPEED := 0.9
const CLEAR_RADIUS := 800.0   ## yeniden dolmak için oyuncuların kampa en az bu kadar uzak olması
const SPAWN_PER_TICK := 3     ## başlangıçta/yeniden dolmada tick başına en çok doğan bekçi (takılma olmasın)

enum S { IDLE, CHASE, SEARCH, RETURN }

var _camps: Array = []        ## {"def", "center": Vector2, "guards": Array (düğüm), "empty_since": float, "queue": int (doğmayı bekleyen)}
var _g: Dictionary = {}       ## yaratık düğüm kimliği -> {"state", "camp", "home", "last_seen", "timer", "goal_timer", "arrived", "return_time"}
var _acc: float = 0.0
var _inited: bool = false
var _clock: float = 0.0


func _physics_process(delta: float) -> void:
	if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:
		return
	_acc += delta
	if _acc < TICK:
		return
	var dt: float = _acc
	_acc = 0.0
	tick(dt)


## Bir karar adımı (testler doğrudan çağırır).
func tick(dt: float) -> void:
	_clock += dt
	if GameManager.is_game_over:
		return
	if not _inited:
		if not _init_camps():
			return
	var players: Array = _players()
	_refill(players)
	var world: Object = EnemyWorldBridgeScript.fog_world(get_tree()) ## ilk bekçi doğana kadar köprü yok: doğuş buna bakmaz
	if world == null:
		return
	for id: int in _g.keys():
		var e: Object = instance_from_id(id)
		if e == null or not is_instance_valid(e) or e.get("is_dead") == true:
			_g.erase(id)
			continue
		_think(e as Node2D, _g[id], dt, world, players)


## Kamp merkezlerini dünya konumuna çevirir ve ilk doğuşu kuyruğa alır. Harita/spawner henüz yoksa false (sonraki tick yeniden dener).
func _init_camps() -> bool:
	var layer: TileMapLayer = GameManager.get_forest_layer()
	var spawner: Node = _spawner()
	if layer == null or spawner == null:
		return false
	for def: Dictionary in CAMPS:
		var center: Vector2 = layer.to_global(layer.map_to_local(def["cell"]))
		_camps.append({"def": def, "center": center, "guards": [], "empty_since": -1.0, "queue": int(def["count"])})
	_inited = true
	return true


func _spawner() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var s: Node = scene.get_node_or_null("EnemySpawner")
	return s if s != null and s.has_method("spawn_guard") else null


## Hedeflenebilir oyuncular: yerel + uzak; ölü/yerde yatan/içerideki/görünmez/çalıda SAKLI olanlar hariç.
func _players() -> Array:
	var out: Array = []
	var tree: SceneTree = get_tree()
	var cands: Array = []
	var lp: Node = tree.get_first_node_in_group("player")
	if lp != null:
		cands.append(lp)
	if NetworkManager.is_multiplayer_active:
		cands.append_array(tree.get_nodes_in_group("remote_players"))
	for p: Node in cands:
		if not is_instance_valid(p) or not (p is Node2D):
			continue
		if p.get("is_dead") == true or p.get("is_downed") == true or p.get("is_indoors") == true:
			continue
		if p.has_method("is_invisible_now") and p.is_invisible_now():
			continue
		if p.get("is_invisible") == true:
			continue
		out.append(p)
	return out


func _seen_player(pos: Vector2, players: Array, world: Object) -> Node2D:
	var best: Node2D = null
	var best_d: float = SIGHT
	for p: Node2D in players:
		if int(p.get("brush_state") if p.get("brush_state") != null else 0) == 1:
			continue ## çalıda saklı (kimse görmedi) - bekçi de göremez
		var d: float = pos.distance_to(p.global_position)
		if d < best_d and world.is_los_clear(pos, p.global_position):
			best_d = d
			best = p
	return best


func _refill(players: Array) -> void:
	var spawner: Node = _spawner()
	if spawner == null:
		return
	for camp: Dictionary in _camps:
		var alive: Array = []
		for e: Variant in camp["guards"]:
			if is_instance_valid(e) and (e as Node).get("is_dead") != true:
				alive.append(e)
		camp["guards"] = alive
		var def: Dictionary = camp["def"]
		if int(camp["queue"]) == 0 and alive.is_empty():
			if float(camp["empty_since"]) < 0.0:
				camp["empty_since"] = _clock
			elif _clock - float(camp["empty_since"]) >= float(def["refill"]):
				var near: bool = false
				for p: Node2D in players:
					if p.global_position.distance_to(camp["center"]) < CLEAR_RADIUS:
						near = true
						break
				if not near:
					camp["queue"] = int(def["count"])
					camp["empty_since"] = -1.0
		elif not alive.is_empty():
			camp["empty_since"] = -1.0
		var n: int = mini(int(camp["queue"]), SPAWN_PER_TICK)
		for i in range(n):
			var pos: Variant = _camp_position(camp)
			camp["queue"] = int(camp["queue"]) - 1
			if pos == null:
				continue
			var e: Node = spawner.spawn_guard(pos)
			if e != null:
				camp["guards"].append(e)
				register_guard(e, camp)


## Bir yaratığı bekçi olarak kaydeder (uykuda IDLE). Testler de kullanır.
func register_guard(e: Node2D, camp: Dictionary) -> void:
	_g[e.get_instance_id()] = {"state": S.IDLE, "camp": camp, "home": e.global_position, "last_seen": e.global_position, "timer": 0.0,
			"goal_timer": randf_range(0.5, 3.0), "arrived": false, "return_time": 0.0, "slot_ready": false}


func _camp_position(camp: Dictionary) -> Variant:
	var r: float = float((camp["def"] as Dictionary)["radius"])
	for _i in range(12):
		var p: Vector2 = (camp["center"] as Vector2) + Vector2.from_angle(randf() * TAU) * randf_range(0.0, r)
		if not GameManager.is_position_blocked_by_walls(p):
			return p
	return null


func _slot(e: Object) -> int:
	var v: Variant = e.get("_ew_slot")
	return int(v) if v != null else -1


func _think(e: Node2D, g: Dictionary, dt: float, world: Object, players: Array) -> void:
	var slot: int = _slot(e)
	if slot < 0:
		return ## henüz C++'a kayıtlı değil (kayıt bir sonraki adımda)
	if not bool(g["slot_ready"]):
		g["slot_ready"] = true
		_enter(e, g, slot, world, S.IDLE)
	var pos: Vector2 = e.global_position
	var seen: Node2D = _seen_player(pos, players, world)
	var state: int = int(g["state"])
	if seen != null:
		g["last_seen"] = seen.global_position
		g["timer"] = 0.0
		if state != S.CHASE:
			_enter(e, g, slot, world, S.CHASE)
			_alert_pack(e, g)
		return
	match state:
		S.IDLE:
			_patrol(e, g, slot, world, dt, g["home"], IDLE_SPEED)
		S.CHASE:
			g["timer"] = float(g["timer"]) + dt
			if pos.distance_to(g["home"]) > LEASH:
				_enter(e, g, slot, world, S.RETURN)
			elif float(g["timer"]) >= MEMORY:
				_enter(e, g, slot, world, S.SEARCH)
		S.SEARCH:
			g["timer"] = float(g["timer"]) + dt
			if not bool(g["arrived"]):
				if pos.distance_to(g["last_seen"]) <= 40.0 or float(g["timer"]) >= ARRIVE_TIMEOUT:
					g["arrived"] = true
					g["timer"] = 0.0
			else:
				_patrol(e, g, slot, world, dt, g["last_seen"], 0.55, 110.0)
				if float(g["timer"]) >= SEARCH_TIME:
					_enter(e, g, slot, world, S.RETURN)
		S.RETURN:
			g["return_time"] = float(g["return_time"]) + dt
			if pos.distance_to(g["home"]) <= 40.0:
				_heal(e)
				_enter(e, g, slot, world, S.IDLE)
			elif float(g["return_time"]) >= RETURN_WARP_AFTER and _seen_player(pos, players, world) == null:
				var far: bool = true
				for p: Node2D in players:
					if p.global_position.distance_to(pos) < 500.0:
						far = false
						break
				if far:
					e.global_position = g["home"]
					world.set_position(slot, g["home"])
					_heal(e)
					_enter(e, g, slot, world, S.IDLE)


func _enter(e: Node2D, g: Dictionary, slot: int, world: Object, state: int) -> void:
	g["state"] = state
	g["timer"] = 0.0
	g["arrived"] = false
	g["return_time"] = 0.0
	g["goal_timer"] = 0.0
	match state:
		S.CHASE:
			world.set_goal(slot, 0.0, 0.0, 0.0)
			world.set_dormant(slot, false)
		S.SEARCH:
			world.set_dormant(slot, true)
			var ls: Vector2 = g["last_seen"]
			world.set_goal(slot, ls.x, ls.y, SEARCH_SPEED)
		S.RETURN:
			world.set_dormant(slot, true)
			var h: Vector2 = g["home"]
			world.set_goal(slot, h.x, h.y, RETURN_SPEED)
		_:
			world.set_dormant(slot, true)
			world.set_goal(slot, 0.0, 0.0, 0.0)


## Uykudaki bekçi `center` çevresinde rastgele noktalara yavaşça gezinir (bazen durur).
func _patrol(e: Node2D, g: Dictionary, slot: int, world: Object, dt: float, center: Vector2, speed_mult: float, radius: float = PATROL_RADIUS) -> void:
	g["goal_timer"] = float(g["goal_timer"]) - dt
	if float(g["goal_timer"]) > 0.0:
		return
	g["goal_timer"] = randf_range(2.5, 5.0)
	if randf() < 0.3:
		world.set_goal(slot, 0.0, 0.0, 0.0)
		return
	for _i in range(6):
		var p: Vector2 = center + Vector2.from_angle(randf() * TAU) * randf_range(radius * 0.3, radius)
		if not GameManager.is_position_blocked_by_walls(p):
			world.set_goal(slot, p.x, p.y, speed_mult)
			return


## Uyanan bekçi aynı kamptaki uyuyan/arayan/dönen arkadaşlarını (ALERT_RADIUS içinde) kovalamaya çağırır.
func _alert_pack(src: Node2D, sg: Dictionary) -> void:
	var world: Object = EnemyWorldBridgeScript.fog_world(get_tree())
	if world == null:
		return
	for id: int in _g.keys():
		var g: Dictionary = _g[id]
		if g["camp"] != sg["camp"] or int(g["state"]) == S.CHASE:
			continue
		var o: Object = instance_from_id(id)
		if o == null or not is_instance_valid(o) or not (o is Node2D) or o == src:
			continue
		if (o as Node2D).global_position.distance_to(src.global_position) > ALERT_RADIUS:
			continue
		var slot: int = _slot(o)
		if slot < 0:
			continue
		g["last_seen"] = sg["last_seen"]
		_enter(o as Node2D, g, slot, world, S.CHASE)


func _heal(e: Node2D) -> void:
	if e.get("max_health") != null:
		e.set("health", e.get("max_health"))
		if e.has_signal("health_changed"):
			e.health_changed.emit(e.get("health"), e.get("max_health"))


## Durumu (testler/hata ayıklama): yaratık düğümü -> S.*; kayıtlı değilse -1.
func state_of(e: Object) -> int:
	if e == null:
		return -1
	var g: Variant = _g.get(e.get_instance_id())
	return int(g["state"]) if g != null else -1
