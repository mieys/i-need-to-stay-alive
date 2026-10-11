extends Node2D

## WENDİGO KAYASI (2026-10-09, kullanıcı: "belli aralıklarla yere vurarak oyuncunun üstüne gökten kayalar indirir; taş atışları isabet halinde 130 hasar"): dünya efekti.
## WARN sn yerde kırmızı uyarı halkası (isabet alanı), sonra kaya FALL sn'de gökten düşer; inince alan hasarı (yarıçap) + toz + kamera sarsıntısı + kısa süre kalan enkaz.
## Yetkili örnek (host/tek oyunculu) alandaki HER oyuncuya `damage` verir (take_special_damage "rock"); istemcideki görsel kopya sadece çizer. Paketin kaya sprite'ı olmadığı için
## kaya kodla çizilir (piksel dilinde birkaç çokgen, TEXEL ızgarası). data: warn, fall, radius.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const DustScript: GDScript = preload("res://scripts/minotaur_dust.gd")
const RUBBLE_TIME := 0.9
const DROP_HEIGHT := 260.0
const TEXEL := 3.0

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _warn: float = 1.0
var _fall: float = 0.28
var _radius: float = 44.0
var _t: float = 0.0
var _landed: bool = false
var _seed: float = 0.0


func _ready() -> void:
	z_index = 5
	_warn = float(data.get("warn", 1.0))
	_fall = float(data.get("fall", 0.28))
	_radius = float(data.get("radius", 44.0))
	_seed = randf() * 100.0
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if not _landed and _t >= _warn + _fall:
		_landed = true
		_impact()
	if _t >= _warn + _fall + RUBBLE_TIME:
		queue_free()
		return
	queue_redraw()


func _impact() -> void:
	if authoritative:
		for p in AbilitiesScript.damageable_players(get_tree()):
			if global_position.distance_to((p as Node2D).global_position) <= _radius + AbilitiesScript.TARGET_BODY_RADIUS:
				AbilitiesScript.deal_special_damage(p, damage, source, "rock")
	DustScript.burst(get_tree(), global_position, Vector2.UP, 0.45)


## Kaya gövdesi (piksel çokgenleri) - merkez (0,0) = kayanın tabanı.
func _rock_polys() -> Array:
	return [
		[_poly([Vector2(-9, 0), Vector2(-11, -6), Vector2(-6, -13), Vector2(2, -15), Vector2(9, -10), Vector2(11, -3), Vector2(7, 0)]), Color(0.46, 0.42, 0.38)],
		[_poly([Vector2(-6, -13), Vector2(2, -15), Vector2(5, -10), Vector2(-2, -8), Vector2(-7, -9)]), Color(0.64, 0.6, 0.54)],
		[_poly([Vector2(-9, 0), Vector2(7, 0), Vector2(9, -3), Vector2(-1, -4), Vector2(-9, -3)]), Color(0.31, 0.28, 0.26)],
	]


func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(p * TEXEL)
	return out


func _draw() -> void:
	var land_t: float = _warn + _fall
	if _t < _warn:
		## Uyarı: halka + içi yavaşça dolan kırmızı (sert piksel dili: 2 yay + dolgu)
		var k: float = clampf(_t / _warn, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_t * 14.0)
		draw_circle(Vector2.ZERO, _radius * k, Color(0.9, 0.2, 0.15, 0.18 + 0.12 * pulse))
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40, Color(1.0, 0.3, 0.2, 0.85), 3.0)
		draw_arc(Vector2.ZERO, _radius * k, 0.0, TAU, 40, Color(1.0, 0.7, 0.4, 0.7), 1.5)
		return
	if _t < land_t:
		var f: float = (_t - _warn) / _fall
		var y: float = -DROP_HEIGHT * (1.0 - f * f)
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40, Color(1.0, 0.3, 0.2, 0.9), 3.0)
		draw_set_transform(Vector2(0.0, y), 0.0, Vector2.ONE * (1.0 + 0.6 * (1.0 - f)))
		for poly: Array in _rock_polys():
			draw_colored_polygon(poly[0], poly[1])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	## Enkaz: iki küçük taş + solan iz halkası
	var r: float = clampf((_t - land_t) / RUBBLE_TIME, 0.0, 1.0)
	var a: float = 1.0 - r
	draw_arc(Vector2.ZERO, _radius * (0.8 + 0.2 * r), 0.0, TAU, 40, Color(0.7, 0.62, 0.5, 0.5 * a), 2.0)
	draw_set_transform(Vector2(-8, 4), 0.0, Vector2.ONE * 0.5)
	for poly: Array in _rock_polys():
		draw_colored_polygon(poly[0], Color(poly[1], a))
	draw_set_transform(Vector2(10, 2), 0.0, Vector2.ONE * 0.38)
	for poly: Array in _rock_polys():
		draw_colored_polygon(poly[0], Color(poly[1], a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
