extends Control

## EVİN CANI çubuğu (madde 313, kullanıcı: "evin canı gözükmeli hasar alırken"). İki kip, ikisi de boss_bar_art.gd'nin piksel parçalarıyla
## (ahşap plaket + parşömen ad tabelası + kırmızı bantlı dolgu, m5x7 yazı):
##  - HUD (house_interior.gd CanvasLayer): yerel oyuncu evdeyken ve ev hasarlıyken / saldırı altındayken ekranın üst ortasında; boss barı
##    görünüyorsa onun altında. Saldırı altındayken çerçeve vuruş anlarında kısa kırmızı parlar (pulse()).
##  - Dünya (world = true, dışarıdaki evin kapısının üstünde): ev hasarlı/yıkıkken; yıkıkken tabela "EV YIKIK", çubuk onarımı gösterir.
## Ağ yok: HouseSiege'in eşitlenen durumunu okur.

const ArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")

const W := 132 ## sanat pikseli
const TAB_H := 13
const PLATE_Y := 11
const PLATE_H := 17
const BAR_X := 5
const BAR_Y := 15
const BAR_H := 9
const HUD_SCALE := 2.0
const TOP_Y := 50.0
const REFRESH := 1.0 / 15.0
const FADE := 0.25

var siege: HouseSiege = null
var house: Node = null
var world: bool = false ## true: dünyada evin üstünde (Node2D ebeveyn), s = 1 yerel birim
var scale_px: float = HUD_SCALE
var bar_w: int = W ## dünya kipinde daha dar

var _ratio: float = 1.0
var _title: String = "EVİN CANI"
var _label: String = ""
var _timer: float = 0.0
var _want: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if world:
		scale_px = 1.0
	size = Vector2(bar_w, PLATE_Y + PLATE_H) * scale_px
	self_modulate.a = 0.0
	visible = false


## Vuruş anı (house_damage_fx.gd): çerçeve kısa kırmızı parlar.
func pulse() -> void:
	_pulse = 0.18


func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta)
		queue_redraw()
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH
	var want: bool = should_show()
	if want != _want:
		_want = want
		if want:
			visible = true
		var tw: Tween = create_tween()
		tw.tween_property(self, "self_modulate:a", 1.0 if want else 0.0, FADE)
		if not want:
			tw.tween_callback(func() -> void: visible = _want)
	if not visible or siege == null:
		return
	var r: float = siege.ratio()
	var title: String = "EVİN CANI"
	var label: String = "%d / %d" % [int(ceilf(siege.hp)), int(HouseSiege.MAX_HP)]
	if siege.collapsed:
		title = "EV YIKIK"
		r = clampf(siege.hp / (HouseSiege.MAX_HP * HouseSiege.REOPEN_RATIO), 0.0, 1.0)
		label = "ONARIM %%%d" % int(roundf(r * 100.0))
	if not is_equal_approx(r, _ratio) or title != _title or label != _label:
		_ratio = r
		_title = title
		_label = label
		queue_redraw()
	if not world:
		_layout()


func should_show() -> bool:
	if siege == null or GameManager.invasion_pending:
		return false
	var damaged: bool = siege.under_attack or siege.collapsed or siege.hp < HouseSiege.MAX_HP - 0.5
	if world:
		return damaged
	var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
	return damaged and HouseSiege.in_house(p)


func _layout() -> void:
	var y: float = TOP_Y
	var main: Node = house.get_parent() if house != null else null
	var boss: Variant = main.get("_boss_bar_top") if main != null else null
	if boss is Control and is_instance_valid(boss) and (boss as Control).visible:
		y = (boss as Control).position.y + (boss as Control).size.y + 6.0
	position = Vector2(roundf((get_viewport_rect().size.x - size.x) * 0.5), y)


func _draw() -> void:
	var s: float = scale_px
	var o := Vector2.ZERO
	var A := ArtScript
	## ad tabelası (parşömen, iki altın çivi)
	var W: int = bar_w
	var tw: float = A.text_width(_title, s)
	var sw: int = int(tw) + 20
	var sx: int = (W - sw) / 2
	A.rrect(self, o, s, sx, 0, sw, TAB_H, A.OUT)
	A.r(self, o, s, sx + 1, 1, sw - 2, TAB_H - 2, A.PARCH)
	A.r(self, o, s, sx + 1, 1, sw - 2, 1, A.PARCH_HI)
	A.r(self, o, s, sx + 1, TAB_H - 2, sw - 2, 1, A.PARCH_SH)
	for nx in [sx + 3, sx + sw - 4]:
		A.nail(self, o, s, nx, 5)
	A.text(self, o, s, sx + 10, 3, _title, A.INK)
	## ahşap plaket (vuruş anında kırmızı kenar)
	var edge: Color = A.RED_L if _pulse > 0.0 else A.OUT
	A.rrect(self, o, s, 0, PLATE_Y, W, PLATE_H, edge)
	A.r(self, o, s, 1, PLATE_Y + 1, W - 2, PLATE_H - 2, A.W_FACE)
	A.r(self, o, s, 1, PLATE_Y + 1, W - 2, 1, A.W_HI)
	A.r(self, o, s, 1, PLATE_Y + PLATE_H - 2, W - 2, 1, A.W_DK)
	A.nail(self, o, s, 2, PLATE_Y + 7)
	A.nail(self, o, s, W - 3, PLATE_Y + 7)
	## çubuk
	var bw: int = W - BAR_X * 2
	A.r(self, o, s, BAR_X - 1, BAR_Y - 1, bw + 2, BAR_H + 2, A.OUT2)
	A.hp_bar_trail(self, o, s, BAR_X, BAR_Y, bw, BAR_H, _ratio, -1.0)
	A.bar_label(self, o, s, BAR_X, BAR_Y, bw, BAR_H, _label)
