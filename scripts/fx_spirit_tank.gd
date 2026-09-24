extends Node2D

## Ruhani Yetenek "Tank" (F): 10sn boyunca gövdeyi saran yarı saydam ÇELİK-MAVİ + ALTIN pixel bariyer (altıgen kalkan aurası).
## DÜZELTME (2026-09-23, kalkan/arı/sarmaşık dönüşümünün devamı - "aynı şeyi ruhani büyüler için de yap"): steady-state altıgen
## çerçeve+dither dolgu+perçinler HER karede ~1200+ draw_rect() çağrısıyla yeniden çiziliyordu, 10sn boyunca SÜREKLİ - birden
## fazla oyuncu aynı anda Tank açarsa bu katlanıyordu. İki katman artık PNG'ye pişirildi (assets/fx/spirit_tank/hex_outer.png +
## hex_inner.png, referans açı 0) ve script'te rotation/scale/modulate ile döndürülüp büyütülüyor/soluyor (bkz.
## oakley_bee_swarm_ring.gd'deki AYNI "statik doku + script rotation" deseni) - draw_rect sayısı ~1200 -> 2'ye indi.
## Açılış şok halkası (~0.55sn, tek seferlik) VE kenar parıltısı (sweep, 3 px()/kare - zaten ucuz) PROSEDÜREL bırakıldı;
## asıl kazanç zaten SÜREKLİ çizilen kısımdaydı.
##  - açılış: metalik beyaz-mavi şok halkası + içe toplanan 6 çizgi (prosedürel)
##  - süre boyunca: yavaş dönen ince altıgen çerçeve + köşelerinde altın perçinler (baked, döndürülür) + üstünden geçen
##    parlak şerit (prosedürel, ucuz)
##  - pulse(): hasar yansıtıldığında (player.gd _spirit_tank_on_hit) çerçeve kısa süre parlar (self_modulate ile)
## Player/RemotePlayer'ın ÇOCUĞU, sabit ömürlü (DURATION = spiritual_skills.gd TANK_DURATION).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const HEX_OUTER_TEX := preload("res://assets/fx/spirit_tank/hex_outer.png")
const HEX_INNER_TEX := preload("res://assets/fx/spirit_tank/hex_inner.png")

const BODY_CENTER := Vector2(0, -4)
const FADE_OUT := 0.5
const RADIUS := 36.0
const ROT_SPEED := 0.35 ## rad/sn - eski `rot = _t*0.35` ile aynı

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.TANK_DURATION
var _pulse: float = 0.0

var _hex_outer: Sprite2D = null
var _hex_inner: Sprite2D = null


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_hex_outer = Sprite2D.new()
	_hex_outer.texture = HEX_OUTER_TEX
	_hex_outer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hex_outer.position = BODY_CENTER
	add_child(_hex_outer)

	_hex_inner = Sprite2D.new()
	_hex_inner.texture = HEX_INNER_TEX
	_hex_inner.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hex_inner.position = BODY_CENTER
	add_child(_hex_inner)


## Hasar yansıyınca çağrılır: çerçeve ~0.25sn parlar.
func pulse() -> void:
	_pulse = 0.25


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta)
	if _t >= _duration + FADE_OUT:
		queue_free()
		return

	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var open: float = clampf(_t / 0.25, 0.0, 1.0) * fade
	var rot: float = _t * ROT_SPEED
	var bright: float = 1.0 + (_pulse / 0.25) * 0.8

	_hex_outer.rotation = rot
	_hex_outer.scale = Vector2.ONE * open
	_hex_outer.modulate = Color(bright, bright, bright, minf(1.0, open))
	_hex_inner.rotation = -rot * 0.8
	_hex_inner.scale = Vector2.ONE * open
	_hex_inner.modulate.a = open

	queue_redraw()


func _hex_points(radius: float, rot: float) -> Array:
	var pts: Array = []
	for k in range(6):
		var a: float = rot + float(k) * TAU / 6.0
		pts.append(BODY_CENTER + Vector2(cos(a) * radius, sin(a) * radius * 0.92))
	return pts


## Sadece açılış patlaması + kenar parıltısı (sweep) - steady-state çerçeve artık Sprite2D (bkz. _ready/_process).
func _draw() -> void:
	## Açılış: metalik şok halkası + içe toplanan çizgiler
	if _t < 0.55:
		var pk: float = _t / 0.55
		PixelDraw.ring(self, BODY_CENTER, 8.0 + pk * 84.0, Color(0.8, 0.92, 1.0, 1.0 - pk), 1)
		PixelDraw.ring(self, BODY_CENTER, 4.0 + pk * 56.0, Color(1.0, 0.85, 0.4, 0.8 * (1.0 - pk)), 1, 3, 3, _t * 20.0)
		for k in range(6):
			var a: float = float(k) * TAU / 6.0 + 0.3
			var r1: float = 70.0 * (1.0 - pk) + 14.0
			PixelDraw.line(self, BODY_CENTER + Vector2(cos(a), sin(a)) * r1, BODY_CENTER + Vector2(cos(a), sin(a)) * (r1 + 14.0), Color(0.75, 0.9, 1.0, 1.0 - pk), 1)
	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var open: float = clampf(_t / 0.25, 0.0, 1.0) * fade
	if open <= 0.0:
		return
	var rot: float = _t * ROT_SPEED
	var outer: Array = _hex_points(RADIUS * open, rot)
	## Kenarlardan geçen parlak şerit
	var sweep: float = fmod(_t * 0.9, 1.0) * 6.0
	var edge: int = int(sweep) % 6
	var f: float = sweep - floorf(sweep)
	var s_a: Vector2 = outer[edge]
	var s_b: Vector2 = outer[(edge + 1) % 6]
	var s_p: Vector2 = s_a.lerp(s_b, f)
	PixelDraw.px(self, s_p, 1, Color(1.0, 1.0, 1.0, open))
	PixelDraw.px(self, s_a.lerp(s_b, clampf(f - 0.08, 0.0, 1.0)), 1, Color(0.85, 0.95, 1.0, 0.7 * open))
	PixelDraw.px(self, s_a.lerp(s_b, clampf(f - 0.16, 0.0, 1.0)), 1, Color(0.75, 0.9, 1.0, 0.4 * open))
