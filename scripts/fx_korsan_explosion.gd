extends Node2D

## Korsan'ın patlaması (Patlat/Q bomba patlamaları + Bombardıman/R mermi patlamaları): sıfırdan pixel-art.
## Katmanlar (hepsi pixel_draw.gd sanat-piksel ızgarasında, gerçek alfa yerine dither/kademeli küçülme):
##   1) yerde kararan yanık izi (dither)   2) beyaz-sarı parlama + yıldız ışınları (ilk 0.09sn)
##   3) kaynayan ateş topu: kırmızı > turuncu > sarı > beyaz çekirdek, lob'lu (yuvarlak DEĞİL, pixel bulut)
##   4) genişleyen pixel şok halkası    5) dışa saçılan kor/enkaz kareleri    6) yükselen koyu duman
## setup(radius, color): görsel patlama yarıçapı (bomba = hasar yarıçapı, mermi = STRIKE_RADIUS). _ready setup'tan ÖNCE
## çalıştığı için parçacık verisi birim yarıçapa göre üretilir, çizimde blast_radius ile ölçeklenir.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SOUND_EXPLOSION: AudioStream = preload("res://assets/audio/fire_staff_explosion.mp3")

const LIFE := 0.85
const LOBES := 6

var blast_radius: float = 150.0
var tint: Color = Color(1.0, 0.6, 0.2)

var _t: float = 0.0
var _debris: Array = [] ## [angle, speed(0.6..1.3), size, color_t]
var _smoke: Array = [] ## [angle, dist(0..0.6), size, delay]
var _lobe_phase: Array = []

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sound: AudioStreamPlayer2D = get_node_or_null("Sound")


func setup(radius: float, color: Color = Color(1.0, 0.6, 0.2)) -> void:
	blast_radius = clampf(radius, 30.0, 320.0)
	tint = color


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 12
	if sprite:
		sprite.visible = false ## eski sprite-sheet patlaması artık çizilmiyor
	if sound:
		sound.stream = SOUND_EXPLOSION
		sound.pitch_scale = randf_range(0.9, 1.1)
		sound.play()
	for i in range(16):
		_debris.append([randf() * TAU, randf_range(0.6, 1.3), randi_range(1, 3), randf()])
	for i in range(8):
		_smoke.append([randf() * TAU, randf_range(0.0, 0.55), randf_range(0.14, 0.24), randf_range(0.12, 0.3)])
	for i in range(LOBES):
		_lobe_phase.append(randf() * TAU)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _ease_out(x: float) -> float:
	var k: float = clampf(x, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


func _draw() -> void:
	var r: float = blast_radius
	var t: float = _t
	## 1) Yanık iz - dither, ömür boyunca yavaş kaybolur (yerde).
	var scorch_r: float = r * 0.6 * _ease_out(t / 0.15)
	if t < LIFE * 0.85:
		PixelDraw.disc_dither(self, Vector2.ZERO, scorch_r, Color(0.03, 0.02, 0.02, 0.6), int(t * 6.0) if t > LIFE * 0.6 else 0, 2)
	## 2) Parlama + yıldız ışınları
	if t < 0.09:
		PixelDraw.disc(self, Vector2.ZERO, r * 0.3, Color(1.0, 0.97, 0.8))
		for k in range(8):
			var a: float = float(k) * TAU / 8.0
			PixelDraw.line(self, Vector2(cos(a), sin(a)) * r * 0.2, Vector2(cos(a), sin(a)) * r * 0.55, Color(1.0, 0.9, 0.5), 2 if k % 2 == 0 else 1)
	## 3) Ateş topu: büyür (0.22sn), kısa süre durur, sonra küçülüp söner
	var grow: float = _ease_out(t / 0.22)
	var fade: float = 1.0 - clampf((t - 0.3) / 0.3, 0.0, 1.0)
	var r_f: float = r * 0.58 * grow * fade
	if r_f > 3.0:
		var layers: Array = [[1.0, PixelDraw.fire_color(0.72)], [0.78, PixelDraw.fire_color(0.5)], [0.55, PixelDraw.fire_color(0.28)], [0.3, PixelDraw.fire_color(0.02)]]
		for layer in layers:
			var sc: float = float(layer[0])
			var col: Color = layer[1]
			PixelDraw.disc(self, Vector2.ZERO, r_f * 0.7 * sc, col)
			for i in range(LOBES):
				var a2: float = float(i) * TAU / float(LOBES) + sin(t * 8.0 + float(_lobe_phase[i])) * 0.25
				var wob: float = 0.5 + 0.08 * sin(t * 14.0 + float(_lobe_phase[i]) * 2.0)
				PixelDraw.disc(self, Vector2(cos(a2), sin(a2)) * r_f * wob * sc, r_f * 0.42 * sc, col)
	## 4) Şok halkası
	var ring_k: float = t / 0.38
	if ring_k < 1.0:
		var ring_r: float = r * _ease_out(ring_k)
		var dash_off: int = int(ring_k * 14.0)
		PixelDraw.ring(self, Vector2.ZERO, ring_r, PixelDraw.fire_color(0.05 + ring_k * 0.5), 2, 6, dash_off, t * 20.0)
	## 5) Kor / enkaz kareleri
	for d in _debris:
		var dk: float = clampf(t / 0.55, 0.0, 1.0)
		if dk >= 1.0:
			continue
		var dist: float = r * float(d[1]) * (0.15 + 0.95 * _ease_out(dk))
		var pos := Vector2(cos(float(d[0])), sin(float(d[0]))) * dist
		var sz: int = int(d[2]) if dk < 0.6 else maxi(int(d[2]) - 1, 1)
		PixelDraw.px(self, pos, sz, PixelDraw.fire_color(0.05 + dk * 0.9))
	## 6) Duman: ateş söndükten sonra yükselen gri kümeler - baştan sona dither (yarı saydam his), açılırken yavaşça dağılır
	for s in _smoke:
		var st: float = t - 0.15 - float(s[3])
		if st <= 0.0:
			continue
		var sk: float = clampf(st / (LIFE - 0.3), 0.0, 1.0)
		var sp := Vector2(cos(float(s[0])), sin(float(s[0]))) * r * float(s[1]) * 0.7 + Vector2(0, -r * 0.35 * sk)
		var sr: float = r * float(s[2]) * 0.75 * (0.6 + sk * 0.9)
		var par: int = int(t * 10.0) + int(s[0] * 3.0)
		PixelDraw.disc_dither(self, sp, sr, Color(0.3, 0.29, 0.33) if sk < 0.5 else Color(0.38, 0.37, 0.41), par, 2)
		if sk < 0.6:
			PixelDraw.disc_dither(self, sp + Vector2(-sr * 0.2, -sr * 0.2), sr * 0.55, Color(0.16, 0.15, 0.18), par + 1, 2)
