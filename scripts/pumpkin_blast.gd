extends Node2D

## KABAK PATLAMASI (2026-10-09, Balkabağı Kafa'nın kabak yaratıkları: "oyunculara yaklaşınca patlayarak alan hasarı olarak 20 hasar verir"): anlık alan hasarı + kısa halka efekti.
## Yetkili örnek (host/tek oyunculu) `data.radius` içindeki HER oyuncuya `damage` verir (take_special_damage "blast"); istemcide görsel kopya sadece halkayı gösterir.
## Kabağın kendi parçalanma animasyonu (kabak_death) enemy.gd tarafından oynatılır.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const LIFE := 0.28

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0
var _t: float = 0.0
var _radius: float = 60.0


func _ready() -> void:
	z_index = 9
	_radius = float(data.get("radius", 60.0))
	if authoritative:
		for p in AbilitiesScript.damageable_players(get_tree()):
			var pn := p as Node2D
			if global_position.distance_to(pn.global_position) <= _radius + AbilitiesScript.TARGET_BODY_RADIUS:
				AbilitiesScript.deal_special_damage(p, damage, source, "blast")
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(_t / LIFE, 0.0, 1.0)
	var r: float = _radius * (0.35 + 0.65 * k)
	var a: float = 1.0 - k
	## Piksel dilinde sert halka (2 katman), dolgu yok.
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.62, 0.15, 0.9 * a), 3.0)
	draw_arc(Vector2.ZERO, maxf(r - 4.0, 1.0), 0.0, TAU, 40, Color(1.0, 0.9, 0.5, 0.6 * a), 1.5)
