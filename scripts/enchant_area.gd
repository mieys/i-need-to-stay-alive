extends Node2D

## EFSUN ALAN VARLIKLARI - dünyada bir süre duran/hareket eden efsun etkileri. TEK script hem yetkili kopya
## (authoritative = true: hasar/element uygular - kaster oyuncunun makinesi, tepkime/ölüm alanlarında host) hem uzak
## görsel kopya (authoritative = false: aynı çizim, hasar YOK) için kullanılır; spawn() yetkili kopyayı yayınlar, uzakta
## enchant_fx.gd "area" dalı AYNI spawn()'u authoritative=false ile çağırır (bkz. CLAUDE.md "iki ayrı yer" hata sınıfı).
## Hasar take_damage/apply_element üzerinden gider - istemcide bunlar zaten host'a yönlendirilir.
## "follow": true olan alanlar sahibini izler (yetkili kopyada yerel oyuncu, uzak kopyada p["peer"]'in kuklası).
## Türler: poison_cloud, steam_fog, lava, hive, arrow_rain, volcano, tornado, hammer, meteor, flame_cone, line, blade,
## sticky_bomb, turret, bird, orbit_blade, blizzard, black_hole, wolf, electric_cloud, field (daire: tik hasarı + element).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const TornadoFrames := preload("res://assets/fx/buyucu_tornado/loop_frames.tres")
const MeteorScene := preload("res://scenes/fx_meteor_strike.tscn")
const ENCHANT_FX_PATH := "res://scripts/enchant_fx.gd"
const SELF_PATH := "res://scripts/enchant_area.gd"
const HIVE_GROUP := "enchant_hives_local"
const TURRET_GROUP := "enchant_turrets_local"
const PULL_INTERVAL := 0.2 ## kasırga/kara delik çekme aralığı (bkz. _process_tornado)

var kind: String = ""
var p: Dictionary = {}
var authoritative: bool = false

var _t: float = 0.0
var _tick: float = 0.0
var _tick2: float = 0.0
var _seed: int = 0
var _done: bool = false
var _rain_drops: Array = [] ## [zaman, konum, vurdu mu]
var _balls: Array = [] ## [başlangıç, hedef, zaman]
var _hit_cd: Dictionary = {} ## düşman instance_id -> bir sonraki isabete kalan sn
var _hit_once: Dictionary = {} ## blade/line: bir kez vurulanlar
var _in_zone: Dictionary = {} ## blizzard: düşman id -> alanda geçen süre
var _origin: Vector2 = Vector2.ZERO
var _sprite: AnimatedSprite2D = null
var _icon: Sprite2D = null
var _angle: float = 0.0
var _struck: bool = false
var _wolf_target: Node2D = null


static func spawn(tree: SceneTree, area_kind: String, pos: Vector2, params: Dictionary, is_authoritative: bool) -> Node2D:
	if tree == null or tree.current_scene == null or area_kind == "":
		return null
	var a: Node2D = (load(SELF_PATH) as GDScript).new()
	a.kind = area_kind
	a.p = params
	a.authoritative = is_authoritative
	## Konum add_child'DAN ÖNCE: _ready _origin'i (çizgi başlangıcı, çekiç dönüş noktası) global_position'dan okuyor -
	## sonra verilirse (0,0) kalıyordu. Kök sahne orijinde; yine de ağaca girince global olarak bir kez daha yazılır.
	a.position = pos
	tree.current_scene.add_child(a)
	a.global_position = pos
	if is_authoritative and NetworkManager.is_multiplayer_active:
		var net: Dictionary = params.duplicate()
		net["area"] = area_kind
		NetworkManager.broadcast_enchant_fx.rpc("area", pos, net)
	return a


func _fx() -> GDScript:
	return load(ENCHANT_FX_PATH) as GDScript


## Gece ışığının rengi (bkz. night_glow.gd, night_glow_catalog.gd BY_SCRIPT) - alan türüne göre.
func get_night_glow_color() -> Color:
	if p.has("color"):
		return Color(p["color"])
	match kind:
		"poison_cloud":
			return Color(0.55, 0.95, 0.35)
		"hive", "hammer", "turret", "electric_cloud":
			return Color(1.0, 0.9, 0.35)
		"tornado", "arrow_rain", "steam_fog", "blizzard", "wolf":
			return Color(0.85, 0.95, 1.0)
		"black_hole":
			return Color(0.7, 0.45, 1.0)
	return Color(1.0, 0.55, 0.2)


func _ready() -> void:
	z_index = 3 if kind in ["poison_cloud", "lava", "steam_fog", "line", "blizzard", "field"] else 9
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seed = randi()
	_origin = global_position
	_angle = float(p.get("angle", randf() * TAU))
	match kind:
		"hive":
			if authoritative:
				add_to_group(HIVE_GROUP)
		"turret":
			if authoritative:
				add_to_group(TURRET_GROUP)
		"arrow_rain":
			var n: int = int(p.get("count", 20))
			var r: float = float(p.get("radius", 110.0))
			for i in range(n):
				var ang: float = randf() * TAU
				var d: float = sqrt(randf()) * r
				_rain_drops.append([float(p.get("delay", 2.0)) + randf() * 0.8, Vector2(cos(ang), sin(ang)) * d, false])
		"tornado":
			_sprite = AnimatedSprite2D.new()
			_sprite.sprite_frames = TornadoFrames
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_sprite.centered = false
			_sprite.offset = Vector2(-70.0, -95.0) ## bkz. fx_buyucu_tornado.gd - huninin yere değdiği nokta
			_sprite.scale = Vector2(0.6, 0.6)
			add_child(_sprite)
			_sprite.play("loop")
		"hammer":
			var icon_path: String = str(p.get("icon", ""))
			if icon_path != "" and ResourceLoader.exists(icon_path):
				_icon = Sprite2D.new()
				_icon.texture = load(icon_path)
				_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				_icon.scale = Vector2.ONE * float(p.get("icon_scale", p.get("scale", 1.0)))
				add_child(_icon)
	if kind == "line" and float(p.get("instant", 0.0)) > 0.0 and authoritative:
		_line_damage_all(float(p["instant"]))


