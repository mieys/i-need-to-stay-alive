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
const MAGS_TEX := preload("res://assets/fx/gun/reload/mags_drop.png") ## düşen şarjör (satır 0 tabanca, 1 tüfek, 2 makineli; 24x24 hücre), gen_gun_reload_fx.py
const MAG_ROWS := 3
const SND_TINK := preload("res://assets/audio/gun/shell_tink.wav")
## Kovan YERE DÜŞME sesi silah türüne göre (2026-11-13, kullanıcı: "yere mermi düşünce bu sesler çıksın silahın türüne bağlı olacak
## şekilde"; kaynak: kullanıcının "mermi düşme sesleri.mp3" kaydı, 12 düşüş). Kayıttaki düşüşler çınlama frekansına göre ayrıldı:
## parlak ~7.2 kHz (küçük kovan) = tabanca, pes ~3 kHz + 8.7 kHz (uzun kovan) = tüfek, donuk ~4.8 kHz = pompalı. Her klip ilk çarpma +
## doğal sekmeleri içerir -> ilk yere değişte BİR kez çalar (sekmelerde ayrı ses yok). Kesim: DC/uğultu süzgeci, 50 ms kuyruk sönümü,
## tepe -1 dBFS (sınırlayıcı yok).
## Tabanca da tüfeğin kovan sesini kullanır (kullanıcı 2026-11-13: "pistol mermisinin düşme sesiyle tüfeğinki aynı olsun");
## kayıttaki parlak ~7.2 kHz tabanca klipleri silindi.
const RIFLE_CASING_SNDS := [preload("res://assets/audio/gun/casing_drop/tufek_1.wav"),
	preload("res://assets/audio/gun/casing_drop/tufek_2.wav"), preload("res://assets/audio/gun/casing_drop/tufek_3.wav"),
	preload("res://assets/audio/gun/casing_drop/tufek_4.wav")]
const CASING_SNDS := {
	"tabanca": RIFLE_CASING_SNDS,
	"tufek": RIFLE_CASING_SNDS,
	"makineli": RIFLE_CASING_SNDS, ## madde 652 (kullanıcı: "mermi yere düşme sesini pistolden al" - Tabanca da bunu kullanır)
	"pompali": [preload("res://assets/audio/gun/casing_drop/pompali_1.wav"), preload("res://assets/audio/gun/casing_drop/pompali_2.wav"),
		preload("res://assets/audio/gun/casing_drop/pompali_3.wav"), preload("res://assets/audio/gun/casing_drop/pompali_4.wav"),
		preload("res://assets/audio/gun/casing_drop/pompali_5.wav"), preload("res://assets/audio/gun/casing_drop/pompali_6.wav")],
}
## Klipler tepeye göre eşitlendi; pompalı kayıtları ortalamada ~5 dB daha kısık (donuk plastik gövde) -> biraz yukarı.
const CASING_DB := {"tabanca": -12.0, "tufek": -12.0, "pompali": -9.0, "makineli": -14.0}
const CASING_MIN_MS := 70 ## hızlı ateşte ses yağmuru olmasın (klipler sekmeleri içerdiği için ~0.6 sn sürer)

const WORLD_PX := 0.575 ## weapon_tier_art.gd WORLD_PX ile aynı (silah dokusu pikseli)
const FRAMES := 8
const ROWS := 5 ## 4 = pompalı av fişeği (madde 448)
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
var _last_casing_ms: int = -100000
var _last_casing_idx: Dictionary = {} ## silah -> son çalınan klip (art arda aynısı gelmesin)
var _casing_snd_count: int = 0 ## test için


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
			int(c["casing_row"]), false, float(c.get("pitch", 1.0)), null, ROWS, WORLD_PX, -1.0, key)


