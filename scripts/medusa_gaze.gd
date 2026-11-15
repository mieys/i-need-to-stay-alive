extends Node2D

## MEDUSA'NIN TAŞLAŞTIRAN BAKIŞI (madde 682; dünya efekti "medusa_gaze", medusa_boss.gd _fire_gaze). Gözlerden (node konumu) data.angles yönlerinde
## data.length uzunluğunda, data.width kalınlığında ışınlar - her biri duvarda / Şovalye kubbesinde biter (iki tarafta aynı harita: aynı kesim).
## data.warn sn UYARI (ince sarı-yeşil raylar + uca doğru dolan çizgi: ne zaman çıkacağı görünür), sonra data.fire sn IŞIN: yetkili örnek
## herhangi bir ışının içindeki her oyuncuya BİR kez `damage` ("medusa_gaze"; taşlaşma / yavaşlama kararı player.gd'de). İstemci kopyası yalnız çizer.
## Görünüş oyunun FX dili: dolu kütleler, koyu kenar, krem çekirdek, saydamlık 4 basamaklı bantlarda (dither yok), uçlar sivrilir.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const C_OUT := Color(0.10, 0.13, 0.07)
const C_DEEP := Color(0.30, 0.42, 0.16)
const C_MID := Color(0.66, 0.80, 0.34)
const C_LIGHT := Color(0.90, 0.97, 0.62)
const C_CREAM := Color(1.0, 1.0, 0.88)
const TIP := 26.0 ## ışının ucu bu uzunlukta sivrilir

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dirs: Array[Vector2] = []
var _lens: PackedFloat32Array = PackedFloat32Array()
var _width: float = 26.0
var _warn: float = 0.9
var _fire: float = 0.3
var _t: float = 0.0
var _hit: Dictionary = {}


func _ready() -> void:
	z_index = 8
	_width = float(data.get("width", 26.0))
	_warn = float(data.get("warn", 0.9))
	_fire = float(data.get("fire", 0.3))
	var length: float = float(data.get("length", 760.0))
	for a in data.get("angles", []):
		var d := Vector2.from_angle(float(a))
		var l: float = AbilitiesScript.clip_ray_to_walls(global_position, d, length)
		l = AbilitiesScript.clip_ray_to_domes(get_tree(), global_position, d, l)
		_dirs.append(d)
		_lens.append(maxf(l, 8.0))
	queue_redraw()


static func band(a: float) -> float:
	return clampf(ceilf(clampf(a, 0.0, 1.0) * 4.0) / 4.0, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= _warn + _fire:
		queue_free()
		return
	if authoritative and _t >= _warn:
		for p in AbilitiesScript.damageable_players(get_tree()):
			var id: int = (p as Node).get_instance_id()
			if _hit.has(id):
				continue
			if in_any_beam((p as Node2D).global_position):
				_hit[id] = true
				AbilitiesScript.deal_special_damage(p, damage, source, "medusa_gaze")
	queue_redraw()


## Dünya noktası herhangi bir ışının şeridinde mi (gövde yarıçapı payıyla)?
func in_any_beam(world_pos: Vector2) -> bool:
	var rel: Vector2 = world_pos - global_position
	var pad: float = AbilitiesScript.TARGET_BODY_RADIUS
	for i in _dirs.size():
		var d: Vector2 = _dirs[i]
		var along: float = rel.dot(d)
		if along < -pad or along > _lens[i] + pad:
			continue
		if absf(rel.cross(d)) <= _width * 0.5 + pad:
			return true
	return false


func _beam_poly(d: Vector2, beam_len: float, half: float) -> PackedVector2Array:
	var n := Vector2(-d.y, d.x)
	var tip: float = minf(TIP, beam_len * 0.5)
	return PackedVector2Array([n * half * 0.35, d * (beam_len - tip) + n * half, d * beam_len, d * (beam_len - tip) - n * half, -n * half * 0.35])


func _draw() -> void:
	if _t < _warn:
		var k: float = _t / _warn
		var rail_a: float = 0.35 + 0.35 * band(0.5 + 0.5 * sin(_t * 16.0))
		for i in _dirs.size():
			var d: Vector2 = _dirs[i]
			var l: float = _lens[i]
			var n := Vector2(-d.y, d.x) * _width * 0.5
			draw_colored_polygon(_beam_poly(d, l, _width * 0.5), Color(C_DEEP, 0.08 + 0.10 * band(k)))
			draw_line(n * 0.3, d * l + n, Color(C_LIGHT, rail_a), 1.5)
			draw_line(-n * 0.3, d * l - n, Color(C_LIGHT, rail_a), 1.5)
			var fill: float = l * k
			if fill > 4.0:
				draw_line(Vector2.ZERO, d * fill, Color(C_MID, 0.7), 3.0)
		## gözlerde toplanan ışık
		draw_circle(Vector2.ZERO, 4.0 + 5.0 * k, Color(C_LIGHT, 0.4 + 0.4 * band(k)))
		return
	var f: float = clampf((_t - _warn) / _fire, 0.0, 1.0)
	var a: float = band(1.0 - f)
	var flash: float = band(1.0 - f / 0.35)
	for i in _dirs.size():
		var d: Vector2 = _dirs[i]
		var l: float = _lens[i]
		draw_colored_polygon(_beam_poly(d, l, _width * 0.5 + 2.0), Color(C_OUT, 0.55 * a))
		draw_colored_polygon(_beam_poly(d, l, _width * 0.5), Color(C_MID, 0.85 * a))
		draw_colored_polygon(_beam_poly(d, l, _width * 0.22), Color(C_LIGHT, 0.95 * a))
		if flash > 0.0:
			draw_colored_polygon(_beam_poly(d, l, _width * 0.1), Color(C_CREAM, flash))
	draw_circle(Vector2.ZERO, 9.0, Color(C_CREAM, 0.8 * a))
