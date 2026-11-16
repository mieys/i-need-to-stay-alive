extends Node2D

## TETİKLENEN EŞYA efekt prototipleri - ortak piksel çizim yardımcıları (2026-11-16, OYUNA BAĞLI DEĞİL).
## Her şey KARAKTER PİKSELİNDE (PX dünya birimi; Talon 2,2368 x EntityScale 0,8075 x Player kökü 0,5 = 0,903) dünya ızgarasına
## oturtulur. Dolu kütleler: 5 tonlu rampa + 1 px koyu kontur, en parlak ton krem. Işık / hale: düz alfa bantları.
## TİTREŞİM / dither / saçılan tek piksel YOK (kalıcı kural); sönme küçülerek ya da düz alfa basamağıyla.
## Düğüm top_level ve (0,0)'da durur -> çizim koordinatı = dünya koordinatı. Katmanlar: ÜST (z 20, karakterin önü),
## ARKA (mutlak z 0: haritanın üstü, oyuncu/yaratıkların altı), GÖLGE (ARKA + düz renk siluet shader'ı, art görüntüler için).

const N4: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const TOP := 0
const BACK := 1
const GHOST := 2

## Rampalar: [kontur, koyu, orta, açık, parlak, krem]
const GOLD: Array[Color] = [Color8(78, 40, 18), Color8(176, 96, 30), Color8(234, 150, 44), Color8(252, 204, 86), Color8(255, 238, 160), Color8(255, 250, 226)]
const NIGHT: Array[Color] = [Color8(22, 18, 50), Color8(50, 46, 112), Color8(84, 86, 172), Color8(138, 148, 222), Color8(198, 210, 250), Color8(240, 244, 255)]
const BLUE: Array[Color] = [Color8(14, 34, 70), Color8(34, 82, 150), Color8(62, 138, 214), Color8(118, 194, 246), Color8(194, 234, 255), Color8(240, 250, 255)]
const PLUM: Array[Color] = [Color8(46, 16, 34), Color8(112, 40, 74), Color8(172, 78, 116), Color8(222, 140, 164), Color8(248, 204, 210), Color8(255, 238, 236)]
const BONE: Array[Color] = [Color8(54, 40, 30), Color8(126, 104, 74), Color8(188, 168, 128), Color8(228, 214, 178), Color8(246, 240, 214), Color8(255, 252, 238)]
const TEAL: Array[Color] = [Color8(12, 50, 56), Color8(28, 112, 116), Color8(56, 172, 164), Color8(132, 224, 204), Color8(212, 250, 234), Color8(255, 252, 232)]
const CRIM: Array[Color] = [Color8(51, 9, 20), Color8(120, 20, 36), Color8(184, 40, 58), Color8(236, 92, 100), Color8(255, 198, 196), Color8(243, 230, 204)]
const DUST: Array[Color] = [Color8(70, 58, 44), Color8(132, 116, 92), Color8(176, 160, 130), Color8(212, 198, 170), Color8(234, 224, 202), Color8(248, 242, 228)]

## Karakter gövdesi (oyuncu kökü global_position'ına göre dünya birimi; Talon yakalamasıyla ölçüldü).
var FEET := Vector2(0, 11)
var CHEST := Vector2(0, -1)
var HEAD := Vector2(0, -14)          ## başın üstü; can/kalkan çubuğu -31..-24 arası (baş üstü efektler -34 üstüne)

var PX: float = 0.903
var item: String = ""
var variant: String = "A"
var owner_node: Node2D = null

var _t: float = 0.0
var _life: float = 2.0
var _o: Vector2 = Vector2.ZERO
var _cells: Dictionary = {}
var _back: Node2D = null
var _ghost: Node2D = null


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_back = Node2D.new()
	_back.z_as_relative = false
	_back.z_index = 0
	add_child(_back)
	_back.draw.connect(func() -> void: _render(BACK, _back))
	_ghost = Node2D.new()
	_ghost.z_as_relative = false
	_ghost.z_index = 0
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvarying vec4 vc;\nvoid vertex() { vc = COLOR; }\nvoid fragment() { float a = texture(TEXTURE, UV).a; COLOR = vec4(vc.rgb, vc.a * step(0.5, a)); }\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_ghost.material = mat
	add_child(_ghost)
	_ghost.draw.connect(func() -> void: _render(GHOST, _ghost))
	_follow()
	_setup()


func _follow() -> void:
	if owner_node != null and is_instance_valid(owner_node):
		_o = owner_node.global_position


func _process(delta: float) -> void:
	_t += delta
	_follow()
	_step(delta)
	if _t >= _life:
		queue_free()
		return
	queue_redraw()
	_back.queue_redraw()
	_ghost.queue_redraw()


func _draw() -> void:
	_render(TOP, self)


## Alt sınıf doldurur.
func _setup() -> void:
	pass


func _step(_delta: float) -> void:
	pass


func _render(_layer: int, _ci: CanvasItem) -> void:
	pass


