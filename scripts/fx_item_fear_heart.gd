extends "res://scripts/item_trigger_fx_base.gd"

## ÜRKEK YÜREK (urkek_yurek) tetiklenince - "Çarpan Kalp" (madde 742, prototip A): can çubuğunun üstünde kırmızı kalp belirip iki kez
## hızla çarpar (yanlarda vuruş yayları), sonra küçülüp kaybolur; hız bonusu sürdükçe (6 sn, doğrusal söner = ITEM_URKEK_TIME) karakter
## koşarken arkasında rüzgâr çizgileri kalır, sayısı bonusla birlikte azalır. Hareket yönü konum farkından (uzak kuklada da aynı).

const BOOST_TIME := 6.0 ## = player.gd ITEM_URKEK_TIME
const BEATS: Array = [0.14, 0.38]

var _rng := RandomNumberGenerator.new()
var _streaks: Array = [] ## {p, d, len, t0}
var _acc: float = 0.0
var _prev_o: Vector2 = Vector2.ZERO
var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 0.0


func _setup() -> void:
	_life = BOOST_TIME
	_rng.randomize()
	_prev_o = _o


func _step(delta: float) -> void:
	if delta > 0.0:
		var mv: Vector2 = _o - _prev_o
		_speed = lerpf(_speed, mv.length() / delta, 0.4)
		if mv.length() > 0.01:
			_dir = mv.normalized()
	_prev_o = _o
	var f: float = 1.0 - _t / BOOST_TIME
	if _speed < 20.0:
		_acc = 0.0
	else:
		_acc += delta * 26.0 * f
	while _acc >= 1.0:
		_acc -= 1.0
		var side := Vector2(-_dir.y, _dir.x)
		var p: Vector2 = _o + _w(Vector2(0, -2)) - _dir * _rng.randf_range(6.0, 11.0) * _sc + side * _rng.randf_range(-13.0, 12.0) * _sc
		_streaks.append({"p": p, "d": _dir, "len": _rng.randf_range(5.0, 10.0), "t0": _t})
	while not _streaks.is_empty() and _t - float(_streaks[0]["t0"]) > 0.3:
		_streaks.pop_front()


func _heart(center: Vector2, r: float) -> void:
	var cc: Vector2 = center / PX
	for y in range(floori(cc.y - r * 1.2), floori(cc.y + r * 1.2) + 1):
		for x in range(floori(cc.x - r * 1.3), floori(cc.x + r * 1.3) + 1):
			var nx: float = (float(x) + 0.5 - cc.x) / r
			var ny: float = -(float(y) + 0.5 - cc.y) / r + 0.15
			var q: float = nx * nx + ny * ny - 1.0
			if q * q * q - nx * nx * ny * ny * ny > 0.0:
				continue
			var tone: int = 2
			if ny > 0.35 and nx < 0.1:
				tone = 3
			if ny < -0.45:
				tone = 1
			if r >= 3.0 and Vector2(nx + 0.5, ny - 0.55).length() < 0.28:
				tone = 4
			_put(Vector2i(x, y), tone)


func _render(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == BACK:
		for st in _streaks:
			var age: float = t - float(st["t0"])
			if age < 0.0 or age > 0.24:
				continue
			var ln: float = float(st["len"]) * (1.0 - _k(age, 0.06, 0.24))
			var p: Vector2 = st["p"]
			var d: Vector2 = st["d"]
			_line(ci, p, p - d * ln * 0.5 * PX, DUST[5], 0.85)
			_line(ci, p - d * ln * 0.5 * PX, p - d * ln * PX, DUST[4], 0.45)
		return
	var s: float
	if t < 0.08:
		s = 1.15 * _eout(t / 0.08)
	else:
		s = 1.0
		for tb in BEATS:
			var kb: float = _k(t, float(tb), float(tb) + 0.13)
			if kb > 0.0 and kb < 1.0:
				s += 0.34 * sin(PI * kb)
		s *= 1.0 - _ein(_k(t, 0.6, 0.76))
	var c: Vector2 = _o + OVER
	if s > 0.12:
		_heart(c, 4.2 * s)
		_flush(ci, CRIM)
	for tb2 in BEATS:
		var ka: float = _k(t, float(tb2), float(tb2) + 0.16)
		if ka <= 0.0 or ka >= 1.0:
			continue
		var rr: float = lerpf(6.5, 9.5, _eout(ka))
		var aa: float = _band(1.0 - _k(ka, 0.5, 1.0))
		_ring(ci, c, rr, CRIM[3], aa, 1.0, 1, -0.5, 0.5)
		_ring(ci, c, rr, CRIM[3], aa, 1.0, 1, PI - 0.5, PI + 0.5)
