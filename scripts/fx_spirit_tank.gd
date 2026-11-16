extends Node2D

## Ruhani Yetenek "Tank" (F): 10 sn hasar yansıtma + kalkan yenileme. Görünüm = prototip "B Rün Mührü" (madde 730, kullanıcı
## seçimi 2026-11-16, madde 734) - eski dönen altıgen çelik bariyer dokuları + şok halkaları silindi.
##  - ayak altında yavaşça dönen basık altıgen (köşelerde altın perçin; assets/fx/ruhani/tank_hex.png: 6 çizim + 24 dönüş karesi,
##    60 derece = tam döngü) 0,3 sn'de kenar kenar çizilir
##  - her köşeden yukarı 30 px ince çelik-mavi ışık sütunu (3 düz bant, yukarı söner); arkadaki köşelerinki karakterin ARKASINDA,
##    öndekiler önünde
##  - zap(hedef): yansıyan her vuruşta saldırana EN YAKIN köşe parlar, o köşeden saldırana ince altın çizgi çakar (köşe tarafından
##    geri çekilir) + saldıranın üstünde krem pırıltı. Kaster player.gd _spirit_tank_on_hit'ten çağırır ve "spirit_tank_zap"
##    vfx'iyle yayınlar; uzak kopyada network_manager.gd aynı zap()'ı çağırır (MP iki-yer kuralı).
## Kök ayakta, 1 yerel birim = 1 dünya birimi (bkz. spirit_fx_util.gd).

const U := preload("res://scripts/spirit_fx_util.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const HEX_TEX := preload("res://assets/fx/ruhani/tank_hex.png")

const HEX_FRAMES := 30
const HEX_RX := 18.0
const HEX_RY := 8.0
const ROT_SPEED := 0.3
const DRAW_IN := 0.3
const PILLAR_H := 30.0
const FADE := 0.5

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.TANK_DURATION
var _zaps: Array = [] ## [doğuş _t, hedef global konum]
var _front: Node2D = null


func _ready() -> void:
	U.setup_root(self)
	show_behind_parent = true
	_front = U.front_layer(self, _draw_front)


## Yansıyan vuruş: saldıranın global konumu.
func zap(target_global: Vector2) -> void:
	_zaps.append([_t, target_global])
	if _zaps.size() > 6:
		_zaps.pop_front()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE:
		queue_free()
		return
	modulate.a = U.band(clampf((_duration + FADE - _t) / FADE, 0.0, 1.0), 4)
	_zaps = _zaps.filter(func(z: Array) -> bool: return _t - float(z[0]) < 0.45)
	queue_redraw()
	_front.queue_redraw()


func _hex_frame() -> int:
	if _t < DRAW_IN:
		return clampi(int(_t / DRAW_IN * 6.0), 0, 5)
	var steps: int = int((_t - DRAW_IN) * ROT_SPEED / (TAU / 6.0) * 24.0)
	return 6 + steps % 24


## Pişmiş karedeki köşeler: [x, y, sin] x6 ve görünen köşe sayısı.
func _verts() -> Array:
	var fr: int = _hex_frame()
	var rot: float = 0.0 if fr < 6 else float(fr - 6) * (TAU / 6.0) / 24.0
	var out: Array = []
	for k in range(6):
		var a: float = rot + float(k) * TAU / 6.0
		out.append(Vector3(HEX_RX * cos(a), HEX_RY * sin(a), sin(a)))
	return out


func _visible_verts() -> int:
	var fr: int = _hex_frame()
	return mini(6, fr + 2) if fr < 6 else 6


func _nearest(verts: Array, p: Vector2) -> int:
	var best: int = 0
	var bd: float = INF
	for k in range(6):
		var v: Vector3 = verts[k]
		var d: float = Vector2(v.x, v.y).distance_squared_to(p)
		if d < bd:
			bd = d
			best = k
	return best


func _flashes(verts: Array) -> PackedFloat32Array:
	var f := PackedFloat32Array([0, 0, 0, 0, 0, 0])
	for z in _zaps:
		var age: float = _t - float(z[0])
		if age < 0.3:
			var j: int = _nearest(verts, to_local(z[1]))
			f[j] = maxf(f[j], 1.0 - age / 0.3)
	return f


func _pillar(ci: CanvasItem, v: Vector3, flash: float, front: bool) -> void:
	var gk: float = U.ease_out((_t - 0.2) / 0.3)
	if gk <= 0.0:
		return
	var h: float = PILLAR_H * gk
	var x: float = floorf(v.x)
	var col: Color = U.CREAM if flash > 0.3 else U.STEEL3
	var bands: Array = [[v.y - h / 3.0, v.y, 0.55], [v.y - 2.0 * h / 3.0, v.y - h / 3.0, 0.32], [v.y - h, v.y - 2.0 * h / 3.0, 0.14]]
	for b in bands:
		var ya: float = roundf(float(b[0]))
		var yb: float = roundf(float(b[1]))
		if yb - ya < 1.0:
			continue
		var al: float = U.band(maxf(float(b[2]) * (0.85 if front else 1.0), flash * 0.9), 4)
		ci.draw_rect(Rect2(x, ya, 1.0, yb - ya), U.with_a(col, al))


func _draw() -> void:
	U.frame(self, HEX_TEX, HEX_FRAMES, _hex_frame(), 0.0, 0.0, Color.WHITE)
	var verts: Array = _verts()
	var fl: PackedFloat32Array = _flashes(verts)
	for k in range(_visible_verts()):
		var v: Vector3 = verts[k]
		if v.z < 0.0:
			_pillar(self, v, fl[k], false)


func _draw_front() -> void:
	var verts: Array = _verts()
	var fl: PackedFloat32Array = _flashes(verts)
	for k in range(_visible_verts()):
		var v: Vector3 = verts[k]
		if v.z >= 0.0:
			_pillar(_front, v, fl[k], true)
		if fl[k] > 0.4:
			U.sparkle(_front, v.x, v.y, 2, U.CREAM, U.GOLD2, 1.0)
	for z in _zaps:
		var age: float = _t - float(z[0])
		var tgt: Vector2 = to_local(z[1])
		var v: Vector3 = verts[_nearest(verts, tgt)]
		var top := Vector2(v.x, v.y - 4.0)
		if age < 0.18:
			var a: Vector2 = top.lerp(tgt, age / 0.18)
			_front.draw_line(a.floor() + Vector2(0.5, 0.5), tgt.floor() + Vector2(0.5, 0.5), U.GOLD4, 1.0)
			_front.draw_line(a.floor() + Vector2(0.5, 1.5), tgt.floor() + Vector2(0.5, 1.5), U.with_a(U.GOLD2, 0.6), 1.0)
		if age > 0.04 and age < 0.3:
			U.sparkle(_front, tgt.x, tgt.y, 3 - int((age - 0.04) / 0.09), U.CREAM, U.GOLD3, 1.0)
