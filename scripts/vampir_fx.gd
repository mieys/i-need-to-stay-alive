extends Node2D

## Vampir Çocuk'un pixel-art efektleri (bkz. vampir_math.gd TEXEL): hepsi karakter dokusunun
## piksel boyutunda (1 sanat pikseli = TEXEL dünya birimi) kareler olarak çizilir, konumlar
## ızgaraya oturtulur - yumuşak/bulanık parçacık yok.
##   "hit"     : yarasa/temas vuruşunda küçük kan pikseli patlaması
##   "bat_in"  : Yarasa Formu'na GİRİŞ (insan -> yarasa) - "Kızıl Girdap", pişmiş sayfa (aşağıda)
##   "bat_out" : Yarasa Formu'ndan DÖNÜŞ (yarasa -> insan) - aynı dil, hilaller yere iner + kızıl halka
##   "drain"   : Kan Emme - "Kan Kalbi": damlalar başın üstünde kalp olur, atar, göğse iner (sink'i takip eder)
## Hepsi kendi kendini siler. Spawn için VampirMath.spawn_fx().

const VampirMath := preload("res://scripts/vampir_math.gd")
const PhysicsInterp := preload("res://scripts/physics_interp.gd")

## Yarasa Formu geçişi (madde 516, kullanıcı: "şuanki kalitesiz" -> 4 prototipten "C - Kızıl Girdap"). Eski "puff" 30 rastgele
## iri kare pikseldi (karakter pikselinin 3-6 katı), giriş/dönüş aynıydı. Sprite dönüşümü E basıldığı karede ANINDA olduğu için
## sayfanın ilk karesi gövdeyi koyu sisle örter. Sayfalar tools/gen_vampir_donusum_fx.py (çizim prototiple birebir:
## tools/proto_20261109/vampir_donusum_proto.py c_in/c_out). İki katman: [0] front = karakterin üstü (bu düğümün z 20'si),
## [1] ground = girdabın ARKA yarısı + yer halkası, MUTLAK z 0 (sahne kökünde haritanın üstü, oyuncuların (z 1) altı) -
## hilaller karakterin arkasından dolanıp önünden geçer. Efekt sahibini (follow) çizilen konumundan izler: girdap gövdeyi
## sarar, yarasa hızla uçarken geride kalmamalı.
const BAT_SHEETS := {
	"bat_in": [preload("res://assets/fx/vampir_donusum/in_front.png"), preload("res://assets/fx/vampir_donusum/in_ground.png"), 16],
	"bat_out": [preload("res://assets/fx/vampir_donusum/out_front.png"), preload("res://assets/fx/vampir_donusum/out_ground.png"), 14],
}
const BAT_FPS := 24.0
## Sayfada doğum noktası (sahip + VampirMath.BODY_CENTER) - kare 136x136.
const BAT_ANCHOR := Vector2(68, 60)
## 1 sayfa pikseli = Vampir karakter pikseli (DEFS[13] scale 2.09797 x EntityScale.SIZE 0.8075 x Player kökü 0.5).
const BAT_WORLD_PX := 0.847

const BLOOD := Color(0.77, 0.09, 0.16)
const BLOOD_D := Color(0.47, 0.05, 0.11)
const BLOOD_L := Color(1.0, 0.38, 0.38)
const FANG := Color(0.96, 0.93, 0.89)

## Kan Emme "C - Kan Kalbi" (madde 724 prototiplerinden kullanıcı seçimi, madde 727; çizim prototiple birebir:
## tools/proto_20261116/kan_emme/kan_emme_proto_fx.gd "C"). Eski drain: hedef başına 9 kare damla, 3 TEXEL (karakter pikselinin ~4 katı)
## -> "noktalı çizgi". Şimdi: her hedeften 5 gözyaşı damlası yukarı kavisle can barının ÜSTÜNDE toplanıp kalp olur, kalp bir kez atar,
## göğse iner (taç halka + 4 sıçrama). Hepsi Vampir KARAKTER PİKSELİNDE (BAT_WORLD_PX) dolu kütle: 5 tonlu kızıl rampa (Yarasa Formu
## "Kızıl Girdap" rampası) + 1 px koyu kontur; dither / saçılan tek piksel YOK, sönme küçülme / düz alfa bandıyla.
const DRAIN_PX := BAT_WORLD_PX
## [kontur, koyu, orta, açık, parlak]
const DRAIN_RAMP: Array[Color] = [Color8(51, 9, 20), Color8(120, 20, 36), Color8(184, 40, 58), Color8(236, 92, 100), Color8(255, 198, 196)]
const DRAIN_N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DRAIN_STAGGER := 0.04            ## hedef sırası (en yakın önce) başına gecikme
const DRAIN_HEART_OFF := Vector2(0, -37) ## kalp merkezi sink'e (gövde ortası) göre: can barının (~ -21) üstünde
const DRAIN_BEADS := 5
const DRAIN_BEAD_GAP := 0.035
const DRAIN_TRAVEL := 0.26
const DRAIN_BEAT := 0.52
const DRAIN_DROP := 0.68
const DRAIN_DROP_T := 0.14
const DRAIN_CROWN := 0.26

