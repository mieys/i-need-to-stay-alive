extends Node2D

## YENİ HAVUZUN ALAN EFEKTLERİ (madde 575, 2026-11-11; bkz. enemy_abilities.gd): yaratığın çevresinde UYARI HALKASI (data.warn sn, kırmızı-turuncu
## nabız + içe doğru daralan ikinci halka) -> PATLAMA. Patlamada (yalnız yetkili örnek) data.radius içindeki her oyuncu BİR kez vurulur.
## İstemcide görsel kopya (broadcast_enemy_ability_fx "creature_nova"); uyarı sürerken sahibi donar/sersemler/ölürse iki tarafta da iptal
## (EnemyAbilities.caster_disabled + _owner_gone, data.src = ağ kimliği).
## data.style:
##   "scythe" - Kertenkele Adam 3 "Tırpan Kasırgası": iki çelik hilal yaratığın çevresinde bir tur döner + kıvılcımlar.
##   "fire"   - Ateş Pelte "Alev Halkası": dışa yayılan alev dilleri halkası + 1,4 sn'de sönen kavrulmuş zemin; isabet yakar ("firenova").
##   "fuse"   - Bomba Pelte fitili: YALNIZ uyarı (hasarsız); bomba ölürse/dağılırsa söner. Patlama ayrı "blast" ile gelir.
##   "blast"  - Bomba Pelte patlaması: uyarısız, bombanın KENDİ saldırı sayfasının patlama kareleri (3-9) + sarsıntı.
##   "howl"   - Gnoll 3 "Kan Uluması": hasarsız, dışa yayılan çift kızıl ses dalgası (sürü öfkesi enemy_abilities.gd'de).
##   "ember"  - İblis 2 "Kor Yağmuru" (madde 597): düğüm İNİŞ noktasında (sahibi izlemez, sahibi donsa da iptal olmaz - top havada). Uyarı = uçuş:
##              yerde daralan halka + büyüyen gölge, data.from (iniş -> atış noktası) üstünden yay çizen kor topu (çocuk düğüm, karakterlerin
##              üstünde z 11); inişte "fire" gibi alev dilleri + kavrulmuş zemin, isabet yakar ("ember").
##   "orbs"   - İblis 3 "Alev Küreleri" (madde 597): hasarsız; sahibin çevresinde data.count küre döner, küre i data.first + i x data.gap'te
##              (yetenek o anda ateş topunu atar) kaybolur. Sahibi donar/ölürse iki tarafta da iptal (istemcide sahip data.src ile izlenir).
## Çizim: sanat pikseli = TEXEL dünya px ızgarasına oturan kareler (dither yok, düz tonlar); halkalar yer düzleminde (y x GROUND_Y).

const TEXEL := 1.212
const GROUND_Y := 0.62 ## yer halkası basıklığı (izometrik his; isabet yine dairesel yarıçapla)
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const CameraShakeScript := preload("res://scripts/camera_shake.gd")
const BOMB_SHEET := preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Pelte 1/PNG/Slime1/With_shadow/Slime1_Attack_with_shadow.png")
const BOMB_FIRST := 3 ## sayfada patlamanın başladığı kare (0-2 fitil kıvılcımı = yaratığın kendi saldırı klibi)
const BOMB_COLS := 10
const BOMB_FPS := 14.0
const BOMB_SCALE := 1.0545 ## enemy_pelte1.tscn Sprite2D ölçeği (patlama gövdeyle aynı pikselde)
const BOMB_OFFSET := Vector2(0, -5.4)

const BURST_TIME := {"scythe": 0.42, "fire": 0.5, "fuse": 0.0, "blast": 7.0 / BOMB_FPS, "howl": 0.7, "ember": 0.45, "orbs": 0.0}
const LINGER := {"fire": 1.4, "ember": 1.4} ## patlamadan sonra zeminde kalan iz (sn)
const WARN_COL := {"scythe": Color8(232, 72, 56), "fire": Color8(255, 132, 40), "fuse": Color8(255, 64, 48), "blast": Color8(255, 64, 48), "howl": Color8(210, 40, 40),
	"ember": Color8(255, 110, 36), "orbs": Color8(255, 132, 40)}
