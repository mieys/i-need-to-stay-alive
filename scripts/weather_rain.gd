extends Node2D

## Yağmurlu hava görseli (kullanıcı isteği 2026-09-25: "hava durumlarını pixel tarzda cozy bir biçimde tasarla,
## yağmurlar yere damlacık parçacıkları bırakacak"). atmosphere.gd'nin çocuğu; şiddeti (0..1) her karede set_intensity()
## ile gelir (yağmur 9 sn'de yumuşakça başlar/biter).
##
## DÜNYA uzayında çizilir (ekrana yapışık bir kaplama DEĞİL): damla, kameranın gördüğü alanda rastgele bir YER noktası
## seçer ve o noktanın biraz yukarısından hafif eğik düşer; yere değince 2 minik sıçrayan damlacık + (bazılarında)
## genişleyen bir su halkası bırakır. Kamera yürürken damlalar dünyada kalır (haritaya yapışık), gece renk geçişi ve sis
## onları da diğer her şey gibi karartır.
##
## Piksel dili: 1 dünya birimi = harita karolarının 1 pikseli (1080p'de 2 ekran pikseli). Damla 1 birim kalınlığında,
## 4-7 birim boyunda bir çizgi; damlacıklar/halka tek piksel noktalar. PERF: parçacık başına Node YOK - tüm damlalar
## TEK draw_multiline çağrısı, sıçramalar birkaç yüz draw_rect (fx_particle_trail.gd ile aynı "tek düğüm" deseni).
## PERF DÜZELTMESİ (kullanıcı bildirimi 2026-09-25: "oyundaki hava durumları fpsi düşürüyor gibi görünüyor"): damla
## başları, sıçramalar ve halka noktaları eskiden TEK TEK draw_rect'ti (sağanakta ve geniş görüşte karede 1500+ komut).
## Artık hepsi 1 birimlik çizgi parçaları olarak TEK draw_multiline_colors çağrısında - görünüm aynı, 2 çizim komutu.
## SAĞANAK: set_intensity'nin storm (0..1) parametresi damlaları daha eğik (rüzgar) ve daha hızlı düşürür.

const MAX_DROPS := 170 ## şiddet 1'de, 1920x1080 görünümde (960x540 dünya birimi) aynı anda düşen damla
const REFERENCE_AREA := 960.0 * 540.0
const DROP_MIN_HEIGHT := 60.0
const DROP_MAX_HEIGHT := 150.0
const DROP_MIN_SPEED := 330.0
const DROP_MAX_SPEED := 430.0
const DROP_MIN_LEN := 4.0
const DROP_MAX_LEN := 7.0
## Eğim: düşülen her birimde yatayda bu kadar kayar (işareti her yağmurda rüzgar yönüne göre değişir).
const SLANT := 0.2
## Yere değen damlaların bu kadarı sıçrama bırakır (hepsi bırakırsa ekran kaynıyor ve pahalı).
const SPLASH_CHANCE := 0.45
const RIPPLE_CHANCE := 0.4
const SPLASH_LIFE := 0.22
const SPLASH_GRAVITY := 260.0
const RIPPLE_LIFE := 0.38
const RIPPLE_MAX_RADIUS := 4.5
const VIEW_MARGIN := 40.0
const STORM_SLANT := 0.55
const STORM_SPEED_MULT := 1.35

const DROP_COLOR := Color(0.74, 0.84, 1.0, 0.5)
const DROP_HEAD_COLOR := Color(0.86, 0.93, 1.0, 0.7)
const SPLASH_COLOR := Color(0.82, 0.9, 1.0, 0.75)
const RIPPLE_COLOR := Color(0.8, 0.9, 1.0, 0.4)

var intensity: float = 0.0
var slant_sign: float = 1.0
var storm: float = 0.0
var _slant: float = SLANT

