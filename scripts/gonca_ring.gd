extends Node2D

## ZEHİRLİ GONCA "DİKEN HALKASI" (madde 682; dünya efekti "gonca_ring", gonca_boss.gd _begin_ring). Bossun çevresinde `radius`lık halka:
## data.warn sn UYARI (soluk dolu disk + dolan iç halka + kenar), sonra PATLAMA: yetkili örnek halkanın içindeki her oyuncuya BİR kez `damage`
## ("gonca_ring": hasar + zehir, player.gd), genişleyen pembe halka + diken uçları. İstemci kopyası yalnız çizer.
## Görünüş oyunun FX dili: dolu kütleler, koyu arka kenar, saydamlık 4 basamaklı bantlarda (dither yok).

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const C_OUT := Color(0.22, 0.09, 0.20)
const C_DEEP := Color(0.48, 0.20, 0.44)
const C_MID := Color(0.84, 0.44, 0.72)
const C_LIGHT := Color(0.98, 0.78, 0.92)
const BURST := 0.32
const SPIKES := 14

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _r: float = 140.0
var _warn: float = 0.5
var _t: float = 0.0
var _done: bool = false


func _ready() -> void:
	z_index = 1
	_r = float(data.get("radius", 140.0))
	_warn = float(data.get("warn", 0.5))
	queue_redraw()


static func band(a: float) -> float:
	return clampf(ceilf(clampf(a, 0.0, 1.0) * 4.0) / 4.0, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_t += delta
	if source != null and is_instance_valid(source):
		global_position = source.global_position ## halka bossa bağlı (göç sırasında atılmaz ama yine de)
	if not _done and _t >= _warn:
		_done = true
		if authoritative:
			for p in AbilitiesScript.damageable_players(get_tree()):
				if (p as Node2D).global_position.distance_to(global_position) <= _r + AbilitiesScript.TARGET_BODY_RADIUS:
					AbilitiesScript.deal_special_damage(p, damage, source, "gonca_ring")
	if _t >= _warn + BURST:
		queue_free()
		return
	queue_redraw()


func _ellipse(r: float, squash: float = 0.62) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var a: float = TAU * float(i) / 40.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * squash))
	return pts


func _draw() -> void:
	if _t < _warn:
		var k: float = _t / _warn
		## Yeşil zeminde gri okunmasın diye (oyun içi yakalama) gövde orta pembe, kenar koyu + açık pembe çift çizgi.
		draw_colored_polygon(_ellipse(_r), Color(C_MID, 0.12 + 0.10 * band(k)))
		var fill: PackedVector2Array = _ellipse(_r * band(k))
		if fill.size() >= 3 and _r * k > 4.0:
			draw_colored_polygon(fill, Color(C_MID, 0.20))
		var rim: PackedVector2Array = _ellipse(_r)
		rim.append(rim[0])
		draw_polyline(rim, Color(C_OUT, 0.5), 4.0)
		draw_polyline(rim, Color(C_LIGHT, 0.6 + 0.3 * band(0.5 + 0.5 * sin(_t * 18.0))), 2.0)
		return
	var e: float = clampf((_t - _warn) / BURST, 0.0, 1.0)
	var ease_e: float = 1.0 - pow(1.0 - e, 2.0)
	var r: float = lerpf(_r * 0.35, _r, ease_e)
	var a: float = band(1.0 - e)
	var ring: PackedVector2Array = _ellipse(r)
	ring.append(ring[0])
	draw_polyline(ring, Color(C_OUT, 0.6 * a), 9.0)
	draw_polyline(ring, Color(C_MID, 0.9 * a), 6.0)
	draw_polyline(ring, Color(C_LIGHT, 0.9 * a), 2.0)
	## diken uçları: halkadan dışa sivri üçgenler
	for i in SPIKES:
		var ang: float = TAU * float(i) / float(SPIKES)
		var dir := Vector2(cos(ang), sin(ang) * 0.62)
		var side := Vector2(-dir.y, dir.x).normalized() * 4.0
		var base: Vector2 = dir * r
		var tip: Vector2 = dir * (r + 14.0 * (1.0 - e * 0.6))
		draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color(C_LIGHT, 0.85 * a))