## Kor topu / alev küresi tonları (dıştan içe): ateş topu + Ateş Pelte ile aynı aile
const FIRE_RED := Color8(214, 60, 30)
const FIRE_ORANGE := Color8(255, 140, 36)
const FIRE_CORE := Color8(255, 230, 120)
const EMBER_ARC_MIN := 46.0 ## kor topunun yay tepesi (dünya px; uzak atışta artar)
const ORB_RADIUS := 19.0 ## kürelerin dönüş yarıçapı (yatay; dikeyde x ORB_FLAT)
const ORB_FLAT := 0.5
const ORB_HEIGHT := -13.0 ## küre yörüngesinin merkezi: iblisin göğsü (sprite ofseti -6 x 1,17)
const ORB_SPIN := 5.5 ## rad/sn

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _style: String = "scythe"
var _warn: float = 0.6
var _radius: float = 70.0
var _t: float = 0.0
var _burst: float = -1.0 ## patlamadan beri geçen süre (< 0: uyarıda)
var _hit_done: bool = false
var _seed: float = 0.0
var _bomb: Sprite2D = null
var _glob: Node2D = null ## "ember": havada uçan kor topu (karakterlerin üstünde çizilsin diye ayrı z'li çocuk)
var _owner_ref: Node2D = null ## "orbs" istemci kopyası: data.src kuklası (önbellek)


func _ready() -> void:
	_style = str(data.get("style", "scythe"))
	_warn = float(data.get("warn", 0.0))
	_radius = float(data.get("radius", 70.0))
	_seed = randf() * TAU
	z_index = 0 ## zemin (enemy_abilities.gd place_on_ground haritanın hemen arkasına taşır)
	if _style == "orbs":
		z_index = 11 ## küreler iblisin önünde (ateş topu gibi)
	elif _style == "ember":
		_glob = Node2D.new()
		_glob.z_index = 11 ## göreli: zemindeki düğümün üstünde, karakterlerin önünde
		add_child(_glob)
		_glob.draw.connect(_draw_glob)
	var life: float = _warn + float(BURST_TIME.get(_style, 0.5)) + float(LINGER.get(_style, 0.0)) + 0.5
	get_tree().create_timer(life, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())
	if _warn <= 0.0:
		_start_burst()


## Sahip düğüm: host'ta source, istemcide data.src kuklası (bulunursa önbelleğe alınır).
func _owner_node() -> Node2D:
	if is_instance_valid(source):
		return source
	if is_instance_valid(_owner_ref):
		return _owner_ref
	var id: int = int(data.get("src", 0))
	if id > 0 and not authoritative:
		_owner_ref = NetworkManager.find_enemy_by_net_id(id) as Node2D
	return _owner_ref if is_instance_valid(_owner_ref) else null


## Fitilin sahibi (bomba) öldü / dağıldı mı? Host: source düğümü; istemci: data.src ağ kimliğiyle kukla.
func _owner_gone() -> bool:
	if is_instance_valid(source):
		return source.get("is_dead") == true
	if authoritative:
		return true ## host'ta sahip silinmiş
	var id: int = int(data.get("src", 0))
	if id > 0:
		var c: Variant = NetworkManager.find_enemy_by_net_id(id)
		return c == null or not is_instance_valid(c) or (c as Node).get("is_dead") == true
	return false


