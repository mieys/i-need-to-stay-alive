extends "res://scripts/item_trigger_fx_base.gd"

## GÜNDÜZ VE GECE (zaman_kiran) tetiklenince - "Tutulma" (madde 742, prototip A): güneş + ay göğüsten dolanıp can çubuğunun
## üstünde tutulma olur (1 sn ölümsüzlük boyunca taç ışınlarıyla durur), 0,45 sn'de yerde gece dalgası görüş alanına yayılır.
## Dalganın değdiği DONMUŞ yaratığın buz kütlesi gizlenir, yerine başında hilal + ayağında gece halkası (donma bitene kadar, en çok
## 5 sn). Donmanın kendisi player.gd _item_freeze_vision_enemies (host yetkili); burası salt görsel - her istemci kendi kopyasında
## yaratığın is_frozen'ına bakar (istemcide donma host'tan biraz geç gelir, işaret o an çıkar).

const WAVE_T0 := 0.45
const WAVE_DUR := 1.0
const WAVE_R := 340.0
const ECLIPSE_END := 1.55
const MARK_TIME := 5.0 ## = player.gd ITEM_ZAMAN_FREEZE
const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")

var _mobs: Array = [] ## {n, arrive}


func _setup() -> void:
	_life = MARK_TIME + 0.15
	## tek seferlik tarama (her karede "enemies" taraması yok); player.gd _item_freeze_vision_enemies ile AYNI görüş elipsi -
	## elips dışında başka kaynakla donmuş yaratığın buzuna dokunulmaz.
	var vr: float = VisionFogScript.current_radius(get_tree())
	if vr <= 0.0:
		vr = 520.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var rel: Vector2 = (e as Node2D).global_position - _o
		if VisionFogScript.normalized_distance(rel, vr, VisionFogScript.VISION_WIDTH_SCALE) > 1.0:
			continue
		var d: float = rel.length()
		var k: float = 1.0 - sqrt(maxf(0.0, 1.0 - minf(d, WAVE_R) / WAVE_R))
		_mobs.append({"n": e, "arrive": WAVE_T0 + k * WAVE_DUR})


func _step(_delta: float) -> void:
	for m in _mobs:
		var n: Node = m["n"]
		if not is_instance_valid(n):
			continue
		var fx: Variant = n.get("_freeze_status_fx")
		if fx is CanvasItem and is_instance_valid(fx):
			(fx as CanvasItem).visible = not (n.get("is_frozen") == true) ## buz kütlesi yerine zaman durması işareti


func _exit_tree() -> void:
	## başka bir kaynak (buz silahı...) aynı yaratığı hâlâ donduruyorsa buzu geri göster
	for m in _mobs:
		var n: Node = m["n"]
		if is_instance_valid(n):
			var fx: Variant = n.get("_freeze_status_fx")
			if fx is CanvasItem and is_instance_valid(fx):
				(fx as CanvasItem).visible = true


