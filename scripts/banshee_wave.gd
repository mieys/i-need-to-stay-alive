extends Node2D

## BANSHEE ÇIĞLIK DALGASI (2026-10-09, kullanıcı: "nereye ses dalgası yollayacağı hakkında uyarı verilir, düz ve kalın çizgiler halinde gönderir, duvarların arkasından geçemez"): dünya efekti.
## Konumdan `dir` yönünde `length` uzunluğunda, `width` kalınlığında şerit. WARN sn uyarı (soluk çizgi + yanıp sönen kenar), sonra FIRE sn ses dalgası: şerit içindeki her oyuncuya BİR kez
## `damage` (take_special_damage "scream"). Uzunluğu çağıran duvara kadar kısaltır (enemy_abilities.clip_ray_to_walls). Yetkili örnek hasar verir; istemcideki kopya sadece çizer.
## data: dir (Vector2), length, width, warn, fire.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _length: float = 400.0
var _width: float = 40.0
var _warn: float = 1.0
var _fire: float = 0.4
var _t: float = 0.0
var _hit: Dictionary = {}


func _ready() -> void:
	z_index = 8
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_length = float(data.get("length", 400.0))
	_width = float(data.get("width", 40.0))
	_warn = float(data.get("warn", 1.0))
	_fire = float(data.get("fire", 0.4))
	rotation = _dir.angle()
	queue_redraw()


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
			if _in_lane((p as Node2D).global_position):
				_hit[id] = true
				AbilitiesScript.deal_special_damage(p, damage, source, "scream")
	queue_redraw()


func _in_lane(world_pos: Vector2) -> bool:
	var local: Vector2 = to_local(world_pos)
	return local.x >= -AbilitiesScript.TARGET_BODY_RADIUS and local.x <= _length + AbilitiesScript.TARGET_BODY_RADIUS \
			and absf(local.y) <= _width * 0.5 + AbilitiesScript.TARGET_BODY_RADIUS


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var half: float = _width * 0.5
	if _t < _warn:
		var k: float = _t / _warn
		var pulse: float = 0.5 + 0.5 * sin(_t * 18.0)
		draw_rect(Rect2(0.0, -half, _length, _width), Color(0.45, 0.8, 1.0, 0.10 + 0.10 * k))
		draw_rect(Rect2(0.0, -half, _length, 2.0), Color(0.6, 0.9, 1.0, 0.55 + 0.3 * pulse))
		draw_rect(Rect2(0.0, half - 2.0, _length, 2.0), Color(0.6, 0.9, 1.0, 0.55 + 0.3 * pulse))
		draw_rect(Rect2(_length * (1.0 - k) - 3.0, -half, 6.0, _width), Color(0.7, 0.95, 1.0, 0.35))
		return
	## Ses dalgası: ileri akan halka şeritleri (dalga cepheleri) + parlak çekirdek
	var f: float = clampf((_t - _warn) / _fire, 0.0, 1.0)
	var a: float = 1.0 - f * 0.6
	draw_rect(Rect2(0.0, -half, _length, _width), Color(0.55, 0.85, 1.0, 0.30 * a))
	draw_rect(Rect2(0.0, -half * 0.4, _length, _width * 0.4), Color(0.85, 0.97, 1.0, 0.45 * a))
	var spacing: float = 34.0
	var phase: float = fmod(f * _length * 1.6, spacing)
	var x: float = phase
	while x < _length:
		var h: float = half * (0.7 + 0.3 * sin(x * 0.07))
		draw_arc(Vector2(x, 0.0), h, -PI * 0.5, PI * 0.5, 14, Color(0.9, 0.98, 1.0, 0.8 * a), 3.0)
		x += spacing