func _process(delta: float) -> void:
	_t += delta
	if _burst < 0.0:
		if _style != "ember" and (AbilitiesScript.caster_disabled(source, data) or ((_style == "fuse" or _style == "orbs") and _owner_gone())):
			queue_free() ## sahibi uyarıda dondu/sersemledi (ya da bomba öldü): patlama yok
			return
		if _style == "orbs": ## küreler iblisle birlikte (istemcide kukla data.src ile)
			var o: Node2D = _owner_node()
			if o != null:
				global_position = o.global_position
		elif is_instance_valid(source) and _style != "fuse" and _style != "ember": ## halka yaratıkla birlikte kalsın (uyarıda kilitli ama itilebilir)
			global_position = source.global_position
		if _t >= _warn:
			if _style == "fuse":
				queue_free()
				return
			_start_burst()
		queue_redraw()
		if _glob:
			_glob.queue_redraw()
		return
	_burst += delta
	if authoritative and not _hit_done and _burst >= _hit_time():
		_hit_done = true
		_apply_hit()
	if _bomb:
		var f: int = mini(BOMB_FIRST + int(_burst * BOMB_FPS), BOMB_COLS - 1)
		_bomb.frame = f
		if _burst * BOMB_FPS >= float(BOMB_COLS - BOMB_FIRST):
			_bomb.visible = false
	queue_redraw()


func _hit_time() -> float:
	match _style:
		"scythe":
			return 0.08
		"fire":
			return 0.1
		"blast", "ember":
			return 0.0
	return INF


func _start_burst() -> void:
	_burst = 0.0
	if _glob:
		_glob.visible = false ## kor topu yere indi
	match _style:
		"scythe", "blast":
			z_index = 12 ## savrulan bıçak / patlama bulutu karakterlerin üstünde
		"howl":
			z_index = 2
	if _style == "blast":
		_bomb = Sprite2D.new()
		_bomb.texture = BOMB_SHEET
		_bomb.hframes = BOMB_COLS
		_bomb.vframes = 4
		_bomb.frame = BOMB_FIRST
		_bomb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bomb.scale = Vector2.ONE * BOMB_SCALE
		_bomb.offset = BOMB_OFFSET
		add_child(_bomb)
		CameraShakeScript.add_at(global_position, 0.35)


func _apply_hit() -> void:
	var kind: String = "firenova" if _style == "fire" else _style
	for p in AbilitiesScript.damageable_players(get_tree()):
		if (p as Node2D).global_position.distance_to(global_position) <= _radius + AbilitiesScript.TARGET_BODY_RADIUS:
			AbilitiesScript.deal_special_damage(p, damage, source, kind)


# ------------------------------------------------------------------------------------------------ çizim
## Sanat pikseli karesi (ızgaraya oturtulmuş).
func _px(p: Vector2, col: Color, size: int = 2) -> void:
	var s: float = TEXEL * size
	var q: Vector2 = (p / TEXEL).round() * TEXEL
	draw_rect(Rect2(q - Vector2(s, s) * 0.5, Vector2(s, s)), col)


## Yer düzleminde halka: yarıçap r, n nokta, aralıklı (dash) ya da dolu.
func _ring(r: float, col: Color, step_px: float = 4.0, dash: bool = false, size: int = 2) -> void:
	var circ: float = TAU * r
	var n: int = maxi(int(circ / (step_px * TEXEL)), 8)
	for i in range(n):
		if dash and int(i / 3.0) % 2 == 1:
			continue
		var a: float = float(i) / float(n) * TAU
		_px(Vector2(cos(a) * r, sin(a) * r * GROUND_Y), col, size)


func _draw() -> void:
	if _burst < 0.0:
		if _style == "orbs":
			_draw_orbs()
			return
		_draw_warn()
		if _style == "ember":
			_draw_ember_shadow()
		return
	match _style:
		"scythe":
			_draw_scythe()
		"fire", "ember":
			_draw_fire()
		"howl":
			_draw_howl()
		"blast":
			_draw_blast_ring()


