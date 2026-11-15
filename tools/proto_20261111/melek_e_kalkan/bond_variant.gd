extends "res://scripts/melek_bond_fx.gd"

## PROTOTİP (oyuna bağlı DEĞİL): Melek E bağı + dostun KALKAN YENİLENME baloncuğu.
## Oyundaki bağın (melek_bond_fx.gd) alt sınıfı; yakala.gd dostun _ally_aura_fx["shield"]'ine bunu koyar.
##   suan : bugünkü bağ (baloncuk yok)
##   a    : bağ dosta değince dostun kalkan baloncuğu açılır (grow -> loop), E boyunca açık, bitince söner
##   b    : a + her dalga paketi varınca baloncuk bağın açık mavisine parlar (kalkan "dolar")
##   c    : b + baloncuk E ile açılır, ip bel halkası yerine baloncuğun YÜZEYİNE (Melek'e bakan tarafına) bağlanır, varışta
##          değme noktasından baloncuğun kenarı boyunca ışık dalgası yayılır, kristal değme noktasında çıkar
## C ailesi - BAĞLANMA NOKTASI (kullanıcı: "C güzel ama bağ kurmuş gibi görünmüyor"); hepsi c + kalıcı bir bağlantı parçası,
## bağ kurulunca 0,25-0,35 sn'de oluşur, kristal göğüste (baloncuğun içinde) çıkar:
##   c1 : BAĞ HALKASI  - değme noktasında yüzeye oturmuş küçük ışık halkası (bel halkasının küçüğü), ip ortasına girer, ışıltı döner
##   c2 : IŞIYAN YAMA  - ipin ucu çan ağzı gibi açılır, baloncuğun değdiği kenarı kalıcı olarak bağ mavisine boyanır
##   c3 : DAMAR SAÇAK  - ipin ucu baloncuğun yüzeyine kök gibi 4 damar salar, dalga damarlardan yayılır
##   c4 : SARMAL BAĞ   - ip değme noktasından iki kola ayrılıp baloncuğu dıştan sarar, dalga kollar boyunca dolanır
## 2. tur (kullanıcı: "C2'nin okunurluğunu ve C1'in görünürlüğünü artır"):
##   c1b : C1 büyük (6x3 texel) + çift kat açık halka + iki yanı koyu hat + dış hale nefesi + dolu ağız, varışta açılıp krem parlar
##   c2b : C2 kalın şerit (3 baloncuk pikseli, koyu dış hat, açık kenar çizgisi, gidip gelen ışıltı) + içe doğru mavi dolum
##         + koyu hatlı büyük çan ağzı

var variant: String = "suan"

const RIM_PX := 10.5 ## baloncuk sanatının görünen kenarı (24x24 karede bbox 1..23)
## "grow" karelerinin görünen yarıçapı (bubble_frames.tres ölçüldü, 12 fps: 0,42 sn'de tam boy)
const GROW_R := [3.0, 5.0, 9.0, 10.0, 10.0, 11.0, 11.0, 11.0, 11.0, 11.0]
const FLARE_TIME := 0.38
const RIPPLE_TIME := 0.42
const CONTACT_FLASH := 0.16
const FORM_TIME := {"c1": 0.25, "c2": 0.25, "c3": 0.32, "c4": 0.36}
const JOINT_FADE := 0.18

var _bubble_on: bool = false
var _bubble_off: bool = false
var _flare_t: float = -10.0
var _conn_t: float = -1.0
var _ripples: Array[float] = []
var _layer: Node2D = null ## bağlantı parçası ipin (z 60) ÜSTÜNDE
var _cells: Dictionary = {} ## çizim önbelleği: Vector2i hücre -> Color (sonra yazılan üstte)


func _is_c() -> bool:
	return variant.begins_with("c")


func _shield_vis() -> Node2D:
	var p: Node = get_parent()
	return p.get_node_or_null("ShieldVisual") as Node2D if p != null else null


func _bubble() -> AnimatedSprite2D:
	var sv: Node2D = _shield_vis()
	return sv.get_node_or_null("BubbleSprite") as AnimatedSprite2D if sv != null else null


## Baloncuğun ŞU ANKİ görünen kenarı (sanat pikseli) - büyürken ip/ışık havada kalmasın.
func _rim_px() -> float:
	var b: AnimatedSprite2D = _bubble()
	if b != null and b.animation == &"grow":
		return float(GROW_R[clampi(b.frame, 0, GROW_R.size() - 1)]) - 0.5
	return RIM_PX


