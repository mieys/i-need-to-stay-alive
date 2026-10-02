extends Node2D

## EFSUN ALAN VARLIKLARI - dünyada bir süre duran/hareket eden efsun etkileri. TEK script hem yetkili kopya
## (authoritative = true: hasar/element uygular - kaster oyuncunun makinesi, tepkime/ölüm alanlarında host) hem uzak
## görsel kopya (authoritative = false: aynı çizim, hasar YOK) için kullanılır; spawn() yetkili kopyayı yayınlar, uzakta
## enchant_fx.gd "area" dalı AYNI spawn()'u authoritative=false ile çağırır (bkz. CLAUDE.md "iki ayrı yer" hata sınıfı).
## Hasar take_damage/apply_element üzerinden gider - istemcide bunlar zaten host'a yönlendirilir.
## "follow": true olan alanlar sahibini izler (yetkili kopyada yerel oyuncu, uzak kopyada p["peer"]'in kuklası).
## Türler: poison_cloud, steam_fog, lava, hive, arrow_rain, volcano, tornado, hammer, meteor, flame_cone, line, blade,
## sticky_bomb, turret, bird, orbit_blade, blizzard, black_hole, wolf, electric_cloud, field (daire: tik hasarı + element).
## 2026-09-30 yeni efsun seti: rain (Arrow Rain alanı + balista), zeus (Beam of Zeus ışını, sahibini izler), shuriken (Blade
## of Valerius: uçar-saplanır-döner), mini_fw (Matryoshka küçük fişeği), heal_orb (Hunter's Eye can küresi), cosmic (Astral
## Yörünge kozmik diski), dot (görünmez süreli hasar listesi - yalnız kasterde). Mevcut türlere eklenenler: line -> slow /
## vuln / kapanış ("close", "fault") / bitiş patlaması ("blast"); field -> slow / vuln / stun / freeze; blade -> push /
## slow / wall_slam; orbit_blade -> knock; black_hole -> "blast" varsa patlar. "sheet" parametresi olan alan kendi
## sprite sayfasıyla görünür (tools/gen_enchant_fx.py) ve prosedürel çizimi atlar; "to"/"tile_len" varsa sayfa hat boyunca
## karolanır. "no_net": true -> yayınlanmaz (kasterin iç işi).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const TornadoFrames := preload("res://assets/fx/buyucu_tornado/loop_frames.tres")
const MeteorScene := preload("res://scenes/fx_meteor_strike.tscn")
const ENCHANT_FX_PATH := "res://scripts/enchant_fx.gd"
const SELF_PATH := "res://scripts/enchant_area.gd"
const HIVE_GROUP := "enchant_hives_local"
const TURRET_GROUP := "enchant_turrets_local"
const PULL_INTERVAL := 0.2 ## kasırga/kara delik çekme aralığı (bkz. _process_tornado)
const SpriteFx := preload("res://scripts/fx_enchant_sprite.gd")
const EnchantLayer := preload("res://scripts/enchant_layer.gd")
const TEXEL := 1.212

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
## 2026-09-30 yeni türler
var _sheet_nodes: Array = []
var _victims: Dictionary = {} ## zeus aşırı yükü: düşman id -> düğüm (yalnız yetkili kopya)
var _phase: String = ""
var _dealt: float = 0.0
var _kills: int = 0
var target_node: Node2D = null ## shuriken hedefi (yetkili kopyada doğrudan, uzakta ağ kimliğinden)
var targets: Array = [] ## dot: hasar alacak düğümler (yalnız yetkili kopya)
var _from: Vector2 = Vector2.ZERO
## "id" parametreli alanlar erken bitirilebilir (enchant_fx.gd "area_end" - Astral Yörünge nesneleri diske birleşince).
static var _by_id: Dictionary = {}


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
	if params.has("id"):
		_by_id[str(params["id"])] = a
	if is_authoritative and NetworkManager.is_multiplayer_active and not bool(params.get("no_net", false)):
		var net: Dictionary = params.duplicate()
		net["area"] = area_kind
		NetworkManager.broadcast_enchant_area.rpc("area", pos, net) ## güvenilir: tek seferlik, kaybı alanı hiç göstermez
	return a


