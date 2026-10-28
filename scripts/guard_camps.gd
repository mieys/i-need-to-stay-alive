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
const DungeonWorldScript := preload("res://scripts/dungeon/dungeon_world.gd")

## ZİNDAN KAMPLARI (madde 373): zindan haritasındaki her "sakin" nesnesi (oda dikdörtgeni + profil + adet) bir kamp, her zindanın "avci" nesnesi
## bir AVCI (rotası büyük odaları dolaşan elit). Aynı durum makinesi (uykuda dolaşır -> görünce kovalar -> kaybedince arar -> döner); farklar:
## kamp yalnız zindanda bir oyuncu varken DOLAR (DUNGEON_DESPAWN_AFTER sn kimse yoksa sakinler silinir, sayıları hatırlanır), görme mesafesi
## kısa (karanlık), yalnız AYNI zindandaki oyuncuyu görür, arkadaşlarını DUNGEON_ALERT içinde uyandırır (oda uyanır). Avcı uykuda rotasını yürür,
## görünce hızlanır (HUNTER_RAGE) ve gördüğü oyuncuya kırmızı uyarı gider (DungeonManager.hunter_alert); uzun hatırlar, geniş arar, dönerken
## rotasına döner. Kaçış: duvarlar görüşü keser (C++ is_los_clear), kapanan kapılar yolu keser, saklanma yerleri (hide_brush) görünmez yapar.
const DUNGEON_DESPAWN_AFTER := 150.0
## Zindan sakinleri YALNIZ oyuncuya yakın odalarda yaşar (madde 376: girişte tüm zindanın ~96 sakini birden doğuyordu -> dışarıdakilerle
## 200+ yaratık + giriş takılması). Kamp merkezine WAKE px'ten yakın oyuncu varsa uyanır; SLEEP px'ten uzakta SLEEP_AFTER sn kalınca
## (kovalayan/arayan sakini yoksa) sakinleri kalkar, canlı sayısı hatırlanır. Avcı tüm zindanda dolaşır (zindan doluyken hep açık).
const DUNGEON_WAKE_DIST := 720.0 ## görüş sisinin (~450 px) ötesinde doğar: göz önünde belirmez
const DUNGEON_SLEEP_DIST := 1050.0
const DUNGEON_SLEEP_AFTER := 8.0
const DUNGEON_SPAWN_BUDGET := 2 ## tik başına tüm zindan kamplarında en çok bu kadar doğuş (aynı kare yığılması yok)
const DUNGEON_REFILL := 240.0
const DUNGEON_SIGHT := 280.0
const DUNGEON_ALERT := 300.0
const DUNGEON_MEMORY := 4.0
const DUNGEON_LEASH := 900.0
const HUNTER_SIGHT := 340.0
const HUNTER_MEMORY := 7.5
const HUNTER_SEARCH := 11.0
const HUNTER_LEASH := 99999.0
const HUNTER_IDLE_SPEED := 0.6
const HUNTER_RAGE := 1.22
const HUNTER_RESPAWN := 300.0