func _process(delta: float) -> void:
	_t += delta
	for id in _hit_cd.keys():
		_hit_cd[id] = float(_hit_cd[id]) - delta
	if bool(p.get("follow", false)):
		var owner_node: Node2D = _follow_target()
		if owner_node:
			_origin = owner_node.global_position
			if kind != "bird" and kind != "orbit_blade":
				global_position = owner_node.global_position
	match kind:
		"poison_cloud":
			_tick_every(delta, 1.0, _poison_cloud_tick)
		"steam_fog":
			_tick_every(delta, 0.5, _steam_fog_tick)
		"lava":
			_tick_every(delta, 1.0, _lava_tick)
		"hive":
			if _t >= float(p.get("delay", 4.0)):
				explode_hive()
				return
		"arrow_rain":
			_process_arrow_rain()
		"volcano":
			_process_volcano(delta)
		"tornado":
			_process_tornado(delta)
		"hammer":
			_process_hammer(delta)
		"meteor":
			_process_meteor()
		"flame_cone":
			_tick_every(delta, 1.0 / 6.0, _flame_cone_tick)
		"line":
			if float(p.get("tick", 0.0)) > 0.0:
				_tick_every(delta, float(p["tick"]), _line_tick)
			if float(p.get("second_cut", 0.0)) > 0.0 and not _struck and _t >= 1.0:
				_struck = true
				if authoritative:
					_line_damage_all(float(p["second_cut"]))
		"blade":
			_process_blade(delta)
		"sticky_bomb":
			if _t >= float(p.get("delay", 1.0)):
				_explode_sticky()
				return
		"turret":
			_tick_every(delta, float(p.get("interval", 1.0)), _turret_tick)
		"bird", "orbit_blade":
			_process_orbit_thing(delta)
		"blizzard":
			_tick_every(delta, 1.0, _blizzard_tick)
		"black_hole":
			_process_black_hole(delta)
		"wolf":
			_process_wolf(delta)
		"electric_cloud":
			_tick_every(delta, 0.33, _electric_cloud_tick)
		"field":
			_tick_every(delta, float(p.get("tick", 0.5)), _field_tick)
	if _t >= _duration() and not _done:
		_done = true
		_on_expire()
		queue_free()
		return
	queue_redraw()


func _duration() -> float:
	match kind:
		"hive":
			return float(p.get("delay", 4.0)) + 0.1
		"arrow_rain":
			return float(p.get("delay", 2.0)) + 1.2
		"hammer":
			return float(p.get("duration", 1.6))
		"meteor":
			return float(p.get("delay", 1.0)) + 0.6
		"sticky_bomb":
			return float(p.get("delay", 1.0)) + 0.1
		"blade":
			return float(p.get("range", 220.0)) / maxf(1.0, float(p.get("speed", 900.0))) + 0.15
	return float(p.get("duration", 3.0))


func _follow_target() -> Node2D:
	if authoritative:
		return get_tree().get_first_node_in_group("player") as Node2D
	var peer: int = int(p.get("peer", 0))
	if peer > 0 and NetworkManager.has_method("_find_remote_player"):
		return NetworkManager._find_remote_player(peer)
	return null


func _tick_every(delta: float, interval: float, fn: Callable) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick += interval
		if authoritative:
			fn.call()


func _enemies_in(radius: float, at: Vector2 = global_position) -> Array:
	var out: Array = []
	for e in Enemy.get_enemies_near(get_tree(), at, radius):
		if is_instance_valid(e) and not e.is_dead:
			out.append(e)
	return out


func _hit(e: Node, amount: float) -> void:
	if amount > 0.0 and is_instance_valid(e) and e.has_method("take_damage"):
		e.take_damage(amount, false, float(p.get("pen", 0.0)), true)


## Elementi uygula: host (tepkime/ölüm alanları) doğrudan, istemcideki kaster alanı host'a yönlendirerek.
func _elem(e: Node, element_kind: String, params: Dictionary) -> void:
	if not is_instance_valid(e) or not e.has_method("apply_element"):
		return
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host and int(p.get("peer", 0)) > 0:
		e.apply_element_host(element_kind, params, int(p["peer"]))
	else:
		e.apply_element(element_kind, params)