var _ground := PackedVector2Array() ## damlanın düşeceği yer noktası
var _height := PackedFloat32Array() ## yerden yükseklik (0'a inince çarpar)
var _speed := PackedFloat32Array()
var _len := PackedFloat32Array()
var _splash_pos := PackedVector2Array()
var _splash_vel := PackedVector2Array()
var _splash_age := PackedFloat32Array()
var _ripple_pos := PackedVector2Array()
var _ripple_age := PackedFloat32Array()
var _view := Rect2()
var _lines := PackedVector2Array()
var _dots := PackedVector2Array()
var _dot_cols := PackedColorArray()


func _ready() -> void:
	z_index = 100 ## dünyadaki her şeyin (karakter, FX z 60) üstünde - HUD ayrı CanvasLayer, etkilenmez
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Sağanakta (atmosphere.gd STORM_RAIN_DENSITY) 1'in üstüne çıkar: daha çok damla (MAX_DROPS x şiddet).
func set_intensity(value: float, p_slant_sign: float, p_storm: float = 0.0) -> void:
	intensity = clampf(value, 0.0, 1.6)
	slant_sign = 1.0 if p_slant_sign >= 0.0 else -1.0
	storm = clampf(p_storm, 0.0, 1.0)
	_slant = lerpf(SLANT, STORM_SLANT, storm)


func _process(delta: float) -> void:
	if intensity <= 0.001 and _ground.is_empty() and _splash_age.is_empty() and _ripple_age.is_empty():
		if visible:
			visible = false
		return
	visible = true
	_view = _visible_world_rect()
	var target: int = int(round(MAX_DROPS * intensity * clampf(_view.get_area() / REFERENCE_AREA, 0.5, 2.5)))
	_update_drops(delta, target)
	_update_splashes(delta)
	## Şiddet artarken eksik damlalar bir anda "duvar" gibi belirmesin: kare başına sınırlı sayıda yeni damla.
	var spawn_budget: int = maxi(2, int(target * delta * 3.0))
	while _ground.size() < target and spawn_budget > 0:
		_spawn_drop(true)
		spawn_budget -= 1
	queue_redraw()


func _visible_world_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	var size: Vector2 = vp.get_visible_rect().size
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * size
	var r := Rect2(a, b - a).abs()
	## Damlalar yer noktasının YUKARISINDAN düştüğü için alanın altı biraz fazladan kapsanır (ekranın alt kenarından
	## düşen damla da görünür), üstü ise çok az.
	return r.grow_individual(VIEW_MARGIN, VIEW_MARGIN * 0.5, VIEW_MARGIN, DROP_MAX_HEIGHT)


func _spawn_drop(random_height: bool) -> void:
	var g := Vector2(randf_range(_view.position.x, _view.end.x), randf_range(_view.position.y, _view.end.y)).floor()
	_ground.append(g)
	_height.append(randf_range(DROP_MIN_HEIGHT, DROP_MAX_HEIGHT) * (randf_range(0.2, 1.0) if random_height else 1.0))
	_speed.append(randf_range(DROP_MIN_SPEED, DROP_MAX_SPEED) * lerpf(1.0, STORM_SPEED_MULT, storm))
	_len.append(randf_range(DROP_MIN_LEN, DROP_MAX_LEN))


func _update_drops(delta: float, target: int) -> void:
	var expanded: Rect2 = _view.grow(60.0)
	var i: int = _ground.size() - 1
	while i >= 0:
		var h: float = _height[i] - _speed[i] * delta
		var g: Vector2 = _ground[i]
		if h <= 0.0:
			if randf() < SPLASH_CHANCE:
				_spawn_splash(g)
			if _ground.size() > target:
				_remove_drop(i)
			else:
				## Aynı damlayı yeni bir yere, tepeden tekrar düşür (dizi büyümeden döngü).
				_ground[i] = Vector2(randf_range(_view.position.x, _view.end.x), randf_range(_view.position.y, _view.end.y)).floor()
				_height[i] = randf_range(DROP_MIN_HEIGHT, DROP_MAX_HEIGHT)
		elif not expanded.has_point(g):
			## Kamera hızla uzaklaştı - görünmeyen damlayı görünür alana taşı.
			if _ground.size() > target:
				_remove_drop(i)
			else:
				_ground[i] = Vector2(randf_range(_view.position.x, _view.end.x), randf_range(_view.position.y, _view.end.y)).floor()
				_height[i] = h
		else:
			_height[i] = h
		i -= 1


