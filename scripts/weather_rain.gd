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
## 4-7 birim boyunda bir çizgi; damlacıklar/halka tek piksel noktalar.
## SAĞANAK: set_intensity'nin storm (0..1) parametresi damlaları daha eğik (rüzgar) ve daha hızlı düşürür.
##
## FPS (2026-10-18, ölçüm: sağanakta GDScript _process + _draw döngüleri ~1,2-1,5 ms/kare; 170 x 1,6 damla + yüzlerce sıçrama noktası + halka):
## animasyon GPU'ya taşındı. Damla yüksekliği, sıçrama ve halka konumları kareden kareye CPU'da değil shaders/weather_rain.gdshader'da `clock`
## uniform'uyla hesaplanır (3 MultiMesh: damla, sıçrama, halka; çizim eski _draw ile aynı geometri/renk/piksel ızgarası). CPU sadece (a) yere değen
## damlayı bulup yeniden doğurur (inişin zamanı doğuşta bilinir: t0 + yükseklik/hız), (b) görüş alanından çıkanı taşır, (c) sıçrama/halka doğurur
## (halka tamponuna 2 çağrı). Her şey (hız, boy, yükseklik, eğim, sıçrama/halka olasılığı, ömürler, renkler) eskisiyle aynı.

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
## Yere değen damlaların bu kadarı sıçrama bırakır (hepsi bırakırsa ekran kaynıyor).
const SPLASH_CHANCE := 0.45
const RIPPLE_CHANCE := 0.4
const SPLASH_LIFE := 0.22 ## shader'daki SPLASH_LIFE ile aynı
const SPLASH_GRAVITY := 260.0 ## shader'daki SPLASH_GRAVITY ile aynı
const RIPPLE_LIFE := 0.38 ## shader'daki RIPPLE_LIFE ile aynı
const RIPPLE_MAX_RADIUS := 4.5 ## shader'daki RIPPLE_MAX_RADIUS ile aynı
const VIEW_MARGIN := 40.0
const STORM_SLANT := 0.55
const STORM_SPEED_MULT := 1.35

const DROP_COLOR := Color(0.74, 0.84, 1.0, 0.5)
const DROP_HEAD_COLOR := Color(0.86, 0.93, 1.0, 0.7)
const SPLASH_COLOR := Color(0.82, 0.9, 1.0, 0.75)
const RIPPLE_COLOR := Color(0.8, 0.9, 1.0, 0.4)

## Kapasiteler: damla = MAX_DROPS x en yüksek şiddet (sağanak 1,6) x en büyük alan çarpanı (2,5) = 680; sıçrama/halka tamponları dönüşümlü (aşan en eskiyi ezer).
const DROP_CAP := 720
const SPLASH_CAP := 480
const RIPPLE_CAP := 360
const DEAD_TIME := -1000.0 ## kullanılmamış tampon örneği: yaşı hep ömründen büyük -> shader gizler

const RainShader := preload("res://shaders/weather_rain.gdshader")

var intensity: float = 0.0
var slant_sign: float = 1.0
var storm: float = 0.0
var _slant: float = SLANT

var _clock: float = 0.0
var _n: int = 0 ## etkin damla sayısı (diziler DROP_CAP boyunda sabit)
var _ground := PackedVector2Array() ## damlanın düşeceği yer noktası
var _speed := PackedFloat32Array()
var _len := PackedFloat32Array()
var _h0 := PackedFloat32Array() ## _t0 anındaki yerden yükseklik
var _t0 := PackedFloat32Array()
var _land := PackedFloat32Array() ## yere değeceği saat (_t0 + _h0 / _speed)
var _view := Rect2()

var _drops_mm: MultiMesh = null
var _splash_mm: MultiMesh = null
var _ripple_mm: MultiMesh = null
var _mats: Array[ShaderMaterial] = []
var _splash_next: int = 0
var _ripple_next: int = 0
var _splash_last: float = -1000.0 ## son sıçrama/halka doğuş saati (düğüm gizlenebilir mi?)
var _ripple_last: float = -1000.0


