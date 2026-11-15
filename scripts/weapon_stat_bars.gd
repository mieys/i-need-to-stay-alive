extends GridContainer

## SİLAH STAT ÇUBUKLARI (kullanıcı isteği 2026-11-13): lobi / karakter seçimi SİLAH sekmesinin ayrıntı kutusunda seçilen silahın
## Saldırı - Saldırı Hızı - Savunma - Destek puanları; 2x2 hücre, her hücre [stat ikonu] [ad / 10 dilimli piksel çubuk].
## Değerler weapon_catalog.gd STAT_BARS (oyuna etkisi yok). Renkler tek paletten (hud_theme.gd, madde 403); 1 sanat px = 3 ekran px.

const HT := preload("res://scripts/hud_theme.gd")
const DK := preload("res://scripts/menu_dark_kit.gd")
const SI := preload("res://scripts/stat_icon.gd")
const WC := preload("res://scripts/weapon_catalog.gd")

## [stat ikonu (stat_icon.gd), ad, dolu dilim rengi]
const ROWS := [
	["damage", "Saldırı", HT.BAD],
	["fire_rate", "Saldırı Hızı", HT.PRICE],
	["shield_protection", "Savunma", HT.SHIELD_BAR],
	["heal_power", "Destek", HT.GOOD],
]

var _pips: Array = [] ## Pips, ROWS sırasıyla
var _cells: Array = [] ## hücre kutuları (ipucu)


## px: 1 sanat pikseli kaç ekran pikseli (masaüstü 3); icon_px: stat ikonu kutusu; fs: ad yazı boyu.
func setup(px: int = 3, icon_px: float = 48.0, fs: int = DK.FS_LABEL) -> void:
	columns = 2
	add_theme_constant_override("h_separation", 6 * px)
	add_theme_constant_override("v_separation", 2 * px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row: Array in ROWS:
		var hb := DK.h(px * 3)
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.mouse_filter = Control.MOUSE_FILTER_PASS
		var f: String = str(SI.ICON_PATHS.get(row[0], ""))
		var tex: Texture2D = load(SI.ICON_DIR + f) as Texture2D if f != "" and ResourceLoader.exists(SI.ICON_DIR + f) else null
		hb.add_child(DK.icon(tex, icon_px))
		var v := DK.v(0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(DK.lbl(str(row[1]), fs, DK.C_DIM))
		var p := Pips.new(row[2], px)
		v.add_child(p)
		hb.add_child(v)
		add_child(hb)
		_pips.append(p)
		_cells.append(hb)


func show_weapon(key: String) -> void:
	var vals: Array = WC.stat_bars(key)
	for i in _pips.size():
		var n: int = int(vals[i]) if i < vals.size() else 0
		(_pips[i] as Pips).set_value(n)
		(_cells[i] as Control).tooltip_text = "%s: %d / %d" % [tr(str(ROWS[i][1])), n, WC.STAT_BAR_MAX]


## Test / yardımcı: çubukta görünen değerler.
func values() -> Array:
	var out: Array = []
	for p in _pips:
		out.append((p as Pips).value)
	return out


## 10 dilimli piksel çubuk: dilim 6x4 sanat px, araları 1 px; dolu dilimde üst 1 px açık, alt 1 px koyu ton (düz renk kutu değil).
class Pips extends Control:
	var value: int = 0
	var col: Color = Color.WHITE
	var k: int = 3

	func _init(c: Color, px: int) -> void:
		col = c
		k = px
		var n: int = WC.STAT_BAR_MAX
		custom_minimum_size = Vector2(n * 6 * k + (n - 1) * k, 4 * k)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: int) -> void:
		value = clampi(v, 0, WC.STAT_BAR_MAX)
		queue_redraw()

	func _draw() -> void:
		var w: float = 6 * k
		var h: float = 4 * k
		for i in WC.STAT_BAR_MAX:
			var x: float = i * (w + k)
			if i < value:
				draw_rect(Rect2(x, 0, w, h), col)
				draw_rect(Rect2(x, 0, w, k), col.lightened(0.3))
				draw_rect(Rect2(x, h - k, w, k), col.darkened(0.35))
			else:
				draw_rect(Rect2(x, 0, w, h), HT.DOCK_MARK)
				draw_rect(Rect2(x, h - k, w, k), HT.OUTLINE)