func _draw_warn() -> void:
	var k: float = clampf(_t / maxf(_warn, 0.01), 0.0, 1.0)
	var base: Color = WARN_COL.get(_style, Color.RED)
	var pulse: float = 0.5 + 0.5 * sin(_t * (14.0 if _style == "fuse" else 9.0))
	## dış halka: sabit, kesikli; iç halka: dışarıdan merkeze daralan dolu halka (ne zaman patlayacağını gösterir)
	_ring(_radius, Color(base, 0.45 + 0.35 * pulse), 4.0, true)
	_ring(_radius * (1.0 - k) + 6.0, Color(base, 0.75), 3.0, false)
	if _style == "fuse": ## fitil: merkezde kırmızı parıltı noktaları
		for i in range(4):
			var a: float = _seed + _t * 6.0 + i * TAU / 4.0
			_px(Vector2(cos(a), sin(a) * GROUND_Y) * 10.0, Color(1.0, 0.85, 0.3, 0.6 + 0.4 * pulse))


func _draw_scythe() -> void:
	var k: float = clampf(_burst / float(BURST_TIME["scythe"]), 0.0, 1.0)
	var fade: float = 1.0 - smoothstep(0.65, 1.0, k)
	var spin: float = _seed + k * TAU * 1.15
	var r: float = _radius * (0.7 + 0.3 * k)
	var steel := Color8(214, 226, 240)
	var edge := Color8(255, 255, 255)
	var dark := Color8(70, 86, 120)
	## iki hilal: her biri ~110 derecelik DOLU kesik - parlak ağız (uçta beyaz), arkasında içe doğru incelen koyu çelik iz bandı.
	## Örnekleme sanat pikselinden sık (boşluksuz şerit).
	var span: float = deg_to_rad(110.0)
	var segs: int = maxi(int(span * r / (TEXEL * 0.8)), 12)
	for h in range(2):
		var a0: float = spin + h * PI
		for i in range(segs):
			var u: float = float(i) / float(segs - 1)
			var a: float = a0 - span * u
			var dir := Vector2(cos(a), sin(a) * GROUND_Y)
			var band: int = int(round(lerpf(5.0, 1.0, u))) ## iz bandının kalınlığı (sanat px), uca doğru incelir
			for b in range(band):
				_px(dir * (r - TEXEL * (2.0 + b)), Color(dark if b > 1 else steel, (0.75 - 0.1 * b) * fade), 1)
			_px(dir * r, Color(edge if u < 0.2 else steel, fade), 2 if u < 0.7 else 1)
	## kıvılcımlar
	for i in range(6):
		var a2: float = _seed * 2.0 + i * TAU / 6.0
		var rr: float = r * (0.9 + 0.5 * k)
		_px(Vector2(cos(a2), sin(a2) * GROUND_Y) * rr, Color(1.0, 0.95, 0.7, fade * (1.0 - k)), 1)


func _draw_fire() -> void:
	var dur: float = float(BURST_TIME[_style])
	var k: float = clampf(_burst / dur, 0.0, 1.0)
	var linger_k: float = clampf((_burst - dur) / float(LINGER[_style]), 0.0, 1.0)
	## kavrulmuş zemin (dolu basık leke, yavaşça söner)
	## kavrulmuş zemin: tek tonlu dolu basık leke (bant/dither yok), yanma bitince yavaşça söner; kenarı 1 sanat px koyu
	var scorch := Color8(52, 32, 24)
	var sa: float = 0.38 * (1.0 - linger_k) * minf(1.0, k * 3.0)
	if sa > 0.01:
		var sr: float = _radius * 0.85
		var rows: int = int(sr * GROUND_Y / TEXEL)
		for yy in range(-rows, rows + 1):
			var y: float = yy * TEXEL
			var half: float = sr * sqrt(maxf(0.0, 1.0 - pow(y / (sr * GROUND_Y), 2.0)))
			half = round(half / TEXEL) * TEXEL
			draw_rect(Rect2(Vector2(-half, y - TEXEL * 0.5), Vector2(half * 2.0, TEXEL)), Color(scorch, sa))
	if k >= 1.0:
		return
	## dışa yayılan alev dilleri: 28 dik dil, her biri 3 tonlu (kor kırmızı taban, turuncu gövde, sarı uç), boyları titrer; arkasında kor tanecikleri
	var r: float = _radius * (0.25 + 0.75 * k)
	var fade: float = 1.0 - smoothstep(0.6, 1.0, k)
	var n: int = maxi(int(_radius * 0.42), 14) ## Ateş Pelte (r 68) 28 dil; kor topu inişi (r 40) 16
	for i in range(n):
		var a: float = _seed + float(i) / float(n) * TAU
		var base := Vector2(cos(a) * r, sin(a) * r * GROUND_Y)
		var hgt: int = 4 + int(3.0 * (0.5 + 0.5 * sin(_seed * 3.0 + i * 1.7 + _burst * 18.0)))
		var sway: float = sin(i * 2.3 + _burst * 14.0) * TEXEL
		for j in range(hgt):
			var c: Color = Color8(196, 46, 26) if j <= 1 else (Color8(255, 140, 36) if j < hgt - 1 else Color8(255, 226, 96))
			var w: int = 3 if j == 0 else (2 if j < hgt - 2 else 1)
			_px(base + Vector2(sway * float(j) / float(hgt), -j * TEXEL * 1.6), Color(c, fade), w)
		var ember := Vector2(cos(a + 0.11), sin(a + 0.11) * GROUND_Y) * (r * 0.7)
		_px(ember + Vector2(0, -_burst * 30.0), Color(Color8(255, 190, 70), fade * 0.8), 1)


