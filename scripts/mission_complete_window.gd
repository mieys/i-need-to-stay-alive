extends CanvasLayer

## "Görev Tamamlandı" penceresi (kullanıcı isteği 2026-10-02: "görev tamamlanınca da görev tamamlandı penceresi
## açılmasını ve o pencereden aynı şekilde para paneline gitmesini istiyorum"). main.gd _on_world_event_completed başarıda
## açar (eskiden yalnız sağ üstte bir bildirim yazısı vardı). Görev altını world_event_manager.gd / NetworkManager.
## grant_reward_gold tarafından GoldRewardFx.hold(&"mission") ile zaten eklendi ve bekletiliyor: pencere belirince altın
## satırındaki külçeden release edilir, paralar sol üstteki altın paneline uçar (gold_reward_fx.gd). Bu oyuncu görev
## bölgesinde değildiyse altın satırı çıkmaz. Oyunu durdurmaz, tıklamaları yutmaz, kendi kendine kapanır.

const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")
const INGOT_ICON := preload("res://assets/ui/newui/icon_ingot.png")
const ELITE_CHEST_SHEET := preload("res://assets/sprites/chests/chest_elite.png")

const LAYER := 40 ## altın uçuş katmanının (41) hemen altı - paralar pencerenin üstünden çıkar
const TOP := 128.0
const STACK_GAP := 12.0
const POP_TIME := 0.25
const RELEASE_AT := 0.45
const HOLD_TIME := 3.6
const FADE_TIME := 0.35
const ICON_SIZE := Vector2(40, 40)

static var _open: Array = []

var mission_label: String = ""
var _panel: PanelContainer = null
var _gold_icon: TextureRect = null
var _gold: int = 0
var _t: float = 0.0
var _released: bool = false


## Pencereyi açar. Başlıktan önce çağıran (main.gd) etiketi verir.
static func open(parent: Node, label: String) -> void:
	if parent == null:
		return
	var w: CanvasLayer = (load("res://scripts/mission_complete_window.gd") as GDScript).new()
	w.set("mission_label", label)
	parent.add_child(w)


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open.append(self)
	_gold = GoldRewardFx.held_amount(&"mission")
	_build()


func _exit_tree() -> void:
	_open.erase(self)
	## Kapanırken hâlâ bırakılmamış altın varsa (çok kısa ömür) bekletilmesin.
	if not _released and _gold > 0 and is_instance_valid(_gold_icon):
		GoldRewardFx.release(&"mission", _gold_icon.get_global_transform_with_canvas() * (_gold_icon.size * 0.5))


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UIKit.theme()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	add_child(_panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	box.add_child(_label("GÖREV TAMAMLANDI!", UIKit.FS_TITLE, UIKit.C_ACCENT))
	if mission_label != "":
		box.add_child(_label(mission_label, 24, UIKit.C_TEXT_DIM))
	var rewards := HBoxContainer.new()
	rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rewards.alignment = BoxContainer.ALIGNMENT_CENTER
	rewards.add_theme_constant_override("separation", 28)
	box.add_child(rewards)
	if _gold > 0:
		_gold_icon = _icon(INGOT_ICON)
		rewards.add_child(_row(_gold_icon, "+%d altın" % _gold, UIKit.C_GOLD))
	var chest_tex := AtlasTexture.new()
	chest_tex.atlas = ELITE_CHEST_SHEET
	chest_tex.region = Rect2(0, 0, 48, 48)
	rewards.add_child(_row(_icon(chest_tex), "+1 Elit Sandık", UIKit.C_TEXT))
	## Boyut içerikten - ekranın üst ortasına, açık başka bir pencere varsa onun altına.
	_panel.reset_size()
	var view: Vector2 = get_viewport().get_visible_rect().size
	var y: float = TOP
	for w in _open:
		if w == self:
			break
		if is_instance_valid(w) and w.get("_panel") != null:
			var other: Control = w.get("_panel")
			y = maxf(y, other.position.y + other.size.y + STACK_GAP)
	_panel.position = Vector2(roundf((view.x - _panel.size.x) * 0.5), y)
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2.ONE * 0.85
	_panel.modulate.a = 0.0


func _label(text: String, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(l, fs, color, 0)
	return l


func _icon(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = ICON_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _row(icon: TextureRect, text: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	h.add_child(icon)
	var l := _label(text, UIKit.FS_BODY, color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return h


func _process(delta: float) -> void:
	_t += delta
	var pop: float = clampf(_t / POP_TIME, 0.0, 1.0)
	var back: float = 1.0 + 2.70158 * pow(pop - 1.0, 3.0) + 1.70158 * pow(pop - 1.0, 2.0) ## easeOutBack
	_panel.scale = Vector2.ONE * lerpf(0.85, 1.0, back)
	_panel.modulate.a = pop
	if not _released and _t >= RELEASE_AT:
		_released = true
		if _gold > 0 and is_instance_valid(_gold_icon):
			GoldRewardFx.release(&"mission", _gold_icon.get_global_transform_with_canvas() * (_gold_icon.size * 0.5))
	if _t > HOLD_TIME:
		var k: float = clampf((_t - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
		_panel.modulate.a = 1.0 - k
		if k >= 1.0:
			queue_free()
