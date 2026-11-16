extends Node2D

## VAMPİR ÇOCUK Q "Kan Emme" efekt PROTOTİPLERİ (2026-11-16, OYUNA BAĞLI DEĞİL; kullanıcı: "Vampirin Q yeteneğinin kan emme
## yeteneği için yeni efekt prototipi hazırla"). Bugünkü "drain" (scripts/vampir_fx.gd): hedef başına 9 kare damla (3 TEXEL =
## 3,6 dünya birimi, Vampir karakter pikselinin ~4 katı iri) bezier'de 0,42 sn, kaynakta 4 piksellik halka, varışta 8 piksellik halka.
## Burada her şey Vampir KARAKTER PİKSELİNDE (0,847 dünya, madde 516 ile aynı) çizilir: dolu kütleler 5 tonlu CRIM rampası (madde 516
## "Kızıl Girdap", onaylı) + 1 px koyu kontur; en parlak ton krem (madde 710 K3). TİTREŞİM / dither / saçılan tek piksel YOK (kalıcı kural);
## sönme küçülme ya da düz alfa bandıyla.
##   A Kan Akıntısı    : hedeften Vampir'e sıvı şerit; boğumlar akış yönünde ilerler, kuyruk kopup iki damlaya ayrılır, varışta yutkunma halkası
##   B Kuyruklu Damla  : hedefte ısırık (iki krem diş kapanır), 3 kuyruklu kan damlası dışarı fışkırıp Vampir'e kıvrılarak döner, varışta sıçrama
##   C Kan Kalbi       : hedeflerden boncuk dizileri başın üstünde toplanıp kalp olur, kalp bir kez atar ve göğse iner (taç sıçrama)
##   D Kızıl Buhar     : konturu olmayan bantlı kızıl sis hedeften sızar, Vampir'in çevresinde sarmal dönüp içine çekilir, ayakta kısa hale
## Kullanım: kan_emme_capture.gd oyunun drain düğümünü gizler ve bunu aynı points / sink ile doğurur (variant = "A".."D").

const PX := 0.847                      ## Vampir karakter pikseli (DEFS[13] 2,09797 x EntityScale 0,8075 x Player kökü 0,5)
const BODY := Vector2(0, -6)           ## VampirMath.BODY_CENTER (drain'in sink noktası)
## [kontur, koyu, orta, açık, parlak, krem]
const RAMP: Array[Color] = [Color8(51, 9, 20), Color8(120, 20, 36), Color8(184, 40, 58), Color8(236, 92, 100), Color8(255, 198, 196), Color8(243, 230, 204)]
const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const STAGGER := 0.04                  ## hedef sırası (en yakın önce) başına gecikme

## A
const A_HEAD := 0.30
const A_TAIL0 := 0.15
const A_TAIL := 0.32
## B
const B_DROPS := 3
const B_BITE := 0.12
## C
const C_HEART_OFF := Vector2(0, -37)   ## kalp merkezi sink'e göre: can barının (~ sink -21) üstünde
const C_BEADS := 5
const C_TRAVEL := 0.26
const C_BEAD_GAP := 0.035
const C_BEAT := 0.52
const C_DROP := 0.68
const C_DROP_T := 0.14
## D
const D_PUFFS := 26
const D_EMIT := 0.0085
const D_TRAVEL := 0.44
## D bant renkleri: [dış, orta, çekirdek] - çimende çamura dönmesin diye açık tonlar, yüksek alfa (madde 516 dersi)
const D_BANDS: Array = [[Color8(196, 48, 66), 0.62], [Color8(232, 86, 96), 0.80], [Color8(255, 186, 184), 0.90]]

var variant: String = "A"
var points: PackedVector2Array = PackedVector2Array()
var sink: Node2D = null

var _t: float = 0.0
var _life: float = 1.0
var _sink_pos: Vector2 = Vector2.ZERO
var _cells: Dictionary = {}            ## Vector2i -> ton (RAMP indeksi 1..5) / D'de bant 1..3
var _ground: Node2D = null
var _drops: Array = []                 ## B: {p, v, delay, hist, acc, done, t_arr, src}
var _splats: Array = []                ## B / C: [doğum t, konum, hız]
var _first_arrive: float = -1.0