func _render(L: int, ci: CanvasItem) -> void:
	var t: float = _t
	if L == BACK:
		var kw: float = _k(t, WAVE_T0, WAVE_T0 + WAVE_DUR)
		if t >= WAVE_T0 and kw < 1.0:
			var r: float = maxf(1.0, _eout(kw) * WAVE_R / PX)
			var a: float = _band(1.0 - _k(kw, 0.5, 1.0))
			_ell(ci, _o + FEET, r, r * 0.5, NIGHT[1], a * 0.2)
			_ring(ci, _o + FEET, r - 1.0, NIGHT[3], a * 0.85, 0.5, 2)
			_ring(ci, _o + FEET, r, GOLD[4], a, 0.5, 1)
		_marks(L, ci)
		return
	if t < 0.44:
		var cur: Array = _orbit(t)
		for j in 3:
			var prv: Array = _orbit(maxf(0.0, t - 0.03 * float(j + 1)))
			var nxt: Array = _orbit(maxf(0.0, t - 0.03 * float(j)))
			_seg(nxt[0], prv[0], lerpf(1.4, 0.6, float(j) / 2.0), lerpf(1.1, 0.4, float(j) / 2.0), 3)
		_disc(cur[0], 3.0, 3)
		_flush(ci, GOLD)
		for j in 3:
			var prv2: Array = _orbit(maxf(0.0, t - 0.03 * float(j + 1)))
			var nxt2: Array = _orbit(maxf(0.0, t - 0.03 * float(j)))
			_seg(nxt2[1], prv2[1], lerpf(1.3, 0.6, float(j) / 2.0), lerpf(1.0, 0.4, float(j) / 2.0), 3)
		_flush(ci, NIGHT)
		_moon(cur[1], 3.0, 3)
		_flush(ci, NIGHT)
	elif t < ECLIPSE_END:
		var e: Vector2 = _eclipse_pos()
		var s: float = 1.0 - _ein(_k(t, 1.3, ECLIPSE_END))
		if s > 0.05:
			var ka: float = _k(t, 0.44, 0.62)
			_halo(ci, e, 9.0 * s, GOLD, _band(lerpf(1.0, 0.75, ka)), 1.0)
			for i in 4:
				var ang: float = (t - 0.44) * 1.4 + float(i) * PI * 0.5
				var dir := Vector2(cos(ang), sin(ang))
				_line(ci, e + dir * 6.8 * s * PX, e + dir * 9.6 * s * PX, GOLD[4], 1.0)
			_ring(ci, e, 5.6 * s, GOLD[3], 1.0)
			_ring(ci, e, 6.6 * s, GOLD[2], 0.55)
			_disc(e, 4.6 * s, 1, false)
			_flush(ci, NIGHT)
			if t < 0.62:
				_spark(ci, e, lerpf(10.0, 3.0, ka), GOLD[5], GOLD[3], 1.0)
	_marks(L, ci)


func _eclipse_pos() -> Vector2:
	return _o + OVER + Vector2(0, -2)


## Güneş [0] ve ay [1]: göğüsten tutulma noktasına daralan sarmal.
func _orbit(tt: float) -> Array:
	var k: float = _eout(tt / 0.44)
	var c: Vector2 = (_o + CHEST).lerp(_eclipse_pos(), k)
	var rad: float = lerpf(20.0 * _sc, 0.0, k)
	var ang: float = PI + k * PI * 1.25
	return [c + Vector2(cos(ang), sin(ang) * 0.45) * rad, c + Vector2(cos(ang + PI), sin(ang + PI) * 0.45) * rad]


## Hilal: disk - kaydırılmış disk.
func _moon(center: Vector2, r: float, tone: int) -> void:
	_disc(center, r, tone, false)
	var cut: Vector2 = center / PX + Vector2(r * 0.55, -r * 0.35)
	for c in _cells.keys():
		if (Vector2(c) + Vector2(0.5, 0.5) - cut).length() < r * 0.9:
			_cells.erase(c)


func _marks(L: int, ci: CanvasItem) -> void:
	for m in _mobs:
		var n: Node2D = m["n"] as Node2D
		if not is_instance_valid(n) or n.get("is_frozen") != true:
			continue
		var at: float = float(m["arrive"])
		if _t < at:
			continue
		var a: float = _band(minf(_k(_t, at, at + 0.08), 1.0 - _k(_t, _life - 0.25, _life)))
		var br: float = clampf(float(n.get("_body_radius")) * absf(n.global_scale.x) * 0.6 / PX, 7.0, 18.0) \
				if n.get("_body_radius") != null else 9.0
		var feet: Vector2 = n.global_position + Vector2(0, 7)
		if L == BACK:
			_ell(ci, feet, br, br * 0.4, NIGHT[1], a * 0.3)
			_ring(ci, feet, br, NIGHT[3], a * 0.85, 0.4, 1)
			continue
		var head: Vector2 = n.global_position + Vector2(0, -24)
		if n.has_method("get_overhead_bar_offset"):
			head = n.to_global(Vector2(0, float(n.call("get_overhead_bar_offset")) + 10.0))
		var pop: float = _eout(_k(_t, at, at + 0.12))
		_moon(head, 3.4 * lerpf(0.4, 1.0, pop), 3)
		_flush(ci, NIGHT, a)
		_spark(ci, head + Vector2(5, -3) * PX, 1.0, NIGHT[5], NIGHT[4], a)