func _ready() -> void:
	super()
	_layer = Node2D.new()
	_layer.z_index = 61
	_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_layer)
	_layer.draw.connect(_draw_layer)
	if _is_c(): ## c ailesi: baloncuk E ile birlikte açılır, ip vardığında tam boydadır
		_bubble_on = true
		var sv: Node2D = _shield_vis()
		if sv != null and sv.has_method("appear"):
			sv.call("appear")


## Baloncuğun Melek'e bakan kenar noktası (dünya).
func _contact_world() -> Vector2:
	var b: AnimatedSprite2D = _bubble()
	if b == null or caster == null or not is_instance_valid(caster):
		return Vector2.ZERO
	var c: Vector2 = b.global_position
	var bpx: float = absf(b.global_scale.x)
	var aim: Vector2 = caster.global_position + Vector2(0.0, -30.0)
	var dir: Vector2 = (aim - c).normalized()
	return c + dir * (_rim_px() - 0.5) * bpx


func ring_world_center() -> Vector2:
	if not _is_c() or _bubble() == null or caster == null or not is_instance_valid(caster):
		return super()
	## ip ucu = halka merkezi + (side * (RING_RX - 1), -1) texel (melek_bond_ribbon.gd compute) -> uç tam değme noktasına düşsün
	var rim: Vector2 = _contact_world()
	var side: float = -1.0 if rim.x >= caster.global_position.x else 1.0
	return rim - Vector2(side * (BondMath.RING_RX - 1.0), -1.0) * BondMath.TEXEL_W


func _arrive(glyph: String) -> void:
	super(glyph)
	if variant == "suan":
		return
	if glyph == "star":
		_conn_t = _t
		if not _bubble_on:
			_bubble_on = true
			var sv: Node2D = _shield_vis()
			if sv != null and sv.has_method("appear"):
				sv.call("appear")
		if _is_c():
			_ripples.append(_t)
	elif glyph == "crystal":
		if variant != "a":
			_flare_t = _t
		if _is_c():
			_ripples.append(_t)


func _process(delta: float) -> void:
	super(delta)
	if variant == "suan":
		return
	var b: AnimatedSprite2D = _bubble()
	if b != null:
		var f: float = clampf(1.0 - (_t - _flare_t) / FLARE_TIME, 0.0, 1.0)
		f = f * f
		## bağın açık mavisine (MANA[3] a6d0ff) doğru aydınlanır + yarı saydam baloncuk bir an koyulaşır
		b.self_modulate = Color(1.0 + 0.55 * f, 1.0 + 0.75 * f, 1.0 + 1.7 * f, 1.0 + 1.1 * f)
	if _stopping and not _bubble_off:
		_bubble_off = true
		var sv: Node2D = _shield_vis()
		if sv != null and sv.has_method("hide_instant"):
			sv.call("hide_instant")
	for i in range(_ripples.size() - 1, -1, -1):
		if _t - _ripples[i] > RIPPLE_TIME:
			_ripples.remove_at(i)
	if _layer != null:
		_layer.queue_redraw()


func _update_ring_frames() -> void:
	super()
	if _is_c():
		for s: Sprite2D in [_ring_back, _ring_front, _echo_back, _echo_front]:
			s.visible = false


func _update_glyphs() -> void:
	if variant != "c": ## c1-c4: kristal göğüste (baloncuğun içinde), oyundaki gibi
		super()
		return
	var sc: float = _local_px_scale()
	var base: Vector2 = to_local(_contact_world()) if _bubble() != null else _body_local(CHEST)
	for i in range(_glyphs.size() - 1, -1, -1):
		var e: Array = _glyphs[i]
		var s: Sprite2D = e[0]
		var glyph: String = e[2]
		var age: float = _t - float(e[1])
		var life: float = STAR_LIFE if glyph == "star" else GLYPH_LIFE
		if age >= life or not is_instance_valid(s):
			if is_instance_valid(s):
				s.queue_free()
			_glyphs.remove_at(i)
			continue
		var k: int = int(age * BondMath.PROTO_FPS)
		s.frame = BondMath.glyph_frame(glyph, k)
		s.scale = Vector2.ONE * sc
		var dy: float = 0.0 if glyph == "star" else -float(k) * 1.0
		s.position = base + Vector2(0.0, dy) * sc


