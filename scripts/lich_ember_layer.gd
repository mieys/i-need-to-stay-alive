extends Node2D

## Lich "Ruh Alevi"nin arkasında yükselip sönen kor pikselleri (madde 280). TÜM lich mermileri için TEK düğüm + tek _draw (mermi başına
## parçacık düğümü yok); enemy_projectile.gd mevcut sahneye bir kez ekler ve `add` ile besler. Sisin içindeki (gizli) mermi kor üretmez -
## katman vision_fog.gd'nin gizlediği gruplarda değil, kor gizli yaratığın yerini ele vermesin. Boşken _process kapalı.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const MAX_EMBERS := 192
## Yaşa göre: açık nane -> parlak turkuaz -> koyu turkuaz (prototip TEAL[6] / [5] / [3]).
const COLORS: Array[Color] = [Color("a6ffe4"), Color("3cf0cb"), Color("23959a")]

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()


func _ready() -> void:
	top_level = true ## kor konumları dünya koordinatı
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func count() -> int:
	return _pos.size()


func add(pos: Vector2, vel: Vector2, life: float) -> void:
	if _pos.size() >= MAX_EMBERS:
		return
	_pos.append(pos)
	_vel.append(vel)
	_age.append(0.0)
	_life.append(life)
	if not is_processing():
		set_process(true)


func _process(delta: float) -> void:
	var n: int = _pos.size()
	var w: int = 0
	for i in n:
		var a: float = _age[i] + delta
		if a >= _life[i]:
			continue
		_age[w] = a
		_life[w] = _life[i]
		_vel[w] = _vel[i]
		_pos[w] = _pos[i] + _vel[i] * delta
		w += 1
	if w != n:
		_pos.resize(w)
		_vel.resize(w)
		_age.resize(w)
		_life.resize(w)
	queue_redraw()
	if w == 0:
		set_process(false)


func _draw() -> void:
	var T: float = PixelDraw.TEXEL
	var sz := Vector2(T, T)
	for i in _pos.size():
		var k: float = _age[i] / _life[i]
		draw_rect(Rect2((_pos[i] / T).floor() * T, sz), COLORS[mini(2, int(k * 3.0))])
