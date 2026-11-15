extends Node2D

## Melek E (Kalkan Yenileme) bağının dostun KALKAN BALONCUĞUNA bağlandığı yer (madde 565; kullanıcı seçimi prototip C1, Kutsal Zırh
## evrimiyle C1 + C4: tools/proto_20261111/melek_e_kalkan/bond_variant.gd _draw_c1 / _draw_c4 / _draw_ripple).
## melek_bond_fx.gd baloncuk kipinde kurar (bağın çocuğu, dönüşümsüz -> yerel = dostun yereli), ipin (z 60) ÜSTÜNDE çizer:
##   - BAĞ HALKASI: değme noktasında baloncuğun yüzeyine teğet küçük elips halka (koyu dış hat + açık halka + dönen krem ışıltı),
##     ip ortasına girer; bağ kurulunca RING_FORM'da açılır, varışta kreme parlar.
##   - KENAR IŞIĞI: her varışta değme noktasından iki yana baloncuğun KENDİ piksel ızgarasında koşan ışık.
##   - SARMAL BAĞ (kaster Kutsal Zırh / melek_e1 evrimliyse): halkadan iki kol baloncuğun hemen dışından dolanıp karşıda buluşur
##     (koyu alt hat + açık hat, yavaş ışıltı); dalga kenar ışığı yerine kollar boyunca koşar.
## Halka + sarmal Melek'in (ipin) sanat pikseli ızgarasında, kenar ışığı baloncuğun ızgarasında. Ağ yok: her istemcide bağ çizer.

const BondMath := preload("res://scripts/melek_bond_math.gd")

const RING_FORM := 0.25
const WRAP_FORM := 0.36
const FADE := 0.18 ## bağ çözülünce (baloncuğun hide_instant'ı ile aynı süre)
const RIPPLE_TIME := 0.42
const RING_RT := 4.6 ## halka yarı ekseni teğet boyunca (texel)
const RING_RN := 2.0 ## yüzeye dik (texel)
const RING_N := 64
const RING_SPIN := 5.0 ## ışıltı rad/sn
const WRAP_SPIN := 2.2

var bond: Node2D = null
var _cells: Dictionary = {} ## Vector2i hücre -> Color (sonra yazılan üstte)


func _ready() -> void:
	z_index = 61


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if bond == null or not is_instance_valid(bond):
		return
	var st: Dictionary = bond.call("joint_state")
	if st.is_empty() or float(st["conn_t"]) < 0.0:
		return
	var c: Vector2 = st["c"]
	var bp: float = st["bp"]
	var rim: float = st["rim"]
	var a0: float = st["a0"]
	var tx: float = st["tx"]
	var t: float = st["t"]
	var fade: float = 1.0
	if float(st["stop_t"]) >= 0.0:
		fade = clampf(1.0 - (t - float(st["stop_t"])) / FADE, 0.0, 1.0)
	if fade <= 0.0:
		return
	var since: float = t - float(st["conn_t"])
	var r: float = rim * bp
	var origin: Vector2 = c - Vector2.ONE * 0.5 * tx
	var wrap: bool = st["wrap"]
	if wrap:
		_wrap(c, a0, r, tx, t, form(since, WRAP_FORM) * fade, st["ripples"])
	_ring(c, c + Vector2.from_angle(a0) * r, a0, tx, t, form(since, RING_FORM) * fade, float(st["glow"]))
	_flush(origin, tx)
	if not wrap:
		_ripple(c, a0, rim, bp, t, st["ripples"])
		_flush(c - Vector2.ONE * 0.5 * bp, bp)


## Oluşma eğrisi (0..1, ease-out kübik).
static func form(since: float, dur: float) -> float:
	var f: float = clampf(since / dur, 0.0, 1.0)
	return 1.0 - pow(1.0 - f, 3.0)