# ---------------------------------------------------------------- çizim (katman: ipin üstü)
## Hücre ızgarası: `step` boyutlu kareler, `origin`e oturur. _stamp sonra yazılanı üste koyar; _flush hepsini çizer.
func _stamp(origin: Vector2, step: float, p: Vector2, col: Color) -> void:
	if col.a <= 0.01:
		return
	var q: Vector2 = (p - origin) / step
	var key := Vector2i(floori(q.x), floori(q.y))
	var prev: Variant = _cells.get(key)
	if prev != null and (prev as Color).a > col.a and col.a < 0.99:
		return ## daha soluk bir yazım parlağı ezmesin
	_cells[key] = col


func _flush(origin: Vector2, step: float) -> void:
	for key: Vector2i in _cells:
		_layer.draw_rect(Rect2(origin + Vector2(key) * step, Vector2.ONE * step), _cells[key])
	_cells.clear()


func _glow() -> float:
	var f: float = clampf(1.0 - (_t - _flare_t) / FLARE_TIME, 0.0, 1.0)
	return f * f


func _form() -> float:
	if _conn_t < 0.0:
		return 0.0
	var f: float = clampf((_t - _conn_t) / float(FORM_TIME.get(variant, 0.25)), 0.0, 1.0)
	f = 1.0 - pow(1.0 - f, 3.0)
	if _stopping:
		f *= clampf(1.0 - (_t - _stop_t) / JOINT_FADE, 0.0, 1.0)
	return f


func _a(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0))


func _draw_layer() -> void:
	if not _is_c():
		return
	var b: AnimatedSprite2D = _bubble()
	if b == null:
		return
	var bp: float = absf(b.scale.x) ## baloncuk sanat pikseli, bu düğümün yerelinde (ikisi de dostun çocuğu)
	var tx: float = _local_px_scale() ## Melek/ip sanat pikseli
	var c: Vector2 = to_local(b.global_position)
	var a0: float = (to_local(_contact_world()) - c).angle()
	var rim: float = _rim_px()
	match variant:
		"c1": _draw_c1(c, a0, rim * bp, tx)
		"c2": _draw_c2(c, a0, rim, bp, tx)
		"c3": _draw_c3(c, a0, rim * bp, tx)
		"c4": _draw_c4(c, a0, rim * bp, tx)
		"c1b": _draw_c1b(c, a0, rim * bp, tx)
		"c2b": _draw_c2b(c, a0, rim, bp, tx)
	if variant != "c4":
		_draw_ripple(c, a0, rim, bp)


## c (ve c1-c3): değme noktasından iki yana baloncuğun KENDİ ızgarasında koşan ışık + değme anında artı parlaması.
func _draw_ripple(c: Vector2, a0: float, rim: float, bp: float) -> void:
	var cols: Array = [BondMath.CREAM, BondMath.MANA[4], BondMath.MANA[3], BondMath.MANA[2]]
	var origin: Vector2 = c - Vector2.ONE * 0.5 * bp
	for t0: float in _ripples:
		var age: float = _t - t0
		var k: float = clampf(age / RIPPLE_TIME, 0.0, 1.0)
		var reach: float = (1.0 - pow(1.0 - k, 2.0)) * PI * 0.92
		var fade: float = 1.0 - k
		for side: float in [-1.0, 1.0]:
			for j in range(4): ## kuyruk: baştan geriye 4 piksel, solan tonlar
				var a: float = a0 + side * (reach - float(j) * 0.16)
				if side * (a - a0) < 0.0:
					continue
				_stamp(origin, bp, c + Vector2.from_angle(a) * rim * bp, _a(cols[j], fade * (1.0 - 0.18 * float(j))))
		if age < CONTACT_FLASH and variant == "c":
			var ca: float = 1.0 - age / CONTACT_FLASH
			var p: Vector2 = c + Vector2.from_angle(a0) * rim * bp
			for o: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				_stamp(origin, bp, p + o * bp, _a(BondMath.CREAM, ca))
	_flush(origin, bp)


