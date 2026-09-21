extends Node2D

## Genel pixel parçacık patlaması (bkz. pixel_draw.gd spawn_burst): kare parçacıklar dışa saçılır, sürtünmeyle
## yavaşlar, ömrün sonunda küçülüp yok olur. palette: "fire" (sarı-turuncu-kırmızı), "smoke" (koyu gri),
## "spark" (beyaz-sarı kıvılcım), "dust" (toprak tozu).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

var palette: String = "fire"
var count: int = 18
var speed: float = 160.0
var life: float = 0.5

var _t: float = 0.0
var _parts: Array = [] ## [pos, vel, color, size, delay]


func _ready() -> void:
	top_level = true
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var colors: Array = _palette_colors(palette)
	for i in range(count):
		var a: float = randf() * TAU
		var v: Vector2 = Vector2(cos(a), sin(a)) * randf_range(speed * 0.35, speed)
		if palette == "smoke":
			v.y -= speed * 0.3 ## duman yükselir
		_parts.append([Vector2.ZERO, v, colors[randi() % colors.size()], randi_range(1, 3), randf() * 0.06])
	queue_redraw()


func _palette_colors(name: String) -> Array:
	match name:
		"smoke":
			return [Color(0.2, 0.19, 0.22), Color(0.32, 0.3, 0.34), Color(0.45, 0.43, 0.47), Color(0.14, 0.13, 0.16)]
		"spark":
			return [Color(1.0, 0.98, 0.8), Color(1.0, 0.85, 0.3), Color(1.0, 0.6, 0.15)]
		"dust":
			return [Color(0.55, 0.45, 0.32), Color(0.7, 0.6, 0.44), Color(0.4, 0.32, 0.22)]
		_:
			return [Color(1.0, 0.92, 0.5), Color(1.0, 0.65, 0.15), Color(0.95, 0.35, 0.08), Color(0.7, 0.14, 0.06)]


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	for p in _parts:
		if _t - float(p[4]) > 0.0:
			p[0] = p[0] + p[1] * delta
			p[1] = p[1] * (1.0 - clampf(4.0 * delta, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0 - _t / life
	for p in _parts:
		if _t - float(p[4]) < 0.0:
			continue
		var size_texel: int = int(p[3])
		if fade < 0.4:
			size_texel = maxi(size_texel - 1, 0)
		if size_texel <= 0:
			continue
		PixelDraw.px(self, to_local(global_position + p[0]), size_texel, p[2])