## Doldurmada boş şarjör düşer (gun_reload_fx.gd, 2026-11-13): kabzadan/gövdeden kayıp çıkan parçanın KENDİSİ (aynı doku pikseli,
## aynı renkler - mags_drop.png 8 dönüş karesi, tools/gen_gun_reload_fx.py). info = GunReloadMath.drop_piece: center (doku px,
## sol-üst köşeye göre), up (şarjör ağzının doku uzayındaki yönü), row. Kayış yönünde (ağzın tersi) hızla çıkar, ayak hizasına düşer.
static func drop_mag(icon: Node2D, key: String, owner_body: Node2D, info: Dictionary = {}) -> void:
	if not _icon_ok(icon) or not GunMagMath.has_mag(key) or info.is_empty() or not (icon is Sprite2D):
		return
	var s: Sprite2D = icon as Sprite2D
	if s.texture == null:
		return
	var center: Vector2 = (info["center"] as Vector2) - s.texture.get_size() * 0.5
	var from: Vector2 = icon_point(icon, center)
	var up_l: Vector2 = info["up"]
	if s.flip_h:
		up_l.x = -up_l.x
	if s.flip_v:
		up_l.y = -up_l.y
	var up: Vector2 = icon.global_transform.basis_xform(up_l).normalized()
	var down: Vector2 = -up
	var vel := Vector2(down.x * 30.0 + randf_range(-6.0, 6.0), randf_range(-4.0, 4.0))
	var ff: float = float(posmod(int(round(atan2(up.x, -up.y) / (PI / 4.0))), FRAMES)) ## kare 0 = ağız yukarı, k = k*45 derece saat yönü
	var mgr = _mgr(icon.get_tree())
	if mgr != null:
		mgr._add(from, ground_y(owner_body), vel, -down.y * 60.0, randf_range(-3.0, 3.0), int(info["row"]), true,
			float(GunMagMath.cfg(key).get("pitch", 1.0)), MAGS_TEX, MAG_ROWS, absf(icon.global_scale.x), ff)


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
	for i in 4: ## kovan klipleri ~0.6 sn (sekmeler dahil) -> hızlı ateşte üst üste binebilsin
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


## tex/rows/px_scale/ff0: düşen şarjör kendi sayfasından, silahın piksel ölçeğinde, kopma açısına uyan kareden başlar (drop_mag).
func _add(from: Vector2, gy: float, vel: Vector2, vz: float, spin: float, row: int, is_mag: bool, pitch: float,
		tex: Texture2D = null, rows: int = ROWS, px_scale: float = WORLD_PX, ff0: float = -1.0, snd_key: String = "") -> void:
	if _pieces.size() >= MAX_ALIVE:
		var old: Dictionary = _pieces.pop_front()
		if is_instance_valid(old["spr"]):
			(old["spr"] as Node).queue_free()
	var spr := Sprite2D.new()
	spr.texture = tex if tex != null else TEX
	spr.hframes = FRAMES
	spr.vframes = rows
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(px_scale, px_scale)
	var ff: float = ff0 if ff0 >= 0.0 else randf() * FRAMES
	spr.frame = row * FRAMES + int(ff) % FRAMES
	add_child(spr)
	var g := Vector2(from.x, maxf(gy, from.y + 4.0))
	var z: float = g.y - from.y
	spr.global_position = Vector2(g.x, g.y - z)
	_pieces.append({"spr": spr, "g": g, "z": z, "vz": vz, "vel": vel, "ff": ff, "spin": spin, "row": row, "st": 0,
		"t": 0.0, "b": 0, "mag": is_mag, "pitch": pitch, "snd": snd_key})
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
		if int(p["b"]) == 0:
			if is_mag:
				_tink(g, is_mag, float(p["pitch"]))
			else: ## 2026-10-19'daki sessiz kovan kararı 2026-11-13'te kullanıcının kendi kaydıyla değişti (CASING_SNDS)
				_casing_drop(g, String(p["snd"]))
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
	asp.stream = SND_TINK
	asp.pitch_scale = (0.55 if is_mag else 1.0) * pitch * randf_range(0.9, 1.12)
	asp.play()


## Kovanın ilk yere değişi: silahın kayıtlı kliplerinden biri (art arda aynısı değil), hafif perde oynaması.
func _casing_drop(at: Vector2, key: String) -> void:
	var list: Array = CASING_SNDS.get(key, [])
	var now: int = Time.get_ticks_msec()
	if list.is_empty() or _players.is_empty() or now - _last_casing_ms < CASING_MIN_MS:
		return
	_last_casing_ms = now
	var idx: int = randi() % list.size()
	if list.size() > 1 and idx == int(_last_casing_idx.get(key, -1)):
		idx = (idx + 1 + randi() % (list.size() - 1)) % list.size()
	_last_casing_idx[key] = idx
	var asp: AudioStreamPlayer2D = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	asp.stream = list[idx]
	asp.global_position = at
	asp.volume_db = float(CASING_DB.get(key, -12.0))
	asp.pitch_scale = randf_range(0.94, 1.06)
	asp.play()
	_casing_snd_count += 1


## Test / ölçüm için.
func alive_count() -> int:
	return _pieces.size()


func casing_sound_count() -> int:
	return _casing_snd_count