## c1 BAĞ HALKASI: yüzeye teğet küçük elips halka (koyu dış hat + açık halka + dönen ışıltı + merkezde ip ağzı).
func _draw_c1(c: Vector2, a0: float, r: float, tx: float) -> void:
	var f: float = _form()
	if f <= 0.0:
		return
	var g: float = _glow()
	var e: Vector2 = c + Vector2.from_angle(a0) * r
	var tn := Vector2.from_angle(a0 + PI * 0.5) ## teğet
	var nm := Vector2.from_angle(a0) ## normal (dışa)
	var origin: Vector2 = e - Vector2.ONE * 0.5 * tx
	var rt: float = 4.6 * f
	var rn: float = 2.0 * f
	var light: Color = BondMath.MANA[3].lerp(BondMath.CREAM, g)
	var n: int = 64
	for pass_i in range(2): ## 0: koyu dış hat, 1: açık halka
		var grow: float = 1.0 if pass_i == 0 else 0.0
		for i in range(n):
			var th: float = TAU * float(i) / float(n)
			var p: Vector2 = e + tn * cos(th) * (rt + grow) * tx + nm * sin(th) * (rn + grow) * tx
			var col: Color = BondMath.MANA[1] if pass_i == 0 else light
			## ışıltı: halka üstünde dönen krem nokta
			if pass_i == 1:
				var d: float = absf(wrapf(th - _t * 5.0, -PI, PI))
				if d < 0.35:
					col = BondMath.CREAM
			_stamp(origin, tx, p, _a(col, f))
	## ağız: ipin girdiği merkez
	for o: Vector2 in [Vector2.ZERO, nm, -nm]:
		_stamp(origin, tx, e + o * tx, _a(BondMath.MANA[4].lerp(BondMath.CREAM, g), f))
	_flush(origin, tx)


## c2 IŞIYAN YAMA: değdiği kenar kalıcı mavi (baloncuk ızgarası, ortada kalın uçlara incelen) + ipin ucunda çan ağzı (ip ızgarası).
func _draw_c2(c: Vector2, a0: float, rim: float, bp: float, tx: float) -> void:
	var f: float = _form()
	if f <= 0.0:
		return
	var g: float = _glow()
	var origin_b: Vector2 = c - Vector2.ONE * 0.5 * bp
	var span: float = 0.75 * f + 0.25 * g
	var steps: int = 40
	for i in range(steps + 1):
		var u: float = lerpf(-1.0, 1.0, float(i) / float(steps))
		var a: float = a0 + u * span
		var w: float = 1.0 - absf(u)
		var col: Color = BondMath.MANA[2].lerp(BondMath.MANA[4], w).lerp(BondMath.CREAM, g * w)
		_stamp(origin_b, bp, c + Vector2.from_angle(a) * rim * bp, _a(col, (0.45 + 0.55 * w) * f))
		if w > 0.45: ## ortada iki piksel kalın (içe doğru)
			_stamp(origin_b, bp, c + Vector2.from_angle(a) * (rim - 1.0) * bp, _a(BondMath.MANA[3], (0.25 + 0.5 * w) * f))
	_flush(origin_b, bp)
	## çan ağzı: ipin son 4 pikseli dışa doğru incelen kama
	var e: Vector2 = c + Vector2.from_angle(a0) * rim * bp
	var nm := Vector2.from_angle(a0)
	var tn := Vector2.from_angle(a0 + PI * 0.5)
	var origin_t: Vector2 = e - Vector2.ONE * 0.5 * tx
	for d in range(5):
		var half: float = (4.0 - float(d)) * f
		var col2: Color = BondMath.MANA[3].lerp(BondMath.MANA[4], 1.0 - float(d) / 4.0).lerp(BondMath.CREAM, g)
		var k: float = -half
		while k <= half + 0.01:
			_stamp(origin_t, tx, e + nm * float(d) * tx + tn * k * tx, _a(col2, f * (1.0 - 0.12 * float(d))))
			k += 1.0
	_flush(origin_t, tx)


## c3 DAMAR SAÇAK: değme noktasından baloncuğun yüzeyine 4 damar (dıştakiler kenarı izler, içtekiler yüzeyde içe kıvrılır).
const VEINS := [Vector2(-0.95, 0.04), Vector2(-0.42, 0.34), Vector2(0.42, 0.34), Vector2(0.95, 0.04)] ## (açı, içe derinlik)