var kind: String = "hit"
var points: PackedVector2Array = PackedVector2Array()
var sink: Node2D = null
## bat_in / bat_out: izlenen sahip (oyuncu ya da kukla); null/silinmişse efekt doğduğu yerde kalır.
var follow: Node2D = null

var _t: float = 0.0
var _life: float = 0.4
var _particles: Array = [] ## [pos, vel, color, size(texel), delay]
var _sink_pos: Vector2 = Vector2.ZERO
var _sheet: Array[Sprite2D] = [] ## bat_in / bat_out katmanları: [front, ground]
var _sheet_frames: int = 0
var _cells: Dictionary = {}            ## drain: Vector2i (sanat pikseli hücresi) -> ton (DRAIN_RAMP indeksi 1..4)
var _splats: Array = []                ## drain taç sıçraması: [doğum t, konum, hız]


func _ready() -> void:
	top_level = true
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match kind:
		"hit":
			_life = 0.34
			_make_burst(9, 40.0, 110.0, [BLOOD, BLOOD_L, BLOOD_D, FANG], 1, 2)
		"bat_in", "bat_out":
			_setup_bat_sheet(BAT_SHEETS[kind])
		"drain":
			_life = DRAIN_DROP + DRAIN_DROP_T + DRAIN_CROWN + 0.04
			_sink_pos = _resolve_sink()
	queue_redraw()


func _setup_bat_sheet(d: Array) -> void:
	_sheet_frames = int(d[2])
	_life = float(_sheet_frames) / BAT_FPS
	for li in range(2):
		var spr := Sprite2D.new()
		spr.texture = d[li]
		spr.hframes = _sheet_frames
		spr.frame = 0
		spr.centered = false
		spr.offset = -BAT_ANCHOR
		spr.scale = Vector2(BAT_WORLD_PX, BAT_WORLD_PX)
		if li == 1:
			## Girdabın arka yarısı: mutlak z 0 = haritanın üstü, oyuncu ve kuklaların (z 1) altı.
			spr.z_as_relative = false
			spr.z_index = 0
		add_child(spr)
		_sheet.append(spr)
	_follow_owner()


func _follow_owner() -> void:
	if follow != null and is_instance_valid(follow):
		global_position = PhysicsInterp.visual_position(follow) + VampirMath.BODY_CENTER


func _make_burst(count: int, v_min: float, v_max: float, colors: Array, size_min: int, size_max: int) -> void:
	for i in range(count):
		var a: float = randf() * TAU
		var v: Vector2 = Vector2(cos(a), sin(a)) * randf_range(v_min, v_max)
		_particles.append([Vector2.ZERO, v, colors[randi() % colors.size()], randi_range(size_min, size_max), randf() * 0.05])


func _resolve_sink() -> Vector2:
	if sink != null and is_instance_valid(sink):
		return sink.global_position + Vector2(0, -6)
	return _sink_pos


func _process(delta: float) -> void:
	_t += delta
	if _t >= _life:
		queue_free()
		return
	if _sheet_frames > 0:
		_follow_owner()
		var f: int = mini(int(_t * BAT_FPS), _sheet_frames - 1)
		for spr in _sheet:
			spr.frame = f
		return
	if kind == "drain":
		_sink_pos = _resolve_sink()
	else:
		for p in _particles:
			var age: float = _t - float(p[4])
			if age > 0.0:
				p[0] = p[0] + p[1] * delta
				p[1] = p[1] * (1.0 - clampf(3.5 * delta, 0.0, 1.0)) ## sürtünme: hızla yavaşlar
	queue_redraw()


func _px(pos: Vector2, size_texel: int, col: Color) -> void:
	var s: float = float(size_texel) * VampirMath.TEXEL
	var p: Vector2 = VampirMath.snap(to_local(pos))
	draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), col)