func _fx() -> GDScript:
	return load(ENCHANT_FX_PATH) as GDScript


## Kimlikli alanı bitiş etkisi OLMADAN kaldırır (yerel; ağ için enchant_fx.gd "area_end").
static func end_by_id(id: String) -> void:
	var a: Variant = _by_id.get(id)
	_by_id.erase(id)
	if a != null and is_instance_valid(a):
		(a as Node).set("_done", true)
		(a as Node).queue_free()


func _exit_tree() -> void:
	if p.has("id") and _by_id.get(str(p["id"])) == self:
		_by_id.erase(str(p["id"]))


## ------------------------------------------------------------------ gece ışığı
## Kullanıcı bildirimi (2026-10-01): "efsunların parıltıları yok, karanlıkta parlamıyorlar" - alanlar eskiden türünden
## bağımsız 50 birimlik zayıf bir nokta ışık alıyordu (x0,65 sonrası kara delik / kozmik disk / lav gibi büyük alanların
## çok altında; Zeus ışını, iz ve yarık hatları sadece başlangıç noktasında hafif parlıyordu). Artık: yarıçap alanın
## kendisinden (glow_radius, katalog "rp"), hatlar hat boyunca (get_glow_segment), renk sayfaya göre; ışık saçmaması
## gereken türler/sayfalar (ok yağmuru, rüzgar dalgası, görünmez hasar listesi, çelik shuriken) night_glow_off.
const SHEET_GLOW_COLORS := {
	"magma_tile": Color(1.0, 0.5, 0.18), "rift_tile": Color(1.0, 0.5, 0.18), "rift_tile_wide": Color(1.0, 0.5, 0.18),
	"lava_pool": Color(1.0, 0.5, 0.18), "volt_tile": Color(1.0, 0.92, 0.45), "zeus_tile": Color(1.0, 0.92, 0.45),
	"frost_ground": Color(0.55, 0.85, 1.0), "radiation": Color(0.7, 1.0, 0.35), "void_hole": Color(0.7, 0.45, 1.0),
	"cosmic_disk": Color(0.7, 0.45, 1.0), "astral_orb": Color(0.8, 0.55, 1.0), "heal_orb": Color(0.55, 1.0, 0.5),
	"crystal_ice_shard": Color(0.55, 0.85, 1.0), "crystal_arcane_shard": Color(0.8, 0.55, 1.0), "mini_fw": Color(1.0, 0.6, 0.25),
}
const NO_GLOW_KINDS := ["rain", "dot", "shuriken"]
var glow_radius: float = 50.0
var night_glow_off: bool = false


func _setup_glow() -> void:
	var sh: String = str(p.get("sheet", ""))
	night_glow_off = kind in NO_GLOW_KINDS or (sh != "" and not SHEET_GLOW_COLORS.has(sh))
	if kind in ["line", "zeus"]:
		glow_radius = maxf(28.0, float(p.get("width", 18.0)) * 2.0)
	elif float(p.get("radius", 0.0)) > 0.0:
		glow_radius = float(p["radius"]) * 1.5
	elif kind in ["orbit_blade", "heal_orb", "mini_fw", "blade"]:
		glow_radius = 34.0


## Hat türleri (sabit "to" hattı ya da sahibini izleyen "tile_len" ışını) hat boyunca parlar; diğerleri nokta (boyu sıfır).
func get_glow_segment() -> Array:
	if kind in ["line", "zeus"]:
		if p.has("to"):
			return [global_position, Vector2(p["to"])]
		if p.has("tile_len"):
			return [global_position, global_position + Vector2(p.get("dir", Vector2.RIGHT)).normalized() * float(p["tile_len"])]
	return [global_position, global_position]


