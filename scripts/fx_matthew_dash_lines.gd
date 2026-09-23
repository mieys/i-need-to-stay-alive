extends Node2D

## Matthew'in tilkisinin Tilki Hücumu dash'i sırasında ARKASINDA duran hız çizgileri (kullanıcı isteği
## 2026-09-23: "tilki dash atarken arkasında dash çizgisi olmalı"). Tilkinin ÇOCUĞU olarak yaşar ve onunla
## birlikte hareket eder (bkz. player_pet.gd dash_to) - önceki sürüm çizgileri dünyaya serpiştirip hemen
## bırakıyordu, tilkinin arkasında "akan" bir iz gibi okunmuyordu. Hareket bitince kısa sürede söner.
## PixelDraw ile 1 sanat pikseli kalınlığında (bkz. hafıza: feedback_pixel_style_fx / pixel density).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const FADE_TIME := 0.12
const LINE_COLOR := Color(1.0, 0.86, 0.62)
## [dik ofset, uzunluk] - ortadakiler daha uzun, klasik "hız çizgisi" demeti.
const LINES := [[-8.0, 30.0], [-3.0, 46.0], [2.0, 38.0], [7.0, 26.0]]

var _dir: Vector2 = Vector2.RIGHT
var _strength: float = 0.0
var _moving: bool = false
var _t: float = 0.0


## NOT: tilkinin gövdesinin ARKASINDA kalması z_index ile DEĞİL, çocuk sırasıyla sağlanıyor (player_pet.gd
## dash_to bunu AnimatedSprite2D'den önceye taşıyor) - z_index = -1 çizgileri zemin katmanının da altına
## itip tamamen görünmez yapıyordu.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false


func start(travel: Vector2) -> void:
	if travel.length() > 0.5:
		_dir = travel.normalized()
	_moving = true
	_strength = 1.0
	visible = true
	queue_redraw()


func stop() -> void:
	_moving = false


func _process(delta: float) -> void:
	if _strength <= 0.0:
		return
	_t += delta
	if not _moving:
		_strength = maxf(0.0, _strength - delta / FADE_TIME)
		if _strength <= 0.0:
			visible = false
	queue_redraw()


func _draw() -> void:
	if _strength <= 0.0:
		return
	var perp: Vector2 = Vector2(-_dir.y, _dir.x)
	for i in range(LINES.size()):
		var off: float = float(LINES[i][0])
		## Hafif titreme - çizgiler "akıyormuş" gibi boyları kare kare biraz oynuyor.
		var length: float = float(LINES[i][1]) * (0.85 + 0.15 * sin(_t * 55.0 + float(i) * 1.7))
		var from: Vector2 = -_dir * 9.0 + perp * off
		var to: Vector2 = from - _dir * length
		PixelDraw.line(self, from, to, Color(LINE_COLOR, 0.85 * _strength), 1)