func _draw() -> void:
	match kind:
		"drain":
			_draw_drain()
		_:
			var fade: float = 1.0 - _t / _life
			for p in _particles:
				var age: float = _t - float(p[4])
				if age < 0.0:
					continue
				var size_texel: int = int(p[3])
				## Ömrün sonunda pikseller küçülüp yok olur (yumuşak alfa yerine boyut kademesi).
				if fade < 0.35:
					size_texel = maxi(size_texel - 1, 0)
				if size_texel <= 0:
					continue
				var col: Color = p[2]
				_px(global_position + p[0], size_texel, col)


func _draw_drain() -> void:
	var hc: Vector2 = _sink_pos + DRAIN_HEART_OFF
	var total: int = points.size() * DRAIN_BEADS
	var fill: float = 0.0
	## damlalar: her hedeften yukarı kavisle kalbin yerine akar (ilki iri ve parlak)
	for i in range(points.size()):
		var a: Vector2 = points[i] + Vector2(0, -3)
		var c: Vector2 = (a + hc) * 0.5 + Vector2(0, -0.30 * a.distance_to(hc) - 10.0)
		for k in range(DRAIN_BEADS):
			var age: float = _t - DRAIN_STAGGER * float(i) - DRAIN_BEAD_GAP * float(k)
			if age <= 0.0:
				continue
			fill += _dr_sstep((age - DRAIN_TRAVEL) / 0.06)
			var u: float = _dr_sstep(age / DRAIN_TRAVEL)
			if u >= 0.98:
				continue
			var bp: Vector2 = _bezier(a, c, hc, u)
			_dr_tear(bp, bp - _bezier(a, c, hc, maxf(u - 0.04, 0.0)), 2.1 if k == 0 else 1.6, 4.0 if k == 0 else 3.0)
		## kaynakta küçük fışkırma
		var tau: float = _t - DRAIN_STAGGER * float(i)
		if tau > 0.0 and tau < 0.14:
			_dr_disc(a, lerpf(2.4, 0.8, tau / 0.14), 2)
	_dr_flush()
	if total <= 0:
		return
	fill /= float(total)
	if fill <= 0.0:
		return
	## kalp: dolarken büyür, bir kez atar, sonra göğse iner ve küçülür
	var s: float = 0.30 + 0.70 * fill
	var tb: float = (_t - DRAIN_BEAT) / 0.16
	if tb > 0.0 and tb < 1.0:
		s *= 1.0 + 0.22 * sin(PI * tb)
	var td: float = (_t - DRAIN_DROP) / DRAIN_DROP_T
	if td >= 1.0:
		_dr_crown()
		return
	var pos: Vector2 = hc
	if td > 0.0:
		pos = hc.lerp(_sink_pos, td * td)
		s *= lerpf(1.0, 0.45, td)
	_dr_heart(pos, 6.6 * s)
	_dr_flush()


## Kalp göğse inince: açık kızıl 1 px halka açılıp düz bantlarla söner + 4 damla yukarı sıçrayıp düşer.
func _dr_crown() -> void:
	var t0: float = DRAIN_DROP + DRAIN_DROP_T
	if _splats.is_empty():
		for k in range(4):
			var ang: float = -PI * 0.5 + (float(k) - 1.5) * 0.55
			_splats.append([t0, _sink_pos + Vector2(0, -3), Vector2(cos(ang), sin(ang)) * 70.0])
	var rt: float = (_t - t0) / DRAIN_CROWN
	if rt < 1.0:
		var e: float = 1.0 - (1.0 - rt) * (1.0 - rt)
		_dr_ring(_sink_pos, 7.0 + 10.0 * e, DRAIN_RAMP[3], _dr_band(1.0 - rt))
	for sp in _splats:
		var age: float = _t - float(sp[0])
		if age < 0.0 or age > 0.24:
			continue
		var p: Vector2 = sp[1] + sp[2] * age + Vector2(0, 380.0) * age * age * 0.5
		_dr_disc(p, lerpf(1.6, 0.7, age / 0.24), 2, false)
	_dr_flush()