func _draw_c3(c: Vector2, a0: float, r: float, tx: float) -> void:
	var f: float = _form()
	if f <= 0.0:
		return
	var g: float = _glow()
	var e: Vector2 = c + Vector2.from_angle(a0) * r
	var origin: Vector2 = e - Vector2.ONE * 0.5 * tx
	var pulse_s: float = clampf((_t - _flare_t) / 0.3, 0.0, 1.2) ## varışta damar boyunca koşan parlak nokta
	for v: Vector2 in VEINS:
		var n: int = 36
		for i in range(n + 1):
			var s: float = float(i) / float(n) * f
			var a: float = a0 + v.x * s
			var rr: float = r * (1.0 - v.y * s * s)
			var p: Vector2 = c + Vector2.from_angle(a) * rr
			var tip: float = s / maxf(f, 0.001)
			var col: Color = BondMath.MANA[4].lerp(BondMath.MANA[2], tip)
			if absf(s - pulse_s) < 0.12:
				col = BondMath.CREAM
			_stamp(origin, tx, p, _a(col, (1.0 - 0.55 * tip) * maxf(f, 0.0)))
	for o: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]: ## düğüm
		_stamp(origin, tx, e + (o - Vector2(0.5, 0.5)) * tx, _a(BondMath.MANA[4].lerp(BondMath.CREAM, g), f))
	_flush(origin, tx)


## c4 SARMAL BAĞ: değme noktasından iki kol baloncuğun hemen DIŞINDAN dolanıp karşıda buluşur (koyu alt hat + açık hat), dalga kollarda koşar.
func _draw_c4(c: Vector2, a0: float, r: float, tx: float) -> void:
	var f: float = _form()
	if f <= 0.0:
		return
	var origin: Vector2 = c - Vector2.ONE * 0.5 * tx
	var reach: float = PI * f
	var rr: float = r + 1.0 * tx
	var n: int = 140
	## dalga paketleri (kollarda değme noktasından karşıya)
	var heads: Array[float] = []
	for t0: float in _ripples:
		var k: float = clampf((_t - t0) / RIPPLE_TIME, 0.0, 1.0)
		heads.append((1.0 - pow(1.0 - k, 2.0)) * PI)
	for side: float in [-1.0, 1.0]:
		for i in range(n + 1):
			var s: float = float(i) / float(n) * reach
			var a: float = a0 + side * s
			_stamp(origin, tx, c + Vector2.from_angle(a) * (rr + tx), _a(BondMath.MANA[1], 0.8 * f))
		for i in range(n + 1):
			var s: float = float(i) / float(n) * reach
			var a: float = a0 + side * s
			var col: Color = BondMath.MANA[3].lerp(BondMath.MANA[2], s / PI)
			var shimmer: float = absf(wrapf(s - _t * 2.2, -0.45, 0.45))
			if shimmer < 0.06:
				col = BondMath.MANA[4]
			var alpha: float = 0.9 * f
			for h: float in heads:
				var dh: float = h - s
				if dh >= 0.0 and dh < 0.5:
					col = BondMath.CREAM.lerp(BondMath.MANA[4], dh / 0.5)
					alpha = f
			_stamp(origin, tx, c + Vector2.from_angle(a) * rr, _a(col, alpha))
	## değme düğümü
	var e: Vector2 = c + Vector2.from_angle(a0) * rr
	var g: float = _glow()
	for o: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_stamp(origin, tx, e + o * tx, _a(BondMath.MANA[4].lerp(BondMath.CREAM, g), f))
	_flush(origin, tx)


