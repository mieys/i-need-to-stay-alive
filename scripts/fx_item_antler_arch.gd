extends "res://scripts/item_trigger_fx_base.gd"

## ÖLÜM EŞİĞİ (olum_esigi) tetiklenince - "Boynuz Kemeri" (madde 742, prototip B): yerde mor eşik halkası kapanır, iki yandan hayalet
## boynuzlar büyüyüp can çubuğunun üstünde birleşir, arası mavi kalkan ışığıyla dolar (kalkan yenilendi), sonra dolgu karaktere
## çekilirken boynuzlar parça parça kırılıp düşer. Tamamen zamana bağlı (uzak kopya aynısını oynar).

const TINES: Array = [[0.4, 7.0, -4.0], [0.66, 6.0, -6.0], [0.86, 3.5, -4.0]] ## [boynuz üstündeki yer u, dışa x, yukarı y]

var _rng := RandomNumberGenerator.new()
var _chips: Array = [] ## kırılan parçalar (karaktere göre): {a, b, v, r}


func _setup() -> void:
	_life = 1.2
	_rng.randomize()


func _beam(side: float, u: float) -> Vector2:
	var b: Vector2 = _o + FEET + _w(Vector2(15.0 * side, -1.0))
	var c: Vector2 = _o + _w(Vector2(25.0 * side, -12.0))
	var e: Vector2 = _o + Vector2(0.0, OVER.y + 2.0)
	return _bez(b, c, e, u)


func _render(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == BACK:
		var kin: float = _eout(_k(t, 0.0, 0.12))
		var a: float = _band(1.0 - _k(t, 0.7, 0.95))
		var r: float = lerpf(26.0, 16.0, kin) * _sc / PX
		_ell(ci, _o + FEET, r, r * 0.38, PLUM[1], a * 0.3)
		_ring(ci, _o + FEET, r, PLUM[3], a, 0.38, 1)
		_ring(ci, _o + FEET, r - 2.0, PLUM[2], a * 0.7, 0.38, 1)
		return
	var grow: float = _eout(_k(t, 0.08, 0.38))
	## kalkan ışığı dolgusu (iki boynuz arası); ortası daha saydam
	var kf: float = _k(t, 0.38, 0.9)
	if t >= 0.38 and kf < 1.0:
		var pts := PackedVector2Array()
		var piv: Vector2 = _o + CHEST
		var shrink: float = lerpf(1.0, 0.45, _ein(_k(t, 0.55, 0.9)))
		for i in 13:
			pts.append(piv + (_beam(-1.0, float(i) / 12.0) - piv) * shrink)
		for i in range(12, -1, -1):
			pts.append(piv + (_beam(1.0, float(i) / 12.0) - piv) * shrink)
		_poly(pts, 3, false)
		var fa: float = 0.85 if t < 0.46 else _band(1.0 - _k(t, 0.6, 0.9)) * 0.75
		_flush_glow(ci, BLUE, fa, 0.6, 0.4)
		if t < 0.56:
			_spark(ci, _beam(1.0, 1.0), lerpf(8.0, 2.0, _k(t, 0.38, 0.56)), BLUE[5], BLUE[3], 1.0)
	## boynuzlar: büyür, 0,52'de kırılır
	if t < 0.52:
		for side in [-1.0, 1.0]:
			var n: int = 14
			for i in n:
				var u0: float = float(i) / float(n)
				if u0 >= grow:
					break
				var u1: float = minf(float(i + 1) / float(n), grow)
				_seg(_beam(side, u0), _beam(side, u1), lerpf(1.8, 1.0, u0), lerpf(1.8, 1.0, u1), 2)
			for tn in TINES:
				var tu: float = float(tn[0])
				var kt: float = _eout(_k(grow, tu + 0.05, minf(tu + 0.3, 1.0)))
				if kt <= 0.0:
					continue
				var p0: Vector2 = _beam(side, tu)
				_seg(p0, p0 + _w(Vector2(float(tn[1]) * side, float(tn[2]))) * kt, 1.1, 0.6, 2)
		_flush(ci, BONE)
		return
	if _chips.is_empty():
		for side in [-1.0, 1.0]:
			for j in 4:
				var ub: float = float(j) * 0.25
				_chips.append({"a": _beam(side, ub) - _o, "b": _beam(side, ub + 0.2) - _o,
					"v": Vector2(side * _rng.randf_range(10.0, 34.0), _rng.randf_range(-40.0, -10.0)), "r": lerpf(1.6, 1.0, ub)})
	var age: float = t - 0.52
	for ch in _chips:
		var off: Vector2 = (ch["v"] as Vector2) * age + Vector2(0, 260.0) * age * age * 0.5
		var rr: float = float(ch["r"]) * (1.0 - _k(age, 0.25, 0.5))
		if rr < 0.5:
			continue
		var mid: Vector2 = ((ch["a"] as Vector2) + (ch["b"] as Vector2)) * 0.5
		var half: Vector2 = ((ch["b"] as Vector2) - (ch["a"] as Vector2)) * 0.5 * (1.0 - _k(age, 0.15, 0.5) * 0.6)
		_seg(_o + mid + off - half, _o + mid + off + half, rr, rr * 0.7, 2)
	_flush(ci, BONE)
