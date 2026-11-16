extends "res://scripts/item_trigger_fx_base.gd"

## KEMİK KOLYE (kemik_kolye) tetiklenince - "Diş Halkası" (madde 742, prototip A): yetenek kullanılınca 6 kemik diş sırayla belirip
## belde döner (önündekiler karakterin önünde, arkasındakiler arkasında); güçlü saldırı başına bir diş dışa fırlayıp iki parçaya
## kırılır. Diş sayısı = player.gd _item_kemik_charges (yerelde her kare okunur); uzak kuklada RemotePlayer'da bu alan yok ->
## kaster her harcamada "kemik_charges" yayını gönderir (network_manager.gd), set_charges ile güncellenir.
## Yeni tetik eskisini siler (aynı sahipte tek halka). Diş kalmayınca söner; güvenlik için en çok MAX_LIFE.

const FULL := 6 ## = player.gd ITEM_KEMIK_CHARGES
const MAX_LIFE := 60.0
const RING_C := Vector2(0, 3)
const RING_RX := 15.0
const RING_RY := 5.5

var _remote_n: int = FULL
var _prev_n: int = 0
var _flying: Array = [] ## {p (sahibe göre), d, t0, back}
var _zero_t: float = -1.0


func _setup() -> void:
	_life = MAX_LIFE
	var par: Node = get_parent()
	if par != null:
		for c in par.get_children():
			if c != self and c.has_method("set_charges"):
				c.queue_free()


## Uzak kukla (network_manager.gd "kemik_charges").
func set_charges(n: int) -> void:
	_remote_n = clampi(n, 0, FULL)


func _count() -> int:
	if owner_node != null and is_instance_valid(owner_node):
		var v: Variant = owner_node.get("_item_kemik_charges")
		if v != null:
			return clampi(int(v), 0, FULL)
	return _remote_n


func _angle(i: int) -> float:
	return _t * 1.8 + float(i) * TAU / float(FULL)


func _pos(i: int) -> Vector2:
	var a: float = _angle(i)
	return _o + _w(RING_C + Vector2(cos(a) * RING_RX, sin(a) * RING_RY))


func _step(_delta: float) -> void:
	var n: int = _count()
	if n < _prev_n:
		for i in range(n, _prev_n):
			var a: float = _angle(i)
			_flying.append({"p": _pos(i) - _o, "d": Vector2(cos(a), sin(a) * 0.37).normalized(), "t0": _t, "back": sin(a) < 0.0})
	_prev_n = n
	if n <= 0 and _t > 0.3:
		if _zero_t < 0.0:
			_zero_t = _t
			_life = minf(_life, _t + 0.55)


## Kemik diş (uç aşağı ya da rot yönünde), kök açık / uç koyu.
func _fang(at: Vector2, s: float, rot: float, tone: int = 3) -> void:
	if s < 0.35:
		_put(_cellv(at), tone)
		return
	var shape: Array = [Vector2(-1.6, -0.6), Vector2(1.6, -0.6), Vector2(1.3, 1.6), Vector2(0.3, 4.4), Vector2(-0.7, 2.2)]
	var pts := PackedVector2Array()
	for v in shape:
		pts.append(at + (v as Vector2).rotated(rot) * s * PX)
	_poly(pts, tone, true)


func _render(L: int, ci: CanvasItem) -> void:
	var n: int = _count()
	var kp: float = _k(_t, 0.0, 0.28)
	if kp < 1.0:
		_ring_half(ci, _o + _w(RING_C), lerpf(10.0, 22.0, _eout(kp)), BONE[4], _band(1.0 - kp), 0.37, L == BACK, 1)
	for i in n:
		if (sin(_angle(i)) < 0.0) != (L == BACK):
			continue
		var s: float = _eout(_k(_t, float(i) * 0.05, float(i) * 0.05 + 0.12))
		_fang(_pos(i), s, 0.0, 3 if L == TOP else 2)
	_flush(ci, BONE)
	## harcanan dişler: dışa fırlar, iki parçaya kırılır
	for f in _flying:
		var age: float = _t - float(f["t0"])
		if age < 0.0 or age > 0.5:
			continue
		if (bool(f["back"]) and age < 0.12) != (L == BACK):
			continue
		var d: Vector2 = f["d"]
		var p: Vector2 = _o + (f["p"] as Vector2) + d * 12.0 * _sc * _eout(minf(age, 0.16) / 0.16)
		if age < 0.16:
			_fang(p, 1.0, 0.0, 3)
		else:
			var a2: float = age - 0.16
			var perp := Vector2(-d.y, d.x)
			for sgn in [-1.0, 1.0]:
				var q: Vector2 = p + perp * sgn * 16.0 * a2 + Vector2(0, 240.0) * a2 * a2 * 0.5 + Vector2(0, -10.0 * a2)
				_disc(q, lerpf(1.2, 0.5, _k(a2, 0.0, 0.3)), 3, false)
	_flush(ci, BONE)
	if L == TOP:
		for f2 in _flying:
			var age2: float = _t - float(f2["t0"])
			if age2 >= 0.14 and age2 < 0.26:
				_spark(ci, _o + (f2["p"] as Vector2) + (f2["d"] as Vector2) * 12.0 * _sc, lerpf(3.0, 1.0, _k(age2, 0.14, 0.26)),
					BONE[5], BONE[3], 1.0)