## Kamplar: hücre (Harita karo koordinatı; tools/ analizinde açık alan, yarıçap >= 6 hücre boşluk), bekçi sayısı, dağılma yarıçapı (px), yeniden dolma süresi (sn).
## İsteğe bağlı: "alert" (uyanan bekçinin arkadaşlarını uyandırma yarıçapı px, 0 = kimseyi çağırmaz; yoksa ALERT_RADIUS) ve "ahead" = [p1, p2]: bekçinin o anki kademenin 1 / 2
## kademe ÖTESİNDEN doğma olasılığı (kalanı o anki kademeden; kademe 15'te kısılır, bkz. enemy_spawner.gd spawn_guard).
## SAĞ ALT TEHLİKELİ BÖLGE (2026-10-14, kullanıcı: "haritanın sağ alt kısmı çok tehlikeli olsun, çok sayıda düşman, haritayı gezmesinler, bizi görenler gelsin - hepsi bir anda
## değil, sonraki kademeden yaratıklar da olabilir"): GD-* kampları (7 kamp, 106 bekçi), `alert` 0 (SADECE görenler kovalar), `ahead` karışımı. Eskiden 3 kamp / 29 bekçi.
const CAMPS: Array = [
	{"name": "GD-A", "cell": Vector2i(219, 225), "count": 24, "radius": 130.0, "refill": 150.0, "alert": 0.0, "ahead": [0.45, 0.25]},   ## düşman üssü çevresi (en tehlikeli)
	{"name": "GD-B", "cell": Vector2i(205, 236), "count": 16, "radius": 110.0, "refill": 150.0, "alert": 0.0, "ahead": [0.4, 0.2]},
	{"name": "GD-C", "cell": Vector2i(244, 182), "count": 14, "radius": 100.0, "refill": 150.0, "alert": 0.0, "ahead": [0.4, 0.15]},
	{"name": "GD-D", "cell": Vector2i(201, 195), "count": 16, "radius": 130.0, "refill": 150.0, "alert": 0.0, "ahead": [0.4, 0.15]},
	{"name": "GD-E", "cell": Vector2i(174, 219), "count": 14, "radius": 130.0, "refill": 150.0, "alert": 0.0, "ahead": [0.4, 0.15]},
	{"name": "GD-F", "cell": Vector2i(240, 219), "count": 12, "radius": 110.0, "refill": 150.0, "alert": 0.0, "ahead": [0.4, 0.15]},
	{"name": "GD-G", "cell": Vector2i(192, 171), "count": 10, "radius": 100.0, "refill": 150.0, "alert": 0.0, "ahead": [0.35, 0.1]},
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


func _ready() -> void:
	add_to_group(&"guard_camps")


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
	_ensure_dungeon_camps()
	var players: Array = _players()
	_update_dungeon_activity(players, dt)
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


func _seen_player(pos: Vector2, players: Array, world: Object, sight: float = SIGHT, dungeon: String = "") -> Node2D:
	var best: Node2D = null
	var best_d: float = sight
	for p: Node2D in players:
		if int(p.get("brush_state") if p.get("brush_state") != null else 0) == 1:
			continue ## çalıda saklı (kimse görmedi) - bekçi de göremez
		if str(p.get("in_dungeon") if p.get("in_dungeon") != null else "") != dungeon:
			continue ## zindan bekçisi yalnız kendi zindanındakini, kenar bekçisi yalnız ana haritadakini görür (madde 373)
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
		if def.has("dungeon"):
			_refill_dungeon_camp(camp, spawner, players)
			continue
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
			var e: Node = spawner.spawn_guard(pos, _roll_ahead(def))
			if e != null:
				camp["guards"].append(e)
				register_guard(e, camp)


## Kampın "ahead" tablosuna göre bu bekçi kaç kademe ötesinden doğsun (0, 1 ya da 2).
func _roll_ahead(def: Dictionary) -> int:
	var table: Array = def.get("ahead", [])
	if table.size() < 2:
		return 0
	var r: float = randf()
	if r < float(table[1]):
		return 2
	if r < float(table[1]) + float(table[0]):
		return 1
	return 0


## Bir yaratığı bekçi olarak kaydeder (uykuda IDLE). Testler de kullanır.
func register_guard(e: Node2D, camp: Dictionary) -> void:
	_g[e.get_instance_id()] = {"state": S.IDLE, "camp": camp, "home": e.global_position, "last_seen": e.global_position, "timer": 0.0,
			"goal_timer": randf_range(0.5, 3.0), "arrived": false, "return_time": 0.0, "slot_ready": false}


func _camp_position(camp: Dictionary) -> Variant:
	var cdef: Dictionary = camp["def"]
	if cdef.has("rect"):
		var rr: Rect2 = cdef["rect"]
		for _i in range(16):
			var q := Vector2(randf_range(rr.position.x + 8.0, rr.end.x - 8.0), randf_range(rr.position.y + 8.0, rr.end.y - 8.0))
			if not GameManager.is_position_blocked_by_walls(q):
				return q
		return null
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
	var cdef: Dictionary = (g["camp"] as Dictionary)["def"]
	var hunter: bool = bool(cdef.get("hunter", false))
	var seen: Node2D = _seen_player(pos, players, world, float(cdef.get("sight", SIGHT)), str(cdef.get("dungeon", "")))
	var state: int = int(g["state"])
	if seen != null:
		g["last_seen"] = seen.global_position
		g["timer"] = 0.0
		if state != S.CHASE:
			_enter(e, g, slot, world, S.CHASE)
			_alert_pack(e, g)
			if hunter:
				_hunter_alert(seen, str(cdef.get("title", "")))
		return
	match state:
		S.IDLE:
			if cdef.has("route"):
				_route_patrol(e, g, slot, world, cdef["route"])
			elif cdef.has("rect"):
				var rr2: Rect2 = cdef["rect"]
				_patrol(e, g, slot, world, dt, rr2.get_center(), IDLE_SPEED, maxf(24.0, minf(rr2.size.x, rr2.size.y) * 0.45))
			else:
				_patrol(e, g, slot, world, dt, g["home"], IDLE_SPEED)
		S.CHASE:
			g["timer"] = float(g["timer"]) + dt
			if pos.distance_to(g["home"]) > float(cdef.get("leash", LEASH)):
				_enter(e, g, slot, world, S.RETURN)
			elif float(g["timer"]) >= float(cdef.get("memory", MEMORY)):
				_enter(e, g, slot, world, S.SEARCH)
		S.SEARCH:
			g["timer"] = float(g["timer"]) + dt
			if not bool(g["arrived"]):
				if pos.distance_to(g["last_seen"]) <= 40.0 or float(g["timer"]) >= ARRIVE_TIMEOUT:
					g["arrived"] = true
					g["timer"] = 0.0
			else:
				_patrol(e, g, slot, world, dt, g["last_seen"], 0.55, 110.0)
				if float(g["timer"]) >= float(cdef.get("search", SEARCH_TIME)):
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
	var cdef: Dictionary = (g["camp"] as Dictionary)["def"]
	if bool(cdef.get("hunter", false)) and world.has_method("set_rage_mult"):
		world.set_rage_mult(slot, HUNTER_RAGE if state == S.CHASE else 1.0)
	if state == S.RETURN and cdef.has("route"):
		g["home"] = _nearest_route_point(e.global_position, cdef["route"])
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


## ---------------------------------------------------------------- zindan kampları (madde 373)

var _dungeon_ready: bool = false
var _dungeon_seen: Dictionary = {} ## zindan id -> içinde oyuncu olan son _clock
var _dungeon_budget: int = 0 ## bu tikte kalan zindan doğuş hakkı


## Zindan verisi kayıtlıysa (DungeonWorld) sakin kamplarını + avcıları bir kez kurar (pasif: oyuncu girince dolar).
func _ensure_dungeon_camps() -> void:
	if _dungeon_ready:
		return
	var ds: Array[Dictionary] = DungeonWorldScript.dungeons()
	if ds.is_empty():
		return
	_dungeon_ready = true
	for e: Dictionary in ds:
		var id: String = str(e["id"])
		var def: Dictionary = e["def"]
		var profiles: Dictionary = def.get("profiles", {})
		var n: int = 0
		for o: Dictionary in (e["data"] as Resource).objects:
			var t: String = str(o.get("type", ""))
			var props: Dictionary = o.get("props", {})
			var wr := Rect2(DungeonWorldScript.local_to_world(id, (o["rect"] as Rect2).position), (o["rect"] as Rect2).size)
			if t == "sakin":
				var prof: String = str(props.get("profil", "oda"))
				var cd := {"name": "%s:%d" % [id, n], "dungeon": id, "rect": wr, "count": int(props.get("adet", 3)), "radius": wr.size.length() * 0.5,
						"refill": DUNGEON_REFILL, "alert": DUNGEON_ALERT, "ids": profiles.get(prof, profiles.get("oda", ["iskelet1"])),
						"ahead": 1 if prof == "kalp" else 0, "sight": DUNGEON_SIGHT, "memory": DUNGEON_MEMORY, "leash": DUNGEON_LEASH}
				_camps.append({"def": cd, "center": wr.get_center(), "guards": [], "empty_since": -1.0, "queue": 0, "active": false, "remember": int(cd["count"])})
				n += 1
			elif t == "avci":
				var route: Array = []
				for part: String in str(props.get("rota", "")).split(";", false):
					var xy: PackedStringArray = part.split(",")
					if xy.size() == 2:
						route.append(DungeonWorldScript.local_to_world(id, Vector2(float(xy[0]), float(xy[1]))))
				var hd: Dictionary = def.get("hunter", {})
				var cd2 := {"name": "%s:avci" % id, "dungeon": id, "rect": wr.grow(24.0), "count": 1, "radius": 40.0, "refill": HUNTER_RESPAWN,
						"alert": 0.0, "ids": [str(hd.get("id", "iskelet3"))], "ahead": 2, "hunter": true, "title": str(hd.get("name", "Avcı")),
						"route": route, "sight": HUNTER_SIGHT, "memory": HUNTER_MEMORY, "search": HUNTER_SEARCH, "leash": HUNTER_LEASH}
				_camps.append({"def": cd2, "center": wr.get_center(), "guards": [], "empty_since": -1.0, "queue": 0, "active": false, "remember": 1})


## DungeonManager girişte çağırır (host'ta hemen dolsun; istemcide etkisiz).
func notify_dungeon_entered(id: String) -> void:
	_dungeon_seen[id] = _clock


func _update_dungeon_activity(players: Array, _dt: float) -> void:
	if not _dungeon_ready:
		return
	for p: Node2D in players:
		var d: String = str(p.get("in_dungeon") if p.get("in_dungeon") != null else "")
		if d != "":
			_dungeon_seen[d] = _clock
	_dungeon_budget = DUNGEON_SPAWN_BUDGET
	for camp: Dictionary in _camps:
		var def: Dictionary = camp["def"]
		if not def.has("dungeon"):
			continue
		var id: String = str(def["dungeon"])
		var occupied: bool = _clock - float(_dungeon_seen.get(id, -9999.0)) < DUNGEON_DESPAWN_AFTER
		if occupied and not bool(def.get("hunter", false)):
			## oda kampı: yakınlık kuralı (avcı zindan doluyken hep açık)
			var near_d: float = 1.0e9
			for p: Node2D in players:
				if str(p.get("in_dungeon") if p.get("in_dungeon") != null else "") == id:
					near_d = minf(near_d, p.global_position.distance_to(camp["center"]))
			if near_d < DUNGEON_WAKE_DIST:
				camp["far_since"] = -1.0
			elif near_d > DUNGEON_SLEEP_DIST and bool(camp["active"]) and not _camp_engaged(camp):
				if float(camp.get("far_since", -1.0)) < 0.0:
					camp["far_since"] = _clock
				occupied = _clock - float(camp["far_since"]) < DUNGEON_SLEEP_AFTER
			elif not bool(camp["active"]):
				occupied = false
			else:
				camp["far_since"] = -1.0  ## orta bantta / kovalarken: uyku sayacı sıfırlanır
		if occupied and not bool(camp["active"]):
			camp["active"] = true
			camp["queue"] = int(camp["remember"])
			camp["empty_since"] = -1.0
			camp["far_since"] = -1.0
		elif not occupied and bool(camp["active"]):
			## kimse yok: sakinleri kaldır (canlı sayısını hatırla), oyuncu dönünce aynı sayıda yeniden doğar
			camp["active"] = false
			var alive: int = 0
			for e: Variant in camp["guards"]:
				if is_instance_valid(e) and (e as Node).get("is_dead") != true:
					alive += 1
					_g.erase((e as Object).get_instance_id())
					_despawn(e as Node)
			camp["guards"] = []
			camp["remember"] = alive + int(camp["queue"])
			camp["queue"] = 0


## Kampın bir sakini kovalıyor / arıyor mu (uyutma onu ortadan kaldırmasın).
func _camp_engaged(camp: Dictionary) -> bool:
	for e: Variant in camp["guards"]:
		if is_instance_valid(e):
			var g: Variant = _g.get((e as Object).get_instance_id())
			if g != null and int(g["state"]) in [S.CHASE, S.SEARCH]:
				return true
	return false


func _despawn(e: Node) -> void:
	var dm: Node = get_tree().get_first_node_in_group(&"dungeon_manager")
	if dm != null and dm.has_method("despawn_enemy"):
		dm.call("despawn_enemy", e)
	else:
		e.queue_free()


func _refill_dungeon_camp(camp: Dictionary, spawner: Node, players: Array) -> void:
	var def: Dictionary = camp["def"]
	if not bool(camp["active"]):
		return
	if (camp["guards"] as Array).is_empty() and int(camp["queue"]) == 0:
		if float(camp["empty_since"]) < 0.0:
			camp["empty_since"] = _clock
		elif _clock - float(camp["empty_since"]) >= float(def["refill"]):
			var near: bool = false
			for p: Node2D in players:
				if p.global_position.distance_to(camp["center"]) < 420.0:
					near = true
					break
			if not near:
				camp["queue"] = int(def["count"])
				camp["empty_since"] = -1.0
	elif not (camp["guards"] as Array).is_empty():
		camp["empty_since"] = -1.0
	if not spawner.has_method("spawn_dungeon_creature"):
		return
	var n: int = mini(mini(int(camp["queue"]), SPAWN_PER_TICK), _dungeon_budget)
	_dungeon_budget -= n
	for i in range(n):
		camp["queue"] = int(camp["queue"]) - 1
		var pos: Variant = _camp_position(camp)
		if pos == null:
			continue
		var e: Node = spawner.spawn_dungeon_creature(_pick_dungeon_id(def), pos, int(def.get("ahead", 0)), bool(def.get("hunter", false)), str(def["dungeon"]))
		if e != null:
			if bool(def.get("hunter", false)):
				e.set_meta("dungeon_hunter", true)
			camp["guards"].append(e)
			register_guard(e, camp)


## Profil listesi zayıftan güçlüye: koşunun kademesi ilerledikçe listenin daha derini açılır.
func _pick_dungeon_id(def: Dictionary) -> String:
	var ids: Array = def.get("ids", [])
	if ids.is_empty():
		return "iskelet1"
	if bool(def.get("hunter", false)):
		return str(ids[0])
	var depth: int = clampi(1 + int(GameManager.run_max_tier) / 3, 1, ids.size())
	return str(ids[randi() % depth])


## Avcı uykudayken rotasını sırayla yürür (bir sonraki noktaya varınca ilerler).
func _route_patrol(e: Node2D, g: Dictionary, slot: int, world: Object, route: Array) -> void:
	if route.is_empty():
		return
	var i: int = int(g.get("route_i", 0)) % route.size()
	var target: Vector2 = route[i]
	if e.global_position.distance_to(target) < 36.0 or float(g["goal_timer"]) > 40.0:
		i = (i + 1) % route.size()
		g["route_i"] = i
		g["goal_timer"] = 0.0
		target = route[i]
	g["goal_timer"] = float(g["goal_timer"]) + TICK
	world.set_goal(slot, target.x, target.y, HUNTER_IDLE_SPEED)


func _nearest_route_point(p: Vector2, route: Array) -> Vector2:
	var best: Vector2 = p
	var bd: float = INF
	for q: Vector2 in route:
		var d: float = p.distance_to(q)
		if d < bd:
			bd = d
			best = q
	return best


func _hunter_alert(seen: Node2D, title: String) -> void:
	var dm: Node = get_tree().get_first_node_in_group(&"dungeon_manager")
	if dm != null and dm.has_method("hunter_alert"):
		dm.call("hunter_alert", seen, title)


## Uyanan bekçi aynı kamptaki uyuyan/arayan/dönen arkadaşlarını (kampın "alert" yarıçapı, yoksa ALERT_RADIUS içinde) kovalamaya çağırır.
## Sağ alt tehlikeli bölgede "alert" 0: arkadaşlarını ÇAĞIRMAZ, yalnız oyuncuyu kendi gören (SIGHT + görüş hattı) bekçiler kovalar.
func _alert_pack(src: Node2D, sg: Dictionary) -> void:
	var alert: float = float(((sg["camp"] as Dictionary)["def"] as Dictionary).get("alert", ALERT_RADIUS))
	if alert <= 0.0:
		return
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
		if (o as Node2D).global_position.distance_to(src.global_position) > alert:
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
