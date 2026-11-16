extends CanvasLayer

## Kum fırtınası ekran katmanı (madde 718, kum_firtinasi.gd). atmosphere.gd kurar (yalnız MapProfiles "kum_firtinasi" haritası), main.gd
## gün-gece renk geçişinin HEMEN önüne yerleştirir (aynı layer=1, ağaç sırası): dünya -> bulut gölgeleri -> KUM -> gün/gece -> sis -> HUD.
## Şiddet 0 (ya da ev içi / zindan) iken ColorRect gizli: ekran okuyan shader hiç çalışmaz (sıfır maliyet).

const KumFirtinasi := preload("res://scripts/kum_firtinasi.gd")
const SHADER := preload("res://scenes/kum_firtinasi.gdshader")

var _rect: ColorRect = null
var _mat: ShaderMaterial = null
var _t: float = 0.0
var _amount: float = 0.0


func _ready() -> void:
	layer = 1
	process_priority = 998 ## kameradan sonra (renk geçişi 999, sis 1000) - cam_origin bu karenin kamerasıyla
	_rect = ColorRect.new()
	_rect.name = "Kum"
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)


## atmosphere.gd her karede: k = açık havadaki fırtına şiddeti (ev içinde 0), açı = rüzgar açısı.
func set_sand(k: float, angle: float) -> void:
	_amount = k
	var on: bool = k > 0.005
	if _rect.visible != on:
		_rect.visible = on
	if on:
		_mat.set_shader_parameter("amount", k)
		_mat.set_shader_parameter("slope", KumFirtinasi.wind_slope(angle))
		_mat.set_shader_parameter("wind_sign", KumFirtinasi.wind_sign(angle))


func _process(delta: float) -> void:
	if _amount <= 0.005:
		return
	_t = fmod(_t + delta, 600.0) ## shader float hassasiyeti (t * hız) - 10 dk.da bir desen sıfırlanır, akan çizgilerde fark edilmez
	var vp: Viewport = get_viewport()
	var inv: Transform2D = (vp.get_final_transform() * vp.get_canvas_transform()).affine_inverse()
	_mat.set_shader_parameter("cam_origin", inv * Vector2.ZERO)
	_mat.set_shader_parameter("world_per_px", inv.get_scale().x)
	_mat.set_shader_parameter("t", _t)
