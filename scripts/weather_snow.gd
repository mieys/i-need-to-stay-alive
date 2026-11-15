extends Node2D

## KAR YAĞIŞI (Ayaz Dağı, 2026-11-12; kullanıcı: "güzel kış-dağ temalı cozy bir harita ... shaderlara da özen göster"). atmosphere.gd'nin "Rain"
## düğümü kar haritasında (map_profiles "kar_yagisi") bu betikle kurulur: weather_rain.gd ile AYNI arayüz (set_intensity(şiddet, eğim
## işareti, fırtına)), yağmurun yerine. Çizim tamamen shaders/weather_snow.gdshader'da: görünüm alanını kaplayan tek dikdörtgen, taneler dünya
## pikselinde (durum / CPU döngüsü yok). Yağmurlu hava = kar yağışı; açık / rüzgârlı havada yalnız dışarıdayken çok seyrek serpinti
## (SERPINTI) - kışın havada hep birkaç tane süzülsün. Rüzgârlı havada eğim biraz artar.

const SnowShader := preload("res://shaders/weather_snow.gdshader")
const SERPINTI := 0.09 ## açık havada (dışarıda) şiddet tabanı
const RUZGAR := 0.22
const FIRTINA_RUZGAR := 0.6
const VIEW_MARGIN := 48.0

var intensity: float = 0.0
var slant_sign: float = 1.0
var storm: float = 0.0
var outdoor: float = 1.0
var _mat: ShaderMaterial = null
var _size := Vector2.ZERO


func _ready() -> void:
	z_index = 100 ## yağmur gibi: dünyadaki her şeyin üstünde - HUD ayrı CanvasLayer, etkilenmez
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = SnowShader
	material = _mat


func set_intensity(value: float, p_slant_sign: float, p_storm: float = 0.0) -> void:
	intensity = clampf(value, 0.0, 1.6)
	slant_sign = 1.0 if p_slant_sign >= 0.0 else -1.0
	storm = clampf(p_storm, 0.0, 1.0)


## atmosphere.gd her karede verir: iç mekânda (ev / bina) serpinti de yok.
func set_outdoor(k: float) -> void:
	outdoor = clampf(k, 0.0, 1.0)


func _process(_delta: float) -> void:
	var k: float = maxf(intensity, SERPINTI * outdoor)
	if k <= 0.001:
		if visible:
			visible = false
		return
	visible = true
	_mat.set_shader_parameter("yogunluk", k)
	_mat.set_shader_parameter("ruzgar", lerpf(RUZGAR, FIRTINA_RUZGAR, storm) * slant_sign)
	var r: Rect2 = _visible_world_rect()
	global_position = r.position
	if r.size != _size:
		_size = r.size
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _size), Color.WHITE)


func _visible_world_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	var size: Vector2 = vp.get_visible_rect().size
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * size
	return Rect2(a, b - a).abs().grow(VIEW_MARGIN)
