extends Node2D

## Ruhani Yetenek "Dükkan" (F): 3sn "odaklanma" (kanal) efekti (1 texel detay, bkz. hafıza "Pixel density 48x48"):
##  - ayağın altında ince MOR elips sihir çemberi (kesikli, ters dönen iki halka + 6 rün işareti)
##  - yukarı doğru büyüyen mor -> altın ışık sütunu (dither) ve sütuna yukarı çekilen ince altın kıvılcımlar
##  - cancel(): odaklanma iptal olursa hızla sönüp kaybolur
## Player/RemotePlayer'ın ÇOCUĞU. Sabit ömür = DUKKAN_CHANNEL; ışınlanma tamamlanınca (player.gd _spirit_dukkan_finish) FX zaten
## bitmiş olur. Uzak kuklada iptal `broadcast_player_vfx "spirit_cancel"` ile (bkz. network_manager.gd) bu düğümün adıyla bulunur.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")

const GROUND := Vector2(0, 26)
const CANCEL_FADE := 0.22
const END_FLASH := 0.25

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.DUKKAN_CHANNEL
var _cancel_t: float = -1.0
var _sparks: Array = [] ## [pos, age, life, start_x]
var _acc: float = 0.0


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func cancel() -> void:
	if _cancel_t < 0.0:
		_cancel_t = 0.0


func _ellipse_ring(rx: float, ry: float, col: Color, dash_on: int, dash_off: int, phase: float) -> void:
	var texel: float = PixelDraw.TEXEL
	var count: int = maxi(24, int(TAU * maxf(rx, ry) / texel))
	var period: int = dash_on + dash_off
	for i in range(count):
		if period > 0 and (int(float(i) + phase) % period) >= dash_on:
			continue
		var a: float = TAU * float(i) / float(count)
		PixelDraw.px(self, GROUND + Vector2(cos(a) * rx, sin(a) * ry), 1, col)


func _process(delta: float) -> void:
	_t += delta
	if _cancel_t >= 0.0:
		_cancel_t += delta
		if _cancel_t >= CANCEL_FADE:
			queue_free()
			return
	if _t >= _duration + END_FLASH:
		queue_free()
		return
	if _t < _duration and _cancel_t < 0.0:
		_acc += delta
		while _acc > 0.05:
			_acc -= 0.05
			var sx: float = randf_range(-26.0, 26.0)
			_sparks.append([Vector2(sx, GROUND.y - randf_range(0.0, 6.0)), 0.0, randf_range(0.7, 1.0), sx])
	for s in _sparks:
		s[1] += delta
		var k: float = float(s[1]) / float(s[2])
		## Sütuna doğru yukarı çekilir (x -> 0)
		s[0] = Vector2(lerpf(float(s[3]), 0.0, k), GROUND.y - 96.0 * k * (0.6 + 0.4 * k))
	_sparks = _sparks.filter(func(s): return float(s[1]) < float(s[2]))
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0
	if _cancel_t >= 0.0:
		fade = clampf(1.0 - _cancel_t / CANCEL_FADE, 0.0, 1.0)
	elif _t > _duration:
		fade = clampf(1.0 - (_t - _duration) / END_FLASH, 0.0, 1.0)
	var progress: float = clampf(_t / _duration, 0.0, 1.0)
	var texel: float = PixelDraw.TEXEL
	var open: float = clampf(_t / 0.3, 0.0, 1.0) * fade
	if open <= 0.0:
		return
	## Sihir çemberi
	var violet := Color(0.72, 0.5, 1.0, 0.9 * open)
	_ellipse_ring(34.0 * open, 15.0 * open, violet, 5, 1, _t * 12.0)
	_ellipse_ring(32.5 * open, 14.0 * open, Color(0.55, 0.35, 0.9, 0.6 * open), 5, 1, _t * 12.0)
	_ellipse_ring(24.0 * open, 10.5 * open, Color(1.0, 0.85, 0.45, 0.75 * open), 3, 3, -_t * 16.0)
	for k in range(6):
		var a: float = _t * 0.9 + float(k) * TAU / 6.0
		var p: Vector2 = GROUND + Vector2(cos(a) * 29.0, sin(a) * 12.7) * open
		PixelDraw.px(self, p, 1, Color(1.0, 0.95, 0.75, open))
		PixelDraw.px(self, p + Vector2(0, -texel), 1, Color(0.85, 0.7, 1.0, 0.8 * open))
	## Yükselen ışık sütunu: yükseklik ilerledikçe büyür, mor -> altın; dither
	var col_h: float = 100.0 * progress
	var rows: int = int(col_h / texel)
	var half_w: int = int(round(9.0 - 4.0 * progress))
	var flick: int = int(_t * 20.0)
	var tint: Color = Color(0.72, 0.5, 1.0).lerp(Color(1.0, 0.86, 0.45), progress)
	for iy in range(rows):
		var y: float = GROUND.y - float(iy) * texel
		var taper: float = 1.0 - float(iy) / maxf(float(rows), 1.0) * 0.6
		var hw: int = maxi(1, int(round(float(half_w) * taper)))
		for ix in range(-hw, hw + 1):
			if ((ix + iy + flick) & 1) == 0:
				continue
			PixelDraw.px(self, Vector2(float(ix) * texel, y), 1, Color(tint.r, tint.g, tint.b, (0.4 + 0.45 * progress) * open))
	## Sütuna çekilen kıvılcımlar
	for s in _sparks:
		var k2: float = float(s[1]) / float(s[2])
		PixelDraw.px(self, s[0], 2 if k2 < 0.5 else 1, Color(1.0, 0.9, 0.5, (1.0 - k2 * 0.5) * open))
	## Bitiş parlaması
	if _cancel_t < 0.0 and _t > _duration:
		PixelDraw.disc_dither(self, Vector2(0, -6), 40.0, Color(1.0, 0.95, 0.8, 0.8 * fade), int(_t * 40.0), 1)
