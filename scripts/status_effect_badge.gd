extends Control

## Buff/debuff durum satırındaki (hud.gd StatusBar) TEK bir rozet - kullanıcı isteği (2026-09-22): "buffların
## sağladığı etkiler, kalan süresi ve stackle alakalı herşey (skiller v.b)... tıpkı loldeki gibi." Kalan süre
## rozetin ALTINDA (dışında, ikonun üstünü kapatmadan) bir sayı olarak gösterilir.
##
## DÜZELTME (kullanıcı bildirimi 2026-09-22: "fareyi götürünce bişey açıklamıyor") - kök neden: kendisi DAHİL
## tüm düğümler MOUSE_FILTER_IGNORE'du (skill bar'ın altındaki oyun tıklamalarını engellemesin diye), yani
## mouse_entered/exited HİÇ tetiklenmiyordu. Artık KÖK Control MOUSE_FILTER_STOP (skill_icon.gd'nin ikon
## tooltip'iyle AYNI desen), çocuklar IGNORE kalmaya devam ediyor.
##
## DÜZELTME (kullanıcı bildirimi: "altlarındaki yeşil dolma barı olmasın onun yerine altlarında süre geri
## sayımı olsun") - ilk sürümde ikonun İÇİNDE, alt kenarda soldan sağa dolan bir ColorRect ("Fill") vardı;
## tamamen kaldırıldı. TimeLabel artık Panel'in DIŞINDA, altında ayrı bir şerit (bkz. status_effect_badge.tscn
## - kök Control artık 30x42, üst 30x30 Panel, alt 12px TimeLabel şeridi).

const WIDTH := 30.0
const HEIGHT := 42.0
## Kullanıcı isteği (2026-09-22, referans görsel: kılıç/kalkan/iksir ikonları): "gelen stat neyle ilgiliyse
## o tarz görünsün" - eski tek harfli (G/H/İ/Y/K) kısaltmalar kaldırıldı, her "kind" kendi gerçek siluetiyle
## gösteriliyor (bkz. tools/gen_status_effect_icons.py -> assets/ui/status/<kind>.png). Yeni bir efekt
## eklemek istersen (bkz. player.gd get_status_effects) o üreticiye yeni bir ikon fonksiyonu + burada tek
## satır yeter.
const ICON_DIR := "res://assets/ui/status/"
static var _icon_cache: Dictionary = {}


static func _icon_for(kind: String) -> Texture2D:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var tex: Texture2D = load(ICON_DIR + kind + ".png") as Texture2D
	_icon_cache[kind] = tex
	return tex
## Tooltip başlığı/açıklaması - kind -> [başlık, açıklama]. GLYPHS'e yeni bir satır eklerken buraya da ekle.
const INFO := {
	"talon_stack": ["Güç (Talon Pasifi)", "Yetenek kullandıkça yığılan güç: her yük +%6 saldırı gücü, +%4 hasar azaltma verir (en fazla 5 yük). Yeni bir kullanım olmazsa yükler zamanla azalır."],
	"speed": ["Hız Artışı", "Geçici hareket hızı bonusu."],
	"invuln": ["Yenilmezlik", "Ruhani Yetenek \"Kalkan\" aktif - bu süre boyunca hiç hasar almazsın."],
	"bat": ["Yarasa Formu", "Vampir Çocuk'un yarasa formu aktif: daha hızlısın ama sürekli can harcarsın."],
	"shield_slow": ["Kalkan Yenilemesi Yavaş", "Bir yetenek kullandın - kalkan yenilenme hızın kısa süreliğine %50 düştü."],
	"savas_sevki": ["Savaş Şevki", "Öldürdükçe yığılan savaş şevki - 50'de kalıcı +1 saldırı gücüne dönüşür."],
	"kalkan_bagi": ["Kalkan Bağı", "Arkadaşınla kalkanınız birbirine bağlı - hasar/bedel/artış %50-%50 paylaşılıyor, ikinizin de kalkanı daha hızlı yenileniyor."],
}

@onready var panel: Panel = $Panel
@onready var icon: TextureRect = $Panel/Icon
@onready var stack_label: Label = $Panel/StackBadge
@onready var time_label: Label = $TimeLabel

var _def: Dictionary = {}
var _tooltip: PanelContainer = null


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size = Vector2(WIDTH, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("status_badge"))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _process(_delta: float) -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_update_tooltip_position()


func _exit_tree() -> void:
	_hide_tooltip()


