class_name UIKit
extends RefCounted

## Cozy/RPG piksel UI kiti için TEK giriş noktası (kullanıcı isteği 2026-09-21: butonlar/paneller/HUD "doğal dursun, esnemeden
## kaynaklı kalite kaybı olmasın, birbiriyle uyumlu olsun"). Dokular tools/gen_ui_kit.py ile üretilir -> assets/ui/kit/*.png.
## Her sanat pikseli TAM 2 ekran pikselidir (dokular zaten x2 büyütülmüş kaydedilir); 9-slice'ın esneyen orta bölgesi düz renk
## olduğu için hangi boyutta çizilirse çizilsin bulanıklık/bozulma olmaz. Yazı tipi m5x7 için 16'nın katı boyutlar (32/48/64)
## yazı piksellerini de aynı 2 px ızgarasına oturtur - FS_* sabitlerini kullanın.
## ShopPanel._apply_wood_button_style / _apply_mini_wood_button_style (oyundaki neredeyse her ekran bunları çağırıyor) artık
## buraya yönlendiriliyor; yeni kod doğrudan UIKit.style_button / UIKit.panel_style kullanmalı.

const KIT := "res://assets/ui/kit/"

## Yazı boyutları (m5x7 piksel fontu: 16 = 1x, 32 = 2x, 48 = 3x ...).
const FS_BODY := 32
const FS_TITLE := 48
const FS_BIG := 64

## Renk paleti (tüm ekranlarda aynı).
const C_TEXT := Color(0.98, 0.93, 0.80, 1.0)
const C_TEXT_DIM := Color(0.80, 0.70, 0.56, 1.0)
const C_ACCENT := Color(0.96, 0.66, 0.34, 1.0)
const C_GOLD := Color(1.0, 0.85, 0.32, 1.0)
const C_OUTLINE := Color(0.14, 0.08, 0.04, 1.0)
const C_GOOD := Color(0.55, 0.86, 0.42, 1.0)
const C_BAD := Color(0.94, 0.42, 0.36, 1.0)

## Buton dokusu 32x20 sanat pikseli (=64x40 px): 9-slice kenar payları px cinsinden, metin payları daha küçük (eski düzenlerin
## yükseklik/genişlik varsayımları bozulmasın diye).
const BTN_MARGIN_H := 20.0
const BTN_MARGIN_V := 16.0
const BTN_CONTENT_H := 18.0
const BTN_CONTENT_V := 4.0
const MINI_MARGIN := 16.0
const MINI_CONTENT := 6.0

const STATES := ["normal", "hover", "pressed", "disabled", "focus"]

static var _tex_cache: Dictionary = {}
static var _style_cache: Dictionary = {}


static func tex(file: String) -> Texture2D:
	if _tex_cache.has(file):
		return _tex_cache[file]
	var t: Texture2D = load(KIT + file) as Texture2D
	_tex_cache[file] = t
	return t


static func button_style(variant: String = "wood", state: String = "normal", mini: bool = false) -> StyleBoxTexture:
	var key: String = "b|%s|%s|%s" % [variant, state, mini]
	if _style_cache.has(key):
		return _style_cache[key]
	var sb := StyleBoxTexture.new()
	sb.texture = tex(("btn_mini_%s_%s.png" if mini else "btn_%s_%s.png") % [variant, state])
	var m: float = MINI_MARGIN if mini else BTN_MARGIN_H
	var mv: float = MINI_MARGIN if mini else BTN_MARGIN_V
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = mv
	sb.texture_margin_bottom = mv
	## Kenar/orta bantlar (ahşap damarı + degrade) esnetilmeden karo olarak tekrarlanır - kalite kaybı/bulanıklık yok (bkz. tools/gen_ui_kit.py plank).
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	var ch: float = MINI_CONTENT if mini else BTN_CONTENT_H
	var cv: float = MINI_CONTENT if mini else BTN_CONTENT_V
	sb.content_margin_left = ch
	sb.content_margin_right = ch
	sb.content_margin_top = cv
	sb.content_margin_bottom = cv
	_style_cache[key] = sb
	return sb


## Herhangi bir Button'a tek çağrıda 5 durumlu (normal/hover/pressed/disabled/focus) kit stilini + okunaklı yazı renklerini uygular.
## variant: wood (varsayılan) / green (onay/satın al/başla) / dark (ikincil) / red (tehlikeli/kapat).
static func style_button(btn: Button, variant: String = "wood", mini: bool = false, font_size: int = -1) -> void:
	if not is_instance_valid(btn):
		return
	for st in STATES:
		btn.add_theme_stylebox_override(st, button_style(variant, st, mini))
	## Sahnede (tscn/kod) zaten özel yazı rengi/konturu verilmiş butonlara dokunma: sadece eksik olanları tamamla.
	var colors := {
		"font_color": C_TEXT, "font_hover_color": Color(1, 1, 0.9, 1), "font_pressed_color": Color(0.9, 0.82, 0.66, 1),
		"font_focus_color": C_TEXT, "font_disabled_color": Color(0.74, 0.66, 0.56, 0.75), "font_outline_color": C_OUTLINE,
	}
	for k in colors:
		if not btn.has_theme_color_override(k):
			btn.add_theme_color_override(k, colors[k])
	if not btn.has_theme_constant_override("outline_size"):
		btn.add_theme_constant_override("outline_size", 4)
	if font_size > 0:
		btn.add_theme_font_size_override("font_size", font_size)


