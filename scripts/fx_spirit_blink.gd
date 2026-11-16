extends Node2D

## Ruhani Yetenek ışınlanma efekti - DÜNYA konumunda tek seferlik (top_level). player.gd _spirit_blink_fx() yerelde doğurur,
## network_manager.gd "spirit_blink" dalı uzakta (caster = kukla).
##  kind "streak" (Taktiksel): prototip "A Ruh Işığı" (madde 730, kullanıcı seçimi 2026-11-16, madde 734) - eski ince
##  çizgiler + nokta serpintisi + kesikli halkalar silindi:
##   - kalkış noktasında kasterin turkuaz silüeti kalır ve hedefe doğru hafifçe kayarak söner
##   - yolun %25/%50/%75'inde üç soluk hayalet silüet (hedefe yakın olan daha belirgin), sırayla söner
##   - gövde hizasında iki ucu sivrilen yumuşak ışık bandı; kuyruğu kalkıştan hedefe doğru çekilir
##   - varışta ayakta genişleyen turkuaz yer halkası + karakterin üstünde kısa krem parlama (silüet)
##  Silüetler kasterin ŞU ANKİ karesinden (spirit_fx_util.make_ghost, düz renk shader'ı); caster yoksa yalnız bant + halka.
## Konumlar oyuncu kökleri (global_position); ayak = kök + (0, 15) dünya.

const U := preload("res://scripts/spirit_fx_util.gd")
const RING_TEX := preload("res://assets/fx/ruhani/ring_ground.png")

const FEET := Vector2(0.0, 15.0)
const LIFE := 0.5

var kind: String = "streak"
var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _off: Vector2 = Vector2.ZERO ## kök -> karakter sprite'ı
var _dep: Sprite2D = null
var _path: Array = [] ## [Sprite2D, u, alfa]
var _flash: Sprite2D = null


func setup(p_kind: String, p_from: Vector2, p_to: Vector2, caster: Node = null) -> void:
	kind = p_kind
	from_pos = p_from
	to_pos = p_to
	global_position = Vector2.ZERO
	var spr: AnimatedSprite2D = U.host_sprite(caster)
	if spr == null:
		return
	_off = spr.global_position - (caster as Node2D).global_position
	_dep = _ghost(spr, U.WIND3, from_pos + _off)
	for j in range(3):
		var u: float = 0.25 * float(j + 1)
		_path.append([_ghost(spr, U.WIND3, from_pos.lerp(to_pos, u) + _off), j, 0.25 + 0.1 * float(j)])
	_flash = _ghost(spr, U.CREAM, to_pos + _off)


func _ghost(spr: AnimatedSprite2D, col: Color, at: Vector2) -> Sprite2D:
	var g: Sprite2D = U.make_ghost(spr, col)
	if g == null:
		return null
	add_child(g)
	g.global_position = at
	g.global_scale = spr.global_scale
	g.self_modulate.a = 0.0
	return g


func _ready() -> void:
	top_level = true
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = Vector2.ZERO


func get_glow_segment() -> Array:
	return [from_pos, to_pos]


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	var dir: Vector2 = (to_pos - from_pos).normalized()
	if is_instance_valid(_dep):
		var k: float = _t / 0.45
		_dep.global_position = from_pos + _off + dir * 3.0 * U.ease_out(k)
		_dep.self_modulate.a = U.band(0.55 * (1.0 - k), 4)
	for p in _path:
		var g: Sprite2D = p[0]
		if is_instance_valid(g):
			g.self_modulate.a = U.band(float(p[2]) * (1.0 - clampf((_t - 0.05 * float(p[1])) / 0.35, 0.0, 1.0)), 4)
	if is_instance_valid(_flash):
		_flash.self_modulate.a = U.band(0.65 * (1.0 - _t / 0.16), 3) if _t < 0.16 else 0.0
	queue_redraw()


func _draw() -> void:
	var span: Vector2 = to_pos - from_pos
	var length: float = span.length()
	if length > 2.0 and _t < 0.45:
		var s_tail: float = U.ease_in(_t / 0.3)
		var al: float = 1.0 - clampf((_t - 0.15) / 0.3, 0.0, 1.0)
		var n: Vector2 = Vector2(-span.y, span.x) / length
		var base: Vector2 = from_pos + FEET + Vector2(0.0, -14.0)
		for layer in [[2.6, U.WIND3, 0.24], [1.0, U.WIND4, 0.6]]:
			var a: float = U.band(float(layer[2]) * al, 4)
			if a <= 0.0:
				continue
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			var steps: int = maxi(8, int(length / 4.0))
			for i in range(steps + 1):
				var s: float = lerpf(s_tail, 1.0, float(i) / float(steps))
				var hw: float = maxf(0.5, float(layer[0]) * sqrt(maxf(0.0, sin(PI * s))))
				var c: Vector2 = base + span * s
				top.append(c + n * hw)
				bot.append(c - n * hw)
			bot.reverse()
			var poly: PackedVector2Array = top + bot
			if poly.size() >= 3:
				draw_colored_polygon(poly, U.with_a(layer[1], a))
	if _t < 0.35:
		var kk: float = _t / 0.35
		var rx: float = 4.0 + 16.0 * U.ease_out(kk)
		var f: Vector2 = to_pos + FEET
		U.frame(self, RING_TEX, 23, int(roundf(rx)) - 4, f.x, f.y, U.with_a(U.WIND3, U.band(0.85 * (1.0 - kk), 4)))