## def: player.gd get_status_effects()'in tek bir girişi (bkz. orada).
func apply(def: Dictionary) -> void:
	_def = def
	## Kullanıcı isteği: "Savaş Şevki"nin biriken yığını ikon olarak yeteneğin KENDİ gerçek ikonunu
	## kullanmalı - "icon_path" varsa assets/ui/status/<kind>.png setinin YERİNE doğrudan o dosya yüklenir
	## (bkz. player.gd get_status_effects, spiritual_skills.gd DEFS "icon" alanları).
	var icon_path: String = str(def.get("icon_path", ""))
	icon.texture = (load(icon_path) as Texture2D) if not icon_path.is_empty() else _icon_for(str(def.get("kind", "")))
	var stacks: int = int(def.get("stacks", 0))
	stack_label.visible = stacks > 0
	stack_label.text = str(stacks)
	var remaining: float = float(def.get("remaining", -1.0))
	if remaining >= 0.0:
		time_label.visible = true
		time_label.text = str(maxi(1, int(ceil(remaining))))
	else:
		time_label.visible = false
	if _tooltip and is_instance_valid(_tooltip):
		_refresh_tooltip_text()


## DÜZELTME (kullanıcı bildirimi 2026-09-23: "Skill açıklama penceresi (buff debuff dahil) fontlar çok ufak
## çok zor okunuyor ve oyunun arayüz temasıyla çok uyumsuz") - skill_icon.gd'nin tooltip'iyle AYNI kök neden
## ve AYNI düzeltme (bkz. o dosyadaki BİREBİR AYNI not): düz siyah StyleBoxFlat -> UIKit.panel_style
## ("window_tight") (ana ekranlarla AYNI ahşap çerçeve), 14-16px -> UIKit.FS_BODY (m5x7'nin standart 32px
## ölçeği) + UIKit renk paleti.
func _on_mouse_entered() -> void:
	_hide_tooltip()
	var layer: Node = _find_canvas_layer()
	if not layer:
		return
	_tooltip = PanelContainer.new()
	_tooltip.custom_minimum_size = Vector2(420, 0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.name = "Box"
	_tooltip.add_child(vbox)
	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.add_theme_font_size_override("font_size", UIKit.FS_BODY)
	title_lbl.add_theme_color_override("font_color", UIKit.C_GOLD)
	title_lbl.add_theme_color_override("font_outline_color", UIKit.C_OUTLINE)
	title_lbl.add_theme_constant_override("outline_size", 4)
	vbox.add_child(title_lbl)
	var desc_lbl := Label.new()
	desc_lbl.name = "Desc"
	desc_lbl.add_theme_font_size_override("font_size", UIKit.FS_BODY)
	desc_lbl.add_theme_color_override("font_color", UIKit.C_TEXT)
	desc_lbl.add_theme_color_override("font_outline_color", UIKit.C_OUTLINE)
	desc_lbl.add_theme_constant_override("outline_size", 3)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(desc_lbl)
	var extra_lbl := Label.new()
	extra_lbl.name = "Extra"
	extra_lbl.add_theme_font_size_override("font_size", UIKit.FS_BODY)
	extra_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	extra_lbl.add_theme_color_override("font_outline_color", UIKit.C_OUTLINE)
	extra_lbl.add_theme_constant_override("outline_size", 3)
	vbox.add_child(extra_lbl)
	layer.add_child(_tooltip)
	_refresh_tooltip_text()
	_tooltip.reset_size()
	_update_tooltip_position()


func _on_mouse_exited() -> void:
	_hide_tooltip()


func _hide_tooltip() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null


func _refresh_tooltip_text() -> void:
	if not (_tooltip and is_instance_valid(_tooltip)):
		return
	var kv: Array = INFO.get(str(_def.get("kind", "")), ["?", ""])
	(_tooltip.get_node("Box/Title") as Label).text = str(kv[0]) + (" (DEBUFF)" if not bool(_def.get("is_buff", true)) else "")
	(_tooltip.get_node("Box/Desc") as Label).text = str(kv[1])
	var extra: Label = _tooltip.get_node("Box/Extra")
	var stacks: int = int(_def.get("stacks", 0))
	var remaining: float = float(_def.get("remaining", -1.0))
	var parts: Array = []
	if stacks > 1:
		parts.append("Yük: %d" % stacks)
	if remaining >= 0.0:
		parts.append("Kalan: %.0fs" % remaining)
	extra.visible = not parts.is_empty()
	extra.text = " | ".join(parts)


func _update_tooltip_position() -> void:
	if not (_tooltip and is_instance_valid(_tooltip)):
		return
	_tooltip.reset_size()
	var s: float = get_global_transform().get_scale().x
	var center_x: float = global_position.x + (size.x * s - _tooltip.size.x) * 0.5
	var top_y: float = global_position.y - _tooltip.size.y - 10.0
	_tooltip.global_position = Vector2(center_x, top_y)


func _find_canvas_layer() -> Node:
	var n: Node = self
	while n:
		if n is CanvasLayer:
			return n
		n = n.get_parent()
	return get_tree().current_scene if is_inside_tree() else null
