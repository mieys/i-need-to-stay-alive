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

## KARAKTER çubukları (2026-11-16, kullanıcı: "Hasar, Savunma, Çeviklik ve Destek"): değerler characters.gd STAT_BARS, show_values ile.
## İkonlar silah çubuklarınınkinden (ROWS) ve orta paneldeki temel stat ızgarasından (Can/Hız/Güç) BİLEREK farklı (kullanıcı isteği).
const CHAR_ROWS := [
	["crit_damage", "Hasar", HT.BAD],
	["shield_amount", "Savunma", HT.SHIELD_BAR],
	["dodge", "Çeviklik", HT.PRICE],
	["health_regen", "Destek", HT.GOOD],
]

var _rows: Array = ROWS
var _pips: Array = [] ## Pips, _rows sırasıyla
var _cells: Array = [] ## hücre kutuları (ipucu)


## px: 1 sanat pikseli kaç ekran pikseli (masaüstü 3); icon_px: stat ikonu kutusu; fs: ad yazı boyu; rows: ROWS / CHAR_ROWS;
## pip_w: dilim genişliği (sanat px; dar alanda 2); col_sep: sütun arası (-1 = 6 sanat px).
func setup(px: int = 3, icon_px: float = 48.0, fs: int = DK.FS_LABEL, rows: Array = ROWS, pip_w: int = 6, col_sep: int = -1) -> void:
	_rows = rows
	columns = 2
	add_theme_constant_override("h_separation", 6 * px if col_sep < 0 else col_sep)
	add_theme_constant_override("v_separation", 2 * px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for row: Array in _rows:
		var hb := DK.h(px * 3)
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.mouse_filter = Control.MOUSE_FILTER_PASS
		var f: String = str(SI.ICON_PATHS.get(row[0], ""))
		var tex: Texture2D = load(SI.ICON_DIR + f) as Texture2D if f != "" and ResourceLoader.exists(SI.ICON_DIR + f) else null
		hb.add_child(DK.icon(tex, icon_px))
		var v := DK.v(0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(DK.lbl(str(row[1]), fs, DK.C_DIM))
		var p := Pips.new(row[2], px, pip_w)
		v.add_child(p)
		hb.add_child(v)
		add_child(hb)
		_pips.append(p)
		_cells.append(hb)


func show_weapon(key: String) -> void:
	show_values(WC.stat_bars(key))


func show_values(vals: Array) -> void:
	for i in _pips.size():
		var n: int = int(vals[i]) if i < vals.size() else 0
		(_pips[i] as Pips).set_value(n)
		(_cells[i] as Control).tooltip_text = "%s: %d / %d" % [tr(str(_rows[i][1])), n, WC.STAT_BAR_MAX]


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
	var pw: int = 6 ## dilim genişliği (sanat px)

	func _init(c: Color, px: int, pip_w: int = 6) -> void:
		col = c
		k = px
		pw = pip_w
		var n: int = WC.STAT_BAR_MAX
		custom_minimum_size = Vector2(n * pw * k + (n - 1) * k, 4 * k)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: int) -> void:
		value = clampi(v, 0, WC.STAT_BAR_MAX)
		queue_redraw()

	func _draw() -> void:
		var w: float = pw * k
		var h: float = 4 * k
		for i in WC.STAT_BAR_MAX:
			var x: float = i * (w + k)
			if i < value:
				draw_rect(Rect2(x, 0, w, h), col)
				draw_rect(Rect2(x, 0, w, k), col.lightened(0.3))
				draw_rect(Rect2(x, h - k, w, k), col.darkened(0.35))
			else:
				## Boş dilim RIM_LO (pencere kenar çizgisi tonu): eski DOCK_MARK (#342316) orta paneldeki ahşap zeminde (INSET #271a11)
				## kayboluyordu (kullanıcı 2026-11-16: "boş olan çubuklar çok zor okunuyor"); koyu kuyuda da okunur.
				draw_rect(Rect2(x, 0, w, h), HT.RIM_LO)
				draw_rect(Rect2(x, h - k, w, k), HT.OUTLINE)
