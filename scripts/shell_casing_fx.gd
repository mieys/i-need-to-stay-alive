extends Node2D

## Tabanca + Tüfek BOŞ KOVAN ve DÜŞEN ŞARJÖR (2026-10-19, madde 296; kullanıcı: "silahlar ateşlenince boş mermi kovanları düşecek
## üstlerinden"). Her atışta silahın kovan deliğinden (GunMagMath port) pirinç kovan geriye-yukarı fırlar, dönerek sahibin ayak
## hizasına (yer) düşer, bir-iki kez seker (ilk çarpışmada ince çınlama), REST_TIME yerde kalır, FADE_TIME'da söner. Doldurmada
## boş şarjör aynı yoldan düşer (gun_reload_fx.gd).
##
## - Yükseklik benzetimi: yer düzlemindeki nokta + yükseklik z; çizim (x, y - z). Havadayken AIR_Z katmanında (karakterlerin
##   üstünde), yere inince haritanın hemen üstündeki zemin katmanına (enemy_abilities.place_on_ground - kan lekesiyle aynı)
##   taşınır: karakterler ve yaratıklar üstünde yürür.
## - Tek yönetici düğüm (sahne başına, tembel kurulur), tek _process, MAX_ALIVE tavanı (aşılınca en eski hemen silinir), boşken
##   işlemez. Kare sayfası tools/gen_gun_mag_fx.py (8 dönüş karesi x 4 satır), doku pikseli silah sanatıyla aynı (WORLD_PX).
## - Çok oyunculu: kaster weapon.gd _fire_at'ta, uzak kukla remote_player.gd "weapon_fire" yayınında kendi kovanını üretir (ek RPC
##   yok, her istemci kendi rastgeleliğiyle - kozmetik).

