extends Node2D

## KOZMİK IŞIN (Uçan Şeytan FİNAL bossu, kullanıcı isteği 2026-10-09: "geniş açılı Kozmik ışın ateşler ve yavaşça 360 derece etrafında döner; temas edene her 0.5 saniyede 100 hasar"): dünya efekti.
## Boss'un konumundan çıkan GENİŞ AÇILI bir dilim (yarım açı `half_angle`, uzunluk `length`). WARN sn önce başlangıç yönünde soluk dilim (uyarı), sonra `spin_time` sn'de tam bir tur (yön `sign`) döner.
## Dilimin içindeki her oyuncuya her `tick` sn'de `damage` (take_special_damage "cosmic"; yetkili örnek). Boss'u takip eder (host: `source`, istemci: data["boss"] ağ kimliği) - boss ölünce söner.
## data: angle, sign, half_angle, length, warn, spin_time, tick, boss (ağ kimliği).

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _angle0: float = 0.0
var _sign: float = 1.0
var _half: float = 0.35
var _length: float = 820.0
var _warn: float = 1.2
var _spin: float = 10.0
var _tick: float = 0.5
var _t: float = 0.0
var _boss: Node2D = null
var _boss_id: int = 0
var _cool: Dictionary = {} ## oyuncu kimliği -> bir sonraki hasara kalan süre


func _ready() -> void:
	z_index = 7
	_angle0 = float(data.get("angle", 0.0))
	_sign = float(data.get("sign", 1.0))
	_half = float(data.get("half_angle", 0.35))
	_length = float(data.get("length", 820.0))
	_warn = float(data.get("warn", 1.2))
	_spin = float(data.get("spin_time", 10.0))
	_tick = float(data.get("tick", 0.5))
	_boss_id = int(data.get("boss", 0))
	_boss = source
	queue_redraw()


## Şu anki ışın yönü (rad).
func current_angle() -> float:
	if _t < _warn:
		return _angle0
	return _angle0 + _sign * TAU * clampf((_t - _warn) / _spin, 0.0, 1.0)


func _follow_boss() -> bool:
	if _boss == null or not is_instance_valid(_boss):
		if _boss_id > 0:
			_boss = NetworkManager.find_enemy_by_net_id(_boss_id)
	if _boss != null and is_instance_valid(_boss):
		if _boss.get("is_dead") == true:
			return false
		global_position = _boss.global_position + Vector2(0.0, -34.0)
		return true
	return _boss_id <= 0 and source == null ## bağlı boss yoksa (test/serbest) olduğu yerde sürer


func _physics_process(delta: float) -> void:
	_t += delta
	if not _follow_boss() or _t >= _warn + _spin:
		queue_free()
		return
	if authoritative and _t >= _warn:
		for p in AbilitiesScript.damageable_players(get_tree()):
			var id: int = (p as Node).get_instance_id()
			_cool[id] = float(_cool.get(id, 0.0)) - delta
			if _in_beam((p as Node2D).global_position) and float(_cool[id]) <= 0.0:
				_cool[id] = _tick
				AbilitiesScript.deal_special_damage(p, damage, source, "cosmic")
	queue_redraw()


func _in_beam(world_pos: Vector2) -> bool:
	var off: Vector2 = world_pos - global_position
	var d: float = off.length()
	if d > _length + AbilitiesScript.TARGET_BODY_RADIUS:
		return false
	if d < 1.0:
		return true
	## oyuncu gövde payı: dilim kenarına yarıçap kadar yaklaşan da sayılır
	var slack: float = asin(clampf(AbilitiesScript.TARGET_BODY_RADIUS / maxf(d, AbilitiesScript.TARGET_BODY_RADIUS + 0.1), 0.0, 1.0))
	return absf(angle_difference(off.angle(), current_angle())) <= _half + slack


func _draw() -> void:
	var a: float = current_angle()
	var pts := PackedVector2Array([Vector2.ZERO])
	var steps: int = 16
	for i in range(steps + 1):
		pts.append(Vector2.from_angle(a - _half + _half * 2.0 * float(i) / float(steps)) * _length)
	if _t < _warn:
		var k: float = _t / _warn
		draw_colored_polygon(pts, Color(0.7, 0.4, 1.0, 0.08 + 0.10 * k))
		var edge := PackedVector2Array([Vector2.from_angle(a - _half) * _length, Vector2.ZERO, Vector2.from_angle(a + _half) * _length])
		draw_polyline(edge, Color(0.85, 0.6, 1.0, 0.5 + 0.3 * sin(_t * 16.0)), 2.0)
		return
	var pulse: float = 0.5 + 0.5 * sin(_t * 22.0)
	draw_colored_polygon(pts, Color(0.55, 0.25, 1.0, 0.30))
	var inner := PackedVector2Array([Vector2.ZERO])
	for i in range(steps + 1):
		inner.append(Vector2.from_angle(a - _half * 0.45 + _half * 0.9 * float(i) / float(steps)) * _length * 0.97)
	draw_colored_polygon(inner, Color(0.85, 0.6, 1.0, 0.35 + 0.15 * pulse))
	var core := PackedVector2Array([Vector2.ZERO])
	for i in range(steps + 1):
		core.append(Vector2.from_angle(a - _half * 0.14 + _half * 0.28 * float(i) / float(steps)) * _length * 0.95)
	draw_colored_polygon(core, Color(1.0, 0.95, 1.0, 0.7))
	## Yıldız tozu: dilimde ilerleyen parlak noktalar (kozmik görünüm)
	for j in range(14):
		var r: float = fposmod(float(j) * 61.0 + _t * 240.0, _length)
		var ang: float = a + sin(float(j) * 2.7 + _t * 3.0) * _half * 0.8
		draw_circle(Vector2.from_angle(ang) * r, 2.2, Color(1.0, 1.0, 1.0, 0.8))
