extends Node2D

## Kurt Adam'ın yakın dövüş pençe savuruşu: saldırı yönüne doğru hızla
## süpürülüp sönen üç paralel pençe izi + hafif dış ışıma. Tamamen
## prosedürel (draw_arc), doku gerektirmez. Weapon._spawn_slash_fx tarafından
## oyuncunun konumunda, saldırı yönüne döndürülmüş olarak yaratılır.

const LIFETIME := 0.22
const SWEEP := 1.2 ## radyan: savuruş boyunca toplam dönme
## Yay, karakterin merkezinden bu uzaklıkta çizilir - karakterin gövdesinin
## hemen dışında süpürülür (Player'ın 0.5 sahne ölçeğiyle birlikte ~44px).
const RADIUS := 88.0

var _t: float = 0.0
var _base_rot: float = 0.0


func _ready() -> void:
	z_index = 60
	_base_rot = rotation
	rotation = _base_rot - SWEEP * 0.5


func _process(delta: float) -> void:
	_t += delta
	var p := _t / LIFETIME
	if p >= 1.0:
		queue_free()
		return
	rotation = _base_rot + lerpf(-SWEEP * 0.5, SWEEP * 0.5, ease(p, 0.4))
	modulate.a = 1.0 - p * p


func _draw() -> void:
	## dış ışıma
	draw_arc(Vector2.ZERO, RADIUS, -0.55, 0.55, 24, Color(1.0, 0.85, 0.75, 0.22), 10.0, true)
	## üç paralel pençe izi (hafif açı kaymalarıyla)
	draw_arc(Vector2.ZERO, RADIUS - 12.0, -0.42, 0.5, 20, Color(1.0, 1.0, 1.0, 0.85), 3.0, true)
	draw_arc(Vector2.ZERO, RADIUS, -0.5, 0.55, 20, Color(1.0, 1.0, 1.0, 0.95), 3.5, true)
	draw_arc(Vector2.ZERO, RADIUS + 12.0, -0.45, 0.48, 20, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
	## uçlarda kızıl bir iz - kurt pençesi hissi
	draw_arc(Vector2.ZERO, RADIUS, 0.35, 0.58, 10, Color(0.95, 0.35, 0.3, 0.6), 3.0, true)