## Gece ışığının rengi (bkz. night_glow.gd, night_glow_catalog.gd BY_SCRIPT) - alan türüne göre.
func get_night_glow_color() -> Color:
	if p.has("color"):
		return Color(p["color"])
	if SHEET_GLOW_COLORS.has(str(p.get("sheet", ""))):
		return SHEET_GLOW_COLORS[str(p["sheet"])]
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
	_setup_glow()
	z_index = EnchantLayer.Z ## karakterlerin altında (bkz. enchant_layer.gd; eskiden 3/9 = karakterin üstü)
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
	_from = global_position
	if kind == "shuriken" and target_node == null:
		target_node = NetworkManager.find_enemy_by_net_id(int(p.get("target_id", 0))) as Node2D
	_setup_sheet()


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
		"rain":
			_tick_every(delta, float(p.get("tick", 0.5)), _rain_tick)
		"zeus":
			_tick_every(delta, float(p.get("tick", 0.25)), _zeus_tick)
		"shuriken":
			if _process_shuriken(delta):
				return
		"mini_fw":
			if _process_mini_fw():
				return
		"heal_orb":
			if _process_heal_orb(delta):
				return
		"cosmic":
			_process_cosmic(delta)
		"dot":
			_tick_every(delta, 1.0, _dot_tick)
	if not _sheet_nodes.is_empty():
		var sd: float = _duration()
		var sf: float = clampf(minf(_t / 0.15, (sd - _t) / 0.3), 0.0, 1.0)
		for sn in _sheet_nodes:
			if is_instance_valid(sn):
				(sn as CanvasItem).modulate.a = sf
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
		"shuriken", "heal_orb":
			return float(p.get("safety", 12.0))
		"mini_fw":
			return float(p.get("flight", 0.35)) + 0.2
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
			## 2026-09-30: patlama artık isteğe bağlı ("blast" varsa - Endless Void Finali "Tekillik Çöküşü").
			if p.has("blast"):
				var br: float = float(p.get("radius", 200.0))
				if p.has("blast_sheet"):
					SpriteFx.spawn(get_tree(), global_position, {"sheet": str(p["blast_sheet"]), "scale": br / (66.0 * TEXEL), "z": 9})
				else:
					_fx().spawn(get_tree(), "explosion", global_position, {"radius": 160.0, "color": Color(0.7, 0.45, 1.0)})
				if authoritative:
					for e in _enemies_in(br):
						_hit(e, float(p.get("blast", 10.0)))
		"rain":
			if float(p.get("ballista", 0.0)) > 0.0:
				SpriteFx.spawn(get_tree(), global_position, {"sheet": "ballista", "offset": Vector2(0.0, -40.0), "z": 9})
				if authoritative:
					for e in _enemies_in(90.0):
						_hit(e, float(p["ballista"]))
		"line":
			_line_expire()
		"zeus":
			_zeus_expire()
		"cosmic":
			SpriteFx.spawn(get_tree(), global_position, {"sheet": "cosmic_blast", "scale": float(p.get("radius", 90.0)) / (74.0 * TEXEL), "z": 9})
			if authoritative:
				for e in _enemies_in(float(p.get("radius", 90.0)) * 1.3):
					var away: Vector2 = e.global_position - global_position
					_elem(e, "knock", {"dir": away.normalized() if away.length() > 1.0 else Vector2.RIGHT, "dist": 110.0, "quiet": true})
					_hit(e, float(p.get("damage", 10.0)))


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
		_status_effects(e, float(p.get("tick", 0.5)))
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
		## Wind Sword: savurma, yavaşlatma, duvara çarptırma (itme yönünde orman duvarı varsa ek hasar + sersemletme).
		var push: float = float(p.get("push", 0.0))
		if push > 0.0 and not e.is_boss:
			_elem(e, "knock", {"dir": dir, "dist": push, "quiet": true})
			if bool(p.get("wall_slam", false)) and GameManager.is_position_blocked_by_forest(e.global_position + dir * push):
				_hit(e, float(p.get("damage", 10.0)) * float(p.get("slam_mult", 1.0)))
				_elem(e, "stun", {"dur": float(p.get("slam_stun", 1.0))})
		if float(p.get("slow", 0.0)) > 0.0:
			_elem(e, "slow", {"pct": float(p["slow"]), "dur": float(p.get("slow_dur", 1.5))})


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
		if float(p.get("knock", 0.0)) > 0.0 and not e.is_boss:
			var aw: Vector2 = e.global_position - _origin
			_elem(e, "knock", {"dir": aw.normalized() if aw.length() > 1.0 else Vector2.RIGHT, "dist": float(p["knock"]), "quiet": true})
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
			_elem(e, "knock", {"dir": to_c.normalized(), "dist": minf(50.0 * float(p.get("pull", 1.0)), to_c.length()), "quiet": true})
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
		_status_effects(e, float(p.get("tick", 0.5)))


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
	if p.has("sheet") or kind in ["rain", "zeus", "shuriken", "mini_fw", "heal_orb", "cosmic", "dot"]:
		return
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


