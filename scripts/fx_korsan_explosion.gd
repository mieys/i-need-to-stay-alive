extends Node2D

## Korsan'ın patlaması (Patlat/Q bomba patlamaları + Bombardıman/R mermi patlamaları) - PIXEL tarzı, YENİDEN
## TASARLANDI (kullanıcı isteği 2026-09-22: "Korsanın patlamalarını beğenmedim, pixel tarzda yeniden tasarla").
## Eski versiyonun iki sorunu vardı: (1) ateş topu "lobe" adı verilen sinüs sallanmasıyla yumuşak bir ÇİÇEK gibi
## görünüyordu, pixel-art hissi vermiyordu; (2) yanık izi/duman disc_dither() ile büyük (cell=2) bir DAMA/KARE
## deseniyle çiziliyordu - küçük efektlerde (kalkan baloncuğu, totem) fark edilmeyen bu desen, patlamanın büyük
## yarıçapında koca, çirkin bir satranç tahtası gibi görünüyordu ("kare kare" şikayeti buradan). Yeni tasarım HİÇ
## disc_dither KULLANMAZ, hepsi düz alfa ile:
##   1) yerde SERT kenarlı ama DÜZENSİZ (birkaç iç içe geçmiş disk) kararmış krater izi - kalıcı, yavaş solar
##   2) beyaz-sarı ilk parlama + 8 yıldız ışını
##   3) ATEŞ TOPU: düz eşmerkezli halkalar (kor/turuncu/sarı/beyaz, sallanma YOK) + etrafında SABİT profilli
##      (rastgele ama efekt boyunca DEĞİŞMEYEN) diken/alev dilleri - gerçek patlama sprite'ları gibi pürüzlü silüet
##   4) genişleyen sert pixel şok halkası
##   5) dışa saçılan kor/enkaz kareleri
##   6) yükselen duman: dama dolgusu YERİNE birkaç örtüşen düz disk'ten oluşan PUF bulutu kümeleri (düz alfa,
##      iki tonlu - gerçek "cumulus" siluet)
## setup(radius, color): görsel patlama yarıçapı (bomba = hasar yarıçapı, mermi = STRIKE_RADIUS). _ready setup'tan
## ÖNCE çalıştığı için parçacık verisi birim yarıçapa göre üretilir, çizimde blast_radius ile ölçeklenir.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const SOUND_EXPLOSION: AudioStream = preload("res://assets/audio/fire_staff_explosion.mp3")

const LIFE := 0.8
const SPIKE_COUNT := 14
const SMOKE_LUMPS: Array = [Vector2(0, 0), Vector2(0.55, 0.12), Vector2(-0.5, 0.18), Vector2(0.08, -0.42), Vector2(-0.15, 0.4)]

var blast_radius: float = 150.0
var tint: Color = Color(1.0, 0.6, 0.2)

