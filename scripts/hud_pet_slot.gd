extends Control

## Oyuncu panelindeki (hud.gd dock) evcil hayvan yuvası - pasif ikonuyla aynı boyda (36 px) küçük çerçeve, içinde seçili
## hayvanın kendi sprite karesi (PetCatalog.icon), tam sayı ölçekle. Kullanıcı isteği (2026-10-14): "pet için de bi yer".
## Üstüne gelince yetenek ipucuyla aynı koyu levha (hud_tooltip.gd): hayvanın adı + etkisi + "BU OYUNDA" bölümü - kullanıcı
## isteği (2026-10-18): "pete mouse'u götürünce ne kadar hasar verdiği, hasar azalttığı, iyileştirdiği v.b gözüksün"
## (sayılar damage_stats.gd pet_totals; ipucu açıkken REFRESH_INTERVAL'da bir canlı yenilenir, Shift gerekmez).

const PetCatalog := preload("res://scripts/pet_catalog.gd")
const DamageStats := preload("res://scripts/damage_stats.gd")
const HudTooltip := preload("res://scripts/hud_tooltip.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const FRAME: Texture2D = preload("res://assets/ui/kit/hud_skill_frame_small.png")
const HudTheme := preload("res://scripts/hud_theme.gd")
const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd")
var tray_frame: bool = false ## hud.gd _apply_tray_slots (masaüstü panel, madde 459)
const UNDER := HudTheme.DOCK_INSET ## madde 454
const FIT := 32.0 ## hayvan en çok bu kareye sığar (çerçevenin iç kenarına 2 px taşabilir; çerçeve üstte çizilir)
const TOOLTIP_WIDTH := 470.0
const TOOLTIP_ICON := 48.0
const REFRESH_INTERVAL := 0.5

var _key: String = ""
var _tex: Texture2D = null
var tooltip_panel: PanelContainer = null
var _stats_label: RichTextLabel = null
var _refresh_t: float = 0.0
## Bekleme süreli evciller (Minik Cadı / Hayalet, madde 509): hayvan düğümü cooldown_fraction() verir -> yuvada yukarıdan silinen koyu örtü.
const CD_SHADE := Color(0.0, 0.0, 0.0, 0.58)
var _cd_frac: float = 0.0
var _pet_node: Node = null
var _pet_lookup_t: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_open_tooltip)
	mouse_exited.connect(_close_tooltip)
	set_pet(PetCatalog.selected())


func set_pet(key: String) -> void:
	_key = key
	_tex = PetCatalog.icon(key)
	tooltip_text = "" ## motorun düz ipucu yerine kendi levhamız (_open_tooltip)
	if tooltip_panel and is_instance_valid(tooltip_panel):
		_open_tooltip()
	queue_redraw()


func _exit_tree() -> void:
	_close_tooltip()


func _process(delta: float) -> void:
	_update_cooldown(delta)
	if tooltip_panel == null or not is_instance_valid(tooltip_panel):
		return
	if not is_visible_in_tree():
		_close_tooltip()
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = REFRESH_INTERVAL
		_stats_label.text = _stats_bbcode()
	HudTooltip.place_above(tooltip_panel, self)


## Yerel oyuncunun evcil düğümü (cooldown_fraction veren) - 0,5 sn'de bir aranır.
func _update_cooldown(delta: float) -> void:
	_pet_lookup_t -= delta
	if (_pet_node == null or not is_instance_valid(_pet_node)) and _pet_lookup_t <= 0.0:
		_pet_lookup_t = 0.5
		_pet_node = null
		var p: Node = get_tree().get_first_node_in_group("player") if is_inside_tree() else null
		if p != null:
			for c in p.get_children():
				if c.has_method("cooldown_fraction"):
					_pet_node = c
					break
	var f: float = float(_pet_node.call("cooldown_fraction")) if _pet_node != null and is_instance_valid(_pet_node) else 0.0
	if not is_equal_approx(f, _cd_frac):
		_cd_frac = f
		queue_redraw()


func cooldown_shown() -> float:
	return _cd_frac


func _stats_bbcode() -> String:
	var ink: Dictionary = HudTheme.INK.duplicate()
	ink["cooldown"] = "#" + HudTheme.DIM.to_html(false) ## soluk ikincil yazı (skill_icon.gd ile aynı)
	return "[color=#%s]%s[/color]\n%s" % [HudTheme.ACCENT.to_html(false), tr("BU OYUNDA"), DamageStats.pet_tooltip_bbcode(_key, ink)]


func _open_tooltip() -> void:
	var rebuilding: bool = tooltip_panel != null and is_instance_valid(tooltip_panel)
	_close_tooltip()
	var layer: Node = get_parent()
	if layer == null or _key == "":
		return
	tooltip_panel = HudTooltip.make_panel(TOOLTIP_WIDTH)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.add_child(vbox)

	## Başlık: [hayvan] AD / EVCİL etiketi
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", HudTooltip.well_style(3.0, 3.0))
	well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(well)
	var pic := TextureRect.new()
	pic.texture = _tex
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.custom_minimum_size = Vector2(TOOLTIP_ICON, TOOLTIP_ICON)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(pic)
	var head_col := VBoxContainer.new()
	head_col.add_theme_constant_override("separation", 3)
	head_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(head_col)
	head_col.add_child(HudTooltip.make_label(PetCatalog.display_name(_key).to_upper(), UIKit.FS_BODY, HudTheme.ACCENT))
	var sub := HBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_col.add_child(sub)
	sub.add_child(HudTooltip.make_tag("EVCİL"))

	vbox.add_child(HudTooltip.make_divider())
	var desc: RichTextLabel = HudTooltip.make_rich(UIKit.FS_BODY, HudTheme.TEXT)
	desc.text = PetCatalog.description(_key)
	vbox.add_child(desc)

	var stats_well: PanelContainer = HudTooltip.make_well()
	vbox.add_child(stats_well)
	_stats_label = HudTooltip.make_rich(UIKit.FS_BODY, HudTheme.TEXT)
	_stats_label.text = _stats_bbcode()
	stats_well.add_child(_stats_label)
	_refresh_t = REFRESH_INTERVAL

	layer.add_child(tooltip_panel)
	HudTooltip.place_above(tooltip_panel, self)
	if not rebuilding:
		UiAnim.reveal(tooltip_panel, 0.0, 0.12)


func _close_tooltip() -> void:
	if tooltip_panel and is_instance_valid(tooltip_panel):
		tooltip_panel.queue_free()
	tooltip_panel = null
	_stats_label = null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size).grow(-4.0), UNDER)
	if _tex:
		var ts: Vector2 = _tex.get_size()
		var s: float = maxf(1.0, floorf(FIT / maxf(ts.x, ts.y)))
		draw_texture_rect(_tex, Rect2((size * 0.5 - ts * s * 0.5).round(), ts * s), false)
	if _cd_frac > 0.0:
		var inner: Rect2 = Rect2(Vector2.ZERO, size).grow(-4.0)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, roundf(inner.size.y * _cd_frac))), CD_SHADE)
	## Masaüstü panel (madde 459): çerçeve dokusu yerine Gömme Tepsi yuva çerçevesi (1 px katlar = 4 px kenar, eskisiyle aynı kalınlık).
	if tray_frame:
		HudTrayFrame.draw(self, Rect2(Vector2.ZERO, size), 1.0)
	else:
		draw_texture_rect(FRAME, Rect2(Vector2.ZERO, size), false)