## ================================================================== 2026-09-30 yeni efsun seti
## Sprite sayfası görünümü (her iki kopya). Hat türlerinde (line / zeus) sayfa karolanır: "to" (sabit hat) ya da "dir" +
## "tile_len" (sahibini izleyen ışın). "sheet_scale" float ya da Vector2 (x hat boyunca, y kalınlık).
func _setup_sheet() -> void:
	if not p.has("sheet"):
		return
	var fr: SpriteFrames = SpriteFx.frames(str(p["sheet"]))
	if fr == null:
		return
	var sc_v: Variant = p.get("sheet_scale", 1.0)
	var sc: Vector2 = sc_v if sc_v is Vector2 else Vector2.ONE * float(sc_v)
	var anim: StringName = &"loop" if fr.has_animation(&"loop") else &"play"
	var tile_vec: Vector2 = Vector2.ZERO
	if p.has("to"):
		tile_vec = Vector2(p["to"]) - global_position
	elif p.has("tile_len"):
		tile_vec = Vector2(p.get("dir", Vector2.RIGHT)).normalized() * float(p["tile_len"])
	if tile_vec.length() > 1.0:
		## Kullanıcı (2026-09-30): "başlangıçları/bitişleri keskin, hiç doğal durmuyor". Karolar artık TAM karo genişliği
		## aralıkla, aynı karede ve çevrilmeden dizilir (sayfalar x'te 16 px periyodik -> desen dikişsiz akar; eskiden 16
		## birim adımla 19 birimlik karolar üst üste biniyor, her biri farklı karede/ters oynuyordu). İlk karo
		## "<sayfa>_cap" (uca doğru sivrilir), son karo onun yatay aynası - hat kare kesik başlayıp bitmez.
		var tex: Texture2D = fr.get_frame_texture(anim, 0)
		var tile_w: float = maxf(4.0, float(tex.get_width()) * sc.x * TEXEL)
		var seg: float = tile_vec.length()
		var n: int = maxi(1, int(round(seg / tile_w)))
		var along: Vector2 = tile_vec / seg
		var cap_fr: SpriteFrames = SpriteFx.frames(str(p["sheet"]) + "_cap")
		for i in range(n):
			var is_cap: bool = cap_fr != null and (i == 0 or i == n - 1)
			var spr := _sheet_sprite(cap_fr if is_cap else fr, anim, sc)
			spr.position = along * (tile_w * (float(i) + 0.5)) + Vector2(p.get("sheet_pos", Vector2.ZERO))
			spr.rotation = tile_vec.angle()
			spr.flip_h = is_cap and i == n - 1 and n > 1
	else:
		var one := _sheet_sprite(fr, anim, sc)
		one.position = Vector2(p.get("sheet_pos", Vector2.ZERO))
		one.rotation = float(p.get("sheet_rot", 0.0))
		one.offset = Vector2(p.get("sheet_offset", Vector2.ZERO))


func _sheet_sprite(fr: SpriteFrames, anim: StringName, sc: Vector2) -> AnimatedSprite2D:
	var spr := AnimatedSprite2D.new()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.sprite_frames = fr
	spr.scale = sc * TEXEL
	add_child(spr)
	spr.play(anim)
	_sheet_nodes.append(spr)
	return spr


## Hat / daire alanlarının ortak durum etkileri (tik başına): yavaşlatma, "tüm hasardan fazla al", sersemletme, dondurma.
func _status_effects(e: Node, tick: float) -> void:
	if float(p.get("slow", 0.0)) > 0.0:
		_elem(e, "slow", {"pct": float(p["slow"]), "dur": tick + 0.4})
	if float(p.get("vuln", 0.0)) > 0.0:
		_elem(e, "vuln", {"pct": float(p["vuln"]), "dur": tick + 0.4})
	if float(p.get("stun", 0.0)) > 0.0:
		_elem(e, "stun", {"dur": float(p["stun"])})
	if float(p.get("freeze", 0.0)) > 0.0:
		if e.get("is_boss") == true:
			_elem(e, "slow", {"pct": 0.5, "dur": tick + 0.4, "boss": true})
		else:
			_elem(e, "freeze", {"dur": float(p["freeze"]), "quiet": true})


