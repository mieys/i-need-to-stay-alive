extends ColorRect

## Sandıktan çıkan ödül kartının ARKASINDAKİ dönen ışık huzmeleri (shaders/reward_rays.gdshader). Kullanıcı isteği
## (2026-09-25): "kartın parıltılı ve ödüllendirici gözükmesi gerekiyor elitte daha da ödüllendirici ... çıkan tiera bağlı
## olarak kartın arkasındaki ışıkları ayarla". Renk/huzme sayısı/hız/boyut tier'a göre (TIER_* tabloları, 5 = Final);
## elit sandıkta daha parlak, ters dönen ikinci huzme takımı ve mor bir dış hale (_aura).
## Düğüm kartın ÇOCUĞU DEĞİL: ekranın kartlardan önceki bir katmanında durur ve her karede hedef kartın merkezini/ölçeğini/
## saydamlığını izler - böylece komşu kartın ışığı bu kartın üstüne çizilmez, kart uçarken ışık da onunla gelir.
## fade (0..1) ışığın kendi açılışı (kart yere inince yanar, bkz. reward_reveal.gd).

const SHADER := preload("res://shaders/reward_rays.gdshader")
const ELITE_COLOR := Color("#c77dff")
## Tier 1 Sıradan gümüş, 2 Nadir mavi, 3 Epik mor, 4 Efsanevi altın, 5 Final parlak altın (enchant_screen TIER_TEXT ile uyumlu).
## Doygun tonlar: ışık karartılmış zeminin üstüne EKLENİR (blend_add) - soluk tonlar orada gri-yeşile dönüp kayboluyordu.
const TIER_COLORS := [Color("#dfe6ee"), Color("#5aa2ff"), Color("#b06bff"), Color("#ffb52e"), Color("#ffd84a")]
const TIER_RAYS := [8.0, 10.0, 12.0, 14.0, 16.0]
const TIER_SPEED := [0.12, 0.18, 0.24, 0.3, 0.34]
const TIER_RAYS2 := [0.0, 0.0, 0.0, 11.0, 12.0]
const TIER_WIDTH := [0.16, 0.18, 0.2, 0.22, 0.24]
const TIER_INTENSITY := [0.45, 0.6, 0.72, 0.85, 0.9]
## Kartın her yanından taşma ve kartı saran hale kalınlığı - SANAT pikseli (savaş kartında 3, efsun kartında 4 ekran px).
const TIER_REACH := [26.0, 34.0, 42.0, 52.0, 56.0]
const TIER_HALO := [5.0, 6.0, 7.0, 8.0, 9.0]
const TIER_PULSE := [0.0, 0.0, 0.08, 0.15, 0.15]
const ELITE_INTENSITY := 1.15
const ELITE_REACH := 1.15

var target: Control = null
var fade: float = 0.0
var _card_size: Vector2 = Vector2(300, 480)
var _texel: float = 3.0
var _reach_scale: float = 1.0
var _aura: ColorRect = null


## card_size: kartın ölçeksiz boyutu; texel: kartın sanat pikseli kaç ekran pikseli (savaş kartı 3, efsun kartı 4).
## reach_scale: taşmayı küçültür (efsun ekranında üç büyük kart yan yana - ışık ekranın tepesine taşmasın).
func setup(card: Control, card_size: Vector2, texel: float, tier: int, elite: bool, reach_scale: float = 1.0) -> void:
	target = card
	_card_size = card_size
	_texel = texel
	_reach_scale = reach_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	set_tier(tier, elite)


## Işık kutusu = kart + her yanda reach (sanat px) - kutu ve kartın yarı boyutu shader'a sanat px olarak gider.
func _apply(mat: ShaderMaterial, reach_art: float) -> Vector2:
	var card_art: Vector2 = (_card_size / _texel).round()
	var box_art: Vector2 = card_art + Vector2(reach_art, reach_art) * 2.0
	mat.set_shader_parameter("art_size", box_art)
	mat.set_shader_parameter("card_half", card_art * 0.5)
	mat.set_shader_parameter("reach", reach_art)
	return box_art * _texel


func set_tier(tier: int, elite: bool) -> void:
	var i: int = clampi(tier, 1, 5) - 1
	var reach_art: float = roundf(float(TIER_REACH[i]) * _reach_scale * (ELITE_REACH if elite else 1.0))
	var mat := material as ShaderMaterial
	size = _apply(mat, reach_art)
	pivot_offset = size * 0.5
	mat.set_shader_parameter("ray_color", TIER_COLORS[i])
	mat.set_shader_parameter("core_color", TIER_COLORS[i].lightened(0.3))
	mat.set_shader_parameter("halo", float(TIER_HALO[i]) * (1.3 if elite else 1.0))
	mat.set_shader_parameter("rays", TIER_RAYS[i])
	mat.set_shader_parameter("speed", TIER_SPEED[i])
	mat.set_shader_parameter("rays2", maxf(float(TIER_RAYS2[i]), float(TIER_RAYS[i]) - 3.0) if elite else float(TIER_RAYS2[i]))
	mat.set_shader_parameter("ray_width", TIER_WIDTH[i])
	mat.set_shader_parameter("intensity", minf(1.0, float(TIER_INTENSITY[i]) * (ELITE_INTENSITY if elite else 1.0)))
	mat.set_shader_parameter("pulse", float(TIER_PULSE[i]) + (0.1 if elite else 0.0))
	## Elit: arkada yavaş ters dönen, daha uzağa taşan mor ince huzmeler - "elit sandıktan çıktı" hissi her tier'da.
	if elite and _aura == null:
		_aura = ColorRect.new()
		_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_aura.show_behind_parent = true
		var am := ShaderMaterial.new()
		am.shader = SHADER
		_aura.material = am
		add_child(_aura)
	if _aura:
		var am2 := _aura.material as ShaderMaterial
		_aura.size = _apply(am2, roundf(reach_art * 1.4 + 8.0))
		_aura.position = (size - _aura.size) * 0.5
		am2.set_shader_parameter("ray_color", ELITE_COLOR)
		am2.set_shader_parameter("core_color", ELITE_COLOR.lightened(0.3))
		am2.set_shader_parameter("halo", 0.0)
		am2.set_shader_parameter("rays", 9.0)
		am2.set_shader_parameter("speed", -0.1)
		am2.set_shader_parameter("rays2", 0.0)
		am2.set_shader_parameter("ray_width", 0.14)
		am2.set_shader_parameter("intensity", 0.5)
		am2.set_shader_parameter("pulse", 0.12)
		_aura.visible = elite


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_follow()


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	_follow()


func _follow() -> void:
	if not is_instance_valid(target):
		return
	var xf: Transform2D = target.get_global_transform()
	var s: float = xf.get_scale().x
	var center: Vector2 = xf * (_card_size * 0.5)
	scale = Vector2(s, s)
	global_position = center - size * 0.5
	var a: float = target.modulate.a * clampf(fade, 0.0, 1.0)
	modulate.a = a
	visible = a > 0.01 and target.is_visible_in_tree()
