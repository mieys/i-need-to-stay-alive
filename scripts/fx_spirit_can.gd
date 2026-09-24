extends Node2D

## Ruhani Yetenek "Can" (F, bkz. spiritual_skills.gd): takım arkadaşlarının HEPSİNİN üzerinde çıkar (player.gd
## apply_spirit_can_buff + network_manager.gd _rpc_spirit_team_buff).
## DÜZELTME (2026-09-23, "aynı şeyi ruhani büyüler için de yap"): dokunulmazlık boyunca (3sn) süren altın bariyer HER
## karede dither dolgu + 3 halka çizerek ~1000+ draw_rect() maliyetine yol açıyordu. Dolgu + 3 halka + perçinler artık
## PNG'ye pişirildi (assets/fx/spirit_can/), her biri KENDİ hızında script'te döndürülen/soluklaştırılan ayrı bir
## Sprite2D (bkz. oakley_bee_swarm_ring.gd'deki AYNI desen) - draw_rect sayısı ~1000+ -> 5'e indi. Şifa halkaları
## (~0.7sn, tek seferlik) ve yükselen "+" işaretleri (14 tanesi, birkaç px()/parçacık - zaten ucuz) PROSEDÜREL kaldı.
##  - ilk 0.7sn: dışa açılan ince altın-yeşil şifa halkaları + yukarı süzülen pixel "+" işaretleri (prosedürel)
##  - 3sn boyunca (dokunulmazlık süresi): gövdeyi saran yarı saydam altın dither bariyer + dönen kesikli halkalar (baked)
## Player/RemotePlayer'ın ÇOCUĞU olarak doğar, ömrü sabittir (DURATION) - ağdan bayrak beklemez.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const DOME_FILL_TEX := preload("res://assets/fx/spirit_can/dome_fill.png")
const RING1_TEX := preload("res://assets/fx/spirit_can/ring1.png")
const RING2_TEX := preload("res://assets/fx/spirit_can/ring2.png")
const RING3_TEX := preload("res://assets/fx/spirit_can/ring3.png")
const RIVETS_TEX := preload("res://assets/fx/spirit_can/rivets.png")

const BODY_CENTER := Vector2(0, -4)
const FADE_OUT := 0.4
const DOME_RADIUS := 31.0
## bkz. sınıf üstü not - orijinal `ring(..., phase=_t*X)` kaymalarının yaklaşık açısal karşılığı (X * halka başına adım
## açısı) - PNG'ler sabit fazda pişirildi, dönüş burada verilir. Rivets kendi ayrı hızında (eski `a=_t*1.2+...`).
const RING1_SPIN := 0.20 ## eski phase=_t*10.0 ile aynı yön
const RING2_SPIN := -0.16 ## eski phase=-_t*8.0 ile aynı yön
const RING3_SPIN := -0.28 ## eski phase=-_t*14.0 ile aynı yön
const RIVET_SPIN := 1.2

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.CAN_INVULN_TIME
var _plus: Array = [] ## [pos, vel, age, life, pink]

var _dome_fill: Sprite2D = null
var _ring1: Sprite2D = null
var _ring2: Sprite2D = null
var _ring3: Sprite2D = null
var _rivets: Sprite2D = null


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in range(14):
		var a: float = randf() * TAU
		var r: float = randf_range(8.0, 28.0)
		_plus.append([BODY_CENTER + Vector2(cos(a) * r, sin(a) * r * 0.8), Vector2(randf_range(-5.0, 5.0), randf_range(-44.0, -22.0)), -randf() * 0.6, randf_range(0.9, 1.4), i % 2 == 0])

	_dome_fill = _make_sprite(DOME_FILL_TEX)
	_ring1 = _make_sprite(RING1_TEX)
	_ring2 = _make_sprite(RING2_TEX)
	_ring3 = _make_sprite(RING3_TEX)
	_rivets = _make_sprite(RIVETS_TEX)


func _make_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = BODY_CENTER
	add_child(s)
	return s


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE_OUT:
		queue_free()
		return
	for p in _plus:
		p[2] += delta
		if p[2] > 0.0:
			p[0] += p[1] * delta

	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var open: float = clampf(_t / 0.25, 0.0, 1.0) * fade
	_dome_fill.scale = Vector2.ONE * open
	_dome_fill.modulate.a = open
	_ring1.rotation = _t * RING1_SPIN
	_ring1.scale = Vector2.ONE * open
	_ring1.modulate.a = open
	_ring2.rotation = _t * RING2_SPIN
	_ring2.scale = Vector2.ONE * open
	_ring2.modulate.a = open
	_ring3.rotation = _t * RING3_SPIN
	_ring3.scale = Vector2.ONE * open
	_ring3.modulate.a = open
	_rivets.rotation = _t * RIVET_SPIN
	_rivets.scale = Vector2.ONE * open
	_rivets.modulate.a = open

	queue_redraw()


func _draw() -> void:
	## Şifa halkaları (ilk 0.7sn) - 1 texel kalınlık, prosedürel (tek seferlik, ucuz)
	if _t < 0.7:
		var pk: float = _t / 0.7
		PixelDraw.ring(self, BODY_CENTER, 8.0 + pk * 110.0, Color(0.55, 1.0, 0.65, 1.0 - pk), 1)
		PixelDraw.ring(self, BODY_CENTER, 4.0 + pk * 74.0, Color(1.0, 0.92, 0.5, 0.9 * (1.0 - pk)), 1, 3, 3, _t * 24.0)
		if _t < 0.1:
			PixelDraw.disc_dither(self, BODY_CENTER, 40.0, Color(1.0, 1.0, 0.85, 0.6), int(_t * 60.0), 1)
	## Yükselen küçük "+" işaretleri (merkez + 4 tek pikselli kol)
	var texel: float = PixelDraw.TEXEL
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
