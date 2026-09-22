extends Node2D

## Kalkan "isabet" (bariyer hasar alma) efekti - PIXEL tarzı, MAVİ tonlarda, YARI SAYDAM.
## Kullanıcı geri bildirimi (2026-09-22): "kalkan hasar alma efektini beğenmedim, hasar alınca HAFİF ÇATLAMA ve BARİYER BALONCUĞU efekti
## çıkmalıydı" -> eski altıgen hücre/dalga/kırık tasarımı tamamen kaldırıldı. Yeni efekt (hepsi 1 texel pixel-art, bkz. pixel_draw.gd):
##   1. BARİYER BALONCUĞU: kalkanın tamamı bir an cam gibi belirir - dither dolgulu yarı saydam mavi küre + bütün kenar boyunca parlak
##      pixel halka; vuruş tarafı daha kalın/parlak (bariyer "yükleniyor" hissi), 0.35 sn'de söner
##   2. YÜZEY DALGASI: vuruş noktasından kalkan yüzeyi boyunca yayılan eşmerkezli yaylar (yalnızca baloncuğun içinde kalan kısım çizilir)
##   3. HAFİF ÇATLAMA: vuruş noktasından içeri doğru inen ince, dallanan, pixel kırık çizgileri - hızla büyür, kısa süre kalır, solar
##      (koyu mavi gölgeli beyaz-mavi kıl çatlaklar; "hafif" olsun diye 3 ana çatlak + birkaç dal)
##   4. Çarpma parlaması + birkaç minik kırıntı
## Hem KASTERİN kendi ekranında (player.gd _spawn_shield_hit_fx) hem uzak oyuncularda (network_manager.gd "shield_hit_flash" dalı) AYNI
## script - görünüm tek yerde, iki taraf sapamaz (bkz. proje kökündeki CLAUDE.md). Paladin bariyeri de aynı efekti kendi yarıçapıyla
## kullanır (bkz. setup'ın radius parametresi).

const PixelDraw := preload("res://scripts/pixel_draw.gd")

## Oyuncunun kalkan baloncuğunun görünen kenarı (ekranda ölçüldü, ~40 birim) - efekt baloncuk yüzeyine oturur.
const RADIUS := 40.0
const LIFE := 0.55
const BUBBLE_LIFE := 0.36 ## baloncuk parıltısının süresi
const CRACK_GROW := 0.13 ## çatlakların tam uzunluğa ulaşma süresi
const CRACK_HOLD := 0.30 ## bu andan sonra çatlaklar solmaya başlar

var impact_angle: float = 0.0
var _radius: float = RADIUS
var _t: float = 0.0
var _cracks: Array = [] ## her biri: PackedVector2Array (ana çatlak ya da dal, başlangıçtan uca sıralı)
var _shards: Array = [] ## [pos, vel]


## angle: karakterden vuran tarafa radyan. radius: bariyerin yarıçapı (varsayılan: oyuncu kalkan baloncuğu).
func setup(angle: float, radius: float = RADIUS) -> void:
	impact_angle = angle
	_radius = radius
	_build_cracks()
	var origin: Vector2 = Vector2.RIGHT.rotated(impact_angle) * _radius
	_shards.clear()
	for i in range(5):
		var a: float = impact_angle + PI + randf_range(-0.9, 0.9)
		_shards.append([origin, Vector2(cos(a), sin(a)) * randf_range(14.0, 42.0)])
	queue_redraw()


func _ready() -> void:
	z_index = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for s in _shards:
		s[0] = s[0] + s[1] * delta
		s[1] = s[1] * (1.0 - clampf(4.0 * delta, 0.0, 1.0))
	queue_redraw()


## Çatlak yolları: vuruş noktasından merkeze doğru inen 3 ana kıl çatlak + rastgele dallar. Adımlar ~3.5 texel, her adımda yön hafifçe sapar.
func _build_cracks() -> void:
	_cracks.clear()
	var t: float = PixelDraw.TEXEL
	var origin: Vector2 = Vector2.RIGHT.rotated(impact_angle) * _radius
	var inward: float = impact_angle + PI
	var offsets: Array = [-0.42, 0.02, 0.4]
	var lengths: Array = [0.62, 0.95, 0.58]
	for m in range(3):
		var path := PackedVector2Array([origin])
		var dir_a: float = inward + float(offsets[m]) + randf_range(-0.12, 0.12)
		var max_len: float = _radius * float(lengths[m])
		var travelled: float = 0.0
		var pos: Vector2 = origin
		var step_i: int = 0
		while travelled < max_len:
			dir_a += randf_range(-0.42, 0.42)
			var step: float = t * randf_range(2.6, 4.4)
			pos += Vector2(cos(dir_a), sin(dir_a)) * step
			travelled += step
			if pos.length() > _radius - 1.0:
				break
			path.append(pos)
			step_i += 1
			## dal: ana çatlağın yanından kısa bir kıl çatlak
			if step_i >= 2 and randf() < 0.42:
				var branch := PackedVector2Array([pos])
				var b_a: float = dir_a + (0.7 if randf() < 0.5 else -0.7) + randf_range(-0.25, 0.25)
				var bp: Vector2 = pos
				for k in range(randi_range(2, 4)):
					b_a += randf_range(-0.4, 0.4)
					bp += Vector2(cos(b_a), sin(b_a)) * t * randf_range(2.2, 3.6)
					if bp.length() > _radius - 1.0:
						break
					branch.append(bp)
				if branch.size() > 1:
					_cracks.append(branch)
		_cracks.append(path)
	## Yüzey boyunca (teğet) iki kısa çatlak - kalkanın "kabuğunda" çatlama hissi
	var tangent_a: float = impact_angle + PI * 0.5
	for sgn in [-1.0, 1.0]:
		var path2 := PackedVector2Array([origin])
		var p2: Vector2 = origin
		var a2: float = tangent_a if sgn > 0.0 else tangent_a + PI
		for k in range(randi_range(3, 5)):
			a2 += randf_range(-0.3, 0.3) + (0.06 if sgn > 0.0 else -0.06)
			p2 += Vector2(cos(a2), sin(a2)) * t * randf_range(2.4, 3.8)
			p2 = p2.normalized() * minf(p2.length(), _radius - 1.5)
			path2.append(p2)
		_cracks.append(path2)