func _on_expire() -> void:
	match kind:
		"bird":
			if bool(p.get("blast", false)):
				_fx().spawn(get_tree(), "explosion", global_position, {"radius": 120.0, "color": Color(1.0, 0.55, 0.2)})
				if authoritative:
					for e in _enemies_in(120.0):
						_hit(e, float(p.get("blast_dmg", 10.0)))
		"turret":
			if bool(p.get("blast", false)):
				_fx().spawn(get_tree(), "spark_ring", global_position, {"radius": 100.0, "color": Color(0.75, 0.9, 1.0)})
				if authoritative:
					for e in _enemies_in(100.0):
						_elem(e, "freeze", {"dur": 2.0})
		"black_hole":
			_fx().spawn(get_tree(), "explosion", global_position, {"radius": 160.0, "color": Color(0.7, 0.45, 1.0)})
			if authoritative:
				for e in _enemies_in(200.0):
					_hit(e, float(p.get("blast", 10.0)))


## ------------------------------------------------------------------ davranışlar (yalnız yetkili kopya)
func _poison_cloud_tick() -> void:
	for e in _enemies_in(float(p.get("radius", 80.0))):
		## Tepkime zincirlemesin diye "sessiz" (bulut kendisi bir tepkime/ölüm etkisinin ürünü olabilir).
		_elem(e, "poison", {"dps": float(p.get("dps", 1.0)), "cap": 200.0, "dur": 6.0, "stacks": 1, "quiet": true})


func _steam_fog_tick() -> void:
	for e in _enemies_in(float(p.get("radius", 80.0))):
		_hit(e, float(p.get("dps", 5.0)) * 0.5)
		_elem(e, "slow", {"pct": 0.4, "dur": 0.8})


func _lava_tick() -> void:
	var bp: Dictionary = {"tick": float(p.get("burn_tick", 1.0)), "dur": float(p.get("burn_dur", 3.0)),
		"max_stacks": int(p.get("max_stacks", 1)), "ap": float(p.get("ap", 0.0)), "rp": float(p.get("rp", 0.0))}
	for e in _enemies_in(float(p.get("radius", 60.0))):
		_elem(e, "burn", bp)
	## Napalm Fişeği V: yanan zeminde duran sahibine saldırı hızı.
	if float(p.get("owner_haste", 0.0)) > 0.0:
		var pl: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if pl and pl.global_position.distance_to(global_position) <= float(p.get("radius", 60.0)) and pl.has_method("enchant_haste"):
			pl.enchant_haste(float(p["owner_haste"]), 1.1)


## Kovan patlaması - süre dolunca ya da sahibi yetenek kullanınca (bkz. player.gd _notify_enchants_skill_used).
func explode_hive() -> void:
	if _done:
		return
	_done = true
	var r: float = float(p.get("radius", 120.0))
	_fx().spawn(get_tree(), "explosion", global_position, {"radius": r * 0.8, "color": Color(1.0, 0.9, 0.35)})
	_fx().spawn(get_tree(), "spark_ring", global_position, {"radius": r, "color": Color(1.0, 0.92, 0.4)})
	if authoritative:
		var sp: Dictionary = p.get("shock", {})
		for e in _enemies_in(r):
			_hit(e, float(p.get("damage", 10.0)))
			if not sp.is_empty():
				_elem(e, "shock", sp)
	queue_free()


func _process_arrow_rain() -> void:
	for drop in _rain_drops:
		if drop[2] or _t < float(drop[0]) + 0.18:
			continue
		drop[2] = true
		var at: Vector2 = global_position + Vector2(drop[1])
		PixelDraw.spawn_burst(get_tree().current_scene, at, "dust", 5, 60.0, 0.3)
		if authoritative:
			for e in _enemies_in(26.0, at):
				_hit(e, float(p.get("damage", 10.0)))


func _process_volcano(delta: float) -> void:
	_tick2 -= delta
	if _tick2 <= 0.0 and _t < float(p.get("duration", 5.0)) - 0.6:
		_tick2 = 0.6
		var ang: float = randf() * TAU
		var target: Vector2 = global_position + Vector2(cos(ang), sin(ang)) * randf_range(40.0, float(p.get("radius", 160.0)))
		_balls.append([global_position + Vector2(0.0, -14.0), target, 0.0])
	for b in _balls:
		b[2] = float(b[2]) + delta
	var landed: Array = []
	for b in _balls:
		if float(b[2]) >= 0.55:
			landed.append(b)
	for b in landed:
		_balls.erase(b)
		var at: Vector2 = Vector2(b[1])
		_fx().spawn(get_tree(), "burst", at, {"palette": "fire", "count": 10, "speed": 90.0, "life": 0.35})
		if authoritative:
			var bp: Dictionary = {"tick": float(p.get("burn_tick", 1.0)), "dur": 3.0, "max_stacks": 1, "ap": float(p.get("ap", 0.0))}
			for e in _enemies_in(40.0, at):
				_hit(e, float(p.get("damage", 10.0)))
				_elem(e, "burn", bp)