# ---------------------------------------------------------------- yumuşatma
static func _sstep(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _eout(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - x) * (1.0 - x)


static func _ein(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x


static func _k(t: float, a: float, b: float) -> float:
	return clampf((t - a) / maxf(b - a, 0.0001), 0.0, 1.0)


## Saydamlık 4 düz basamak (dither yok).
static func _band(a: float) -> float:
	if a > 0.85:
		return 1.0
	if a > 0.55:
		return 0.7
	if a > 0.22:
		return 0.4
	return 0.0


## Doğuş-sönüş zarfı (bantlı): a..b arası görünür, kenarlarda fin/fout sn içinde basamakla.
static func _env(t: float, a: float, b: float, fin: float = 0.06, fout: float = 0.12) -> float:
	if t < a or t > b:
		return 0.0
	return _band(minf(_k(t, a, a + fin), 1.0 - _k(t, b - fout, b)))


# ---------------------------------------------------------------- hücre toplama (rampalı kütle)
func _put(c: Vector2i, tone: int) -> void:
	if tone > int(_cells.get(c, 0)):
		_cells[c] = tone


func _cellv(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / PX), floori(p.y / PX))


## Gölgeli dolu disk (r sanat pikseli); ışık sol üstten.
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


## Uçları yuvarlak, kalınlığı ra -> rb incelen kapsül; üst yüzü açık ton.
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
			var r: float = maxf(lerpf(ra, rb, t), 0.72)
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


## Çokgen (dünya noktaları) dolgusu; üst üçte bir açık, alt üçte bir koyu.
func _poly(pts: PackedVector2Array, tone_base: int = 2, shade: bool = true) -> void:
	if pts.size() < 3:
		return
	var q := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var c: Vector2 = p / PX
		q.append(c)
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.y))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.y))
	var h: float = maxf(hi.y - lo.y, 1.0)
	for y in range(floori(lo.y), floori(hi.y) + 1):
		for x in range(floori(lo.x), floori(hi.x) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(p, q):
				continue
			var tone: int = tone_base
			if shade:
				var f: float = (p.y - lo.y) / h
				if f < 0.3:
					tone += 1
				elif f > 0.72:
					tone -= 1
			_put(Vector2i(x, y), clampi(tone, 1, 5))


## Toplanan hücreler: önce 1 px kontur (4 komşu), sonra dolgular; alfa düz.
func _flush(ci: CanvasItem, ramp: Array[Color], alpha: float = 1.0, outline: bool = true) -> void:
	if _cells.is_empty():
		return
	if alpha <= 0.0:
		_cells.clear()
		return
	if outline:
		var outl: Dictionary = {}
		for c in _cells:
			for o in N4:
				var n: Vector2i = c + o
				if not _cells.has(n):
					outl[n] = true
		for c in outl:
			_cell(ci, c, ramp[0], alpha)
	for c in _cells:
		_cell(ci, c, ramp[int(_cells[c])], alpha)
	_cells.clear()


## Işık kütlesi: kenardan içe doğru ton artar (kenar = orta, 1 içeri = açık, 2+ içeri = parlak / krem); kontur koyu-orta,
## yarı saydam. "Işıktan yapılmış" şekiller (el, kalkan dolgusu) için.
## fade_y0 / fade_span (hücre satırı): o satırın üstü yukarı doğru bantlı söner (ışıktan kol gökte erisin).
func _flush_glow(ci: CanvasItem, ramp: Array[Color], alpha: float = 1.0, edge_alpha: float = 0.6, fade_y0: int = -1000000000,
		fade_span: float = 1.0, inner_mul: float = 1.0) -> void:
	if _cells.is_empty():
		return
	if alpha <= 0.0:
		_cells.clear()
		return
	var outl: Dictionary = {}
	for c in _cells:
		for o in N4:
			if not _cells.has(c + o):
				outl[c + o] = true
	for c in outl:
		_cell(ci, c, ramp[1], alpha * edge_alpha * _fade_row(c.y, fade_y0, fade_span))
	for c in _cells:
		var fm: float = _fade_row(c.y, fade_y0, fade_span)
		if fm <= 0.0:
			continue
		var depth: int = 3
		for o in N4:
			if not _cells.has(c + o):
				depth = 0
				break
			if not _cells.has(c + o * 2):
				depth = mini(depth, 1)
			elif not _cells.has(c + o * 3):
				depth = mini(depth, 2)
		var col: Color = [ramp[2], ramp[3], ramp[4], ramp[5]][depth]
		_cell(ci, c, col, alpha * fm * (0.85 if depth < 2 else inner_mul))
	_cells.clear()


## Birden çok rampalı hücre kümesi tek ortak konturla (ör. kum saati camı + kemik kapaklar): parts = [[hücreler, rampa], ...].
func _flush_union(ci: CanvasItem, parts: Array, alpha: float, outline_col: Color) -> void:
	var all: Dictionary = {}
	for pr in parts:
		for c in (pr[0] as Dictionary):
			all[c] = true
	for c in all:
		for o in N4:
			if not all.has(c + o):
				_cell(ci, c + o, outline_col, alpha)
	for pr in parts:
		var cells: Dictionary = pr[0]
		var ramp: Array = pr[1]
		for c in cells:
			_cell(ci, c, ramp[int(cells[c])], alpha)


static func _fade_row(y: int, y0: int, span: float) -> float:
	if y >= y0:
		return 1.0
	return _band(1.0 - float(y0 - y) / span)


func _cell(ci: CanvasItem, c: Vector2i, col: Color, alpha: float) -> void:
	if alpha < 1.0:
		col.a *= alpha
	ci.draw_rect(Rect2(Vector2(c) * PX, Vector2(PX, PX)), col)


# ---------------------------------------------------------------- doğrudan çizimler (ışık / halka / pırıltı)
## Halka (r sanat pikseli, squash < 1 = yerde elips); kalınlık thick hücre; parametrik örnekleme (büyük halkada da ucuz).
## arc: yalnız [a0, a1] açı aralığı (radyan, 0 = sağ, PI/2 = aşağı).
func _ring(ci: CanvasItem, center: Vector2, r: float, col: Color, alpha: float, squash: float = 1.0, thick: int = 1,
		a0: float = 0.0, a1: float = TAU) -> void:
	if alpha <= 0.0 or r < 0.6:
		return
	var cc: Vector2 = center / PX
	var seen: Dictionary = {}
	for k in thick:
		var rr: float = r - float(k)
		if rr < 0.5:
			break
		var n: int = maxi(12, int(TAU * rr * 1.6))
		for i in n + 1:
			var a: float = lerpf(a0, a1, float(i) / float(n))
			var c := Vector2i(floori(cc.x + cos(a) * rr), floori(cc.y + sin(a) * rr * squash))
			if seen.has(c):
				continue
			seen[c] = true
			_cell(ci, c, col, alpha)


## Dolu elips (r sanat pikseli), satır satır tek dikdörtgen.
func _ell(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, alpha: float) -> void:
	if alpha <= 0.0 or rx < 0.5 or ry < 0.5:
		return
	var cc: Vector2 = center / PX
	if alpha < 1.0:
		col.a *= alpha
	for y in range(floori(cc.y - ry), floori(cc.y + ry) + 1):
		var fy: float = (float(y) + 0.5 - cc.y) / ry
		if absf(fy) > 1.0:
			continue
		var hw: float = rx * sqrt(1.0 - fy * fy)
		var x0: int = floori(cc.x - hw + 0.5)
		var x1: int = floori(cc.x + hw - 0.5)
		if x1 < x0:
			continue
		ci.draw_rect(Rect2(Vector2(x0, y) * PX, Vector2(x1 - x0 + 1, 1) * PX), col)


## Elipsin yalnız üst (back=true) ya da alt yarısı - yerde duran halkanın arkası karakterin arkasında kalsın.
func _ring_half(ci: CanvasItem, center: Vector2, r: float, col: Color, alpha: float, squash: float, back: bool, thick: int = 1) -> void:
	if back:
		_ring(ci, center, r, col, alpha, squash, thick, PI, TAU)
	else:
		_ring(ci, center, r, col, alpha, squash, thick, 0.0, PI)


## 4 köşeli pırıltı: merkez + eksen kolları (arm sanat pikseli); kol uçları renkli, gövde krem.
func _spark(ci: CanvasItem, center: Vector2, arm: float, core: Color, tip: Color, alpha: float) -> void:
	if alpha <= 0.0 or arm < 0.5:
		return
	var c: Vector2i = _cellv(center)
	var n: int = int(round(arm))
	_cell(ci, c, core, alpha)
	for d in N4:
		for i in range(1, n + 1):
			_cell(ci, c + d * i, core if i <= n / 2 else tip, alpha)
	if n >= 3:
		for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			_cell(ci, c + d, tip, alpha)


## 1 px düz çizgi (hücrelerle).
func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var aa: Vector2 = a / PX
	var bb: Vector2 = b / PX
	var n: int = maxi(1, int(ceil(aa.distance_to(bb))))
	var seen: Dictionary = {}
	for i in n + 1:
		var p: Vector2 = aa.lerp(bb, float(i) / float(n))
		var c := Vector2i(floori(p.x), floori(p.y))
		if seen.has(c):
			continue
		seen[c] = true
		_cell(ci, c, col, alpha)


## Hale: iç içe düz alfa elipsleri (dış renkli az saydam, iç soluk daha opak) - "ışık" okunsun, parazit olmasın.
func _halo(ci: CanvasItem, center: Vector2, r: float, ramp: Array[Color], alpha: float, squash: float = 1.0) -> void:
	if alpha <= 0.0:
		return
	_ell(ci, center, r, r * squash, ramp[3], alpha * 0.22)
	_ell(ci, center, r * 0.66, r * 0.66 * squash, ramp[4], alpha * 0.26)
	_ell(ci, center, r * 0.36, r * 0.36 * squash, ramp[5], alpha * 0.34)
