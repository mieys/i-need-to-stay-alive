extends Label

## ALTIN KAZANCI YAZISI (kullanıcı isteği 2026-11-06: "karakter altın toplayınca üstünde +altın görünmesin... artı altın miktarı, altın miktarını
## gösteren mini çerçevenin yanında görünsün"): HUD altın çerçevesinin (GoldIndicator) YANINDA kısa süre "+N" çıkar, sonra söner.
##
## Kaynağa bakmaz: sayaçta gördüğün değer (GoldRewardFx.display_gold) ARTTIĞINDA yazar - yerden toplama, yaratık altını, maden, sandık/görev
## ödülü (paralar panele varırken sayaçla birlikte), arkadaş hediyesi hep aynı yerde görünür. Harcama (düşüş) yazı çıkarmaz.
## Peş peşe kazançlar MERGE_WINDOW içinde TEK yazıda toplanır ("+3" sonra "+2" -> "+5"), yeni kazanç gelince süre baştan başlar.
## PROCESS_MODE_ALWAYS: sandık ekranı gibi duraklatılmış anlarda da sayaçla birlikte çalışır.
## Çerçeve ekranın solundaysa yazı sağında, sağındaysa solunda durur (telefonda altın sağ üst şeritte). Çerçeve gizliyse yazı da gizli.

const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")

const MERGE_WINDOW := 0.8 ## önceki kazançtan bu kadar sn içinde gelen kazanç aynı yazıya eklenir
const HOLD := 1.1 ## tam görünür kalma süresi (son kazançtan itibaren)
const FADE := 0.45 ## sönme süresi
const GAP := 8.0 ## çerçeve ile yazı arası (px)
const TEXT_COLOR := Color(1.0, 0.85, 0.25) ## eski dünya "+N" yazısıyla aynı altın sarısı
const OUTLINE_COLOR := Color(0, 0, 0, 1)
const OUTLINE_SIZE := 3

## Yanında duracağı çerçeve (HUD GoldIndicator). Atanmazsa yazı çıkmaz.
var anchor: Control = null

var _prev: int = -1
var _sum: int = 0
var _age: float = 99.0 ## son kazançtan beri geçen süre


func _init() -> void:
	name = "GoldGainPopup"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_color_override("font_color", TEXT_COLOR)
	add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	add_theme_constant_override("outline_size", OUTLINE_SIZE)
	visible = false


## Kazancı kaydet (düşüş yoksayılır). Test edilebilsin diye _process'ten ayrı.
func note_value(value: int) -> void:
	if _prev < 0:
		_prev = value
		return
	var d: int = value - _prev
	_prev = value
	if d <= 0:
		return
	_sum = _sum + d if _age <= MERGE_WINDOW and visible else d
	_age = 0.0
	text = "+%d" % _sum
	reset_size()


## 0..1 görünürlük (HOLD boyunca 1, sonra yumuşak söner).
static func alpha_at(age: float) -> float:
	if age < HOLD:
		return 1.0
	var t: float = (age - HOLD) / FADE
	return cos(clampf(t, 0.0, 1.0) * PI * 0.5)


func _process(delta: float) -> void:
	note_value(GoldRewardFx.display_gold())
	_age += delta
	var a: float = alpha_at(_age)
	var show_now: bool = a > 0.0 and _age < HOLD + FADE and anchor != null and is_instance_valid(anchor) and anchor.is_visible_in_tree()
	if show_now != visible:
		visible = show_now
		if show_now:
			reset_size()
	if not show_now:
		return
	self_modulate.a = a ## modulate'e dokunulmaz: arayüz opaklık ayarı o kanalı kullanır
	_place_beside_anchor()


func _place_beside_anchor() -> void:
	var r: Rect2 = anchor.get_global_rect()
	var vw: float = get_viewport_rect().size.x
	var x: float = r.end.x + GAP
	if r.get_center().x > vw * 0.5:
		x = r.position.x - GAP - size.x
	global_position = Vector2(x, r.position.y + (r.size.y - size.y) * 0.5)