func _draw() -> void:
	var t: float = PixelDraw.TEXEL
	var k: float = _t / LIFE
	var origin: Vector2 = Vector2.RIGHT.rotated(impact_angle) * _radius
	var bub: float = clampf(1.0 - _t / BUBBLE_LIFE, 0.0, 1.0) ## baloncuk parıltısı (hızlı söner)
	## --- 1. BARİYER BALONCUĞU: yarı saydam mavi dither küre + bütün kenar halkası (vuruş tarafı kalın/parlak) ---
	if bub > 0.0:
		var pop: float = 1.0 + 0.045 * sin(minf(_t / 0.08, 1.0) * PI) ## ilk anda küçük bir "şişme"
		var rr: float = _radius * pop
		PixelDraw.disc_dither(self, Vector2.ZERO, rr - t, Color(0.42, 0.72, 1.0, 0.26 * bub), int(_t * 30.0), 2)
		PixelDraw.ring(self, Vector2.ZERO, rr, Color(0.62, 0.86, 1.0, 0.78 * bub), 1)
		PixelDraw.ring(self, Vector2.ZERO, rr - 2.0 * t, Color(0.4, 0.68, 1.0, 0.32 * bub), 1, 2, 3, _t * 25.0)
		var arc_half: float = deg_to_rad(38.0)
		PixelDraw.ring(self, Vector2.ZERO, rr + t, Color(0.86, 0.96, 1.0, 0.85 * bub), 1, 0, 0, 0.0, impact_angle - arc_half, arc_half * 2.0)
		PixelDraw.ring(self, Vector2.ZERO, rr - t, Color(0.86, 0.96, 1.0, 0.6 * bub), 1, 0, 0, 0.0, impact_angle - arc_half * 0.7, arc_half * 1.4)
	## --- 2. YÜZEY DALGASI: vuruş noktasından yayılan, yalnızca baloncuk içinde kalan eşmerkezli yaylar ---
	for ring_i in range(3):
		var delay: float = 0.03 * float(ring_i)
		var lk: float = clampf((_t - delay) / (0.34 - delay), 0.0, 1.0)
		if lk <= 0.0 or lk >= 1.0:
			continue
		var rad: float = t * (3.0 + 22.0 * lk)
		var n: int = maxi(12, int(TAU * rad / t))
		var wcol := Color(0.7, 0.9, 1.0, 0.6 * (1.0 - lk))
		for i in range(n):
			var a: float = TAU * float(i) / float(n)
			var p: Vector2 = origin + Vector2(cos(a), sin(a)) * rad
			if p.length() <= _radius - t:
				PixelDraw.px(self, p, 1, wcol)
	## --- 3. HAFİF ÇATLAMA: büyüyen, sonra solan ince pixel çatlaklar (koyu mavi gölge + beyaz-mavi çekirdek) ---
	var grow: float = clampf(_t / CRACK_GROW, 0.0, 1.0)
	var fade: float = 1.0 - clampf((_t - CRACK_HOLD) / (LIFE - CRACK_HOLD), 0.0, 1.0)
	if fade > 0.0:
		for path in _cracks:
			var pts: PackedVector2Array = path
			var visible_pts: int = maxi(2, int(ceil(float(pts.size()) * grow)))
			for i in range(mini(visible_pts, pts.size()) - 1):
				var a2: Vector2 = pts[i]
				var b2: Vector2 = pts[i + 1]
				var depth: float = float(i) / float(maxi(pts.size() - 1, 1))
				var ca: float = fade * (1.0 - depth * 0.55)
				PixelDraw.line(self, a2 + Vector2(t, t), b2 + Vector2(t, t), Color(0.18, 0.36, 0.78, 0.55 * ca), 1)
				PixelDraw.line(self, a2, b2, Color(0.9, 0.97, 1.0, 0.92 * ca), 1)
	## --- 4. Çarpma parlaması + kırıntılar ---
	if _t < 0.1:
		var fk: float = 1.0 - _t / 0.1
		PixelDraw.px(self, origin, 3, Color(1, 1, 1, 0.9 * fk))
		for d4 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			PixelDraw.px(self, origin + d4 * t * 3.0, 1, Color(0.85, 0.96, 1.0, 0.8 * fk))
			PixelDraw.px(self, origin + d4 * t * 5.0, 1, Color(0.6, 0.85, 1.0, 0.5 * fk))
	for s in _shards:
		PixelDraw.px(self, s[0], 1, Color(0.85, 0.96, 1.0, 0.8 * (1.0 - k)))