## Hat bitişi: "close" (Tektonik Seviye 4 kapanışı), "fault" (Final: merkeze çekip ezen dev patlama), "blast" (Magma /
## Lightning Trail Finali: patlama + süreli yanma/çarpılma). Hasar içerideki düşman başına %15 artar (close / fault).
func _line_expire() -> void:
	var a: Vector2 = _origin
	var b: Vector2 = _origin + _line_to()
	var mid: Vector2 = (a + b) * 0.5
	var fault: float = float(p.get("fault", 0.0))
	var close: float = float(p.get("close", 0.0))
	var blast: float = float(p.get("blast", 0.0))
	if fault > 0.0:
		SpriteFx.spawn(get_tree(), mid, {"sheet": "fault_blast", "offset": Vector2(0.0, -22.0), "z": 9})
	elif close > 0.0:
		_fx().spawn(get_tree(), "tiles", a, {"sheet": "quake_tile", "to": b, "step": 20.0, "rot": 0.0})
	if blast > 0.0:
		_fx().spawn(get_tree(), "tiles", a, {"sheet": str(p.get("blast_sheet", "trail_pop_fire")), "to": b, "step": 24.0})
	if not authoritative:
		return
	var victims: Array = _enemies_on_line(float(p.get("width", 22.0)))
	var crowd: float = 1.0 + float(p.get("crowd_bonus", 0.15)) * float(victims.size())
	for e in victims:
		if fault > 0.0:
			var to_mid: Vector2 = mid - e.global_position
			if to_mid.length() > 8.0 and not e.is_boss:
				_elem(e, "knock", {"dir": to_mid.normalized(), "dist": to_mid.length(), "quiet": true})
			_hit(e, fault * crowd)
		elif close > 0.0:
			_hit(e, close * crowd)
		if blast > 0.0:
			_hit(e, blast)
	if blast > 0.0 and float(p.get("blast_dot", 0.0)) > 0.0 and not victims.is_empty():
		if str(p.get("blast_mode", "")) == "fire":
			for e in victims:
				_elem(e, "burn", {"tick": float(p["blast_dot"]), "dur": 3.0, "ap": float(p.get("ap", 0.0)), "quiet": true})
		else:
			var d := spawn(get_tree(), "dot", global_position, {"duration": 3.05, "damage": float(p["blast_dot"]),
				"fx_sheet": "bounce_spark", "no_net": true, "peer": int(p.get("peer", 0))}, true)
			if d:
				d.set("targets", victims)


## Arrow Rain: alandakilere tik hasarı (+ Finalde kalkan kırma). Görsel sayfa döngüsü (arrow_rain).
func _rain_tick() -> void:
	for e in _enemies_in(float(p.get("radius", 70.0))):
		if float(p.get("shield_break", 0.0)) > 0.0:
			_elem(e, "shield_break", {"pct": float(p["shield_break"]), "dur": float(p.get("tick", 0.5)) + 0.4})
		_hit(e, float(p.get("damage", 5.0)))


## Beam of Zeus: sahibinden "dir" yönünde tile_len boyunca, "width" kalınlığında. Değenleri Final için kaydeder.
func _zeus_seg() -> Array:
	var a: Vector2 = global_position
	return [a, a + Vector2(p.get("dir", Vector2.RIGHT)).normalized() * float(p.get("tile_len", 300.0))]


func _zeus_tick() -> void:
	var seg: Array = _zeus_seg()
	var a: Vector2 = seg[0]
	var b: Vector2 = seg[1]
	var w: float = float(p.get("width", 18.0))
	var dir: Vector2 = (b - a).normalized()
	for e in _enemies_in(a.distance_to(b) * 0.5 + w, (a + b) * 0.5):
		if e.global_position.distance_to(Geometry2D.get_closest_point_to_segment(e.global_position, a, b)) > w:
			continue
		_hit(e, float(p.get("damage", 5.0)))
		if float(p.get("push", 0.0)) > 0.0 and not e.is_boss:
			_elem(e, "knock", {"dir": dir.orthogonal() * signf(dir.orthogonal().dot(e.global_position - a)) if absf(dir.orthogonal().dot(e.global_position - a)) > 1.0 else dir, "dist": float(p["push"]) * 0.5, "quiet": true})
		if bool(p.get("overcharge", false)):
			_victims[e.get_instance_id()] = e