func _ready() -> void:
	z_index = 100 ## dünyadaki her şeyin (karakter, FX z 60) üstünde - HUD ayrı CanvasLayer, etkilenmez
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground.resize(DROP_CAP)
	_speed.resize(DROP_CAP)
	_len.resize(DROP_CAP)
	_h0.resize(DROP_CAP)
	_t0.resize(DROP_CAP)
	_land.resize(DROP_CAP)
	_drops_mm = _make_multimesh(0, DROP_CAP)
	_splash_mm = _make_multimesh(1, SPLASH_CAP)
	_ripple_mm = _make_multimesh(2, RIPPLE_CAP)
	_drops_mm.visible_instance_count = 0
	var dead := Color(DEAD_TIME, 0.0, 0.0, 0.0)
	for i in range(SPLASH_CAP):
		_splash_mm.set_instance_custom_data(i, dead)
	for i in range(RIPPLE_CAP):
		_ripple_mm.set_instance_custom_data(i, dead)
	_push_slant()


## kind: 0 damla (çizgi + baş noktası), 1 sıçrama (iki nokta), 2 halka (sekiz nokta). Köşe UV.x = ilkel etiketi (shader okur).
func _make_multimesh(kind: int, capacity: int) -> MultiMesh:
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var quads: Array = []
	match kind:
		0:
			quads.append([Rect2(0.0, -1.0, 1.0, 2.0), 0.0]) ## çizgi: x 0..1 (kuyruk -> uç), y -1..+1 (kalınlık yönü)
			quads.append([Rect2(0.0, 0.0, 1.0, 1.0), 1.0]) ## baş noktası 1x1
		1:
			quads.append([Rect2(0.0, 0.0, 1.0, 1.0), 0.0]) ## sol sıçrama noktası
			quads.append([Rect2(0.0, 0.0, 1.0, 1.0), 1.0]) ## sağ sıçrama noktası
		_:
			for s in range(8):
				quads.append([Rect2(0.0, 0.0, 1.0, 1.0), float(s) / 8.0]) ## halka noktaları
	for q in quads:
		var r: Rect2 = q[0]
		var base: int = verts.size()
		verts.append(r.position)
		verts.append(Vector2(r.end.x, r.position.y))
		verts.append(r.end)
		verts.append(Vector2(r.position.x, r.end.y))
		for k in range(4):
			uvs.append(Vector2(float(q[1]), 0.0))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.custom_aabb = AABB(Vector3(-1.0e6, -1.0e6, -1.0), Vector3(2.0e6, 2.0e6, 2.0)) ## örnekler orijinde değil (konum shader'da): kamera uzaktayken çizim atılmasın
	var mat := ShaderMaterial.new()
	mat.shader = RainShader
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("drop_color", DROP_COLOR)
	mat.set_shader_parameter("head_color", DROP_HEAD_COLOR)
	mat.set_shader_parameter("splash_color", SPLASH_COLOR)
	mat.set_shader_parameter("ripple_color", RIPPLE_COLOR)
	_mats.append(mat)
	var mmi := MultiMeshInstance2D.new()
	mmi.name = ["Drops", "Splashes", "Ripples"][kind]
	mmi.multimesh = mm
	mmi.material = mat
	add_child(mmi)
	return mm


## Sağanakta (atmosphere.gd STORM_RAIN_DENSITY) 1'in üstüne çıkar: daha çok damla (MAX_DROPS x şiddet).
func set_intensity(value: float, p_slant_sign: float, p_storm: float = 0.0) -> void:
	intensity = clampf(value, 0.0, 1.6)
	slant_sign = 1.0 if p_slant_sign >= 0.0 else -1.0
	storm = clampf(p_storm, 0.0, 1.0)
	_slant = lerpf(SLANT, STORM_SLANT, storm)
	_push_slant()


func _push_slant() -> void:
	if _mats.is_empty():
		return
	_mats[0].set_shader_parameter("slant", _slant * slant_sign)


func _process(delta: float) -> void:
	var tails: bool = _clock - _splash_last < SPLASH_LIFE or _clock - _ripple_last < RIPPLE_LIFE
	if intensity <= 0.001 and _n == 0 and not tails:
		if visible:
			visible = false
		return
	visible = true
	_clock += delta
	_view = _visible_world_rect()
	var target: int = mini(DROP_CAP, int(round(MAX_DROPS * intensity * clampf(_view.get_area() / REFERENCE_AREA, 0.5, 2.5))))
	_update_drops(target)
	## Şiddet artarken eksik damlalar bir anda "duvar" gibi belirmesin: kare başına sınırlı sayıda yeni damla.
	var spawn_budget: int = maxi(2, int(target * delta * 3.0))
	while _n < target and spawn_budget > 0:
		_spawn_drop(true)
		spawn_budget -= 1
	_drops_mm.visible_instance_count = _n
	for m in _mats:
		m.set_shader_parameter("clock", _clock)


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


