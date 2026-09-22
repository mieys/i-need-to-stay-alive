extends Node2D

## Ruhani Yetenek "Can" (F, bkz. spiritual_skills.gd): takım arkadaşlarının HEPSİNİN üzerinde çıkar (player.gd
## apply_spirit_can_buff + network_manager.gd _rpc_spirit_team_buff). Pixel-art (1 texel detay, bkz. hafıza "Pixel density 48x48"):
##  - ilk 0.7sn: dışa açılan ince altın-yeşil şifa halkaları + yukarı süzülen pixel "+" işaretleri
##  - 3sn boyunca (dokunulmazlık süresi): gövdeyi saran yarı saydam altın dither bariyer + dönen kesikli halka
## Player/RemotePlayer'ın ÇOCUĞU olarak doğar, ömrü sabittir (DURATION) - ağdan bayrak beklemez.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

const BODY_CENTER := Vector2(0, -4)
const FADE_OUT := 0.4
const DOME_RADIUS := 31.0

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.CAN_INVULN_TIME
var _plus: Array = [] ## [pos, vel, age, life, pink]


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(14):
		var a: float = randf() * TAU
		var r: float = randf_range(8.0, 28.0)
		_plus.append([BODY_CENTER + Vector2(cos(a) * r, sin(a) * r * 0.8), Vector2(randf_range(-5.0, 5.0), randf_range(-44.0, -22.0)), -randf() * 0.6, randf_range(0.9, 1.4), i % 2 == 0])


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE_OUT:
		queue_free()
		return
	for p in _plus:
		p[2] += delta
		if p[2] > 0.0:
			p[0] += p[1] * delta
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var texel: float = PixelDraw.TEXEL
	## Şifa halkaları (ilk 0.7sn) - 1 texel kalınlık
	if _t < 0.7:
		var pk: float = _t / 0.7
		PixelDraw.ring(self, BODY_CENTER, 8.0 + pk * 110.0, Color(0.55, 1.0, 0.65, 1.0 - pk), 1)
		PixelDraw.ring(self, BODY_CENTER, 4.0 + pk * 74.0, Color(1.0, 0.92, 0.5, 0.9 * (1.0 - pk)), 1, 3, 3, _t * 24.0)
		if _t < 0.1:
			PixelDraw.disc_dither(self, BODY_CENTER, 40.0, Color(1.0, 1.0, 0.85, 0.6), int(_t * 60.0), 1)
	## Altın bariyer: yarı saydam ince dither + kesikli dönen kenar + 6 küçük "perçin"
	var open: float = clampf(_t / 0.25, 0.0, 1.0) * fade
	if open > 0.0:
		var flick: int = int(_t * 8.0)
		PixelDraw.disc_dither(self, BODY_CENTER, DOME_RADIUS * open, Color(1.0, 0.9, 0.45, 0.28), flick, 1)
		PixelDraw.ring(self, BODY_CENTER, DOME_RADIUS * open, Color(1.0, 0.88, 0.4, open), 1, 5, 1, _t * 10.0)
		PixelDraw.ring(self, BODY_CENTER, (DOME_RADIUS + 1.5) * open, Color(1.0, 0.95, 0.6, 0.55 * open), 1, 3, 3, -_t * 8.0)
		PixelDraw.ring(self, BODY_CENTER, (DOME_RADIUS - 3.0) * open, Color(1.0, 1.0, 0.85, 0.3 * open), 1, 2, 5, -_t * 14.0)
		for k in range(6):
			var a: float = _t * 1.2 + float(k) * TAU / 6.0
			PixelDraw.px(self, BODY_CENTER + Vector2(cos(a), sin(a)) * DOME_RADIUS * open, 1, Color(1.0, 0.97, 0.7, 0.95 * open))
	## Yükselen küçük "+" işaretleri (merkez + 4 tek pikselli kol)
	for p in _plus:
		if float(p[2]) < 0.0:
			continue
		var k2: float = float(p[2]) / float(p[3])
		if k2 >= 1.0:
			continue
		var col: Color = Color(1.0, 0.45, 0.6, 1.0 - k2) if bool(p[4]) else Color(0.55, 1.0, 0.65, 1.0 - k2)
		var c: Vector2 = p[0]
		PixelDraw.px(self, c, 1, col)
		PixelDraw.px(self, c + Vector2(texel, 0), 1, col)
		PixelDraw.px(self, c - Vector2(texel, 0), 1, col)
		PixelDraw.px(self, c + Vector2(0, texel), 1, col)
		PixelDraw.px(self, c - Vector2(0, texel), 1, col)