func _zeus_expire() -> void:
	if not authoritative or _victims.is_empty():
		return
	var n: int = 0
	for id in _victims:
		var e = _victims[id]
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		n += 1
		if n > 14:
			break
		var at: Vector2 = (e as Node2D).global_position
		_fx().play(get_tree(), "sprite", at, {"sheet": "zeus_burst", "z": 9})
		for v in _enemies_in(40.0, at):
			_hit(v, float(p.get("oc_dmg", 10.0)))
		var near: Array = _enemies_in(220.0, at)
		near.sort_custom(func(x, y): return x.global_position.distance_squared_to(at) < y.global_position.distance_squared_to(at))
		var jumped: int = 0
		for v in near:
			if v == e or jumped >= 3:
				continue
			jumped += 1
			_fx().play(get_tree(), "chain", at, {"to": v.global_position, "color": Color(1.0, 0.95, 0.5)})
			_hit(v, float(p.get("chain_dmg", 5.0)))


## Blade of Valerius shurikeni: "fly" (hedefe uçar) -> "stick" (hedefe saplı, saniyede hasar) -> "return" (sahibine döner;
## Finalde yolundakileri deler) -> sahibine varınca verdiği hasarın "leech" oranı kadar can (yalnız yetkili kopya). Uzak kopya
## aynı hedefi ağ kimliğinden bulur, aynı yolu çizer, hasar/can YOK. true = düğüm silindi.
func _process_shuriken(delta: float) -> bool:
	if _phase == "":
		_phase = "fly"
	match _phase:
		"fly":
			var tgt: Vector2 = target_node.global_position if is_instance_valid(target_node) else Vector2(p.get("tpos", global_position))
			var k: float = clampf(_t / 0.2, 0.0, 1.0)
			global_position = _from.lerp(tgt, k)
			if k >= 1.0:
				_phase = "stick"
				_tick = 1.0
				_t = 0.0
				if authoritative and is_instance_valid(target_node):
					_deal_tracked(target_node, float(p.get("hit", 5.0)))
					_fx().play(get_tree(), "sprite", global_position, {"sheet": "shuriken_hit", "z": 9})
		"stick":
			var alive: bool = is_instance_valid(target_node) and target_node.get("is_dead") != true
			if alive:
				global_position = target_node.global_position + Vector2(0.0, -6.0)
			if authoritative and alive:
				_tick -= delta
				if _tick <= 0.0:
					_tick += 1.0
					_deal_tracked(target_node, float(p.get("dot", 1.0)))
			if _t >= float(p.get("stick", 5.0)) or not alive:
				_phase = "return"
				_hit_once.clear()
		"return":
			var owner_node: Node2D = _follow_target()
			if owner_node == null:
				queue_free()
				return true
			var to_o: Vector2 = owner_node.global_position - global_position
			var stepd: float = 520.0 * delta
			if authoritative and bool(p.get("return_pierce", false)):
				for e in _enemies_in(16.0):
					var id: int = e.get_instance_id()
					if _hit_once.has(id):
						continue
					_hit_once[id] = true
					var dmg: float = float(p.get("return_hit", 5.0))
					if float(e.get("health")) <= dmg:
						_kills += 1
					_deal_tracked(e, dmg)
			if to_o.length() <= stepd + 6.0:
				if authoritative and owner_node.has_method("heal"):
					var leech: float = float(p.get("kill_leech", 0.0)) if _kills > 0 and float(p.get("kill_leech", 0.0)) > 0.0 else float(p.get("leech", 0.01))
					var amount: float = _dealt * leech
					if amount > 0.0:
						owner_node.heal(amount)
				queue_free()
				return true
			global_position += to_o.normalized() * stepd
	for sn in _sheet_nodes:
		if is_instance_valid(sn):
			(sn as Node2D).rotation += delta * 18.0
	if _t > 30.0:
		queue_free()
		return true
	return false