func _ring(c: Vector2, e: Vector2, a0: float, tx: float, t: float, f: float, g: float) -> void:
	if f <= 0.0:
		return
	var tn := Vector2.from_angle(a0 + PI * 0.5)
	var nm := Vector2.from_angle(a0)
	var rt: float = RING_RT * f
	var rn: float = RING_RN * f
	var light: Color = BondMath.MANA[3].lerp(BondMath.CREAM, g)
	for pass_i in range(2): ## 0: koyu dış hat, 1: açık halka
		var grow: float = 1.0 if pass_i == 0 else 0.0
		for i in range(RING_N):
			var th: float = TAU * float(i) / float(RING_N)
			var p: Vector2 = e + tn * cos(th) * (rt + grow) * tx + nm * sin(th) * (rn + grow) * tx
			var col: Color = BondMath.MANA[1] if pass_i == 0 else light
			if pass_i == 1 and absf(wrapf(th - t * RING_SPIN, -PI, PI)) < 0.35:
				col = BondMath.CREAM
			_stamp(c, tx, p, _a(col, f))
	for o: Vector2 in [Vector2.ZERO, nm, -nm]: ## ağız: ipin girdiği merkez
		_stamp(c, tx, e + o * tx, _a(BondMath.MANA[4].lerp(BondMath.CREAM, g), f))


func _wrap(c: Vector2, a0: float, r: float, tx: float, t: float, f: float, ripples: Array) -> void:
	if f <= 0.0:
		return
	var reach: float = PI * f
	var rr: float = r + tx
	var n: int = maxi(24, int(PI * rr / tx * 1.4))
	var heads: Array[float] = []
	for t0: float in ripples: ## dalga paketleri kollarda değme noktasından karşıya
		var k: float = clampf((t - t0) / RIPPLE_TIME, 0.0, 1.0)
		heads.append((1.0 - pow(1.0 - k, 2.0)) * PI)
	for side: float in [-1.0, 1.0]:
		for i in range(n + 1):
			var s: float = float(i) / float(n) * reach
			_stamp(c, tx, c + Vector2.from_angle(a0 + side * s) * (rr + tx), _a(BondMath.MANA[1], 0.8 * f))
		for i in range(n + 1):
			var s: float = float(i) / float(n) * reach
			var col: Color = BondMath.MANA[3].lerp(BondMath.MANA[2], s / PI)
			if absf(wrapf(s - t * WRAP_SPIN, -0.45, 0.45)) < 0.06:
				col = BondMath.MANA[4]
			var alpha: float = 0.9 * f
			for h: float in heads:
				var dh: float = h - s
				if dh >= 0.0 and dh < 0.5:
					col = BondMath.CREAM.lerp(BondMath.MANA[4], dh / 0.5)
					alpha = f
			_stamp(c, tx, c + Vector2.from_angle(a0 + side * s) * rr, _a(col, alpha))


func _ripple(c: Vector2, a0: float, rim: float, bp: float, t: float, ripples: Array) -> void:
	var cols: Array = [BondMath.CREAM, BondMath.MANA[4], BondMath.MANA[3], BondMath.MANA[2]]
	for t0: float in ripples:
		var k: float = clampf((t - t0) / RIPPLE_TIME, 0.0, 1.0)
		var reach: float = (1.0 - pow(1.0 - k, 2.0)) * PI * 0.92
		var fade: float = 1.0 - k
		for side: float in [-1.0, 1.0]:
			for j in range(4): ## kuyruk: baştan geriye 4 piksel, solan tonlar
				var a: float = a0 + side * (reach - float(j) * 0.16)
				if side * (a - a0) < 0.0:
					continue
				_stamp(c, bp, c + Vector2.from_angle(a) * rim * bp, _a(cols[j], fade * (1.0 - 0.18 * float(j))))


## Hücre ızgarası: `step` boyutlu kareler, merkezi `anchor`a oturur (anchor + (n + 0.5) * step değil: anchor bir hücrenin merkezi).
func _stamp(anchor: Vector2, step: float, p: Vector2, col: Color) -> void:
	if col.a <= 0.01:
		return
	var q: Vector2 = (p - anchor) / step + Vector2(0.5, 0.5)
	var key := Vector2i(floori(q.x), floori(q.y))
	var prev: Variant = _cells.get(key)
	if prev != null and (prev as Color).a > col.a and col.a < 0.99:
		return ## daha soluk bir yazım parlağı ezmesin
	_cells[key] = col


func _flush(origin: Vector2, step: float) -> void:
	## origin = anchor - 0.5 * step (hücre (0,0) anchor'ı ortalar). Halka + sarmal aynı ızgarada: ikisi de baloncuk merkezini anchor alır.
	for key: Vector2i in _cells:
		draw_rect(Rect2(origin + Vector2(key) * step, Vector2.ONE * step), _cells[key])
	_cells.clear()


func _a(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, clampf(a, 0.0, 1.0))