## Panel türleri: window (ahşap çerçeve + demir köşe + deri iç), inset (koyu çukur), card / card_selected / card_sold, plaque (başlık tahtası).
static func panel_style(kind: String = "window") -> StyleBoxTexture:
	var key: String = "p|" + kind
	if _style_cache.has(key):
		return _style_cache[key]
	var sb := StyleBoxTexture.new()
	match kind:
		"window":
			sb.texture = tex("panel_window.png")
			_margins(sb, 36.0, 44.0)
		"window_tight":
			## Aynı ahşap pencere, ama iç boşluk küçük: büyük menü panelleri (lobi/karakter seçimi) için - içerik fazla daralmasın.
			sb.texture = tex("panel_window.png")
			_margins(sb, 36.0, 18.0)
		"inset":
			sb.texture = tex("panel_inset.png")
			_margins(sb, 12.0, 12.0)
		"status_badge":
			## Kullanıcı isteği (2026-09-22): "bunların da ince dış açık kahverengi çerçeveleri olsun" - buff/
			## debuff rozetleri (status_effect_badge.gd) için ability_bar ile AYNI ince ahşap pervaz dili,
			## küçük bir rozete sığacak kadar ince tek katman (bkz. tools/gen_ui_kit.py status_badge_panel).
			sb.texture = tex("panel_status_badge.png")
			_margins(sb, 10.0, 4.0)
		"ability_bar":
			## Kullanıcı isteği (2026-09-22): "skill kutucuklarının olduğu yere arkasını kaplayacak bir
			## çerçeve... diğer arayüzlerle uyumlu olacak şekilde... çerçeveler oval olmalı" - "window" stiliyle
			## (merchant/envanter/stat'ın kullandığı AYNI kalın ahşap+demir pervaz) BİREBİR aynı çerçeve,
			## sadece köşe yarıçapı çok daha büyük (hap/oval uçlar) - bkz. tools/gen_ui_kit.py ability_bar_panel.
			## Pay yarıçaptan (28 actual px, tools/gen_ui_kit.py ability_bar_panel'deki radius x2) küçük
			## OLAMAZ yoksa eğri kesilip esnetilirdi. DÜZELTME (kullanıcı bildirimi: "çerçeve çok kalın") -
			## ilk denemenin 46/36'sı gereğinden fazlaydı, radius küçülünce pay da küçüldü.
			sb.texture = tex("panel_ability_bar.png")
			sb.texture_margin_left = 30.0
			sb.texture_margin_right = 30.0
			sb.texture_margin_top = 26.0
			sb.texture_margin_bottom = 26.0
			sb.content_margin_left = 10.0
			sb.content_margin_right = 10.0
			sb.content_margin_top = 6.0
			sb.content_margin_bottom = 6.0
		"card":
			sb.texture = tex("panel_card.png")
			_margins(sb, 18.0, 14.0)
		"card_selected":
			sb.texture = tex("panel_card_selected.png")
			_margins(sb, 18.0, 14.0)
		"card_sold":
			sb.texture = tex("panel_card_sold.png")
			_margins(sb, 18.0, 14.0)
		"plaque":
			sb.texture = tex("panel_plaque.png")
			sb.texture_margin_left = 20.0
			sb.texture_margin_right = 20.0
			sb.texture_margin_top = 16.0
			sb.texture_margin_bottom = 16.0
			sb.content_margin_left = 22.0
			sb.content_margin_right = 22.0
			sb.content_margin_top = 6.0
			sb.content_margin_bottom = 6.0
	_style_cache[key] = sb
	return sb


static func _margins(sb: StyleBoxTexture, tex_margin: float, content: float) -> void:
	sb.texture_margin_left = tex_margin
	sb.texture_margin_right = tex_margin
	sb.texture_margin_top = tex_margin
	sb.texture_margin_bottom = tex_margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content
	sb.content_margin_bottom = content


## Bir Label'a kit yazı stili (m5x7 için 16'nın katı boyut + koyu kontur) uygular.
static func style_label(lbl: Label, font_size: int = FS_BODY, color: Color = C_TEXT, outline: int = 0) -> void:
	if not is_instance_valid(lbl):
		return
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if outline > 0:
		lbl.add_theme_color_override("font_outline_color", C_OUTLINE)
		lbl.add_theme_constant_override("outline_size", outline)