func _process_tornado(delta: float) -> void:
	if not bool(p.get("follow", false)):
		var dir: Vector2 = Vector2(p.get("dir", Vector2.RIGHT)).normalized()
		global_position += dir * float(p.get("speed", 150.0)) * delta
	if not authoritative:
		return
	var pull_r: float = float(p.get("radius", 70.0))
	## Çekme 0,2 sn'de bir (istemcide her "knock" host'a bir RPC - her karede düşman başına RPC ağı boğuyordu).
	_tick2 -= delta
	var pull_now: bool = _tick2 <= 0.0
	if pull_now:
		_tick2 = PULL_INTERVAL
	for e in _enemies_in(pull_r):
		var to_c: Vector2 = global_position - e.global_position
		## Sahibini izleyen hortum (Hortum Çarkı) çekmez: merkezi oyuncunun kendisi - düşmanları oyuncunun üstüne sürüklerdi
		## (duman testinde oyuncu 2,5 sn'de öldü). Sadece keser.
		if pull_now and to_c.length() > 6.0 and not e.is_boss and not bool(p.get("follow", false)):
			_elem(e, "knock", {"dir": to_c.normalized(), "dist": minf(40.0, to_c.length()), "quiet": true})
		var id: int = e.get_instance_id()
		if float(_hit_cd.get(id, 0.0)) <= 0.0 and to_c.length() <= pull_r * 0.6:
			_hit_cd[id] = 0.4
			_hit(e, float(p.get("damage", 10.0)))


func _process_hammer(delta: float) -> void:
	var dur: float = float(p.get("duration", 1.6))
	var k: float = clampf(_t / dur, 0.0, 1.0)
	var out: float = sin(k * PI) ## 0 -> 1 -> 0 (gidip döner)
	var dir: Vector2 = Vector2(p.get("dir", Vector2.RIGHT)).normalized()
	global_position = _origin + dir * float(p.get("range", 220.0)) * out
	if _icon:
		_icon.rotation = _t * 14.0
	if not authoritative:
		return
	var hit_r: float = 34.0 * float(p.get("scale", 1.0))
	for e in _enemies_in(hit_r):
		var id: int = e.get_instance_id()
		if float(_hit_cd.get(id, 0.0)) > 0.0:
			continue
		_hit_cd[id] = 0.5
		_hit(e, float(p.get("damage", 10.0)))
		var sp: Dictionary = p.get("shock", {})
		if not sp.is_empty():
			_elem(e, "shock", sp)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		var near: Array = _enemies_in(140.0)
		if not near.is_empty():
			var t: Node = near[randi() % near.size()]
			_fx().play(get_tree(), "chain", global_position, {"to": t.global_position})
			_hit(t, float(p.get("branch", 5.0)))


func _process_meteor() -> void:
	if _struck or _t < float(p.get("delay", 1.0)):
		return
	_struck = true
	var r: float = float(p.get("radius", 110.0))
	var m: Node2D = MeteorScene.instantiate() as Node2D
	get_tree().current_scene.add_child(m)
	if m.has_method("setup"):
		m.setup(global_position)
	else:
		m.global_position = global_position
	_fx().spawn(get_tree(), "explosion", global_position, {"radius": r, "color": Color(1.0, 0.5, 0.18)})
	if not authoritative:
		return
	for e in _enemies_in(r):
		_hit(e, float(p.get("damage", 10.0)))
		if float(p.get("stun", 0.0)) > 0.0:
			_elem(e, "stun", {"dur": float(p["stun"])})
	if bool(p.get("lava", false)):
		spawn(get_tree(), "lava", global_position, {"radius": r * 0.7, "duration": 3.0, "burn_tick": float(p.get("burn_tick", 1.0)),
			"burn_dur": 3.0, "ap": float(p.get("ap", 0.0)), "peer": int(p.get("peer", 0))}, true)


func _cone_dir() -> Vector2:
	return Vector2(p.get("dir", Vector2.RIGHT)).normalized()


func _flame_cone_tick() -> void:
	var r: float = float(p.get("radius", 150.0))
	var half: float = deg_to_rad(float(p.get("half_angle", 28.0)))
	var dir: Vector2 = _cone_dir()
	for e in _enemies_in(r):
		var to_e: Vector2 = e.global_position - global_position
		if to_e.length() < 4.0 or absf(dir.angle_to(to_e)) <= half:
			_hit(e, float(p.get("damage", 5.0)))
			if float(p.get("burn_tick", 0.0)) > 0.0:
				_elem(e, "burn", {"tick": float(p["burn_tick"]), "dur": 2.0, "ap": float(p.get("ap", 0.0)), "quiet": true})


func _line_to() -> Vector2:
	return Vector2(p.get("to", global_position + Vector2.RIGHT * 200.0)) - _origin


func _enemies_on_line(width: float) -> Array:
	var out: Array = []
	var a: Vector2 = _origin
	var b: Vector2 = _origin + _line_to()
	var mid: Vector2 = (a + b) * 0.5
	for e in _enemies_in(a.distance_to(b) * 0.5 + width, mid):
		var cp: Vector2 = Geometry2D.get_closest_point_to_segment(e.global_position, a, b)
		if e.global_position.distance_to(cp) <= width:
			out.append(e)
	return out


func _line_damage_all(amount: float) -> void:
	for e in _enemies_on_line(float(p.get("width", 22.0))):
		_hit(e, amount)
		_line_effect(e)


func _line_tick() -> void:
	for e in _enemies_on_line(float(p.get("width", 22.0))):
		_hit(e, float(p.get("damage", 0.0)))
		_line_effect(e)
	## Enerji Kırbacı: ağın değdiği tecrübe küreleri sahibine çekilir.
	if bool(p.get("collect_xp", false)):
		var my_id: int = multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer() else -1
		var a: Vector2 = _origin
		var b: Vector2 = _origin + _line_to()
		for orb in get_tree().get_nodes_in_group("xp_orbs"):
			if not is_instance_valid(orb) or not orb.has_method("attract_to_player"):
				continue
			if orb.global_position.distance_to(Geometry2D.get_closest_point_to_segment(orb.global_position, a, b)) <= float(p.get("width", 22.0)) + 10.0:
				orb.attract_to_player(my_id)