func _remove_drop(i: int) -> void:
	_ground.remove_at(i)
	_height.remove_at(i)
	_speed.remove_at(i)
	_len.remove_at(i)


func _spawn_splash(g: Vector2) -> void:
	for side in [-1.0, 1.0]:
		_splash_pos.append(g + Vector2(side * 0.5, -0.5))
		_splash_vel.append(Vector2(side * randf_range(18.0, 38.0), -randf_range(32.0, 52.0)))
		_splash_age.append(0.0)
	if randf() < RIPPLE_CHANCE:
		_ripple_pos.append(g)
		_ripple_age.append(0.0)


func _update_splashes(delta: float) -> void:
	var i: int = _splash_age.size() - 1
	while i >= 0:
		var age: float = _splash_age[i] + delta
		if age >= SPLASH_LIFE:
			_splash_pos.remove_at(i)
			_splash_vel.remove_at(i)
			_splash_age.remove_at(i)
		else:
			var v: Vector2 = _splash_vel[i]
			v.y += SPLASH_GRAVITY * delta
			_splash_vel[i] = v
			_splash_pos[i] = _splash_pos[i] + v * delta
			_splash_age[i] = age
		i -= 1
	var j: int = _ripple_age.size() - 1
	while j >= 0:
		var rage: float = _ripple_age[j] + delta
		if rage >= RIPPLE_LIFE:
			_ripple_pos.remove_at(j)
			_ripple_age.remove_at(j)
		else:
			_ripple_age[j] = rage
		j -= 1


func _dot(p: Vector2, c: Color) -> void:
	_dots.append(Vector2(p.x, p.y + 0.5))
	_dots.append(Vector2(p.x + 1.0, p.y + 0.5))
	_dot_cols.append(c)


func _draw() -> void:
	var n: int = _ground.size()
	var dir := Vector2(_slant * slant_sign, 1.0).normalized()
	_lines.resize(n * 2)
	_dots.clear()
	_dot_cols.clear()
	for i in range(n):
		var h: float = _height[i]
		## Damlanın alt ucu: yer noktasının h yukarısında, eğim yönünün TERSİNE kaymış (eğik düşüp tam noktaya varır).
		var tip: Vector2 = (_ground[i] + Vector2(-_slant * slant_sign * h, -h)).floor()
		var tip_c: Vector2 = tip + Vector2(0.5, 0.5)
		_lines[i * 2] = tip_c - dir * _len[i]
		_lines[i * 2 + 1] = tip_c
		## Parlak damla başı (alt uç) - tek piksel.
		_dot(tip, DROP_HEAD_COLOR)
	if n > 0:
		draw_multiline(_lines, DROP_COLOR, 1.0)
	for i in range(_splash_age.size()):
		var c: Color = SPLASH_COLOR
		c.a *= 1.0 - _splash_age[i] / SPLASH_LIFE
		_dot(_splash_pos[i].floor(), c)
	## Su halkası: yatay yassı (üstten görünüm) elips, 8 piksel nokta, genişlerken söner.
	for j in range(_ripple_age.size()):
		var k: float = _ripple_age[j] / RIPPLE_LIFE
		var r: float = lerpf(1.0, RIPPLE_MAX_RADIUS, k)
		var rc: Color = RIPPLE_COLOR
		rc.a *= 1.0 - k
		var center: Vector2 = _ripple_pos[j]
		for s in range(8):
			var ang: float = float(s) * TAU / 8.0
			_dot((center + Vector2(cos(ang) * r, sin(ang) * r * 0.45)).floor(), rc)
	if not _dot_cols.is_empty():
		draw_multiline_colors(_dots, _dot_cols, 1.0)