func _ready() -> void:
	top_level = true
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sink_pos = _resolve_sink()
	match variant:
		"A":
			_life = A_TAIL0 + A_TAIL + _stagger(points.size() - 1) + 0.32
		"B":
			_life = 1.4
			_setup_drops()
		"C":
			_life = C_DROP + C_DROP_T + 0.30
		"D":
			_life = _stagger(points.size() - 1) + D_EMIT * D_PUFFS + D_TRAVEL + 0.30
	_ground = Node2D.new()
	_ground.z_as_relative = false
	_ground.z_index = 0                ## haritanın üstü, oyuncuların (z 1) altı - Yarasa Formu ground katmanı gibi
	add_child(_ground)
	_ground.draw.connect(_draw_ground)
	queue_redraw()


func _resolve_sink() -> Vector2:
	if sink != null and is_instance_valid(sink):
		return sink.global_position + BODY
	return _sink_pos


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	_sink_pos = _resolve_sink()
	if variant == "B":
		_step_drops(delta)
	queue_redraw()
	_ground.queue_redraw()


func _draw() -> void:
	match variant:
		"A":
			_draw_a()
		"B":
			_draw_b()
		"C":
			_draw_c()
		"D":
			_draw_d()


func _draw_ground() -> void:
	if variant == "D":
		_draw_d_ground()


# ============================================================================ ortak
func _src(i: int) -> Vector2:
	return points[i] + Vector2(0, -3)


func _stagger(i: int) -> float:
	return float(maxi(i, 0)) * STAGGER


func _ctrl(a: Vector2, b: Vector2, i: int, k: float) -> Vector2:
	var d: Vector2 = b - a
	var side: float = 1.0 if i % 2 == 0 else -1.0
	var n: Vector2 = Vector2(-d.y, d.x).normalized() * side
	return (a + b) * 0.5 + n * clampf(d.length() * k, 10.0, 40.0)