func _line_effect(e: Node) -> void:
	match str(p.get("mode", "")):
		"fire":
			_elem(e, "burn", {"tick": float(p.get("burn_tick", 1.0)), "dur": 3.0, "ap": float(p.get("ap", 0.0)), "quiet": true})
		"ice":
			if e.get("is_boss") == true:
				_elem(e, "slow", {"pct": 0.5, "dur": 1.0, "boss": true})
			else:
				_elem(e, "freeze", {"dur": 1.5, "quiet": true})
		"shock":
			_elem(e, "shock", {"dur": 3.0, "jump": 0.25, "jumps": 1, "ap": float(p.get("ap", 0.0)), "quiet": true})
		"arcane":
			if bool(p.get("mark", false)):
				_elem(e, "mark", {"stacks": 1, "cap": 20})


func _process_blade(delta: float) -> void:
	var dir: Vector2 = Vector2(p.get("dir", Vector2.RIGHT)).normalized()
	global_position += dir * float(p.get("speed", 900.0)) * delta
	if not authoritative:
		return
	var w: float = float(p.get("width", 26.0))
	for e in _enemies_in(w):
		var id: int = e.get_instance_id()
		if _hit_once.has(id):
			continue
		_hit_once[id] = true
		_hit(e, float(p.get("damage", 10.0)))
		if int(p.get("mark", 0)) > 0:
			_elem(e, "mark", {"stacks": int(p["mark"]), "cap": 20})


func _explode_sticky() -> void:
	if _done:
		return
	_done = true
	var r: float = float(p.get("radius", 60.0))
	_fx().spawn(get_tree(), "explosion", global_position, {"radius": r, "color": Color(1.0, 0.65, 0.25)})
	if authoritative:
		for e in _enemies_in(r):
			if bool(p.get("chain", false)):
				_elem(e, "chain_bomb", {"ap": float(p.get("ap", 10.0)), "dur": 0.6, "gold": float(p.get("gold", 0.03))})
			_hit(e, float(p.get("damage", 10.0)))
			if bool(p.get("burn", false)):
				_elem(e, "burn", {"tick": float(p.get("burn_tick", 1.0)), "dur": 3.0, "ap": float(p.get("ap", 0.0))})
	queue_free()


func _turret_tick() -> void:
	var e: Node = null
	var best: float = INF
	for c in _enemies_in(float(p.get("range", 220.0))):
		var d: float = c.global_position.distance_squared_to(global_position)
		if d < best:
			best = d
			e = c
	if e == null:
		return
	_fx().play(get_tree(), "chain", global_position + Vector2(0.0, -14.0), {"to": e.global_position, "color": Color(p.get("color", Color(1.0, 0.95, 0.5)))})
	_hit(e, float(p.get("damage", 10.0)))
	match str(p.get("element", "")):
		"shock":
			_elem(e, "shock", {"dur": 3.0, "jump": 0.25, "jumps": 1, "ap": float(p.get("ap", 0.0))})
		"slow":
			_elem(e, "slow", {"pct": 0.3, "dur": 1.5})
		"freeze":
			_elem(e, "freeze", {"dur": 1.5})


func _process_orbit_thing(delta: float) -> void:
	var spd: float = float(p.get("orbit_speed", 3.2))
	_angle += spd * delta
	global_position = _origin + Vector2(cos(_angle), sin(_angle)) * float(p.get("orbit_radius", 70.0))
	if not authoritative:
		return
	for e in _enemies_in(float(p.get("touch", 26.0))):
		var id: int = e.get_instance_id()
		if float(_hit_cd.get(id, 0.0)) > 0.0:
			continue
		_hit_cd[id] = 0.6
		var dmg: float = float(p.get("damage", 0.0))
		if dmg > 0.0:
			_hit(e, dmg)
		if float(p.get("burn_tick", 0.0)) > 0.0:
			_elem(e, "burn", {"tick": float(p["burn_tick"]), "dur": 3.0, "ap": float(p.get("ap", 0.0))})
		## Kan Çarkı: kanayan düşmandan can çeker.
		if float(p.get("drain", 0.0)) > 0.0 and dmg > 0.0:
			var pl: Node = get_tree().get_first_node_in_group("player")
			if pl and pl.has_method("heal"):
				pl.heal(dmg * float(p["drain"]))


func _blizzard_tick() -> void:
	var r: float = float(p.get("radius", 120.0))
	var inside: Array = _enemies_in(r)
	var seen: Dictionary = {}
	for e in inside:
		var id: int = e.get_instance_id()
		seen[id] = true
		_in_zone[id] = float(_in_zone.get(id, 0.0)) + 1.0
		_hit(e, float(p.get("damage", 5.0)))
		_elem(e, "slow", {"pct": 0.3, "dur": 1.2})
		if bool(p.get("freeze", false)) and float(_in_zone[id]) >= 2.0:
			_in_zone[id] = 0.0
			_elem(e, "freeze", {"dur": 1.5})
	for id in _in_zone.keys():
		if not seen.has(id):
			_in_zone.erase(id)
	## Kutup Girdabı: içindeki düşman başına can.
	if float(p.get("regen", 0.0)) > 0.0 and not inside.is_empty():
		var pl: Node = get_tree().get_first_node_in_group("player")
		if pl and pl.has_method("heal"):
			pl.heal(minf(3.0, float(p["regen"]) * float(inside.size())))