## c1b: C1'in görünür sürümü. Halkalar (texel kayması, renk): dış hale -> koyu dış hat -> koyu iç hat -> açık iç -> açık ana halka.
func _draw_c1b(c: Vector2, a0: float, r: float, tx: float) -> void:
	var f: float = _form()
	if f <= 0.0:
		return
	var g: float = _glow()
	var breathe: float = 0.5 + 0.5 * sin(_t * 5.0)
	var e: Vector2 = c + Vector2.from_angle(a0) * r
	var tn := Vector2.from_angle(a0 + PI * 0.5)
	var nm := Vector2.from_angle(a0)
	var origin: Vector2 = e - Vector2.ONE * 0.5 * tx
	var rt: float = (6.0 + 1.0 * g) * f
	var rn: float = (3.0 + 0.6 * g) * f
	var main_col: Color = BondMath.MANA[4].lerp(BondMath.CREAM, g)
	var inner_col: Color = BondMath.MANA[3].lerp(BondMath.MANA[4], 0.4 * breathe).lerp(BondMath.CREAM, g)
	var rings: Array = [
		[2.0, _a(BondMath.MANA[3], (0.22 + 0.25 * breathe + 0.4 * g) * f)],
		[1.0, _a(BondMath.MANA[0], 0.95 * f)],
		[-2.0, _a(BondMath.MANA[1], 0.95 * f)],
		[-1.0, _a(inner_col, f)],
		[0.0, _a(main_col, f)],
	]
	var n: int = 120
	## ağız: halkanın içi dolu (ipin girdiği yer)
	for i in range(n):
		var th: float = TAU * float(i) / float(n)
		for k: float in [0.0, 0.34, 0.67]:
			var p: Vector2 = e + tn * cos(th) * maxf(rt - 2.0, 0.0) * k * tx + nm * sin(th) * maxf(rn - 2.0, 0.0) * k * tx
			_stamp(origin, tx, p, _a(BondMath.MANA[2].lerp(BondMath.MANA[4], 1.0 - k), 0.8 * f))
	for ring: Array in rings:
		var d: float = ring[0]
		for i in range(n):
			var th: float = TAU * float(i) / float(n)
			var p: Vector2 = e + tn * cos(th) * (rt + d) * tx + nm * sin(th) * (rn + d) * tx
			var col: Color = ring[1]
			if d == 0.0:
				var d1: float = absf(wrapf(th - _t * 4.0, -PI, PI))
				var d2: float = absf(wrapf(th + _t * 4.0 + PI, -PI, PI))
				if d1 < 0.3 or d2 < 0.3:
					col = _a(BondMath.CREAM, f)
			_stamp(origin, tx, p, col)
	_flush(origin, tx)


## c2b: C2'nin okunur sürümü. Baloncuk ızgarasında kalın şerit (dıştan içe: koyu hat, açık kenar, 3 kat mavi, soluk dolum) +
## şerit üstünde gidip gelen krem ışıltı + koyu hatlı büyük çan ağzı (ip ızgarası).
func _draw_c2b(c: Vector2, a0: float, rim: float, bp: float, tx: float) -> void:
	var f: float = _form()
	if f <= 0.0:
		return
	var g: float = _glow()
	var origin_b: Vector2 = c - Vector2.ONE * 0.5 * bp
	var span: float = (0.95 + 0.3 * g) * f
	var shim: float = sin(_t * 2.6) * 0.75
	var steps: int = 72
	## katlar: [baloncuk pikseli kayması, renk, alfa, en az ağırlık]
	var layers: Array = [
		[1.0, BondMath.MANA[0], 0.9, 0.12],
		[-4.0, BondMath.MANA[3], 0.22, 0.55],
		[-3.0, BondMath.MANA[2], 0.45, 0.4],
		[-2.0, BondMath.MANA[2], 0.75, 0.2],
		[-1.0, BondMath.MANA[3], 0.9, 0.0],
		[0.0, BondMath.MANA[4], 1.0, 0.0],
	]
	for layer: Array in layers:
		var d: float = layer[0]
		for i in range(steps + 1):
			var u: float = lerpf(-1.0, 1.0, float(i) / float(steps))
			var w: float = 1.0 - absf(u)
			if w < float(layer[3]):
				continue
			var a: float = a0 + u * span
			var col: Color = layer[1]
			if d >= -1.0:
				col = col.lerp(BondMath.CREAM, g * w)
				if d == 0.0 and absf(u - shim) < 0.09:
					col = BondMath.CREAM
			var alpha: float = float(layer[2]) * f * clampf(w * 2.2, 0.0, 1.0)
			_stamp(origin_b, bp, c + Vector2.from_angle(a) * (rim + d) * bp, _a(col, alpha))
	_flush(origin_b, bp)
	## çan ağzı: koyu hatlı, 7 piksel boyunca dışa incelen kama
	var e: Vector2 = c + Vector2.from_angle(a0) * rim * bp
	var nm := Vector2.from_angle(a0)
	var tn := Vector2.from_angle(a0 + PI * 0.5)
	var origin_t: Vector2 = e - Vector2.ONE * 0.5 * tx
	for d in range(8):
		var half: float = (6.0 - float(d) * 0.85) * f
		if half < 0.0:
			break
		var k: float = -half - 1.0
		while k <= half + 1.01:
			var edge: bool = absf(k) > half
			var col2: Color = BondMath.MANA[0] if edge else BondMath.MANA[4].lerp(BondMath.MANA[3], float(d) / 7.0).lerp(BondMath.CREAM, g)
			_stamp(origin_t, tx, e + nm * float(d) * tx + tn * k * tx, _a(col2, f * (0.95 if edge else 1.0)))
			k += 1.0
	_flush(origin_t, tx)
