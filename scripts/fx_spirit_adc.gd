extends Node2D

## Ruhani Yetenek "Adc" (F): 10sn boyunca (saldırı hızı/kalkan delme/can emme) karakteri saran KIZIL-TURUNCU pixel güç aurası.
## DÜZELTME (2026-09-23, "aynı şeyi ruhani büyüler için de yap"): zemin dither elipsi + 9 alev dili HER karede ~650+
## draw_rect() maliyetine yol açıyordu, 10sn boyunca SÜREKLİ. Zemin artık statik bir doku (titreşim atlandı - ihmal
## edilebilir detay), alevler ise TAM BİR SALINIM PERİYODUNU (2π/11sn, orijinal `sin(_t*11+..)` formülüyle BİREBİR
## örtüşüyor) kapsayan 12 kareli, kusursuz döngülenen bir animasyon olarak pişirildi (bkz. assets/fx/spirit_adc/) -
## draw_rect sayısı ~650+ -> 2'ye indi. Dönen 3 elmas TEK bir sabit dokuya pişirilip script'te döndürülüyor (bkz.
## oakley_bee_swarm_ring.gd'deki AYNI desen) - ön/arka parlaklık farkı basitlik için atlandı. Açılış patlaması
## (~0.6sn, tek seferlik) ve yükselen kıvılcımlar (birkaç px()/parçacık - zaten ucuz) PROSEDÜREL kaldı.
## Player/RemotePlayer'ın ÇOCUĞU, sabit ömürlü (DURATION = spiritual_skills.gd ADC_DURATION).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const GROUND_TEX := preload("res://assets/fx/spirit_adc/ground.png")
const FLAME_FRAMES := preload("res://assets/fx/spirit_adc/flames_frames.tres")
const DIAMONDS_TEX := preload("res://assets/fx/spirit_adc/diamonds.png")

const BODY_CENTER := Vector2(0, -4)
const FADE_OUT := 0.5
const DIAMOND_SPIN := 5.0 ## rad/sn - eski `a2 = _t*5.0+...` ile aynı

## bkz. gen_spirit_perf_sprites.py gen_adc() - ground/flame dokuları CANVAS'ın (48,82) noktasını "yer düzlemi merkezi"
## (dünya (0,26)) olarak pişirdi; centered=false + bu offset ile doğru world konumuna oturtuluyor.
const GROUND_ANCHOR := Vector2(48, 82)
const GROUND_WORLD_POS := Vector2(0, 26)

var _t: float = 0.0
var _duration: float = SpiritualSkillsScript.ADC_DURATION
var _sparks: Array = [] ## [pos, vel, age, life]
var _acc: float = 0.0

var _ground: Sprite2D = null
var _flames: AnimatedSprite2D = null
var _diamonds: Sprite2D = null


func _ready() -> void:
	show_behind_parent = true ## alevler karakterin ARKASINDA (siblings sonra çizilir)
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_ground = Sprite2D.new()
	_ground.texture = GROUND_TEX
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.centered = false
	_ground.offset = -GROUND_ANCHOR
	_ground.position = GROUND_WORLD_POS
	add_child(_ground)

	_flames = AnimatedSprite2D.new()
	_flames.sprite_frames = FLAME_FRAMES
	_flames.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_flames.centered = false
	_flames.offset = -GROUND_ANCHOR
	_flames.position = GROUND_WORLD_POS
	add_child(_flames)
	_flames.play("loop")

	_diamonds = Sprite2D.new()
	_diamonds.texture = DIAMONDS_TEX
	_diamonds.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_diamonds.position = BODY_CENTER
	add_child(_diamonds)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _duration + FADE_OUT:
		queue_free()
		return
	if _t < _duration:
		_acc += delta
		while _acc > 0.04:
			_acc -= 0.04
			_sparks.append([BODY_CENTER + Vector2(randf_range(-18.0, 18.0), randf_range(8.0, 28.0)), Vector2(randf_range(-8.0, 8.0), randf_range(-64.0, -30.0)), 0.0, randf_range(0.5, 0.85)])
	for s in _sparks:
		s[2] += delta
		s[0] += s[1] * delta
	_sparks = _sparks.filter(func(s): return float(s[2]) < float(s[3]))

	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var open: float = clampf(_t / 0.2, 0.0, 1.0) * fade
	_ground.modulate.a = open
	_flames.modulate.a = open
	_diamonds.rotation = _t * DIAMOND_SPIN
	_diamonds.modulate.a = open

	queue_redraw()


func _draw() -> void:
	## Açılış patlaması (prosedürel, tek seferlik/ucuz)
	if _t < 0.6:
		var pk: float = _t / 0.6
		PixelDraw.ring(self, BODY_CENTER, 8.0 + pk * 92.0, Color(1.0, 0.35 + 0.4 * pk, 0.12, 1.0 - pk), 1)
		for k in range(10):
			var a: float = float(k) * TAU / 10.0 + 0.1
			var r0: float = 18.0 + pk * 42.0
			PixelDraw.line(self, BODY_CENTER + Vector2(cos(a), sin(a)) * r0, BODY_CENTER + Vector2(cos(a), sin(a)) * (r0 + 18.0 * (1.0 - pk)), Color(1.0, 0.6, 0.2, 1.0 - pk), 1)
	## Yükselen ince kıvılcımlar (prosedürel, ucuz)
	var fade: float = clampf((_duration + FADE_OUT - _t) / FADE_OUT, 0.0, 1.0)
	var open: float = clampf(_t / 0.2, 0.0, 1.0) * fade
	for s in _sparks:
		var k2: float = float(s[2]) / float(s[3])
		PixelDraw.px(self, s[0], 1, Color(1.0, 0.75 - 0.5 * k2, 0.2, (1.0 - k2) * open))