func _process_black_hole(delta: float) -> void:
	if not authoritative:
		return
	var r: float = float(p.get("radius", 200.0))
	_tick -= delta
	var dmg_now: bool = _tick <= 0.0
	if dmg_now:
		_tick = 0.5
	_tick2 -= delta
	var pull_now: bool = _tick2 <= 0.0
	if pull_now:
		_tick2 = PULL_INTERVAL
	for e in _enemies_in(r):
		var to_c: Vector2 = global_position - e.global_position
		if pull_now and to_c.length() > 10.0 and not e.is_boss:
			_elem(e, "knock", {"dir": to_c.normalized(), "dist": minf(50.0, to_c.length()), "quiet": true})
		if dmg_now:
			_hit(e, float(p.get("dps", 5.0)) * 0.5)
	if bool(p.get("pull_xp", false)) and dmg_now:
		var my_id: int = multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active and multiplayer.has_multiplayer_peer() else -1
		for orb in get_tree().get_nodes_in_group("xp_orbs"):
			if is_instance_valid(orb) and orb.global_position.distance_to(global_position) <= r and orb.has_method("attract_to_player"):
				orb.attract_to_player(my_id)


func _process_wolf(delta: float) -> void:
	if not is_instance_valid(_wolf_target) or _wolf_target.get("is_dead") == true:
		_wolf_target = null
		var best: float = INF
		for e in _enemies_in(320.0):
			var d: float = e.global_position.distance_squared_to(global_position)
			if d < best:
				best = d
				_wolf_target = e
	if _wolf_target:
		var to_t: Vector2 = _wolf_target.global_position - global_position
		if to_t.length() > 22.0:
			global_position += to_t.normalized() * 230.0 * delta
		elif authoritative:
			var id: int = _wolf_target.get_instance_id()
			if float(_hit_cd.get(id, 0.0)) <= 0.0:
				_hit_cd[id] = 0.6
				_hit(_wolf_target, float(p.get("damage", 5.0)))


## Daire alan (elektrik alanı, alev halkası, buz zemini): her tikte içindekilere hasar + "mode" elementi (line ile aynı).
## "ring" > 0 ise sadece o yarıçapın çevresindeki halka (iç yarıçap = radius - ring).
func _field_tick() -> void:
	var r: float = float(p.get("radius", 80.0))
	var inner: float = r - float(p.get("ring", 0.0)) if float(p.get("ring", 0.0)) > 0.0 else -1.0
	for e in _enemies_in(r):
		if inner > 0.0 and e.global_position.distance_to(global_position) < inner:
			continue
		_hit(e, float(p.get("damage", 0.0)))
		_line_effect(e)


func _electric_cloud_tick() -> void:
	var r: float = float(p.get("radius", 120.0))
	var near: Array = _enemies_in(r)
	if near.is_empty():
		return
	var t: Node = near[randi() % near.size()]
	_fx().play(get_tree(), "bolt", t.global_position, {"warn": 0.02})
	for e in _enemies_in(40.0, t.global_position):
		_hit(e, float(p.get("damage", 5.0)))