func _draw_howl() -> void:
	var dur: float = float(BURST_TIME["howl"])
	for w in range(2):
		var k: float = clampf((_burst - w * 0.18) / (dur - 0.18), 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var fade: float = 1.0 - k
		var r: float = 14.0 + _radius * k
		_ring(r, Color(Color8(210, 40, 40), 0.8 * fade), 3.0, false, 2)
		_ring(r - TEXEL * 2.0, Color(Color8(255, 150, 120), 0.5 * fade), 4.0, true, 1)


## Sanat pikseli ızgarasında dolu daire (yarıçap sanat px): `ci` üstüne (kendisi ya da kor topu çocuğu).
func _disc(ci: CanvasItem, center: Vector2, r_px: float, col: Color) -> void:
	var c: Vector2 = (center / TEXEL).round() * TEXEL
	var rows: int = int(ceil(r_px))
	for yy in range(-rows, rows + 1):
		var half: float = floor(sqrt(maxf(0.0, r_px * r_px - float(yy * yy))) + 0.35)
		if half <= 0.0 and yy != 0:
			continue
		ci.draw_rect(Rect2(c + Vector2(-half - 0.5, yy - 0.5) * TEXEL, Vector2(half * 2.0 + 1.0, 1.0) * TEXEL), col)


## Parlayan ateş küresi (kırmızı kenar, turuncu gövde, sarı çekirdek, sol üstte açık nokta); r = gövde yarıçapı (sanat px). Koyu kontür
## YOK: küçük kürede kontür baskın çıkıp topu kahverengi gösteriyordu (ilk çekim). shade < 1: opak ama koyu (yörüngenin arkası) - iç içe
## yarı saydam diskler çamurlaşırdı.
func _fire_ball(ci: CanvasItem, center: Vector2, r: float, shade: float = 1.0) -> void:
	var d: float = 1.0 - shade
	_disc(ci, center, r + 1.0, FIRE_RED.darkened(d))
	_disc(ci, center, r, FIRE_ORANGE.darkened(d))
	_disc(ci, center + Vector2(-0.5, -0.5) * TEXEL, r * 0.55, FIRE_CORE.darkened(d))
	_disc(ci, center + Vector2(-1.0, -1.0) * TEXEL * maxf(r * 0.4, 1.0), 0.0, Color(1.0, 0.98, 0.85).darkened(d))


## Kor topunun yoldaki konumu (düğüme göre; k = 0 atış, 1 iniş): düz çizgi + yukarı yay.
func _ember_pos(k: float) -> Vector2:
	var from: Vector2 = Vector2(data.get("from", Vector2(0, -60)))
	var h: float = EMBER_ARC_MIN + from.length() * 0.22
	return from * (1.0 - k) + Vector2(0.0, -h * 4.0 * k * (1.0 - k))


## "ember" uyarısı: iniş noktasında büyüyen koyu gölge (top yaklaştıkça koyulaşır).
func _draw_ember_shadow() -> void:
	var k: float = clampf(_t / maxf(_warn, 0.01), 0.0, 1.0)
	var sr: float = (3.0 + 7.0 * k) * TEXEL
	var rows: int = maxi(int(sr * GROUND_Y / TEXEL), 1)
	var col := Color(0.08, 0.03, 0.02, 0.18 + 0.32 * k)
	for yy in range(-rows, rows + 1):
		var y: float = yy * TEXEL
		var half: float = round(sr * sqrt(maxf(0.0, 1.0 - pow(y / (sr * GROUND_Y), 2.0))) / TEXEL) * TEXEL
		draw_rect(Rect2(Vector2(-half, y - TEXEL * 0.5), Vector2(half * 2.0, TEXEL)), col)


## "ember" kor topu (çocuk düğümün draw sinyali): top + arkasında sönen 4 kor tanesi (yolun geçmiş noktaları).
func _draw_glob() -> void:
	if _burst >= 0.0:
		return
	var k: float = clampf(_t / maxf(_warn, 0.01), 0.0, 1.0)
	for i in range(4, 0, -1):
		var kk: float = k - 0.04 * i
		if kk <= 0.0:
			continue
		var tail_col: Color = FIRE_CORE if i == 1 else (FIRE_ORANGE if i == 2 else FIRE_RED)
		_disc(_glob, _ember_pos(kk), 3.0 - 0.55 * i, tail_col)
	var flick: float = 0.3 * sin(_t * 30.0 + _seed)
	_fire_ball(_glob, _ember_pos(k), 4.0 + flick)


## "orbs": iblisin göğsü çevresinde dönen alev küreleri; küre i, sırası gelince (first + i x gap) atılır ve kaybolur.
func _draw_orbs() -> void:
	var n: int = int(data.get("count", 3))
	var first: float = float(data.get("first", _warn))
	var gap: float = float(data.get("gap", 0.2))
	var grow: float = smoothstep(0.0, 0.3, _t) ## çağrılış: merkezden açılır
	for i in range(n):
		if _t >= first + gap * float(i):
			continue
		var a: float = _seed + _t * ORB_SPIN + float(i) / float(n) * TAU
		var p := Vector2(cos(a) * ORB_RADIUS * grow, ORB_HEIGHT + sin(a) * ORB_RADIUS * ORB_FLAT * grow)
		var back: bool = sin(a) < 0.0 ## yörüngenin arka yarısı biraz soluk (derinlik)
		## kısa iz: yörüngede geride kalan 2 kor tanesi
		for j in range(1, 3):
			var aj: float = a - 0.3 * j
			var pj := Vector2(cos(aj) * ORB_RADIUS * grow, ORB_HEIGHT + sin(aj) * ORB_RADIUS * ORB_FLAT * grow)
			_disc(self, pj, 1.8 - 0.6 * j, (FIRE_ORANGE if j == 1 else FIRE_RED).darkened(0.15 if back else 0.0))
		var pulse: float = 0.35 * sin(_t * 24.0 + i * 2.1)
		_fire_ball(self, p, (2.8 + pulse) * (0.4 + 0.6 * grow) + (0.6 if _t >= first - 0.25 else 0.0), 0.85 if back else 1.0)


## Bomba: patlama bulutunun altında zeminde kısa bir şok halkası.
func _draw_blast_ring() -> void:
	var k: float = clampf(_burst / 0.3, 0.0, 1.0)
	if k >= 1.0:
		return
	_ring(_radius * (0.35 + 0.65 * k), Color(Color8(255, 200, 120), 0.7 * (1.0 - k)), 3.0, false, 2)