static func _dr_sstep(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Saydamlık 4 düz basamak (dither yok).
static func _dr_band(a: float) -> float:
	if a > 0.85:
		return 1.0
	if a > 0.55:
		return 0.7
	if a > 0.22:
		return 0.4
	return 0.0


func _dr_put(c: Vector2i, tone: int) -> void:
	if tone > int(_cells.get(c, 0)):
		_cells[c] = tone


## Gölgeli dolu disk (r sanat pikseli); ışık sol üstten, tone_base = orta ton.
func _dr_disc(center: Vector2, r: float, tone_base: int = 2, hi: bool = true) -> void:
	var cc: Vector2 = center / DRAIN_PX
	if r < 0.8:
		_dr_put(Vector2i(floori(cc.x), floori(cc.y)), tone_base)
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
			_dr_put(Vector2i(x, y), clampi(tone, 1, 4))


## Uçları yuvarlak, ra -> rb kalınlaşan kapsül (damla kuyruğu); üst yüzü açık ton.
func _dr_seg(a: Vector2, b: Vector2, ra: float, rb: float, tone_base: int = 2) -> void:
	var aa: Vector2 = a / DRAIN_PX
	var bb: Vector2 = b / DRAIN_PX
	var ab: Vector2 = bb - aa
	var l2: float = ab.length_squared()
	if l2 < 0.0001:
		_dr_disc(a, maxf(ra, rb), tone_base, false)
		return
	var nrm: Vector2 = Vector2(-ab.y, ab.x).normalized()
	if nrm.y > 0.0:
		nrm = -nrm
	var rm: float = maxf(maxf(ra, rb), 0.72)
	for y in range(floori(minf(aa.y, bb.y) - rm), floori(maxf(aa.y, bb.y) + rm) + 1):
		for x in range(floori(minf(aa.x, bb.x) - rm), floori(maxf(aa.x, bb.x) + rm) + 1):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - aa).dot(ab) / l2, 0.0, 1.0)
			var r: float = maxf(lerpf(ra, rb, t), 0.72) ## ince uç kopmasın
			var d: Vector2 = p - (aa + ab * t)
			if d.length_squared() > r * r:
				continue
			var tone: int = tone_base
			if r >= 1.0:
				var sd: float = d.dot(nrm) / r
				if sd > 0.2:
					tone += 1
				elif sd < -0.5:
					tone -= 1
			_dr_put(Vector2i(x, y), clampi(tone, 1, 4))


## Gözyaşı damlası: hız yönünde yuvarlak baş (r sanat px) + arkaya sivrilen kısa kuyruk (tail dünya birimi).
func _dr_tear(p: Vector2, v: Vector2, r: float, tail: float) -> void:
	var dirv: Vector2 = v.normalized() if v.length() > 0.01 else Vector2.UP
	_dr_seg(p - dirv * tail, p, 0.3, r * 0.75, 2)
	_dr_disc(p, r, 2)


## Kalp (r = yarı genişlik, sanat pikseli): klasik örtük eğri (x²+y²-1)³ - x²y³ <= 0, sol üst lobda parlama.
func _dr_heart(center: Vector2, r: float) -> void:
	if r < 1.2:
		_dr_disc(center, 1.0, 2, false)
		return
	var cc: Vector2 = center / DRAIN_PX
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
			if r >= 2.5 and Vector2(hx + 0.5, hy - 0.42).length() < 0.24:
				tone = 4
			_dr_put(Vector2i(x, y), tone)


## 1 px halka (r sanat pikseli), hücreler doğrudan.
func _dr_ring(center: Vector2, r: float, col: Color, alpha: float) -> void:
	if alpha <= 0.0:
		return
	col.a *= alpha
	var cc: Vector2 = center / DRAIN_PX
	for y in range(floori(cc.y - r) - 1, floori(cc.y + r) + 2):
		for x in range(floori(cc.x - r) - 1, floori(cc.x + r) + 2):
			if absf((Vector2(x + 0.5, y + 0.5) - cc).length() - r) <= 0.5:
				_dr_cell(Vector2i(x, y), col)


## Toplanan hücreler: önce 1 px kontur (4 komşu boş hücre), sonra dolgu tonları.
func _dr_flush() -> void:
	if _cells.is_empty():
		return
	var outl: Dictionary = {}
	for c in _cells:
		for o in DRAIN_N4:
			var n: Vector2i = c + o
			if not _cells.has(n):
				outl[n] = true
	for c in outl:
		_dr_cell(c, DRAIN_RAMP[0])
	for c in _cells:
		_dr_cell(c, DRAIN_RAMP[int(_cells[c])])
	_cells.clear()


func _dr_cell(c: Vector2i, col: Color) -> void:
	draw_rect(Rect2(to_local(Vector2(c) * DRAIN_PX), Vector2(DRAIN_PX, DRAIN_PX)), col)


func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t