## ------------------------------------------------------------------ çizim (her iki kopya)
func _draw() -> void:
	var dur: float = _duration()
	var fade: float = clampf(minf(_t / 0.25, (dur - _t) / 0.4), 0.0, 1.0)
	var col: Color = Color(p.get("color", get_night_glow_color()))
	match kind:
		"poison_cloud", "steam_fog":
			var r: float = float(p.get("radius", 80.0))
			var base: Color = Color(0.45, 0.78, 0.25) if kind == "poison_cloud" else Color(0.85, 0.9, 0.95)
			PixelDraw.disc(self, Vector2.ZERO, r, Color(base, 0.16 * fade))
			for i in range(7):
				var ang: float = TAU * PixelDraw.hash01(_seed + i) + _t * 0.4
				var d: float = r * (0.3 + 0.55 * PixelDraw.hash01(_seed + i * 5))
				PixelDraw.disc(self, Vector2(cos(ang), sin(ang)) * d, r * 0.24, Color(base.lightened(0.1), 0.2 * fade))
			PixelDraw.ring(self, Vector2.ZERO, r, Color(base.lightened(0.2), 0.5 * fade), 1, 3, 3, _t * 10.0)
		"lava":
			var rl: float = float(p.get("radius", 60.0))
			PixelDraw.disc(self, Vector2.ZERO, rl, Color(0.55, 0.12, 0.05, 0.45 * fade))
			PixelDraw.disc(self, Vector2.ZERO, rl * 0.7, Color(0.95, 0.38, 0.08, 0.45 * fade))
			for i in range(6):
				var ph: float = fmod(_t * 1.3 + PixelDraw.hash01(_seed + i), 1.0)
				var ang2: float = TAU * PixelDraw.hash01(_seed + i * 3)
				var pos2: Vector2 = Vector2(cos(ang2), sin(ang2)) * rl * 0.6 * PixelDraw.hash01(_seed + i * 9)
				PixelDraw.px(self, pos2 - Vector2(0.0, ph * 6.0), 2, Color(1.0, 0.85, 0.3, (1.0 - ph) * fade))
		"hive":
			var pulse: float = 0.5 + 0.5 * sin(_t * (6.0 + _t * 4.0))
			PixelDraw.disc(self, Vector2(0.0, -6.0), 5.0 + pulse * 2.0, Color(1.0, 0.9, 0.3, 0.9))
			PixelDraw.ring(self, Vector2(0.0, -6.0), 9.0 + pulse * 3.0, Color(1.0, 1.0, 0.7, 0.8), 1, 2, 2, _t * 30.0)
			PixelDraw.ground_shadow(self, Vector2(0.0, 4.0), Vector2(7.0, 3.0))
		"arrow_rain":
			var delay: float = float(p.get("delay", 2.0))
			var rr: float = float(p.get("radius", 110.0))
			if _t < delay + 0.9:
				PixelDraw.ring(self, Vector2.ZERO, rr, Color(1.0, 0.95, 0.8, 0.35 * fade), 1, 3, 3, _t * 12.0)
			for drop in _rain_drops:
				var dt: float = _t - float(drop[0])
				if dt < 0.0 or dt > 0.18:
					continue
				var fall: float = 1.0 - dt / 0.18
				var at: Vector2 = Vector2(drop[1])
				PixelDraw.line(self, at - Vector2(0.0, 36.0 * fall + 10.0), at - Vector2(0.0, 36.0 * fall), Color(0.95, 0.88, 0.7, 1.0), 1)
		"volcano":
			PixelDraw.ground_shadow(self, Vector2.ZERO, Vector2(20.0, 8.0))
			PixelDraw.disc(self, Vector2(0.0, -4.0), 14.0, Color(0.32, 0.2, 0.14, fade))
			PixelDraw.disc(self, Vector2(0.0, -12.0), 6.0, Color(1.0, 0.45 + 0.2 * sin(_t * 9.0), 0.1, fade))
			for b in _balls:
				var k2: float = clampf(float(b[2]) / 0.55, 0.0, 1.0)
				var from: Vector2 = Vector2(b[0]) - global_position
				var to: Vector2 = Vector2(b[1]) - global_position
				var pos3: Vector2 = from.lerp(to, k2) - Vector2(0.0, sin(k2 * PI) * 50.0)
				PixelDraw.px(self, pos3, 3, Color(1.0, 0.55, 0.15, 1.0))
				PixelDraw.px(self, pos3, 1, Color(1.0, 0.95, 0.6, 1.0))
		"tornado":
			PixelDraw.ground_shadow(self, Vector2.ZERO, Vector2(18.0, 7.0))
			if _sprite:
				_sprite.modulate.a = fade
		"hammer":
			PixelDraw.ground_shadow(self, Vector2(0.0, 18.0), Vector2(10.0, 4.0))
			PixelDraw.ring(self, Vector2.ZERO, 16.0, Color(1.0, 0.92, 0.4, 0.7), 1, 2, 2, _t * 40.0)
		"meteor":
			if not _struck:
				var r2: float = float(p.get("radius", 110.0))
				PixelDraw.ring(self, Vector2.ZERO, r2, Color(1.0, 0.45, 0.2, 0.75), 1, 3, 2, _t * 20.0)
				PixelDraw.ring(self, Vector2.ZERO, r2 * clampf(_t / float(p.get("delay", 1.0)), 0.0, 1.0), Color(1.0, 0.6, 0.25, 0.5), 1)
		"flame_cone":
			var rc: float = float(p.get("radius", 150.0))
			var half2: float = deg_to_rad(float(p.get("half_angle", 28.0)))
			var dir2: Vector2 = _cone_dir()
			for i in range(26):
				var hh: float = PixelDraw.hash01(_seed + i * 7 + int(_t * 12.0))
				var dist: float = rc * fmod(hh + _t * 1.7, 1.0)
				var ang5: float = dir2.angle() + (PixelDraw.hash01(_seed + i * 13) * 2.0 - 1.0) * half2 * (dist / rc)
				PixelDraw.px(self, Vector2(cos(ang5), sin(ang5)) * dist, 2 if dist < rc * 0.6 else 1, PixelDraw.fire_color(dist / rc) * Color(1, 1, 1, fade))
		"line":
			var to2: Vector2 = _line_to()
			var n_steps: int = maxi(2, int(to2.length() / 6.0))
			var lc: Color = col
			for i in range(n_steps):
				var q: Vector2 = to2 * (float(i) / float(n_steps))
				var jitter: float = (PixelDraw.hash01(_seed + i + int(_t * 10.0)) - 0.5) * float(p.get("width", 22.0)) * 0.6
				PixelDraw.px(self, q + to2.orthogonal().normalized() * jitter, 2, Color(lc, 0.75 * fade))
		"blade":
			var bdir: Vector2 = Vector2(p.get("dir", Vector2.RIGHT)).normalized()
			var bw: float = float(p.get("width", 26.0))
			for i in range(6):
				var back: Vector2 = -bdir * float(i) * 5.0
				PixelDraw.line(self, back + bdir.orthogonal() * bw * 0.6, back - bdir.orthogonal() * bw * 0.6, Color(col, (1.0 - float(i) / 6.0) * 0.9), 1)
		"sticky_bomb":
			var blink: bool = int(_t * (6.0 + _t * 10.0)) % 2 == 0
			PixelDraw.px(self, Vector2.ZERO, 3, Color(0.35, 0.25, 0.15, 1.0))
			PixelDraw.px(self, Vector2(0.0, -2.0), 1, Color(1.0, 0.3, 0.2, 1.0) if blink else Color(0.4, 0.1, 0.1, 1.0))
		"turret":
			PixelDraw.ground_shadow(self, Vector2(0.0, 6.0), Vector2(9.0, 4.0))
			PixelDraw.rect(self, Vector2(0.0, -6.0), 5, 12, Color(col.darkened(0.3), fade))
			PixelDraw.disc(self, Vector2(0.0, -16.0), 4.0 + sin(_t * 8.0), Color(col, fade))
		"orbit_blade":
			var sc: Color = col
			var spin: float = _t * 16.0
			for k in range(3):
				var a3: float = spin + TAU * float(k) / 3.0
				PixelDraw.line(self, Vector2.ZERO, Vector2(cos(a3), sin(a3)) * 10.0, Color(sc, fade), 2)
			PixelDraw.px(self, Vector2.ZERO, 2, Color(sc.lightened(0.4), fade))
		"field":
			var rf: float = float(p.get("radius", 80.0))
			var ring_w: float = float(p.get("ring", 0.0))
			var fc: Color = col
			if ring_w <= 0.0:
				PixelDraw.disc(self, Vector2.ZERO, rf, Color(fc, 0.14 * fade))
			PixelDraw.ring(self, Vector2.ZERO, rf, Color(fc.lightened(0.2), 0.6 * fade), 1, 3, 2, _t * 14.0)
			if ring_w > 0.0:
				PixelDraw.ring(self, Vector2.ZERO, rf - ring_w, Color(fc, 0.35 * fade), 1, 2, 3, -_t * 10.0)
			for i in range(10):
				var ang8: float = TAU * PixelDraw.hash01(_seed + i) + _t * 0.8
				var lo: float = (rf - ring_w) if ring_w > 0.0 else 0.0
				var d8: float = lerpf(lo, rf, PixelDraw.hash01(_seed + i * 7 + int(_t * 6.0)))
				PixelDraw.px(self, Vector2(cos(ang8), sin(ang8)) * d8, 2, Color(fc.lightened(0.35), 0.8 * fade))
		"bird":
			var flap: float = sin(_t * 18.0)
			var bc: Color = col
			PixelDraw.disc(self, Vector2.ZERO, 5.0, Color(bc, fade))
			PixelDraw.line(self, Vector2(-3.0, 0.0), Vector2(-11.0, -5.0 * flap), Color(bc.lightened(0.3), fade), 2)
			PixelDraw.line(self, Vector2(3.0, 0.0), Vector2(11.0, -5.0 * flap), Color(bc.lightened(0.3), fade), 2)
			PixelDraw.px(self, Vector2(0.0, 0.0), 1, Color(1.0, 1.0, 0.8, fade))
		"blizzard":
			var rb: float = float(p.get("radius", 120.0))
			PixelDraw.ring(self, Vector2.ZERO, rb, Color(0.85, 0.95, 1.0, 0.45 * fade), 1, 3, 3, _t * 14.0)
			for i in range(18):
				var ang6: float = TAU * PixelDraw.hash01(_seed + i) + _t * (1.5 + PixelDraw.hash01(_seed + i * 3))
				var d6: float = rb * (0.2 + 0.8 * PixelDraw.hash01(_seed + i * 11))
				PixelDraw.px(self, Vector2(cos(ang6), sin(ang6)) * d6, 1, Color(1.0, 1.0, 1.0, 0.85 * fade))
		"black_hole":
			var rh: float = float(p.get("radius", 200.0))
			PixelDraw.disc(self, Vector2.ZERO, 16.0 + 3.0 * sin(_t * 7.0), Color(0.08, 0.02, 0.14, 0.95 * fade))
			PixelDraw.ring(self, Vector2.ZERO, 20.0, Color(0.7, 0.45, 1.0, fade), 2)
			for i in range(3):
				var rr2: float = rh * fmod(1.0 - (_t * 0.6 + float(i) / 3.0), 1.0)
				PixelDraw.ring(self, Vector2.ZERO, rr2, Color(0.7, 0.45, 1.0, 0.35 * fade), 1, 3, 4, _t * 20.0)
		"wolf":
			var wc: Color = Color(0.75, 0.9, 1.0, 0.8 * fade)
			PixelDraw.ground_shadow(self, Vector2(0.0, 7.0), Vector2(9.0, 3.0))
			PixelDraw.rect(self, Vector2(0.0, 0.0), 12, 5, wc)
			PixelDraw.rect(self, Vector2(7.0, -3.0), 5, 4, wc)
			PixelDraw.px(self, Vector2(9.0, -6.0), 1, wc)
			PixelDraw.px(self, Vector2(-8.0, -2.0), 2, wc)
		"electric_cloud":
			var re: float = float(p.get("radius", 120.0))
			for i in range(5):
				var ang7: float = TAU * PixelDraw.hash01(_seed + i) + _t * 0.5
				PixelDraw.disc(self, Vector2(cos(ang7), sin(ang7) * 0.5) * re * 0.4 - Vector2(0.0, 40.0), 14.0, Color(0.3, 0.3, 0.38, 0.55 * fade))
			PixelDraw.ring(self, Vector2.ZERO, re, Color(1.0, 0.95, 0.5, 0.3 * fade), 1, 2, 4, _t * 16.0)