func _deal_tracked(e: Node, amount: float) -> void:
	if amount > 0.0 and is_instance_valid(e) and e.get("is_dead") != true:
		_dealt += amount
		_hit(e, amount)


## Matryoshka küçük fişeği: "to" noktasına yay çizerek uçar, patlar (hasar + isteğe bağlı sersemletme); "micro" > 0 ise
## yetkili kopya 2 mikro fişek doğurur (onlar da kendilerini yayınlar). true = düğüm silindi.
func _process_mini_fw() -> bool:
	var fl: float = float(p.get("flight", 0.35))
	var k: float = clampf(_t / fl, 0.0, 1.0)
	var to: Vector2 = Vector2(p.get("to", _from))
	global_position = _from.lerp(to, k) - Vector2(0.0, sin(k * PI) * 22.0)
	if k < 1.0:
		return false
	var r: float = float(p.get("radius", 35.0))
	SpriteFx.spawn(get_tree(), to, {"sheet": "mini_pop", "scale": r / (29.0 * TEXEL), "z": 9})
	if authoritative:
		for e in _enemies_in(r, to):
			_hit(e, float(p.get("damage", 5.0)))
			if float(p.get("stun", 0.0)) > 0.0:
				_elem(e, "stun", {"dur": float(p["stun"])})
		if float(p.get("micro", 0.0)) > 0.0:
			var base_ang: float = randf() * TAU
			for i in range(2):
				var ang: float = base_ang + PI * float(i)
				var d: Dictionary = p.duplicate()
				d.erase("id")
				d["micro"] = 0.0
				d["damage"] = float(p["micro"])
				d["radius"] = r * 0.7
				d["to"] = to + Vector2(cos(ang), sin(ang)) * float(p.get("range", 60.0)) * 0.6
				d["sheet_scale"] = 0.7
				spawn(get_tree(), "mini_fw", to, d, true)
	queue_free()
	return true


## Hunter's Eye can küresi: kısa bekleyip sahibine uçar; varınca (yetkili kopyada) "heal" kadar can. true = silindi.
func _process_heal_orb(delta: float) -> bool:
	if _t < 0.35:
		global_position.y -= 20.0 * delta
		return false
	var owner_node: Node2D = _follow_target()
	if owner_node == null:
		queue_free()
		return true
	var to_o: Vector2 = owner_node.global_position - global_position
	var stepd: float = (260.0 + _t * 200.0) * delta
	if to_o.length() <= stepd + 6.0:
		if authoritative and owner_node.has_method("heal"):
			owner_node.heal(float(p.get("heal", 5.0)))
		queue_free()
		return true
	global_position += to_o.normalized() * stepd
	return false


## Astral Yörünge kozmik diski: sahibini izler, bosslar dışındakileri içine çeker, 0,3 sn'de bir hasar; bitince dışa patlar.
func _process_cosmic(delta: float) -> void:
	if not authoritative:
		return
	var r: float = float(p.get("radius", 90.0))
	_tick2 -= delta
	var pull_now: bool = _tick2 <= 0.0
	if pull_now:
		_tick2 = PULL_INTERVAL
	_tick -= delta
	var dmg_now: bool = _tick <= 0.0
	if dmg_now:
		_tick = float(p.get("tick", 0.3))
	for e in _enemies_in(r * 1.6):
		var to_c: Vector2 = global_position - e.global_position
		if pull_now and to_c.length() > 18.0 and not e.is_boss:
			_elem(e, "knock", {"dir": to_c.normalized(), "dist": minf(45.0, to_c.length() - 14.0), "quiet": true})
		if dmg_now and to_c.length() <= r:
			_hit(e, float(p.get("damage", 5.0)))


## Görünmez süreli hasar (Lightning Trail Finali "çarpılmaya devam eder"): saniyede bir listedekilere hasar + küçük kıvılcım.
func _dot_tick() -> void:
	var alive: Array = []
	for e in targets:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		alive.append(e)
		_hit(e, float(p.get("damage", 1.0)))
		if p.has("fx_sheet"):
			_fx().play(get_tree(), "sprite", (e as Node2D).global_position, {"sheet": str(p["fx_sheet"]), "z": 9})
	targets = alive
