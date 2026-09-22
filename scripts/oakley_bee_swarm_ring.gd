extends Node2D

## oakley_bee_swarm.gd'nin alan göstergesi - Oakley'in Arı Sürüsü (Q) alanı. Kullanıcı isteği (2026-09-21): "alanın içinde minik arılar
## uçuşsun, efekti pixel tarzda yeniden tasarla, ses efektiyle beraber". Eskiden düz sarı daire + 8 siyah nokta çiziyordu.
## Şimdi (1 texel detay, bkz. hafıza "Pixel density 48x48"):
##  - alan sınırı: kesikli amber pixel halka (+ içte ince ikinci halka) ve çok hafif bal rengi dither dolgu
##  - içinde 18 minik pixel ARI: sarı-siyah çizgili gövde, çırpan kanatlar (2 karede yanıp söner), her biri kendi rastgele-gibi
##    yörüngesinde gezinir (Lissajous + titreşim), yerde küçük gölgeleri var (havada uçtukları belli olsun)
##  - SES: alan yaşadığı sürece aralıklı çalan vızıltı (assets/audio/oakley/oakley_bees.wav, konumlu 2D ses => herkes duyar)
## Bu düğüm hem GERÇEK alanda (oakley_bee_swarm.gd) hem uzak istemcilerde (network_manager.gd "oakley_bee_swarm_spawn") aynı dosyadan
## doğar - görsel/ses iki tarafta AYNI (bkz. proje kökündeki CLAUDE.md).

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const BUZZ_PATH := "res://assets/audio/oakley/oakley_bees.wav"
const BEE_COUNT := 18
const BUZZ_GAP := 0.8 ## iki vızıltı arası boşluk (sn)

const C_YELLOW := Color(1.0, 0.84, 0.16, 1.0)
const C_YELLOW_D := Color(0.9, 0.6, 0.08, 1.0)
const C_BLACK := Color(0.1, 0.07, 0.03, 1.0)
const C_WING := Color(0.85, 0.95, 1.0, 0.8)

var _radius: float = 130.0
var _t: float = 0.0
var _bees: Array = [] ## {r, w, phase, phase2, wob, spd2}
var _sfx: AudioStreamPlayer2D = null
var _gap_timer: float = 0.0


func setup(radius: float) -> void:
	_radius = radius


func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(BEE_COUNT):
		_bees.append({
			"r": rng.randf_range(0.12, 0.9),
			"w": rng.randf_range(0.5, 1.5) * (1.0 if i % 2 == 0 else -1.0),
			"phase": rng.randf_range(0.0, TAU),
			"phase2": rng.randf_range(0.0, TAU),
			"wob": rng.randf_range(0.15, 0.4),
			"spd2": rng.randf_range(1.6, 3.4),
		})
	var stream: AudioStream = load(BUZZ_PATH) as AudioStream
	if stream != null:
		_sfx = AudioStreamPlayer2D.new()
		_sfx.stream = stream
		_sfx.volume_db = -9.0
		_sfx.max_distance = 900.0
		add_child(_sfx)
		_sfx.finished.connect(func() -> void: _gap_timer = BUZZ_GAP)
		_sfx.play()


func _process(delta: float) -> void:
	_t += delta
	if _sfx != null and not _sfx.playing:
		_gap_timer -= delta
		if _gap_timer <= 0.0:
			_sfx.play()
	queue_redraw()


func _bee_pos(b: Dictionary) -> Vector2:
	var theta: float = float(b["phase"]) + float(b["w"]) * _t + float(b["wob"]) * sin(_t * float(b["spd2"]) + float(b["phase2"]))
	var rr: float = _radius * float(b["r"]) * (1.0 + 0.12 * sin(_t * 1.7 + float(b["phase2"])))
	return Vector2(cos(theta) * rr, sin(theta) * rr * 0.86)


func _draw() -> void:
	## Alan sınırı + bal rengi çok hafif dolgu
	PixelDraw.ring(self, Vector2.ZERO, _radius, Color(1.0, 0.78, 0.2, 0.75), 1, 5, 2, _t * 8.0)
	PixelDraw.ring(self, Vector2.ZERO, _radius - 4.0, Color(1.0, 0.86, 0.35, 0.3), 1, 2, 5, -_t * 10.0)
	PixelDraw.disc_dither(self, Vector2.ZERO, _radius, Color(1.0, 0.8, 0.25, 0.07), 0, 3)
	## Arılar
	var wing_up: bool = int(_t * 16.0) % 2 == 0
	for b in _bees:
		var p: Vector2 = _bee_pos(b)
		var ahead: Vector2 = _bee_pos_at(b, 0.05) - p
		var face_right: bool = ahead.x >= 0.0
		var bob: float = sin(_t * 9.0 + float(b["phase"])) * 1.2
		var pos: Vector2 = p + Vector2(0, bob)
		## Yer gölgesi
		PixelDraw.px(self, p + Vector2(0, 9.0), 1, Color(0.05, 0.05, 0.02, 0.28))
		## Gövde (2 texel: sarı + siyah çizgi), baş yönde
		var dir: float = 1.0 if face_right else -1.0
		var tx: float = PixelDraw.TEXEL
		PixelDraw.px(self, pos, 2, C_YELLOW)
		PixelDraw.px(self, pos + Vector2(dir * tx * 1.5, 0), 1, C_BLACK)
		PixelDraw.px(self, pos + Vector2(dir * tx * 2.5, 0), 2, C_YELLOW_D)
		PixelDraw.px(self, pos + Vector2(dir * tx * 3.5, 0), 1, C_BLACK)
		PixelDraw.px(self, pos + Vector2(dir * tx * 4.5, 0), 1, C_BLACK) ## baş
		## Kanatlar (yukarıda, 2 kareli çırpma)
		var wy: float = -tx * (1.5 if wing_up else 2.5)
		PixelDraw.px(self, pos + Vector2(dir * tx * 0.5, wy), 1, C_WING)
		PixelDraw.px(self, pos + Vector2(dir * tx * 1.5, wy - (tx if wing_up else 0.0)), 1, C_WING)
		PixelDraw.px(self, pos + Vector2(dir * tx * 2.5, wy), 1, C_WING)


func _bee_pos_at(b: Dictionary, dt: float) -> Vector2:
	var t_save: float = _t
	_t += dt
	var p: Vector2 = _bee_pos(b)
	_t = t_save
	return p