func _random_ground() -> Vector2:
	return Vector2(randf_range(_view.position.x, _view.end.x), randf_range(_view.position.y, _view.end.y)).floor()


func _write_drop(i: int) -> void:
	_drops_mm.set_instance_transform_2d(i, Transform2D(0.0, _ground[i]))
	_drops_mm.set_instance_custom_data(i, Color(_speed[i], _len[i], _h0[i], _t0[i]))


func _spawn_drop(random_height: bool) -> void:
	if _n >= DROP_CAP:
		return
	var i: int = _n
	_n += 1
	_ground[i] = _random_ground()
	_h0[i] = randf_range(DROP_MIN_HEIGHT, DROP_MAX_HEIGHT) * (randf_range(0.2, 1.0) if random_height else 1.0)
	_speed[i] = randf_range(DROP_MIN_SPEED, DROP_MAX_SPEED) * lerpf(1.0, STORM_SPEED_MULT, storm)
	_len[i] = randf_range(DROP_MIN_LEN, DROP_MAX_LEN)
	_t0[i] = _clock
	_land[i] = _clock + _h0[i] / _speed[i]
	_write_drop(i)


## Yere değen damlayı bul (sıçrama bırak, yeniden doğur ya da şiddet düştüyse kaldır); görüş alanından uzaklaşanı taşı/kaldır.
func _update_drops(target: int) -> void:
	var ex: Rect2 = _view.grow(60.0)
	var x0: float = ex.position.x
	var y0: float = ex.position.y
	var x1: float = ex.end.x
	var y1: float = ex.end.y
	var i: int = _n - 1
	while i >= 0:
		if _land[i] <= _clock:
			if randf() < SPLASH_CHANCE:
				_spawn_splash(_ground[i])
			if _n > target:
				_remove_drop(i)
			else:
				## Aynı damlayı yeni bir yere, tepeden tekrar düşür (hız/boy aynı kalır).
				_ground[i] = _random_ground()
				_h0[i] = randf_range(DROP_MIN_HEIGHT, DROP_MAX_HEIGHT)
				_t0[i] = _clock
				_land[i] = _clock + _h0[i] / _speed[i]
				_write_drop(i)
		else:
			var g: Vector2 = _ground[i]
			if g.x < x0 or g.y < y0 or g.x >= x1 or g.y >= y1:
				## Kamera hızla uzaklaştı - görünmeyen damlayı görünür alana taşı (şu anki yüksekliğiyle).
				if _n > target:
					_remove_drop(i)
				else:
					var h_now: float = _h0[i] - _speed[i] * (_clock - _t0[i])
					_ground[i] = _random_ground()
					_h0[i] = h_now
					_t0[i] = _clock
					_land[i] = _clock + h_now / _speed[i]
					_write_drop(i)
		i -= 1


## Son damlayı i'nin yerine alır (geriye doğru gezildiği için son damla bu karede zaten işlendi).
func _remove_drop(i: int) -> void:
	var last: int = _n - 1
	if i != last:
		_ground[i] = _ground[last]
		_speed[i] = _speed[last]
		_len[i] = _len[last]
		_h0[i] = _h0[last]
		_t0[i] = _t0[last]
		_land[i] = _land[last]
		_write_drop(i)
	_n = last


func _spawn_splash(g: Vector2) -> void:
	var i: int = _splash_next
	_splash_next = (i + 1) % SPLASH_CAP
	_splash_mm.set_instance_transform_2d(i, Transform2D(0.0, g))
	_splash_mm.set_instance_custom_data(i, Color(_clock, randf() * 100.0, 0.0, 0.0))
	_splash_last = _clock
	if randf() < RIPPLE_CHANCE:
		var j: int = _ripple_next
		_ripple_next = (j + 1) % RIPPLE_CAP
		_ripple_mm.set_instance_transform_2d(j, Transform2D(0.0, g))
		_ripple_mm.set_instance_custom_data(j, Color(_clock, 0.0, 0.0, 0.0))
		_ripple_last = _clock
