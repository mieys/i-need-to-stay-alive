extends Node2D

## Ruhani Yetenek "Dükkan" (F): 3sn "odaklanma" (kanal) efekti.
## DÜZELTME (2026-09-23, "aynı şeyi ruhani büyüler için de yap"): sihir çemberi (3 kesikli elips halkası + 6 rün) +
## yükselen ışık sütunu HER karede ~1200+ draw_rect() maliyetine yol açıyordu, 3.25sn boyunca SÜREKLİ. Halkalar/rünler
## artık statik dokular (script'te döndürülüyor, bkz. oakley_bee_swarm_ring.gd'deki AYNI desen); sütun NÖTR (beyaz)
## pişirilip script'te scale.y (büyüme) + modulate (mor->altın renk geçişi + solma) ile kontrol ediliyor - hiçbiri
## için ekstra kare gerekmedi. draw_rect sayısı ~1200+ -> 4'e indi. Yükselen kıvılcımlar (birkaç px()/parçacık) ve
## bitiş parlaması (tek seferlik) PROSEDÜREL kaldı.
##  - ayağın altında ince MOR elips sihir çemberi (kesikli, ters dönen iki halka + 6 rün işareti) - baked
##  - yukarı doğru büyüyen mor -> altın ışık sütunu (dither) ve sütuna yukarı çekilen ince altın kıvılcımlar
##  - cancel(): odaklanma iptal olursa hızla sönüp kaybolur
## Player/RemotePlayer'ın ÇOCUĞU. Sabit ömür = DUKKAN_CHANNEL; ışınlanma tamamlanınca (player.gd _spirit_dukkan_finish) FX zaten
## bitmiş olur. Uzak kuklada iptal `broadcast_player_vfx "spirit_cancel"` ile (bkz. network_manager.gd) bu düğümün adıyla bulunur.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const RING_VIOLET_TEX := preload("res://assets/fx/spirit_dukkan/ring_violet.png")
const RING_GOLD_TEX := preload("res://assets/fx/spirit_dukkan/ring_gold.png")
const RUNES_TEX := preload("res://assets/fx/spirit_dukkan/runes.png")
const COLUMN_TEX := preload("res://assets/fx/spirit_dukkan/column.png")

const GROUND := Vector2(0, 26)
const CANCEL_FADE := 0.22
const END_FLASH := 0.25
const RING_VIOLET_SPIN := 0.9 ## eski phase=_t*12.0 ile aynı yön (iki mor halka da aynı hızda dönüyordu)
const RING_GOLD_SPIN := -1.15 ## eski phase=-_t*16.0 ile aynı yön
const RUNE_SPIN := 0.9 ## eski `a=_t*0.9+...`

const VIOLET := Color(0.72, 0.5, 1.0)
const GOLD := Color(1.0, 0.86, 0.45)
const COL_W := 20.0
const COL_H := 100.0

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.DUKKAN_CHANNEL
var _cancel_t: float = -1.0
var _sparks: Array = [] ## [pos, age, life, start_x]
var _acc: float = 0.0

var _ring_violet: Sprite2D = null
var _ring_gold: Sprite2D = null
var _runes: Sprite2D = null
var _column: Sprite2D = null


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_ring_violet = _make_ring_sprite(RING_VIOLET_TEX)
	_ring_gold = _make_ring_sprite(RING_GOLD_TEX)
	_runes = _make_ring_sprite(RUNES_TEX)

	_column = Sprite2D.new()
	_column.texture = COLUMN_TEX
	_column.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_column.centered = false
	_column.offset = Vector2(-COL_W / 2.0, -COL_H)
	_column.position = GROUND
	_column.scale = Vector2(1.0, 0.0)
	add_child(_column)


func _make_ring_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = GROUND
	add_child(s)
	return s


func cancel() -> void:
	if _cancel_t < 0.0:
		_cancel_t = 0.0


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
		s[0] = Vector2(lerpf(float(s[3]), 0.0, k), GROUND.y - 96.0 * k * (0.6 + 0.4 * k))
	_sparks = _sparks.filter(func(s): return float(s[1]) < float(s[2]))

	var fade: float = 1.0
	if _cancel_t >= 0.0:
		fade = clampf(1.0 - _cancel_t / CANCEL_FADE, 0.0, 1.0)
	elif _t > _duration:
		fade = clampf(1.0 - (_t - _duration) / END_FLASH, 0.0, 1.0)
	var progress: float = clampf(_t / _duration, 0.0, 1.0)
	var open: float = clampf(_t / 0.3, 0.0, 1.0) * fade

	_ring_violet.rotation = _t * RING_VIOLET_SPIN
	_ring_violet.scale = Vector2.ONE * open
	_ring_violet.modulate.a = open
	_ring_gold.rotation = _t * RING_GOLD_SPIN
	_ring_gold.scale = Vector2.ONE * open
	_ring_gold.modulate.a = open
	_runes.rotation = _t * RUNE_SPIN
	_runes.scale = Vector2.ONE * open
	_runes.modulate.a = open

	_column.scale.y = progress
	var tint: Color = VIOLET.lerp(GOLD, progress)
	_column.modulate = Color(tint.r, tint.g, tint.b, (0.4 + 0.45 * progress) * open)

	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0
	if _cancel_t >= 0.0:
		fade = clampf(1.0 - _cancel_t / CANCEL_FADE, 0.0, 1.0)
	elif _t > _duration:
		fade = clampf(1.0 - (_t - _duration) / END_FLASH, 0.0, 1.0)
	## Sütuna çekilen kıvılcımlar (prosedürel, ucuz)
	for s in _sparks:
		var k2: float = float(s[1]) / float(s[2])
		PixelDraw.px(self, s[0], 2 if k2 < 0.5 else 1, Color(1.0, 0.9, 0.5, (1.0 - k2 * 0.5) * fade))
	## Bitiş parlaması (tek seferlik, ucuz)
	if _cancel_t < 0.0 and _t > _duration:
		PixelDraw.disc_dither(self, Vector2(0, -6), 40.0, Color(1.0, 0.95, 0.8, 0.8 * fade), int(_t * 40.0), 1)
