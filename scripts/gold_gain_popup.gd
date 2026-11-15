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
var _prev_silent: int = -1 ## GameManager.passive_gold_total'ın son görülen değeri (sessiz pasif gelir yazı çıkarmaz, 2026-11-14)
var _silent_debt: int = 0 ## sayaçta henüz görülmemiş sessiz altın (bkz. note_value)
var _silent_age: float = 0.0
const SILENT_DEBT_TTL := 0.5 ## borç bu kadar sn içinde sayaçta görünmezse silinir (gerçek bir kazancı yutmasın)
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
## silent: o ana kadar SESSİZ kazanılan toplam (GameManager.passive_gold_total) - artışı kazançtan düşülür, pasif gelir "+1" yazmaz.
func note_value(value: int, silent: int = 0) -> void:
	if _prev < 0 or _prev_silent < 0:
		_prev = value
		_prev_silent = silent
		return
	var ds: int = maxi(0, silent - _prev_silent)
	_prev_silent = silent
	if ds > 0:
		_silent_debt += ds
		_silent_age = 0.0
	var d: int = value - _prev
	_prev = value
	## Sayaç (GoldRewardFx) bu düğümden önce ya da sonra işlenebilir: sessiz artış aynı karede ya da birkaç kare sonra görünür -
	## borç olarak tutulup ilk ARTIŞTAN düşülür (harcama borca dokunmaz).
	if d > 0 and _silent_debt > 0:
		var eat: int = mini(d, _silent_debt)
		d -= eat
		_silent_debt -= eat
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
	note_value(GoldRewardFx.display_gold(), GameManager.passive_gold_total)
	_silent_age += delta
	if _silent_age > SILENT_DEBT_TTL:
		_silent_debt = 0
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