const GunMagMath := preload("res://scripts/gun_mag_math.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const TEX := preload("res://assets/fx/gun/casings.png")
const SND_TINK := preload("res://assets/audio/gun/shell_tink.wav")

const WORLD_PX := 0.575 ## weapon_tier_art.gd WORLD_PX ile aynı (silah dokusu pikseli)
const FRAMES := 8
const ROWS := 4
const MAX_ALIVE := 48
const GRAVITY := 560.0 ## dünya px/sn^2
const REST_TIME := 1.6
const FADE_TIME := 0.5
const AIR_Z := 55
const FEET_LOCAL_Y := 30.0 ## sahibin kök ölçeğinde gerçek ayak teması (karakter karesinde gölge pişmiş, Shadow düğümü 55'te - kullanılmaz)
const TINK_MIN_MS := 60 ## iki çınlama arası en az süre (hızlı ateşte ses yağmuru olmasın)
const TINK_DB := -21.0
const MAG_LAND_DB := -15.0
const NODE_NAME := "ShellCasingFx"

var _ground: Node2D = null
var _pieces: Array = [] ## {spr, g, z, vz, vel, ff, spin, row, st, t, b, mag, pitch}
var _players: Array = []
var _next_player: int = 0
var _last_tink_ms: int = -100000


## Silah dokusu merkezine göre doku pikseli -> dünya konumu (aynalama dahil). icon: Sprite2D (kaster icon_sprite / kukla ikonu).
static func icon_point(icon: Node2D, tex_px: Vector2) -> Vector2:
	var p: Vector2 = tex_px
	if icon is Sprite2D:
		var s: Sprite2D = icon as Sprite2D
		if s.flip_h:
			p.x = -p.x
		if s.flip_v:
			p.y = -p.y
		p += s.offset
	return icon.global_transform * p


## Sahibin ayak hizası (dünya y) - kovan buraya düşer.
static func ground_y(owner_body: Node2D) -> float:
	if owner_body == null or not is_instance_valid(owner_body):
		return 0.0
	return owner_body.global_position.y + FEET_LOCAL_Y * absf(owner_body.global_scale.y)


## Ateş anında kovan fırlat. aim_dir: atış yönü (kovan bunun tersine/yukarı fırlar).
static func eject(icon: Node2D, key: String, aim_dir: Vector2, owner_body: Node2D) -> void:
	if not _icon_ok(icon) or not GunMagMath.has_mag(key):
		return
	var c: Dictionary = GunMagMath.cfg(key)
	var from: Vector2 = icon_point(icon, c["port"])
	var back: float = -signf(aim_dir.x) if absf(aim_dir.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	var vel := Vector2(back * randf_range(28.0, 52.0), randf_range(-14.0, 14.0))
	var mgr = _mgr(icon.get_tree())
	if mgr != null:
		mgr._add(from, ground_y(owner_body), vel, randf_range(80.0, 115.0), back * randf_range(16.0, 26.0),
			int(c["casing_row"]), false, float(c.get("pitch", 1.0)))


## Doldurmada boş şarjör düşer (gun_reload_fx.gd MAG_OUT olayı).
static func drop_mag(icon: Node2D, key: String, owner_body: Node2D) -> void:
	if not _icon_ok(icon) or not GunMagMath.has_mag(key):
		return
	var c: Dictionary = GunMagMath.cfg(key)
	var from: Vector2 = icon_point(icon, c["mag_out"])
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var vel := Vector2(side * randf_range(6.0, 16.0), randf_range(-5.0, 5.0))
	var mgr = _mgr(icon.get_tree())
	if mgr != null:
		mgr._add(from, ground_y(owner_body), vel, randf_range(12.0, 30.0), side * randf_range(5.0, 9.0),
			int(c["mag_row"]), true, float(c.get("pitch", 1.0)))


## Görünmeyen (çalıda saklı kukla, içe çekilmiş silah) ikondan kovan çıkmasın - konumu ele vermesin.
static func _icon_ok(icon: Node2D) -> bool:
	if icon == null or not is_instance_valid(icon) or not icon.is_inside_tree() or not icon.is_visible_in_tree():
		return false
	var a: float = 1.0
	var n: Node = icon
	for i in 5:
		if n == null or not (n is CanvasItem):
			break
		a *= (n as CanvasItem).modulate.a
		n = n.get_parent()
	return a > 0.3


static func _mgr(tree: SceneTree) -> Node2D:
	if tree == null or tree.current_scene == null:
		return null
	var root: Node = tree.current_scene
	var m: Node = root.get_node_or_null(NODE_NAME)
	if m != null:
		return m as Node2D
	var node: Node2D = (load("res://scripts/shell_casing_fx.gd") as GDScript).new()
	node.name = NODE_NAME
	root.add_child(node)
	node.call("_setup")
	return node


func _setup() -> void:
	z_index = AIR_Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground = Node2D.new()
	_ground.name = "ShellCasingGround"
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_parent().add_child(_ground)
	EnemyAbilities.place_on_ground(get_tree(), _ground)
	for i in 3:
		var asp := AudioStreamPlayer2D.new()
		asp.stream = SND_TINK
		asp.max_distance = 700.0
		asp.attenuation = 1.8
		add_child(asp)
		_players.append(asp)
	set_process(false)


func _exit_tree() -> void:
	if is_instance_valid(_ground):
		_ground.queue_free()


func _add(from: Vector2, gy: float, vel: Vector2, vz: float, spin: float, row: int, is_mag: bool, pitch: float) -> void:
	if _pieces.size() >= MAX_ALIVE:
		var old: Dictionary = _pieces.pop_front()
		if is_instance_valid(old["spr"]):
			(old["spr"] as Node).queue_free()
	var spr := Sprite2D.new()
	spr.texture = TEX
	spr.hframes = FRAMES
	spr.vframes = ROWS
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(WORLD_PX, WORLD_PX)
	var ff: float = randf() * FRAMES
	spr.frame = row * FRAMES + int(ff) % FRAMES
	add_child(spr)
	var g := Vector2(from.x, maxf(gy, from.y + 4.0))
	var z: float = g.y - from.y
	spr.global_position = Vector2(g.x, g.y - z)
	_pieces.append({"spr": spr, "g": g, "z": z, "vz": vz, "vel": vel, "ff": ff, "spin": spin, "row": row, "st": 0,
		"t": 0.0, "b": 0, "mag": is_mag, "pitch": pitch})
	set_process(true)


func _process(delta: float) -> void:
	var i: int = 0
	while i < _pieces.size():
		var p: Dictionary = _pieces[i]
		## Önce geçerlilik: silinmiş nesneyi "as" ile dönüştürmek her karede SCRIPT ERROR basar.
		if not is_instance_valid(p["spr"]):
			_pieces.remove_at(i)
			continue
		var spr: Sprite2D = p["spr"] as Sprite2D
		var st: int = int(p["st"])
		if st == 0:
			_step_air(p, spr, delta)
		elif st == 1:
			p["t"] = float(p["t"]) + delta
			if float(p["t"]) >= REST_TIME:
				p["st"] = 2
				p["t"] = 0.0
		else:
			p["t"] = float(p["t"]) + delta
			var a: float = 1.0 - float(p["t"]) / FADE_TIME
			if a <= 0.0:
				spr.queue_free()
				_pieces.remove_at(i)
				continue
			spr.modulate.a = a
		i += 1
	if _pieces.is_empty():
		set_process(false)


func _step_air(p: Dictionary, spr: Sprite2D, delta: float) -> void:
	var g: Vector2 = p["g"]
	g += (p["vel"] as Vector2) * delta
	var vz: float = float(p["vz"]) - GRAVITY * delta
	var z: float = float(p["z"]) + vz * delta
	var ff: float = float(p["ff"]) + float(p["spin"]) * delta
	if z <= 0.0:
		z = 0.0
		var is_mag: bool = p["mag"]
		var max_b: int = 1 if is_mag else 2
		if int(p["b"]) == 0 and is_mag: ## boş kovan sessiz düşer (kullanıcı isteği 2026-10-19); sadece şarjör sesi kalır
			_tink(g, is_mag, float(p["pitch"]))
		if int(p["b"]) < max_b and vz < -60.0:
			vz = -vz * (0.22 if is_mag else 0.32)
			p["vel"] = (p["vel"] as Vector2) * 0.45
			p["spin"] = float(p["spin"]) * 0.5
			p["b"] = int(p["b"]) + 1
		else:
			_land(p, spr, g, ff)
			return
	p["g"] = g
	p["vz"] = vz
	p["z"] = z
	p["ff"] = ff
	spr.frame = int(p["row"]) * FRAMES + posmod(int(ff), FRAMES)
	spr.global_position = (Vector2(g.x, g.y - z) * 2.0).round() * 0.5


## Yere oturur: yatık bir kareye (dik duran kovan/şarjör tuhaf durur) ve zemin katmanına geçer.
func _land(p: Dictionary, spr: Sprite2D, g: Vector2, ff: float) -> void:
	var f: int = posmod(int(round(ff)), FRAMES)
	if f == 0 or f == 4:
		f += 1 if randf() < 0.5 else -1
	if bool(p["mag"]):
		f = 2 if f < 4 else 6
	spr.frame = int(p["row"]) * FRAMES + posmod(f, FRAMES)
	p["st"] = 1
	p["t"] = 0.0
	if is_instance_valid(_ground):
		remove_child(spr)
		_ground.add_child(spr)
	spr.global_position = (g * 2.0).round() * 0.5


func _tink(at: Vector2, is_mag: bool, pitch: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_tink_ms < TINK_MIN_MS or _players.is_empty():
		return
	_last_tink_ms = now
	var asp: AudioStreamPlayer2D = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	asp.global_position = at
	asp.volume_db = MAG_LAND_DB if is_mag else TINK_DB
	asp.pitch_scale = (0.55 if is_mag else 1.0) * pitch * randf_range(0.9, 1.12)
	asp.play()


## Test / ölçüm için.
func alive_count() -> int:
	return _pieces.size()