var _t: float = 0.0
var _debris: Array = [] ## [angle, speed(0.6..1.3), size, color_t]
var _smoke: Array = [] ## [angle, dist(0..0.55), size, delay, lump_scale(0.75..1.15)]
var _spikes: Array = [] ## [angle, len_mult, flicker_seed]
var _scorch_blobs: Array = [] ## [offset_fraction(Vector2), radius_fraction]

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
		_smoke.append([randf() * TAU, randf_range(0.0, 0.55), randf_range(0.14, 0.24), randf_range(0.12, 0.3), randf_range(0.75, 1.15)])
	for i in range(SPIKE_COUNT):
		_spikes.append([float(i) * TAU / float(SPIKE_COUNT) + randf_range(-0.16, 0.16), randf_range(0.55, 1.35), randf() * TAU])
	for i in range(5):
		var a: float = randf() * TAU
		_scorch_blobs.append([Vector2(cos(a), sin(a)) * randf_range(0.0, 0.22), randf_range(0.42, 0.62)])


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
	## 1) Yanık iz - birkaç örtüşen düz disk (sert kenar, DAMA YOK), ömür boyunca yavaş kaybolur.
	var scorch_grow: float = _ease_out(t / 0.15)
	var scorch_fade: float = 1.0 - clampf((t - LIFE * 0.6) / (LIFE * 0.4), 0.0, 1.0)
	if scorch_fade > 0.0:
		for blob in _scorch_blobs:
			var off: Vector2 = (blob[0] as Vector2) * r * scorch_grow
			PixelDraw.disc(self, off, r * float(blob[1]) * scorch_grow, Color(0.03, 0.02, 0.02, 0.4 * scorch_fade))
	## 2) Parlama + yıldız ışınları
	if t < 0.09:
		PixelDraw.disc(self, Vector2.ZERO, r * 0.3, Color(1.0, 0.97, 0.8))
		for k in range(8):
			var a: float = float(k) * TAU / 8.0
			PixelDraw.line(self, Vector2(cos(a), sin(a)) * r * 0.2, Vector2(cos(a), sin(a)) * r * 0.55, Color(1.0, 0.9, 0.5), 2 if k % 2 == 0 else 1)
	## 3) Ateş topu: büyür (0.22sn), kısa süre durur, sonra küçülüp söner. Sallanma YOK - düz eşmerkezli halkalar.
	var grow: float = _ease_out(t / 0.22)
	var fade: float = 1.0 - clampf((t - 0.3) / 0.3, 0.0, 1.0)
	var r_f: float = r * 0.5 * grow * fade
	if r_f > 3.0:
		PixelDraw.disc(self, Vector2.ZERO, r_f, PixelDraw.fire_color(0.72))
		PixelDraw.disc(self, Vector2.ZERO, r_f * 0.74, PixelDraw.fire_color(0.5))
		PixelDraw.disc(self, Vector2.ZERO, r_f * 0.5, PixelDraw.fire_color(0.26))
		PixelDraw.disc(self, Vector2.ZERO, r_f * 0.26, PixelDraw.fire_color(0.02))
		## Sabit profilli diken/alev dilleri - patlama boyunca AYNI açı/uzunlukta (yalnızca boyu grow/fade ile
		## değişir), böylece "sallanan çiçek" değil "pürüzlü/dikenli" bir silüet okunur.
		for sp in _spikes:
			var ang: float = float(sp[0])
			var len_mult: float = float(sp[1])
			var flicker: float = 0.85 + 0.15 * sin(t * 26.0 + float(sp[2]))
			var spike_len: float = r_f * len_mult * 0.55 * flicker
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			var steps: int = maxi(1, int(spike_len / PixelDraw.TEXEL))
			for s in range(steps):
				var f: float = float(s) / float(steps)
				var pos: Vector2 = dir * (r_f * 0.72 + f * spike_len)
				var sz: int = 2 if f < 0.5 else 1
				PixelDraw.px(self, pos, sz, PixelDraw.fire_color(0.1 + f * 0.75))
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
		var pos2 := Vector2(cos(float(d[0])), sin(float(d[0]))) * dist
		var sz2: int = int(d[2]) if dk < 0.6 else maxi(int(d[2]) - 1, 1)
		PixelDraw.px(self, pos2, sz2, PixelDraw.fire_color(0.05 + dk * 0.9))
	## 6) Duman: dama dolgusu YERİNE her puf birkaç örtüşen düz diskten oluşan bir küme (düz alfa, iki ton) -
	## gerçek pixel-art "cumulus" siluet, çirkin dama deseni yok.
	for s3 in _smoke:
		var st: float = t - 0.15 - float(s3[3])
		if st <= 0.0:
			continue
		var sk: float = clampf(st / (LIFE - 0.3), 0.0, 1.0)
		var sp3: Vector2 = Vector2(cos(float(s3[0])), sin(float(s3[0]))) * r * float(s3[1]) * 0.7 + Vector2(0, -r * 0.35 * sk)
		var sr: float = r * float(s3[2]) * float(s3[4]) * (0.6 + sk * 0.9)
		var puff_alpha: float = (0.55 if sk < 0.5 else 0.55 * (1.0 - (sk - 0.5) / 0.5))
		var base_col := Color(0.32, 0.31, 0.35, puff_alpha)
		var top_col := Color(0.42, 0.41, 0.46, puff_alpha * 0.9)
		for li in range(SMOKE_LUMPS.size()):
			var lump: Vector2 = SMOKE_LUMPS[li] as Vector2
			var lr: float = sr * (0.62 if li > 0 else 0.78)
			PixelDraw.disc(self, sp3 + lump * sr, lr, base_col if li % 2 == 0 else top_col)
