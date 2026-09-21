extends Node2D

## Vampir Çocuk'un pixel-art efektleri (bkz. vampir_math.gd TEXEL): hepsi karakter dokusunun
## piksel boyutunda (1 sanat pikseli = TEXEL dünya birimi) kareler olarak çizilir, konumlar
## ızgaraya oturtulur - yumuşak/bulanık parçacık yok.
##   "hit"   : yarasa/temas vuruşunda küçük kan pikseli patlaması
##   "puff"  : Yarasa Formu'na girerken/çıkarken koyu mor-kırmızı duman patlaması
##   "drain" : Kan Emme - hedeflerden karaktere akan kan damlaları (sink'i takip eder)
## Hepsi kendi kendini siler. Spawn için VampirMath.spawn_fx().

const VampirMath := preload("res://scripts/vampir_math.gd")

const BLOOD := Color(0.77, 0.09, 0.16)
const BLOOD_D := Color(0.47, 0.05, 0.11)
const BLOOD_L := Color(1.0, 0.38, 0.38)
const FANG := Color(0.96, 0.93, 0.89)
const MEM := Color(0.39, 0.09, 0.19)
const FUR_D := Color(0.17, 0.08, 0.15)
const FUR_M := Color(0.28, 0.13, 0.24)
const MEM_L := Color(0.62, 0.2, 0.4)

const DRAIN_DROPS := 9
const DRAIN_TRAVEL := 0.42
const DRAIN_STAGGER := 0.045

var kind: String = "hit"
var points: PackedVector2Array = PackedVector2Array()
var sink: Node2D = null

var _t: float = 0.0
var _life: float = 0.4
var _particles: Array = [] ## [pos, vel, color, size(texel), delay]
var _sink_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	top_level = true
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	match kind:
		"hit":
			_life = 0.34
			_make_burst(9, 40.0, 110.0, [BLOOD, BLOOD_L, BLOOD_D, FANG], 1, 2)
		"puff":
			_life = 0.6
			_make_burst(30, 110.0, 300.0, [FUR_M, MEM, MEM_L, BLOOD_D, BLOOD, BLOOD_L], 2, 4)
		"drain":
			_life = DRAIN_TRAVEL + DRAIN_STAGGER * float(DRAIN_DROPS) + 0.2
			_sink_pos = _resolve_sink()
	queue_redraw()


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
	for si in range(points.size()):
		var src: Vector2 = points[si]
		## Kaynakta kısa bir "emilme" halkası: 4 piksel dışa doğru açılıp kaybolur.
		if _t < 0.2:
			var r: float = 6.0 + _t * 90.0
			for k in range(4):
				var a: float = float(k) * TAU / 4.0 + 0.6
				_px(src + Vector2(cos(a), sin(a)) * r, 1, BLOOD_L)
		var to_sink: Vector2 = _sink_pos - src
		var mid: Vector2 = (src + _sink_pos) * 0.5
		var side: float = 1.0 if (si % 2 == 0) else -1.0
		var ctrl: Vector2 = mid + Vector2(-to_sink.y, to_sink.x).normalized() * 34.0 * side
		for n in range(DRAIN_DROPS):
			var prog: float = (_t - float(n) * DRAIN_STAGGER) / DRAIN_TRAVEL
			if prog <= 0.0 or prog >= 1.0:
				continue
			var e: float = VampirMath.eased(prog)
			var pos: Vector2 = _bezier(src, ctrl, _sink_pos, e)
			## 3 pikselik damla + parlak çekirdek, arkasında 2'şer kademeli koyu kuyruk.
			_px(_bezier(src, ctrl, _sink_pos, VampirMath.eased(maxf(prog - 0.14, 0.0))), 1, BLOOD_D)
			_px(_bezier(src, ctrl, _sink_pos, VampirMath.eased(maxf(prog - 0.07, 0.0))), 2, BLOOD_D)
			_px(pos, 3, BLOOD)
			_px(pos, 1, BLOOD_L)
	## Damlalar karaktere varınca gövdede kısa bir kırmızı parlama.
	var arrive: float = (_t - DRAIN_TRAVEL) / 0.25
	if arrive > 0.0 and arrive < 1.0:
		var ring: float = 8.0 + arrive * 16.0
		for k in range(8):
			var a: float = float(k) * TAU / 8.0
			_px(_sink_pos + Vector2(cos(a), sin(a)) * ring, 1, BLOOD_L if k % 2 == 0 else BLOOD)


func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return a * u * u + c * 2.0 * u * t + b * t * t
