extends Node2D

## WENDİGO SARMAŞIĞI (2026-10-09, kullanıcı: "yerden oyuncunun gideceği yönlere doğru sürekli yerden çıkan sarmaşıklar; isabet halinde 100 hasar"): dünya efekti.
## Yetkili örnek (host/tek oyunculu) çıkış penceresinde yarıçaptaki her oyuncuya BİR kez `damage` verir (take_special_damage "vine"); istemcideki görsel kopya sadece oynar.
## Animasyon paketin "branch - full animation (16x32)" şeridi: ilk 6 kare UYARI (büyüyen kırmızı elips, WARN sn), sonraki 13 kare yerden çıkış (GROW sn). Hasar çıkışın
## orta karelerinde (HIT_FROM..HIT_TO oranı). data: warn, grow, radius, scale.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const SHEET := preload("res://assets/fx/wendigo/vine.png")
const ANTICIP_FRAMES := 6
const GROW_FRAMES := 13
const HIT_FROM := 0.12
const HIT_TO := 0.6
const LINGER := 0.35

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _warn: float = 0.7
var _grow: float = 0.8
var _radius: float = 26.0
var _t: float = 0.0
var _hit: Dictionary = {}
var _sprite: Sprite2D = null


func _ready() -> void:
	add_to_group("wendigo_vines")
	z_index = 3
	_warn = float(data.get("warn", 0.7))
	_grow = float(data.get("grow", 0.8))
	_radius = float(data.get("radius", 26.0))
	_sprite = Sprite2D.new()
	_sprite.texture = SHEET
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = ANTICIP_FRAMES + GROW_FRAMES
	_sprite.vframes = 1
	_sprite.offset = Vector2(0.0, -16.0) ## karenin alt-ortası node'un konumunda
	_sprite.scale = Vector2.ONE * float(data.get("scale", 1.9))
	add_child(_sprite)
	_sprite.frame = 0


func _physics_process(delta: float) -> void:
	_t += delta
	var total: float = _warn + _grow + LINGER
	if _t >= total:
		queue_free()
		return
	if _t < _warn:
		_sprite.frame = mini(int(_t / _warn * ANTICIP_FRAMES), ANTICIP_FRAMES - 1)
		return
	var g: float = clampf((_t - _warn) / _grow, 0.0, 1.0)
	_sprite.frame = ANTICIP_FRAMES + mini(int(g * GROW_FRAMES), GROW_FRAMES - 1)
	if _t > _warn + _grow:
		_sprite.modulate.a = clampf(1.0 - (_t - _warn - _grow) / LINGER, 0.0, 1.0)
	if authoritative and g >= HIT_FROM and g <= HIT_TO:
		_try_hit()


func _try_hit() -> void:
	for p in AbilitiesScript.damageable_players(get_tree()):
		var id: int = (p as Node).get_instance_id()
		if _hit.has(id):
			continue
		if global_position.distance_to((p as Node2D).global_position) <= _radius + AbilitiesScript.TARGET_BODY_RADIUS:
			_hit[id] = true
			AbilitiesScript.deal_special_damage(p, damage, source, "vine")