static func _bez(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t


static func _sstep(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _ein(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x


static func _eout(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


## Saydamlık 4 düz basamak (dither yok).
static func _band(a: float) -> float:
	if a > 0.85:
		return 1.0
	if a > 0.55:
		return 0.7
	if a > 0.22:
		return 0.4
	return 0.0


func _put(c: Vector2i, tone: int) -> void:
	if tone > int(_cells.get(c, 0)):
		_cells[c] = tone


## Gölgeli dolu disk (r sanat pikseli); ışık sol üstten. tone_base = orta ton.
func _disc(center: Vector2, r: float, tone_base: int = 2, hi: bool = true) -> void:
	var cc: Vector2 = center / PX
	if r < 0.8:
		_put(Vector2i(floori(cc.x), floori(cc.y)), tone_base)
		return
	for y in range(floori(cc.y - r), floori(cc.y + r) + 1):
		for x in range(floori(cc.x - r), floori(cc.x + r) + 1):
			var n: Vector2 = (Vector2(x + 0.5, y + 0.5) - cc) / r
			if n.length_squared() > 1.0:
				continue
			var tone: int = tone_base
			var l: float = -(n.x * 0.5 + n.y * 0.86)
			if l > 0.35:
				tone += 1
			elif l < -0.45:
				tone -= 1
			if hi and r >= 1.6 and (n - Vector2(-0.35, -0.45)).length() < 0.36:
				tone = tone_base + 2
			_put(Vector2i(x, y), clampi(tone, 1, 5))


## Uçları yuvarlak, kalınlığı ra -> rb incelen kapsül (sıvı şerit / kuyruk); üst yüzü açık ton şerit.
func _seg(a: Vector2, b: Vector2, ra: float, rb: float, tone_base: int = 2) -> void:
	var aa: Vector2 = a / PX
	var bb: Vector2 = b / PX
	var ab: Vector2 = bb - aa
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		_disc(a, maxf(ra, rb), tone_base, false)
		return
	var nrm: Vector2 = Vector2(-ab.y, ab.x).normalized()
	if nrm.y > 0.0:
		nrm = -nrm
	var rm: float = maxf(maxf(ra, rb), 0.72)
	for y in range(floori(minf(aa.y, bb.y) - rm), floori(maxf(aa.y, bb.y) + rm) + 1):
		for x in range(floori(minf(aa.x, bb.x) - rm), floori(maxf(aa.x, bb.x) + rm) + 1):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - aa).dot(ab) / l2, 0.0, 1.0)
			var r: float = maxf(lerpf(ra, rb, t), 0.72) ## ince çizgi kopmasın
			var d: Vector2 = p - (aa + ab * t)
			if d.length_squared() > r * r:
				continue
			var tone: int = tone_base
			if r >= 1.0:
				var s: float = d.dot(nrm) / r
				if s > 0.2:
					tone += 1
				elif s < -0.5:
					tone -= 1
			_put(Vector2i(x, y), clampi(tone, 1, 5))


## Gözyaşı damlası: hız yönünde yuvarlak baş (r) + arkaya sivrilen kısa kuyruk (tail dünya birimi).
func _tear(p: Vector2, v: Vector2, r: float, tail: float) -> void:
	var dirv: Vector2 = v.normalized() if v.length() > 1.0 else Vector2.DOWN
	_seg(p - dirv * tail, p, 0.3, r * 0.75, 2)
	_disc(p, r, 2)


## Toplanan hücreleri çizer: önce 1 px kontur (4 komşu), sonra dolgular; alpha düz.
func _flush(alpha: float = 1.0, outline: bool = true, ci: CanvasItem = null) -> void:
	if ci == null:
		ci = self
	if _cells.is_empty():
		return
	if outline:
		var outl: Dictionary = {}
		for c in _cells:
			for o in N4:
				var n: Vector2i = c + o
				if not _cells.has(n):
					outl[n] = true
		for c in outl:
			_cell_rect(ci, c, RAMP[0], alpha)
	for c in _cells:
		_cell_rect(ci, c, RAMP[int(_cells[c])], alpha)
	_cells.clear()


func _cell_rect(ci: CanvasItem, c: Vector2i, col: Color, alpha: float) -> void:
	if alpha < 1.0:
		col.a *= alpha
	ci.draw_rect(Rect2(Vector2(c) * PX - global_position, Vector2(PX, PX)), col)


## 1 px halka (squash < 1 = yerde elips). Hücreler doğrudan çizilir.
func _ring(ci: CanvasItem, center: Vector2, r: float, col: Color, alpha: float, squash: float = 1.0) -> void:
	if alpha <= 0.0 or r < 1.0:
		return
	var cc: Vector2 = center / PX
	var ry: float = r * squash
	for y in range(floori(cc.y - ry) - 1, floori(cc.y + ry) + 2):
		for x in range(floori(cc.x - r) - 1, floori(cc.x + r) + 2):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - cc
			var q: float = Vector2(d.x, d.y / squash).length()
			if absf(q - r) <= 0.5:
				_cell_rect(ci, Vector2i(x, y), col, alpha)


## Küçük sıçrama damlaları (yerçekimli, küçülerek söner) - B ve C.
func _draw_splats(life: float, grav: float) -> void:
	for s in _splats:
		var age: float = _t - float(s[0])
		if age < 0.0 or age > life:
			continue
		var p: Vector2 = s[1] + s[2] * age + Vector2(0, grav) * age * age * 0.5
		_disc(p, lerpf(1.6, 0.7, age / life), 2, false)
	_flush()


# ============================================================================ A - Kan Akıntısı
func _draw_a() -> void:
	for i in points.size():
		var tau: float = _t - _stagger(i)
		if tau <= 0.0:
			continue
		var a: Vector2 = _src(i)
		var b: Vector2 = _sink_pos
		var c: Vector2 = _ctrl(a, b, i, 0.2)
		var dist: float = a.distance_to(b)
		var h: float = _sstep(tau / A_HEAD)
		var tl: float = _ein((tau - A_TAIL0) / A_TAIL)
		## yaradan küçük fışkırma: disk söner + iki damla yukarı sıçrar
		if tau < 0.16:
			var k: float = tau / 0.16
			_disc(a, lerpf(2.6, 0.8, k), 2)
			for s in [-1.0, 1.0]:
				_disc(a + Vector2(s * (2.0 + 8.0 * k), -3.0 - 8.0 * k + 9.0 * k * k), lerpf(1.3, 0.7, k), 2, false)
		## şerit: kuyruk (tl) -> baş (h); kalınlık kuyrukta ince, başta kalın; boğumlar Vampir'e doğru akar
		if tl < 0.995 and h > tl + 0.01:
			var n_samp: int = maxi(int(dist * (h - tl) / (PX * 1.5)), 2)
			var prev: Vector2 = Vector2.ZERO
			var prev_r: float = 0.0
			for k in range(n_samp + 1):
				var v: float = float(k) / float(n_samp)
				var u: float = lerpf(tl, h, v)
				var p: Vector2 = _bez(a, c, b, u)
				var bead: float = 0.5 + 0.5 * sin(u * dist / 5.0 - tau * 36.0)
				var r: float = lerpf(0.8, 1.5, v) + 0.85 * bead * sin(PI * clampf(v * 1.15, 0.0, 1.0))
				if k > 0:
					_seg(prev, p, prev_r, r, 2)
				prev = p
				prev_r = r
			if h < 0.97:
				_disc(_bez(a, c, b, h), 2.6, 2)
		## kuyruk kopunca peşinden iki damla
		for j in range(2):
			var dj: float = A_TAIL0 + 0.05 * float(j + 1)
			if tau < dj:
				continue
			var uj: float = _ein((tau - dj) / A_TAIL)
			if uj > 0.02 and uj < 0.97:
				_disc(_bez(a, c, b, uj), 1.25 - 0.35 * float(j), 2, false)
		if tau >= A_HEAD and _first_arrive < 0.0:
			_first_arrive = _t
	_flush()
	## yutkunma halkası: ilk şerit gövdeye varınca bir kez
	if _first_arrive >= 0.0:
		var rt: float = (_t - _first_arrive) / 0.32
		if rt < 1.0:
			_ring(self, _sink_pos, 9.0 + 11.0 * _eout(rt), RAMP[3], _band(1.0 - rt))


# ============================================================================ B - Kuyruklu Damla
func _setup_drops() -> void:
	for i in points.size():
		var a: Vector2 = _src(i)
		var dir: Vector2 = (_sink_pos - a).normalized()
		for j in range(B_DROPS):
			var sgn: float = 1.0 if (i + j) % 2 == 0 else -1.0
			var v0: Vector2 = dir.rotated(sgn * deg_to_rad(95.0 + 25.0 * float(j))) * (85.0 + 15.0 * float(j))
			_drops.append({"p": a, "v": v0, "delay": _stagger(i) + B_BITE + 0.05 * float(j), "hist": [a], "acc": 0.0,
				"done": false, "src": a})


func _step_drops(delta: float) -> void:
	var steps: int = maxi(int(ceil(delta / (1.0 / 120.0))), 1)
	var dt: float = delta / float(steps)
	for d in _drops:
		if d["done"]:
			continue
		var age: float = _t - float(d["delay"])
		if age <= 0.0:
			continue
		for _s in range(steps):
			var p: Vector2 = d["p"]
			var v: Vector2 = d["v"]
			var want: Vector2 = (_sink_pos - p).normalized() * (230.0 + 900.0 * age)
			v = v.lerp(want, 1.0 - exp(-(8.0 + 50.0 * age) * dt))
			p += v * dt
			d["p"] = p
			d["v"] = v
			d["acc"] = float(d["acc"]) + dt
			if float(d["acc"]) >= 1.0 / 60.0:
				d["acc"] = 0.0
				var hist: Array = d["hist"]
				hist.append(p)
				if hist.size() > 6:
					hist.pop_front()
			if p.distance_to(_sink_pos) < 5.0 or age > 0.6:
				d["done"] = true
				## varış sıçraması: gövdeden dışa doğru 3 küçük damla
				var out: Vector2 = (p - _sink_pos).normalized()
				if out == Vector2.ZERO:
					out = Vector2.UP
				for k in range(2):
					var sv: Vector2 = out.rotated((float(k) - 0.5) * 1.1) * 60.0 + Vector2(0, -40.0)
					_splats.append([_t, p, sv])
				break
	var all_done: bool = true
	for d in _drops:
		if not d["done"]:
			all_done = false
			break
	if all_done and _t < _life - 0.22:
		_life = _t + 0.22


func _draw_b() -> void:
	## ısırık: iki krem diş yukarıdan iner ve kapanır, sonra yerinde küçük kan diski
	for i in points.size():
		var tau: float = _t - _stagger(i)
		if tau <= 0.0:
			continue
		var a: Vector2 = _src(i)
		if tau < B_BITE:
			var k: float = tau / B_BITE
			var gap: float = lerpf(4.5, 1.5, _eout(k))
			var drop: float = lerpf(-6.0, 0.0, _eout(k))
			for s in [-1, 1]:
				_fang(a + Vector2((float(s) * gap - 1.5) * PX, (drop - 4.0) * PX), s)
			_flush()
		elif tau < B_BITE + 0.14:
			var k2: float = (tau - B_BITE) / 0.14
			_disc(a, lerpf(2.4, 0.8, k2), 2)
	_flush()
	## damlalar: hız yönünde gözyaşı (yuvarlak baş + sivri kısa kuyruk)
	for d in _drops:
		if d["done"] or _t < float(d["delay"]):
			continue
		var v: Vector2 = d["v"]
		_tear(d["p"], v, 2.4, clampf(v.length() * 0.035, 3.0, 9.0))
	_flush()
	_draw_splats(0.2, 420.0)


## Tek diş (krem, dış kenarı pembe gölge), uç aşağı ve içe: 3-3-2-2-1 piksel.
func _fang(top_center: Vector2, side: int) -> void:
	var c: Vector2i = Vector2i(floori(top_center.x / PX), floori(top_center.y / PX))
	var rows: Array = [[0, 1, 2], [0, 1, 2], [1, 2], [1, 2], [2]] if side < 0 else [[0, 1, 2], [0, 1, 2], [0, 1], [0, 1], [0]]
	var shade: int = 0 if side < 0 else 2
	for y in rows.size():
		for x in rows[y]:
			_put(c + Vector2i(int(x), y), 4 if int(x) == shade else 5)


# ============================================================================ C - Kan Kalbi
func _heart_center() -> Vector2:
	return _sink_pos + C_HEART_OFF


func _draw_c() -> void:
	var hc: Vector2 = _heart_center()
	var total: int = points.size() * C_BEADS
	var fill: float = 0.0
	## boncuk dizileri: yukarı kavisle kalbin yerine akar
	for i in points.size():
		var a: Vector2 = _src(i)
		var c: Vector2 = (a + hc) * 0.5 + Vector2(0, -0.30 * a.distance_to(hc) - 10.0)
		for k in range(C_BEADS):
			var age: float = _t - _stagger(i) - C_BEAD_GAP * float(k)
			if age <= 0.0:
				continue
			fill += _sstep((age - C_TRAVEL) / 0.06)
			var u: float = _sstep(age / C_TRAVEL)
			if u >= 0.98:
				continue
			var bp: Vector2 = _bez(a, c, hc, u)
			_tear(bp, bp - _bez(a, c, hc, maxf(u - 0.04, 0.0)), 2.1 if k == 0 else 1.6, 4.0 if k == 0 else 3.0)
		## kaynakta küçük fışkırma
		var tau: float = _t - _stagger(i)
		if tau > 0.0 and tau < 0.14:
			_disc(a, lerpf(2.4, 0.8, tau / 0.14), 2)
	_flush()
	if total <= 0:
		return
	fill /= float(total)
	if fill <= 0.0:
		return
	## kalp: dolarken büyür, bir kez atar, sonra göğse iner ve küçülür
	var s: float = 0.30 + 0.70 * fill
	var tb: float = (_t - C_BEAT) / 0.16
	if tb > 0.0 and tb < 1.0:
		s *= 1.0 + 0.22 * sin(PI * tb)
	var pos: Vector2 = hc
	var td: float = (_t - C_DROP) / C_DROP_T
	if td >= 1.0:
		_c_crown(td)
		return
	if td > 0.0:
		pos = hc.lerp(_sink_pos, _ein(td))
		s *= lerpf(1.0, 0.45, td)
	_heart(pos, 6.6 * s)
	_flush()


func _c_crown(td: float) -> void:
	var t0: float = C_DROP + C_DROP_T
	if _splats.is_empty():
		for k in range(4):
			var ang: float = -PI * 0.5 + (float(k) - 1.5) * 0.55
			_splats.append([t0, _sink_pos + Vector2(0, -3), Vector2(cos(ang), sin(ang)) * 70.0])
	var rt: float = (_t - t0) / 0.26
	if rt < 1.0:
		_ring(self, _sink_pos, 7.0 + 10.0 * _eout(rt), RAMP[3], _band(1.0 - rt))
	_draw_splats(0.24, 380.0)


## Kalp (r = yarı genişlik, sanat pikseli): klasik örtük eğri, sol üst lobda parlama.
func _heart(center: Vector2, r: float) -> void:
	if r < 1.2:
		_disc(center, 1.0, 2, false)
		return
	var cc: Vector2 = center / PX
	var k: float = 1.16 / r
	for y in range(floori(cc.y - r * 1.05), floori(cc.y + r * 1.1) + 1):
		for x in range(floori(cc.x - r * 1.05), floori(cc.x + r * 1.05) + 1):
			var hx: float = (x + 0.5 - cc.x) * k
			var hy: float = -(y + 0.5 - cc.y) * k + 0.12
			var q: float = hx * hx + hy * hy - 1.0
			if q * q * q - hx * hx * hy * hy * hy > 0.0:
				continue
			var tone: int = 2
			var l: float = -hx * 0.45 + hy * 0.55
			if l > 0.3:
				tone = 3
			elif l < -0.5:
				tone = 1
			if Vector2(hx + 0.5, hy - 0.42).length() < 0.24 and r >= 2.5:
				tone = 4
			_put(Vector2i(x, y), tone)


# ============================================================================ D - Kızıl Buhar
func _d_pos(a: Vector2, i: int, u: float) -> Vector2:
	var side: float = 1.0 if i % 2 == 0 else -1.0
	var ang0: float = (a - _sink_pos).angle() + side * 0.9
	var entry: Vector2 = _sink_pos + Vector2(cos(ang0), sin(ang0) * 0.55) * 13.0
	if u < 0.7:
		return _bez(a, _ctrl(a, entry, i, 0.18), entry, u / 0.7)
	var w: float = (u - 0.7) / 0.3
	var ang: float = ang0 + side * 1.7 * w
	var rad: float = 13.0 * pow(1.0 - w, 1.2)
	return _sink_pos + Vector2(cos(ang), sin(ang) * 0.55) * rad


## Puflar tek tek bant çizmez: (1 - q^2)^2 katkıları toplanır (metaball), bantlar toplam alandan -> üst üste binen puflar
## tek pürüzsüz bulut olur (ayrı ayrı çekirdekler "boğumlu tırtıl" gibi okunuyordu, 1. çekim).
var _field: Dictionary = {}


func _puff(center: Vector2, r: float) -> void:
	var cc: Vector2 = center / PX
	for y in range(floori(cc.y - r), floori(cc.y + r) + 1):
		for x in range(floori(cc.x - r), floori(cc.x + r) + 1):
			var q2: float = (Vector2(x + 0.5, y + 0.5) - cc).length_squared() / (r * r)
			if q2 >= 1.0:
				continue
			var c: Vector2i = Vector2i(x, y)
			_field[c] = float(_field.get(c, 0.0)) + (1.0 - q2) * (1.0 - q2)


func _draw_d() -> void:
	for i in points.size():
		var a: Vector2 = _src(i) + Vector2(0, -2)
		for k in range(D_PUFFS):
			var age: float = _t - _stagger(i) - D_EMIT * float(k)
			if age <= 0.0:
				continue
			var u: float = pow(clampf(age / D_TRAVEL, 0.0, 1.0), 1.25)
			if u >= 1.0:
				if _first_arrive < 0.0:
					_first_arrive = _t
				continue
			## hedeften sızarken önce biraz yükselir
			var rise: Vector2 = Vector2(0, -6.0 * _eout(age / 0.12)) * (1.0 - u)
			var r: float = lerpf(5.4, 2.0, u) * _sstep(age / 0.07) * (0.85 + 0.15 * sin(float(k) * 2.3 + float(i)))
			if r >= 0.8:
				_puff(_d_pos(a, i, u) + rise, r)
	for c in _field:
		var f: float = _field[c]
		var lv: int = 2 if f > 0.9 else (1 if f > 0.38 else (0 if f > 0.07 else -1))
		if lv >= 0:
			var bd: Array = D_BANDS[lv]
			_cell_rect(self, c, bd[0], float(bd[1]))
	_field.clear()


## Ayakta kısa hale: sis vardıkça açılan iki ince elips (krem-pembe iç, açık kızıl dış), 0,4 sn'de söner.
func _draw_d_ground() -> void:
	if _first_arrive < 0.0:
		return
	var rt: float = (_t - _first_arrive) / 0.42
	if rt >= 1.0:
		return
	var feet: Vector2 = _sink_pos - BODY + Vector2(0, 13)
	var r: float = 10.0 + 5.0 * _eout(rt)
	var a: float = _band(1.0 - rt)
	_ring(_ground, feet, r / PX, RAMP[3], a * 0.85, 0.42)
	_ring(_ground, feet, (r - 2.0) / PX, RAMP[4], a * 0.7, 0.42)
