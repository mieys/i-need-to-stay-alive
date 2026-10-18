extends Node2D

## En üst kademe (demirci 5) silahın ucunda "şing" parıltısı (madde 247): çıkış animasyonunun sonunda ve karakter durunca.
## 4 kollu piksel yıldız + kısa çaprazlar (madde 245 prototipindeki gibi), 1 dünya px kalınlık (zoom 2'de 2 ekran px), sin zarfı.
## İkonun ucunu (WeaponTip.tip_global) her karede izler; süre bitince kendini siler.

const WeaponTipScript := preload("res://scripts/weapon_tip.gd")
const LIFE := 0.26
const COL := Color(1.0, 0.988, 0.91)

var _icon: Node2D = null
var _forward_deg: float = 0.0
var _t: float = 0.0


func setup(icon: Node2D, forward_deg: float) -> void:
	_icon = icon
	_forward_deg = forward_deg
	z_index = 2
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_follow()


func _follow() -> void:
	if _icon != null and is_instance_valid(_icon) and _icon is Sprite2D:
		global_position = (WeaponTipScript.tip_global(_icon as Sprite2D, _forward_deg) * 2.0).round() * 0.5
	elif _icon != null and is_instance_valid(_icon):
		global_position = _icon.global_position


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE or _icon == null or not is_instance_valid(_icon):
		queue_free()
		return
	_follow()
	queue_redraw()


func _draw() -> void:
	var k: float = sin(PI * clampf(_t / LIFE, 0.0, 1.0))
	if k <= 0.02:
		return
	var r: float = roundf(1.5 + 4.0 * k)
	var c := Color(COL.r, COL.g, COL.b, k)
	## kollar 1 px kalın, merkez 1 px kare (yarım px ızgara: düğüm 0,5'e yuvarlı)
	draw_rect(Rect2(-r, -0.5, r * 2.0, 1.0), c)
	draw_rect(Rect2(-0.5, -r, 1.0, r * 2.0), c)
	var d: float = roundf(r * 0.35)
	if d >= 1.0:
		var c2 := Color(c.r, c.g, c.b, k * 0.8)
		for i in range(1, int(d) + 1):
			var f: float = float(i)
			draw_rect(Rect2(-0.5 + f, -0.5 + f, 1.0, 1.0), c2)
			draw_rect(Rect2(-0.5 - f, -0.5 + f, 1.0, 1.0), c2)
			draw_rect(Rect2(-0.5 + f, -0.5 - f, 1.0, 1.0), c2)
			draw_rect(Rect2(-0.5 - f, -0.5 - f, 1.0, 1.0), c2)
