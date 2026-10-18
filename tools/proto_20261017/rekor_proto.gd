extends SceneTree

## REKOR EKRANI PROTOTİPLERİ (2026-10-17). Kullanıcı: "rekor ekranı ara yüzü için 4 prototip hazırla".
## Şu anki: records_screen.gd (ana menü "REKORLAR" öğesi; bej MenuKit penceresi: 2 sütun yazı tablosu 8 rekor + "[X] / [ ]" metin
## listesiyle 17 başarım + BALANS VERİSİ KLASÖRÜ + KAPAT) - ana menünün koyu "Ocak Başı" dilinden kopuk kalan son pencere.
## Oyuna BAĞLI DEĞİL: gerçek main_menu.tscn açılır (canlı şömine + parti), her prototip ayrı CanvasLayer'da üstüne kurulur.
## Veri SAHTE ama tutarlı bir oyuncu (31 koşu, 1 zafer, 11/17 başarım). "simdi" çekimi AYNI sahte veriyi gerçek ekranda gösterir
## (run_records.set_path_override -> geçici dosya, sonunda silinir). A/B/C bugünkü kayıtla yapılır (+ "son koşuda kırıldı" YENİ işareti =
## küçük yeni alan); D yeni veri ister (koşu geçmişi, rekoru hangi karakter kırdı, karakter başı en iyi kademe).
##  A Ateş Işığı       = Ayarlar ekranının dili (madde 234): panelsiz, solda kategori (EN İYİLER / BAŞARIMLAR / GERİ), sağda satırlar.
##  B Kupa Rafı        = Demirci ahşabı (PAL_WOOD): pirinç rekor plakaları + raflarda duran başarım madalyaları + seçili madalya şeridi.
##  C Kayrak Pano      = Oyun Bitti / Seyyar Satıcı (PAL_SLATE): madalyonlu pencere, stat kutuları, 3 sütun başarım kartı.
##  D Kahraman Defteri = SEÇİM D koyu kit (menu_dark_kit): en iyi koşu + SON KOŞULAR tablosu + KAHRAMANLAR + başarım rozetleri.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261017/rekor_proto.gd
##   REKOR_ONLY = "A,B" gibi seçili çekimler (boşsa A-D + ozet.png). Çıktı out/rekor/.
##   OYUNDA (madde 250, A seçildi): "oyunda,oyunda_basarim" = gerçek main_menu.tscn + records_screen.gd, aynı sahte veriyle.
##   ("simdi" artık YENİ ekranı açar - eski bej ekranın görüntüsü out/rekor/simdi.png.)

const OUT := "res://tools/proto_20261017/out/rekor/"
const FAKE_CFG := "res://tools/proto_20261017/out/rekor/_sahte_records.cfg"

## ------------------------------------------------------------------ sahte oyuncu
const REC := {
	"best_time": 3150.0, "best_tier": 16, "best_kills": 3412, "best_layer": 2, "best_victory_time": 2832.0,
	"victories": 1, "runs": 31, "total_kills": 9140, "total_time": 34860.0, "victory_chars": [2],
}
const NEW_KEYS := ["kills"] ## son koşuda (17.10, Şovalye) kırılan rekor
const UNLOCKED := {
	"tier_5": "2026-10-05", "time_15": "2026-10-05", "kills_500": "2026-10-06", "tier_10": "2026-10-08",
	"runs_10": "2026-10-09", "time_30": "2026-10-11", "kills_3000": "2026-10-13", "tier_15": "2026-10-14",
	"final": "2026-10-16", "victory": "2026-10-16", "victory_coop": "2026-10-16",
}
## D (YENİ veri): koşu geçmişi [tarih, karakter, süre sn, kademe, öldürme, sonuç]
const RUNS := [
	["17.10", 7, 2480.0, 14, 3412, "ÖLDÜ"],
	["16.10", 2, 3150.0, 16, 3105, "ZAFER"],
	["16.10", 10, 1384.0, 8, 1210, "ÖLDÜ"],
	["15.10", 7, 2210.0, 12, 2650, "ÖLDÜ"],
	["14.10", 2, 2540.0, 15, 2980, "ÖLDÜ"],
	["14.10", 15, 610.0, 4, 402, "ÇIKTI"],
	["13.10", 5, 1960.0, 11, 3011, "ÖLDÜ"],
	["12.10", 4, 1502.0, 9, 1720, "ÖLDÜ"],
]
## D (YENİ veri): rekoru kıran karakter
const HOLDER := {"time": 2, "tier": 2, "kills": 7, "layer": 2, "victory_time": 2}
## D (YENİ veri): karakter başı en iyi kademe (0 = oynanmadı, -1 = kilitli)
const HERO_BEST := {1: 9, 2: 16, 3: 6, 4: 9, 5: 11, 7: 14, 8: 7, 9: 5, 10: 8, 11: 0, 12: 3, 13: -1, 14: -1, 15: 4}
const HERO_ORDER := [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15]

const CAPTIONS := {
	"simdi": "ŞU AN - bej pencere: yazı tablosu + [X] listesi",
	"oyunda": "OYUNDA - A, EN İYİLER (gerçek records_screen.gd)",
	"oyunda_basarim": "OYUNDA - A, BAŞARIMLAR (gerçek records_screen.gd)",
	"A": "A - Ateş Işığı (Ayarlar dili) - EN İYİLER sayfası",
	"A_basarim": "A - Ateş Işığı - BAŞARIMLAR sayfası",
	"B": "B - Kupa Rafı (Demirci ahşabı)",
	"C": "C - Kayrak Pano (Oyun Bitti / Seyyar Satıcı)",
	"D": "D - Kahraman Defteri (Seçim D) - YENİ veri ister",
}

## ------------------------------------------------------------------ piksel desenler (# ana, h parlak, k koyu)
const P_SKULL := [
	"..#####..",
	".#######.",
	"#########",
	"#kk###kk#",
	"#kk###kk#",
	".###k###.",
	"..#####..",
	"..#k#k#..",
]
const P_HORNS := [
	"#.......#",
	"##.....##",
	".#######.",
	"#########",
	"#kk###kk#",
	"#kk###kk#",
	".###k###.",
	"..#k#k#..",
]
const P_CROWN := [
	"#...#...#",
	"##.###.##",
	"#########",
	"#h##h##h#",
	"#########",
	".#######.",
]
const P_MOON := [
	"..####...",
	".###.....",
	"###....h.",
	"###...hhh",
	"###....h.",
	"###......",
	".###.....",
	"..####...",
]
const P_SWORD := [
	".......hh",
	"......h#h",
	".....h#h.",
	"....h#h..",
	"k..h#h...",
	".k##h....",
	"..kk.....",
	".k..k....",
	"k........",
]
const P_SWORDS := [
	"h.......h",
	"#h.....h#",
	".#h...h#.",
	"..#h.h#..",
	"...#h#...",
	"..k#.#k..",
	".k.....k.",
	"k.......k",
]
const P_HOURGLASS := [
	"#########",
	".#hhhhh#.",
	"..#hhh#..",
	"...#h#...",
	"...#.#...",
	"..#.h.#..",
	".#.hhh.#.",
	"#########",
]
const P_FLAG := [
	"##.......",
	"#######..",
	"#hhhhhh#.",
	"#hhhhh#..",
	"#######..",
	"#........",
	"#........",
	"##.......",
]
const P_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const P_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const P_BACK := ["...#...", "..#....", "#######", "..#....", "...#..."]
const P_DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]
const PATS := {"skull": P_SKULL, "horns": P_HORNS, "crown": P_CROWN, "moon": P_MOON, "sword": P_SWORD,
		"swords": P_SWORDS, "hourglass": P_HOURGLASS, "flag": P_FLAG}

const METAL := {
	"bronz": [Color("#f0b47a"), Color("#b8743e"), Color("#5c3418")],
	"gumus": [Color("#eef3f7"), Color("#a9b7c6"), Color("#4e5a6c")],
	"altin": [Color("#ffe28c"), Color("#e0a83a"), Color("#6e4510")],
	"kizil": [Color("#ffb48e"), Color("#d6553c"), Color("#5e1a14")],
}
const ACH_ART := {
	"tier_5": ["skull", "bronz"], "tier_10": ["skull", "gumus"], "tier_15": ["skull", "altin"], "final": ["horns", "kizil"],
	"victory": ["crown", "altin"], "victory_solo": ["crown", "gumus"], "victory_coop": ["crown", "gumus"],
	"victory_heroes_3": ["crown", "kizil"], "layer_3": ["moon", "bronz"], "layer_10": ["moon", "gumus"],
	"layer_25": ["moon", "altin"], "kills_500": ["sword", "bronz"], "kills_3000": ["sword", "gumus"],
	"time_15": ["hourglass", "bronz"], "time_30": ["hourglass", "gumus"], "total_kills_10000": ["swords", "altin"],
	"runs_10": ["flag", "bronz"],
}

## Ateş Işığı renkleri (fire_menu_kit.gd ile aynı)
const C_GOLD := Color("#f4c56e")
const C_GOLD_DIM := Color("#e2c08a")
const C_CREAM := Color("#efe2c6")
const C_SUB := Color("#b09878")
const C_TAG := Color("#c8b28e")


## ------------------------------------------------------------------ çizim sınıfları
class Pic extends Control:
	var rows: Array = []
	var cols: Dictionary = {}
	var px: float = 3.0

	func _init(r: Array, c: Dictionary, s: float = 3.0) -> void:
		rows = r
		cols = c
		px = s
		custom_minimum_size = Vector2(str(r[0]).length() * s, r.size() * s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		for j in rows.size():
			var row: String = rows[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					draw_rect(Rect2(off + Vector2(i * px, j * px), Vector2(px, px)), cols[ch])


## Başarım madalyası. kind: "disk" (yuvarlak, B/D, A'nın başarım sayfası), "tile" (kare, C).
class Medal extends Control:
	var rows: Array = []
	var metal: Array = []
	var locked := false
	var kind := "disk"
	var px := 4.0
	var cell := 3.0
	var pedestal := false
	var glow := false
	var glow_col := Color.WHITE
	var dark_fill := Color("#1a140f")
	var dark_rim := Color("#45372a")
	var lock_col := Color("#ad9b80")
	var outline := Color("#0d0906")

	func setup(r: Array, m: Array, is_locked: bool, k: String, w: float, h: float, gpx: float) -> Medal:
		rows = r
		metal = m
		locked = is_locked
		kind = k
		px = gpx
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return self

	func _cols() -> Dictionary:
		if locked:
			var g: Color = dark_rim.lightened(0.14)
			return {"#": g, "h": g, "k": dark_fill.darkened(0.35)}
		return {"#": metal[0], "h": Color("#fff6dc"), "k": (metal[2] as Color).darkened(0.45)}

	func _disk(c: Vector2, rad: float, col: Color) -> void:
		var n := int(ceil(rad / cell)) + 1
		for j in range(-n, n):
			for i in range(-n, n):
				var cx := (i + 0.5) * cell
				var cy := (j + 0.5) * cell
				if cx * cx + cy * cy <= rad * rad:
					draw_rect(Rect2(c.x + i * cell, c.y + j * cell, cell, cell), col)

	func _glyph(c: Vector2, cols: Dictionary) -> void:
		var gw: float = str(rows[0]).length() * px
		var gh: float = rows.size() * px
		var o := (c - Vector2(gw, gh) * 0.5).round()
		for j in rows.size():
			var row: String = rows[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					draw_rect(Rect2(o.x + i * px, o.y + j * px, px, px), cols[ch])

	func _lock_badge(pos: Vector2) -> void:
		_disk(pos, 11.0, outline)
		_disk(pos, 8.0, dark_rim)
		for j in P_LOCK_ROWS.size():
			var row: String = P_LOCK_ROWS[j]
			for i in row.length():
				if row[i] == "#":
					draw_rect(Rect2(pos.x - 7 + i * 2, pos.y - 7 + j * 2, 2, 2), lock_col)

	const P_LOCK_ROWS := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]

	func _draw() -> void:
		var w: float = size.x
		var hgt: float = size.y
		var hi: Color = dark_rim.lightened(0.06) if locked else metal[0]
		var mid: Color = dark_rim if locked else metal[1]
		var dk: Color = dark_fill if locked else metal[2]
		match kind:
			"disk":
				var ped: float = 18.0 if pedestal else 0.0
				var rad: float = floorf(minf(w, hgt - ped) * 0.5) - 1.0
				var c := Vector2(floorf(w * 0.5), floorf((hgt - ped) * 0.5))
				if glow:
					for i in 3:
						draw_circle(c, rad + 21.0 - i * 7.0, Color(glow_col, 0.07 + i * 0.06))
				if pedestal:
					var top_y: float = c.y + rad - 6.0
					var base_y: float = hgt - 6.0
					draw_colored_polygon(PackedVector2Array([Vector2(c.x - 9, top_y), Vector2(c.x + 9, top_y),
							Vector2(c.x + 18, base_y), Vector2(c.x - 18, base_y)]), outline)
					draw_colored_polygon(PackedVector2Array([Vector2(c.x - 6, top_y), Vector2(c.x + 6, top_y),
							Vector2(c.x + 14, base_y), Vector2(c.x - 14, base_y)]), mid)
					draw_rect(Rect2(c.x - 27, base_y - 3, 54, 9), outline)
					draw_rect(Rect2(c.x - 24, base_y, 48, 3), dk)
				_disk(c, rad, outline)
				_disk(c, rad - 3.0, hi)
				_disk(c, rad - 6.0, mid)
				_disk(c, rad - 9.0, dk)
				_glyph(c, _cols())
				if locked:
					_lock_badge((c + Vector2(rad * 0.66, rad * 0.66)).floor())
			"tile":
				draw_rect(Rect2(0, 0, w, hgt), outline)
				draw_rect(Rect2(3, 3, w - 6, hgt - 6), mid)
				draw_rect(Rect2(6, 6, w - 12, hgt - 12), dk)
				draw_rect(Rect2(6, 6, w - 12, 3), mid if locked else hi)
				_glyph(Vector2(floorf(w * 0.5), floorf(hgt * 0.5)), _cols())
				if locked:
					_lock_badge(Vector2(w - 10, hgt - 10))


class PBar extends Control:
	var frac := 0.0
	var fill := Color.WHITE
	var track := Color.BLACK
	var border := Color(0, 0, 0, 0)

	func setup(f: float, fc: Color, tc: Color, bc: Color, w: float, h: float) -> PBar:
		frac = clampf(f, 0.0, 1.0)
		fill = fc
		track = tc
		border = bc
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return self

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var inner := Rect2(0, 0, w, h)
		if border.a > 0.0:
			draw_rect(Rect2(0, 0, w, h), border)
			inner = Rect2(2, 2, w - 4, h - 4)
		draw_rect(inner, track)
		var fw: float = floorf(inner.size.x * frac)
		if fw > 0.0:
			draw_rect(Rect2(inner.position, Vector2(fw, inner.size.y)), fill)
			if inner.size.y >= 6.0:
				draw_rect(Rect2(inner.position, Vector2(fw, 2)), fill.lightened(0.35))


## Basamaklı dikey solma (liste kayıyor hissi).
class Fade extends Control:
	var col := Color.BLACK
	var steps := 6

	func _draw() -> void:
		var sh: float = ceilf(size.y / steps)
		for i in steps:
			draw_rect(Rect2(0, i * sh, size.x, sh), Color(col, col.a * float(i + 1) / steps))


## B: kazınmış pirinç rekor plakası.
class Plaque extends Control:
	var cap := ""
	var val := ""
	var fresh := false
	var font: Font = null

	func r(x: float, y: float, w: float, h: float, c: Color) -> void:
		if w > 0.0 and h > 0.0:
			draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)

	func _text(s: String, top: float, fs: int, col: Color, hl: Color) -> void:
		var by: float = roundf(top + font.get_ascent(fs))
		if hl.a > 0.0:
			draw_string(font, Vector2(0, by + 3), s, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, hl)
		draw_string(font, Vector2(0, by), s, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, col)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var o := Color("#1a0f06")
		var b_hi := Color("#efcf86")
		var b_mid := Color("#c3924a")
		var b_lo := Color("#8a5f28")
		var b_dk := Color("#5e3d16")
		r(3, 0, w - 6, h, o)
		r(0, 3, w, h - 6, o)
		r(3, 3, w - 6, h - 6, b_mid)
		r(3, 3, w - 6, 3, b_hi)
		r(3, h - 9, w - 6, 6, b_lo)
		var ix := 15.0
		var iy := 15.0
		var iw := w - 30.0
		var ih := h - 30.0
		r(ix, iy, iw, ih, Color("#b1813c"))
		r(ix, iy, iw, 3, b_dk)
		r(ix, iy, 3, ih, b_dk)
		r(ix, iy + ih - 3, iw, 3, b_hi)
		r(ix + iw - 3, iy, 3, ih, b_hi)
		for p: Vector2 in [Vector2(6, 6), Vector2(w - 12, 6), Vector2(6, h - 12), Vector2(w - 12, h - 12)]:
			r(p.x, p.y, 6, 6, b_dk)
			r(p.x, p.y, 3, 3, b_hi)
		if font:
			_text(cap, iy + 8, 24, Color("#4a2c10"), Color(0, 0, 0, 0))
			_text(val, iy + ih - font.get_height(48) - 2, 48, Color("#2a1606"), Color("#e2b968"))
		if fresh:
			r(w - 86, -10, 74, 30, o)
			r(w - 83, -7, 68, 24, Color("#b8402e"))
			r(w - 83, -7, 68, 3, Color("#e2705a"))
			if font:
				var by: float = roundf(-7 + (24 - font.get_height(16)) * 0.5 + font.get_ascent(16))
				draw_string(font, Vector2(w - 83, by), "YENİ", HORIZONTAL_ALIGNMENT_CENTER, 68, 16, Color("#fff1dc"))


## B: dolap arkalığı + raflar.
class Cabinet extends Control:
	var shelves := 3
	var sh := 164.0
	var plank_y := 104.0

	func r(x: float, y: float, w: float, h: float, c: Color) -> void:
		if w > 0.0 and h > 0.0:
			draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)

	func _draw() -> void:
		var w: float = size.x
		var hh: float = size.y
		r(0, 0, w, hh, Color("#100b07"))
		r(3, 3, w - 6, hh - 6, Color("#1d1611"))
		var x := 118.0
		while x < w - 12.0:
			r(x, 3, 3, hh - 6, Color("#15100b"))
			r(x + 3, 3, 3, hh - 6, Color("#241c15"))
			x += 118.0
		for i in shelves:
			var y0: float = i * sh + plank_y
			r(3, y0 + 18, w - 6, 9, Color(0, 0, 0, 0.32))
			r(0, y0, w, 3, Color("#a07a52"))
			r(0, y0 + 3, w, 12, Color("#5e4632"))
			r(0, y0 + 15, w, 3, Color("#2b2016"))
			for bx: float in [30.0, w - 42.0]:
				r(bx, y0 + 18, 12, 18, Color("#2b2016"))
				r(bx + 3, y0 + 18, 6, 12, Color("#4a3726"))


## C: pencerenin tepesindeki madalyon (game_over_board.gd Medallion düzeni, kayrak tonları, içinde kadeh).
class TopMedal extends Control:
	var tex: Texture2D = null
	var lift := 60.0
	var cols: Array = []

	func _disk(c: Vector2, rad: float, cell: float, col: Color) -> void:
		var n := int(ceil(rad / cell)) + 1
		for j in range(-n, n):
			for i in range(-n, n):
				var cx := (i + 0.5) * cell
				var cy := (j + 0.5) * cell
				if cx * cx + cy * cy <= rad * rad:
					draw_rect(Rect2(roundf(c.x + i * cell), roundf(c.y + j * cell), cell, cell), col)

	func _draw() -> void:
		var c := Vector2(roundf(size.x * 0.5), -lift)
		_disk(c, 56, 4, cols[0])
		_disk(c, 52, 4, cols[1])
		_disk(c, 46, 4, cols[2])
		_disk(c, 44, 4, cols[0])
		_disk(c, 40, 4, cols[3])
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(32, 34), Vector2(64, 64)), false)


## ------------------------------------------------------------------ durum
var font: Font = null
var FM: GDScript = null
var DK: GDScript = null
var SDK: GDScript = null
var LobbyUI: GDScript = null
var chars: GDScript = null
var ach_defs: Array = []
var tex_kadeh: Texture2D = null
var tex_madalyon: Texture2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])
	return img


## ------------------------------------------------------------------ veri yardımcıları
func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _tm(sec: float) -> String:
	var t: int = int(sec)
	@warning_ignore("integer_division")
	return "%02d:%02d" % [t / 60, t % 60]


func _hours(sec: float) -> String:
	var t: int = int(sec)
	@warning_ignore("integer_division")
	return "%d sa %02d dk" % [t / 3600, (t % 3600) / 60]


func _roman(n: int) -> String:
	if n <= 0:
		return "-"
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	var out := ""
	var left := n
	for i in vals.size():
		while left >= int(vals[i]):
			out += str(syms[i])
			left -= int(vals[i])
	return out


func _tier_txt(n: int) -> String:
	return "FİNAL" if n >= 16 else _roman(n)


func _date(iso: String) -> String:
	var p := iso.split("-")
	return "%s.%s.%s" % [p[2], p[1], p[0]]


func _ach_val(key: String) -> float:
	match key:
		"tier":
			return float(REC["best_tier"])
		"time":
			return float(REC["best_time"])
		"kills":
			return float(REC["best_kills"])
		"layer":
			return float(REC["best_layer"])
		"victory":
			return 1.0 if int(REC["victories"]) > 0 else 0.0
		"victory_coop":
			return 1.0
		"victory_chars":
			return float((REC["victory_chars"] as Array).size())
		"runs_total":
			return float(REC["runs"])
		"total_kills":
			return float(REC["total_kills"])
	return 0.0


func _ach_frac(d: Dictionary) -> float:
	return clampf(_ach_val(str(d["key"])) / float(d["min"]), 0.0, 1.0)


func _ach_count(d: Dictionary) -> String:
	var key: String = d["key"]
	var cur: float = minf(_ach_val(key), float(d["min"]))
	match key:
		"tier":
			return "%s / %s" % [_tier_txt(int(cur)), _tier_txt(int(d["min"]))]
		"time":
			return "%d / %d dk" % [int(cur / 60.0), int(float(d["min"]) / 60.0)]
	return "%s / %s" % [_num(int(cur)), _num(int(d["min"]))]


func _medal(id: String, kind: String, w: float, h: float, gpx: float, pal: Dictionary = {}) -> Medal:
	var art: Array = ACH_ART[id]
	var m := Medal.new().setup(PATS[art[0]], METAL[art[1]], not UNLOCKED.has(id), kind, w, h, gpx)
	for k: String in pal.keys():
		m.set(k, pal[k])
	return m


## Rekor satırları: [anahtar, desen, ad, değer]
func _record_rows() -> Array:
	return [
		["time", P_HOURGLASS, "En uzun süre", _tm(REC["best_time"])],
		["tier", P_SKULL, "En yüksek kademe", _tier_txt(int(REC["best_tier"]))],
		["kills", P_SWORD, "Tek koşuda en çok öldürme", _num(int(REC["best_kills"]))],
		["layer", P_MOON, "En yüksek sonsuz kat", str(int(REC["best_layer"]))],
		["victory_time", P_CROWN, "En hızlı zafer", _tm(REC["best_victory_time"])],
	]


func _face(cid: int) -> Texture2D:
	return LobbyUI.face_texture(str(chars.get_def(cid).get("portrait", "")))


func _cname(cid: int) -> String:
	return str(chars.get_def(cid).get("name", "?"))


## ------------------------------------------------------------------ ortak düğüm yardımcıları
func _full(parent: Node) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _dim(parent: Control, col: Color) -> void:
	var d := ColorRect.new()
	d.color = col
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(d)


func _center(parent: Control, n: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	cc.add_child(n)


func _tr(tex: Texture2D, s: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(s, s)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


func _sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, rad: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	if border.a > 0.0 and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(rad)
	s.corner_detail = 1
	s.anti_aliasing = false
	return s


func _pc(sbx: StyleBox, l: float = 0.0, t: float = 0.0, rr: float = -1.0, b: float = -1.0) -> PanelContainer:
	var pc := PanelContainer.new()
	var s: StyleBox = sbx.duplicate()
	s.content_margin_left = l
	s.content_margin_right = l if rr < 0.0 else rr
	s.content_margin_top = t
	s.content_margin_bottom = t if b < 0.0 else b
	pc.add_theme_stylebox_override("panel", s)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pc


func _shadowed(s: StyleBoxFlat) -> StyleBoxFlat:
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 10)
	return s


func _caption(parent: Node, k: String) -> void:
	var l := CanvasLayer.new()
	l.layer = 120
	parent.add_child(l)
	var kit: RefCounted = SDK.new(SDK.PAL_SLATE)
	var p := _pc(_sb(Color(0, 0, 0, 0.72), Color(1, 1, 1, 0.25), 2, 4), 12, 2)
	p.position = Vector2(12, 6)
	var lb: Label = kit.lbl(CAPTIONS.get(k, k), 24, Color.WHITE)
	p.add_child(lb)
	var holder := _full(l)
	holder.theme = kit.theme()
	holder.add_child(p)


## ================================================================== A - Ateş Işığı
func _A(rc: Control, page: String) -> void:
	rc.theme = DK.theme()
	var band = FM.StepShade.new()
	band.col = Color(0.05, 0.035, 0.025, 0.74)
	rc.add_child(band)
	var sub: Label = FM.lbl("%d koşu  ·  %s oyun" % [int(REC["runs"]), _hours(REC["total_time"])], DK.FS_BODY, C_TAG)
	var logo: Control = FM.title_block("REKORLAR", sub)
	rc.add_child(logo)
	logo.position = FM.TITLE_POS
	var col: VBoxContainer = DK.v(0)
	var specs: Array = [
		["EN İYİLER", "Tek koşu rekorları ve toplamlar", FM.tex_icon(tex_kadeh)],
		["BAŞARIMLAR", "%d / %d açıldı" % [UNLOCKED.size(), ach_defs.size()], FM.tex_icon(tex_madalyon)],
	]
	var btns: Array = []
	for sp: Array in specs:
		var b: Button = FM.item(sp[0], sp[1], sp[2], false, false)
		b.focus_mode = Control.FOCUS_NONE
		col.add_child(b)
		btns.append(b)
	col.add_child(DK.sp(0, 24))
	var back: Button = FM.item("GERİ", "Ana menüye dön", DK.glyph(P_BACK, C_SUB, 5), false, false)
	back.focus_mode = Control.FOCUS_NONE
	col.add_child(back)
	rc.add_child(col)
	col.position = FM.COL_POS
	col.custom_minimum_size.x = FM.COL_W
	FM.set_selected(btns[0 if page == "rekor" else 1], true)
	var hv: VBoxContainer = DK.v(10)
	hv.add_child(FM.hint([["W/S", "seç"], ["Q/E", "bölüm"]]))
	hv.add_child(FM.hint([["ESC", "geri"]]))
	rc.add_child(hv)
	hv.position = Vector2(64, 952)
	var rows: VBoxContainer = DK.v(0)
	rows.custom_minimum_size.x = 840
	rc.add_child(rows)
	rows.position = Vector2(660, 150)
	if page == "rekor":
		_A_records(rows)
	else:
		_A_achievements(rows)
		var fade := Fade.new()
		fade.col = Color(0.05, 0.035, 0.025, 0.96)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rc.add_child(fade)
		fade.position = Vector2(640, 900)
		fade.size = Vector2(880, 180)


func _A_section(rows: VBoxContainer, title: String, extra: String = "") -> void:
	var h: HBoxContainer = DK.h(10)
	h.custom_minimum_size.y = 48
	h.add_child(DK.glyph(P_DIAMOND, C_GOLD, 3))
	var t: Label = DK.lbl(title, DK.FS_BODY, C_GOLD)
	t.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.03, 1))
	t.add_theme_constant_override("outline_size", 6)
	h.add_child(t)
	if extra != "":
		h.add_child(DK.lbl(extra, DK.FS_LABEL, C_SUB))
	var ln := ColorRect.new()
	ln.color = Color(C_GOLD_DIM, 0.28)
	ln.custom_minimum_size = Vector2(0, 2)
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ln)
	if rows.get_child_count() > 0:
		rows.add_child(DK.sp(0, 18))
	rows.add_child(h)


func _A_row(rows: VBoxContainer, icon: Control, label: String, sub: String, right: Control, focused: bool, hh: float = 64.0) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_GOLD, 0.09) if focused else Color(0, 0, 0, 0)
	if focused:
		s.border_width_left = 6
		s.border_color = C_GOLD
	var pc := _pc(s, 18, 4)
	pc.custom_minimum_size.y = hh
	var hb: HBoxContainer = DK.h(16)
	if icon:
		var ib := CenterContainer.new()
		ib.custom_minimum_size = Vector2(56, 0)
		ib.add_child(icon)
		hb.add_child(ib)
	var lv: VBoxContainer = DK.v(-4)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.add_child(DK.lbl(label, DK.FS_BODY, C_GOLD if focused else C_CREAM))
	if sub != "":
		lv.add_child(DK.lbl(sub, DK.FS_LABEL, C_SUB))
	hb.add_child(lv)
	if right:
		hb.add_child(right)
	pc.add_child(hb)
	var wrap: VBoxContainer = DK.v(0)
	wrap.add_child(pc)
	var ln := ColorRect.new()
	ln.color = Color(C_GOLD_DIM, 0.16)
	ln.custom_minimum_size = Vector2(0, 2)
	wrap.add_child(ln)
	rows.add_child(wrap)


func _A_new_chip() -> Control:
	var p := _pc(_sb(C_GOLD, Color("#6a4416"), 2, 4), 8, 0)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(DK.lbl("YENİ", DK.FS_LABEL, Color("#24160a"), HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _A_records(rows: VBoxContainer) -> void:
	var gl := {"#": C_TAG, "h": C_TAG}
	_A_section(rows, "EN İYİ KOŞU")
	for r: Array in _record_rows():
		var fresh: bool = NEW_KEYS.has(r[0])
		var right: HBoxContainer = DK.h(14)
		if fresh:
			right.add_child(_A_new_chip())
		right.add_child(DK.lbl(r[3], DK.FS_BODY, C_GOLD if fresh else C_GOLD_DIM))
		_A_row(rows, Pic.new(r[1], gl, 3), r[2], "", right, fresh)
	_A_section(rows, "TOPLAM")
	var vic: HBoxContainer = DK.h(12)
	vic.add_child(DK.icon(_face(2), 48))
	vic.add_child(DK.lbl(str(int(REC["victories"])), DK.FS_BODY, C_GOLD_DIM))
	var tot: Array = [
		[P_FLAG, "Toplam koşu", "", DK.lbl(str(int(REC["runs"])), DK.FS_BODY, C_GOLD_DIM)],
		[P_CROWN, "Zafer", "Kazanan kahramanlar", vic],
		[P_SWORDS, "Toplam öldürme", "", DK.lbl(_num(int(REC["total_kills"])), DK.FS_BODY, C_GOLD_DIM)],
		[P_HOURGLASS, "Toplam oyun süresi", "", DK.lbl(_hours(REC["total_time"]), DK.FS_BODY, C_GOLD_DIM)],
	]
	for r: Array in tot:
		_A_row(rows, Pic.new(r[0], gl, 3), r[1], r[2], r[3], false, 64.0 if r[2] == "" else 72.0)
	_A_section(rows, "SIRADAKİ BAŞARIM")
	var d: Dictionary = _def("total_kills_10000")
	var right: HBoxContainer = DK.h(12)
	right.add_child(PBar.new().setup(_ach_frac(d), C_GOLD, Color("#140e09"), Color("#3b2a1a"), 220, 18))
	right.add_child(DK.lbl(_ach_count(d), DK.FS_LABEL, C_TAG))
	_A_row(rows, _medal("total_kills_10000", "disk", 48, 48, 3), str(d["name"]), str(d["desc"]), right, false, 72.0)


func _A_achievements(rows: VBoxContainer) -> void:
	var locked: Array = []
	var done: Array = []
	for d: Dictionary in ach_defs:
		if UNLOCKED.has(str(d["id"])):
			done.append(d)
		else:
			locked.append(d)
	locked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _ach_frac(a) > _ach_frac(b))
	done.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(UNLOCKED[a["id"]]) > str(UNLOCKED[b["id"]]))
	_A_section(rows, "YAKINDA", "%d kilitli" % locked.size())
	for i in locked.size():
		var d: Dictionary = locked[i]
		var right: HBoxContainer = DK.h(12)
		right.add_child(PBar.new().setup(_ach_frac(d), C_GOLD, Color("#140e09"), Color("#3b2a1a"), 200, 18))
		var cl: Label = DK.lbl(_ach_count(d), DK.FS_LABEL, C_TAG, HORIZONTAL_ALIGNMENT_RIGHT)
		cl.custom_minimum_size.x = 150
		right.add_child(cl)
		_A_row(rows, _medal(str(d["id"]), "disk", 48, 48, 3), str(d["name"]), str(d["desc"]), right, i == 0, 72.0)
	_A_section(rows, "AÇILANLAR", "%d" % done.size())
	for d: Dictionary in done:
		var right: HBoxContainer = DK.h(10)
		right.add_child(DK.glyph(P_CHECK, C_GOLD, 3))
		right.add_child(DK.lbl(_date(str(UNLOCKED[d["id"]])), DK.FS_LABEL, C_SUB))
		_A_row(rows, _medal(str(d["id"]), "disk", 48, 48, 3), str(d["name"]), str(d["desc"]), right, false, 72.0)


func _def(id: String) -> Dictionary:
	for d: Dictionary in ach_defs:
		if str(d["id"]) == id:
			return d
	return {}


## ================================================================== B - Kupa Rafı
const B_SH := 158.0
const B_PLANK := 104.0
const B_COLS := 6


func _B(rc: Control) -> void:
	_dim(rc, Color(0.06, 0.04, 0.02, 0.74))
	var kit: RefCounted = SDK.new(SDK.PAL_WOOD)
	var win := PanelContainer.new()
	var st: StyleBoxFlat = _shadowed(kit.sb(kit.c("panel"), kit.c("line_hi"), 3, 8))
	st.content_margin_left = 28
	st.content_margin_right = 28
	st.content_margin_top = 24
	st.content_margin_bottom = 24
	win.add_theme_stylebox_override("panel", st)
	win.theme = kit.theme()
	var v: VBoxContainer = kit.v(14)
	win.add_child(v)
	## başlık
	var tb: HBoxContainer = kit.h(16)
	tb.add_child(kit.icon(tex_kadeh, 64))
	var tv: VBoxContainer = kit.v(-6)
	tv.add_child(kit.lbl("REKORLAR", 48, kit.c("accent")))
	tv.add_child(kit.lbl("Kupa rafı  ·  %d koşu  ·  %s oyun" % [int(REC["runs"]), _hours(REC["total_time"])], 24, kit.c("dim")))
	tb.add_child(tv)
	tb.add_child(kit.sp(0, 0, true))
	var chip: PanelContainer = kit.box(kit.c("inset"), kit.c("line_hi"), 10)
	var ch: HBoxContainer = kit.h(12)
	ch.add_child(kit.icon(tex_madalyon, 32))
	var cv: VBoxContainer = kit.v(-8)
	cv.add_child(kit.lbl("BAŞARIM", 24, kit.c("dim")))
	cv.add_child(kit.lbl("%d / %d" % [UNLOCKED.size(), ach_defs.size()], 32, kit.c("price")))
	ch.add_child(cv)
	ch.add_child(kit.sp(4))
	chip.add_child(ch)
	tb.add_child(chip)
	v.add_child(tb)
	## pirinç plakalar
	var ph: HBoxContainer = kit.h(14)
	var caps := {"time": "EN UZUN SÜRE", "tier": "EN YÜKSEK KADEME", "kills": "EN ÇOK ÖLDÜRME", "layer": "SONSUZ KAT", "victory_time": "EN HIZLI ZAFER"}
	for r: Array in _record_rows():
		var p := Plaque.new()
		p.font = font
		p.cap = caps[r[0]]
		p.val = r[3]
		p.fresh = NEW_KEYS.has(r[0])
		p.custom_minimum_size = Vector2(264, 116)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ph.add_child(p)
	v.add_child(ph)
	## toplamlar satırı
	var tl: HBoxContainer = kit.h(16)
	tl.alignment = BoxContainer.ALIGNMENT_CENTER
	var parts := ["%d koşu" % int(REC["runs"]), "%d zafer" % int(REC["victories"]), "%s öldürme" % _num(int(REC["total_kills"])),
			"%s oyun" % _hours(REC["total_time"])]
	for i in parts.size():
		if i > 0:
			tl.add_child(kit.glyph(P_DIAMOND, kit.c("accent_dk"), 3))
		tl.add_child(kit.lbl(parts[i], 32, kit.c("text")))
	v.add_child(tl)
	## dolap + raflar + madalyalar
	var cw := 1424.0
	var cab := Cabinet.new()
	cab.sh = B_SH
	cab.plank_y = B_PLANK
	cab.custom_minimum_size = Vector2(cw, 3.0 * B_SH)
	cab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_w: float = cw / B_COLS
	var sel_id := "layer_10"
	## Her raf bir HBox (madalya + raf payı + ad + tarih/ilerleme dikey yuvalarda); elle konumlanan Label'lar kayıyordu.
	for row in 3:
		var hb: HBoxContainer = kit.h(0)
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cab.add_child(hb)
		hb.position = Vector2(0, row * B_SH + B_PLANK - 99)
		hb.size = Vector2(cw, 99 + 64)
		for i in range(row * B_COLS, mini((row + 1) * B_COLS, ach_defs.size())):
			var d: Dictionary = ach_defs[i]
			var id: String = d["id"]
			var is_locked: bool = not UNLOCKED.has(id)
			var slot: VBoxContainer = kit.v(0)
			slot.custom_minimum_size.x = slot_w
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(_medal(id, "disk", 84, 102, 4, {"pedestal": true, "glow": id == sel_id, "glow_col": Color("#f2c674")}))
			slot.add_child(kit.sp(0, 16))
			slot.add_child(kit.lbl(str(d["name"]), 24, kit.c("dim") if is_locked else (kit.c("accent") if id == sel_id else kit.c("text")),
					HORIZONTAL_ALIGNMENT_CENTER))
			if is_locked:
				var pc := CenterContainer.new()
				pc.custom_minimum_size.y = 18
				pc.add_child(PBar.new().setup(_ach_frac(d), kit.c("accent"), kit.c("inset"), kit.c("line"), 132, 10))
				slot.add_child(pc)
			else:
				slot.add_child(kit.lbl(_date(str(UNLOCKED[id])), 16, kit.c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
			hb.add_child(slot)
	v.add_child(cab)
	## seçili madalya şeridi
	var sd: Dictionary = _def(sel_id)
	var info: PanelContainer = kit.box(kit.c("inset"), kit.c("line_hi"), 14)
	var ih: HBoxContainer = kit.h(18)
	ih.add_child(_medal(sel_id, "disk", 72, 72, 4))
	var iv: VBoxContainer = kit.v(-2)
	iv.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_child(kit.lbl(str(sd["name"]), 32, kit.c("accent")))
	iv.add_child(kit.lbl(str(sd["desc"]) + "  Kilitli.", 24, kit.c("text")))
	ih.add_child(iv)
	ih.add_child(kit.sp(0, 0, true))
	var pv: VBoxContainer = kit.v(2)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(kit.lbl("İLERLEME", 24, kit.c("dim"), HORIZONTAL_ALIGNMENT_RIGHT))
	var prow: HBoxContainer = kit.h(14)
	prow.add_child(PBar.new().setup(_ach_frac(sd), kit.c("accent"), kit.c("panel"), kit.c("line_hi"), 320, 20))
	prow.add_child(kit.lbl(_ach_count(sd), 32, kit.c("price")))
	pv.add_child(prow)
	ih.add_child(pv)
	ih.add_child(kit.sp(6))
	info.add_child(ih)
	v.add_child(info)
	## düğmeler
	var bh: HBoxContainer = kit.h(16)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	var close: Button = kit.btn("Kapat", "primary", 32, 60, 320)
	close.focus_mode = Control.FOCUS_NONE
	bh.add_child(close)
	var bal: Button = kit.btn("Balans Verisi Klasörü", "ghost", 24, 60, 340)
	bal.focus_mode = Control.FOCUS_NONE
	bh.add_child(bal)
	v.add_child(bh)
	_center(rc, win)


## ================================================================== C - Kayrak Pano
func _C(rc: Control) -> void:
	_dim(rc, Color(0.02, 0.025, 0.04, 0.74))
	var kit: RefCounted = SDK.new(SDK.PAL_SLATE)
	var win := PanelContainer.new()
	var st: StyleBoxFlat = _shadowed(kit.sb(kit.c("panel"), kit.c("line_hi"), 3, 8))
	st.content_margin_left = 32
	st.content_margin_right = 32
	st.content_margin_top = 64
	st.content_margin_bottom = 26
	win.add_theme_stylebox_override("panel", st)
	win.theme = kit.theme()
	win.custom_minimum_size.x = 1440
	var v: VBoxContainer = kit.v(10)
	win.add_child(v)
	var med := TopMedal.new()
	med.tex = tex_kadeh
	med.lift = 60.0
	med.cols = [Color("#0b0e15"), kit.c("line_hi"), kit.c("line"), kit.c("inset")]
	med.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(med)
	v.add_child(kit.lbl("REKORLAR", 48, kit.c("accent"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(kit.lbl("%d koşu  ·  %d zafer  ·  %s öldürme  ·  %s oyun" % [int(REC["runs"]), int(REC["victories"]),
			_num(int(REC["total_kills"])), _hours(REC["total_time"])], 24, kit.c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	## ayraç
	var dv: HBoxContainer = kit.h(10)
	dv.custom_minimum_size.y = 20
	for i in 3:
		if i == 1:
			dv.add_child(kit.glyph(P_DIAMOND, kit.c("accent"), 3))
		else:
			var ln := ColorRect.new()
			ln.color = kit.c("line")
			ln.custom_minimum_size = Vector2(0, 3)
			ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			dv.add_child(ln)
	v.add_child(dv)
	## stat kutuları
	var th: HBoxContainer = kit.h(10)
	var caps := {"time": "EN UZUN SÜRE", "tier": "EN YÜKSEK KADEME", "kills": "TEK KOŞUDA ÖLDÜRME", "layer": "SONSUZ KAT", "victory_time": "EN HIZLI ZAFER"}
	var tcol := {"time": Color("#e9dcc0"), "tier": Color("#e9dcc0"), "kills": kit.c("bad"), "layer": Color("#b49cf0"), "victory_time": kit.c("accent")}
	for r: Array in _record_rows():
		var fresh: bool = NEW_KEYS.has(r[0])
		var tile: PanelContainer = kit.box(kit.c("panel2"), kit.c("accent_dk") if fresh else kit.c("line"), 14, 3, 6)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hb: HBoxContainer = kit.h(14)
		hb.add_child(Pic.new(r[1], {"#": tcol[r[0]], "h": Color("#fff6dc"), "k": kit.c("inset")}, 4))
		var tv: VBoxContainer = kit.v(-6)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var caprow: HBoxContainer = kit.h(8)
		caprow.add_child(kit.lbl(caps[r[0]], 24, kit.c("dim")))
		tv.add_child(caprow)
		var valrow: HBoxContainer = kit.h(10)
		valrow.add_child(kit.lbl(r[3], 48, kit.c("text")))
		if fresh:
			var nc := _pc(_sb(kit.c("accent"), kit.c("accent_dk"), 2, 4), 8, 0)
			nc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			nc.add_child(kit.lbl("YENİ", 16, kit.c("accent_text"), HORIZONTAL_ALIGNMENT_CENTER))
			valrow.add_child(nc)
		tv.add_child(valrow)
		hb.add_child(tv)
		tile.add_child(hb)
		th.add_child(tile)
	v.add_child(th)
	## başarım başlığı + genel ilerleme
	v.add_child(kit.sp(0, 4))
	var hh: HBoxContainer = kit.h(14)
	hh.add_child(kit.lbl("BAŞARIMLAR", 32, kit.c("accent")))
	hh.add_child(kit.lbl("%d / %d" % [UNLOCKED.size(), ach_defs.size()], 32, kit.c("text")))
	var gb := PBar.new().setup(float(UNLOCKED.size()) / ach_defs.size(), kit.c("accent"), kit.c("inset"), kit.c("line"), 0, 18)
	gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(gb)
	hh.add_child(kit.lbl("%%%d" % roundi(100.0 * UNLOCKED.size() / ach_defs.size()), 24, kit.c("dim")))
	v.add_child(hh)
	## kartlar
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for d: Dictionary in ach_defs:
		grid.add_child(_C_card(kit, d))
	v.add_child(grid)
	## düğmeler
	v.add_child(kit.sp(0, 6))
	var bh: HBoxContainer = kit.h(16)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	var close: Button = kit.btn("Kapat", "primary", 32, 60, 380)
	close.focus_mode = Control.FOCUS_NONE
	bh.add_child(close)
	var bal: Button = kit.btn("Balans Verisi Klasörü", "ghost", 24, 60, 380)
	bal.focus_mode = Control.FOCUS_NONE
	bh.add_child(bal)
	v.add_child(bh)
	_center(rc, win)


func _C_card(kit: RefCounted, d: Dictionary) -> Control:
	var id: String = d["id"]
	var done: bool = UNLOCKED.has(id)
	var card: PanelContainer = kit.box(kit.c("panel2") if done else kit.c("inset"), kit.c("line_hi") if done else kit.c("line"), 8, 2, 6)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 72
	var hb: HBoxContainer = kit.h(12)
	hb.add_child(_medal(id, "tile", 56, 56, 4, {"outline": Color("#0b0e15"), "dark_fill": kit.c("inset"), "dark_rim": kit.c("line"),
			"lock_col": kit.c("dim")}))
	var tv: VBoxContainer = kit.v(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	var top: HBoxContainer = kit.h(8)
	var nl: Label = kit.lbl(str(d["name"]), 32, kit.c("text") if done else kit.c("dim"))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nl)
	if done:
		top.add_child(kit.glyph(P_CHECK, kit.c("good"), 2))
		top.add_child(kit.lbl(_date(str(UNLOCKED[id])).substr(0, 5), 16, kit.c("good")))
	else:
		top.add_child(kit.lbl(_ach_count(d), 16, kit.c("dim")))
	tv.add_child(top)
	tv.add_child(kit.lbl(str(d["desc"]), 16, kit.c("dim")))
	if not done:
		tv.add_child(kit.sp(0, 4))
		var pb := PBar.new().setup(_ach_frac(d), kit.c("accent"), kit.c("panel"), Color(0, 0, 0, 0), 0, 6)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(pb)
	hb.add_child(tv)
	card.add_child(hb)
	return card


## ================================================================== D - Kahraman Defteri
func _D_panel(rc: Control, pos: Vector2, sz: Vector2, title: String, right: Control) -> VBoxContainer:
	var p: PanelContainer = DK.box(DK.C_PANEL, DK.C_LINE_HI, 18, 3, 6)
	rc.add_child(p)
	p.position = pos
	p.size = sz
	p.custom_minimum_size = sz
	var v: VBoxContainer = DK.v(10)
	p.add_child(v)
	v.add_child(DK.title_bar(title, right))
	v.add_child(DK.hline(3.0))
	return v


func _D(rc: Control) -> void:
	rc.theme = DK.theme()
	_dim(rc, Color(0.02, 0.03, 0.04, 0.42))
	## üst çubuk
	var back: Button = DK.btn("GERİ", "ghost", DK.FS_BODY, 56, 150)
	back.focus_mode = Control.FOCUS_NONE
	rc.add_child(back)
	back.position = Vector2(48, 40)
	var tv: VBoxContainer = DK.v(-6)
	tv.add_child(DK.lbl("REKORLAR", DK.FS_TITLE, DK.C_ACCENT))
	tv.add_child(DK.lbl("Kahraman defteri  ·  son koşu 17.10", DK.FS_LABEL, DK.C_DIM))
	rc.add_child(tv)
	tv.position = Vector2(224, 34)
	var chips: HBoxContainer = DK.h(10)
	chips.add_child(DK.chip(P_FLAG, "%d KOŞU" % int(REC["runs"]), DK.C_TEXT))
	chips.add_child(DK.chip(DK.G_CROWN, "%d ZAFER" % int(REC["victories"]), DK.C_PRICE))
	chips.add_child(DK.chip(P_SWORDS, "%s ÖLDÜRME" % _num(int(REC["total_kills"])), DK.C_TEXT))
	chips.add_child(DK.chip(P_HOURGLASS, _hours(REC["total_time"]).to_upper(), DK.C_TEXT))
	rc.add_child(chips)
	chips.position = Vector2(1872 - 860, 44)
	chips.size = Vector2(860, 48)
	chips.alignment = BoxContainer.ALIGNMENT_END
	## sol: en iyi koşu
	var lv := _D_panel(rc, Vector2(48, 128), Vector2(476, 904), "EN İYİ KOŞUN", DK.chip(DK.G_CROWN, "ZAFER", DK.C_ACCENT))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 236)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spot: Control = DK.Spot.new(DK.C_SPOT, 0.86)
	spot.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(spot)
	var por := _tr(load(str(chars.get_def(2).get("portrait", ""))) as Texture2D, 192)
	stage.add_child(por)
	por.position = Vector2(220 - 96, 18)
	lv.add_child(stage)
	lv.add_child(DK.lbl(_cname(2), DK.FS_TITLE, DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	lv.add_child(DK.lbl("Final  ·  zafer 47:12  ·  16.10.2026", DK.FS_LABEL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	lv.add_child(DK.sp(0, 6))
	var gl := {"#": DK.C_DIM, "h": DK.C_DIM}
	var short := {"time": "En uzun süre", "tier": "En yüksek kademe", "kills": "En çok öldürme", "layer": "Sonsuz kat", "victory_time": "En hızlı zafer"}
	for r: Array in _record_rows():
		var fresh: bool = NEW_KEYS.has(r[0])
		var row: HBoxContainer = DK.h(10)
		row.custom_minimum_size.y = 56
		var ib := CenterContainer.new()
		ib.custom_minimum_size = Vector2(40, 0)
		ib.add_child(Pic.new(r[1], gl, 3))
		row.add_child(ib)
		var nl: Label = DK.lbl(short[r[0]], DK.FS_LABEL, DK.C_DIM)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		if fresh:
			var nc: Control = DK.chip([], "YENİ", DK.C_PRICE, DK.FS_SMALL)
			nc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(nc)
		var hs: Control = DK.slot(_face(int(HOLDER[r[0]])), 24)
		hs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hs)
		var vl: Label = DK.lbl(r[3], DK.FS_BODY, DK.C_PRICE if fresh else DK.C_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(vl)
		lv.add_child(row)
		var ln := ColorRect.new()
		ln.color = DK.C_LINE
		ln.custom_minimum_size = Vector2(0, 2)
		lv.add_child(ln)
	## orta: son koşular
	var mv := _D_panel(rc, Vector2(540, 128), Vector2(820, 904), "SON KOŞULAR", DK.lbl("son %d" % RUNS.size(), DK.FS_LABEL, DK.C_DIM))
	var cols_w := [72.0, 220.0, 96.0, 96.0, 104.0, 0.0]
	var head: HBoxContainer = DK.h(8)
	var heads := ["TARİH", "KAHRAMAN", "SÜRE", "KADEME", "ÖLDÜRME", "SONUÇ"]
	for i in heads.size():
		var hl: Label = DK.lbl(heads[i], DK.FS_SMALL, DK.C_DIM)
		hl.custom_minimum_size.x = cols_w[i]
		if i == heads.size() - 1:
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.add_child(hl)
	var hp := _pc(StyleBoxEmpty.new(), 12, 0)
	hp.add_child(head)
	mv.add_child(hp)
	for i in RUNS.size():
		var r: Array = RUNS[i]
		var win: bool = r[5] == "ZAFER"
		var rowp: PanelContainer = DK.box(DK.C_PANEL3 if win else (DK.C_PANEL2 if i % 2 == 0 else DK.C_INSET),
				DK.C_ACCENT if win else DK.C_LINE, 12, 2 if not win else 3, 4)
		rowp.custom_minimum_size.y = 80
		var hb: HBoxContainer = DK.h(8)
		var dl: Label = DK.lbl(str(r[0]), DK.FS_LABEL, DK.C_DIM)
		dl.custom_minimum_size.x = cols_w[0]
		hb.add_child(dl)
		var who: HBoxContainer = DK.h(10)
		who.custom_minimum_size.x = cols_w[1]
		who.add_child(DK.slot(_face(int(r[1])), 48))
		who.add_child(DK.lbl(_cname(int(r[1])), DK.FS_LABEL, DK.C_TEXT))
		hb.add_child(who)
		var vals := [_tm(r[2]), _tier_txt(int(r[3])), _num(int(r[4]))]
		for j in 3:
			var is_rec: bool = (j == 2 and int(r[4]) == int(REC["best_kills"])) or (j == 1 and int(r[3]) >= 16)
			var vl: Label = DK.lbl(vals[j], DK.FS_BODY, DK.C_PRICE if is_rec else DK.C_TEXT)
			vl.custom_minimum_size.x = cols_w[2 + j]
			hb.add_child(vl)
		var res_col: Color = DK.C_ACCENT if win else (DK.C_BAD if r[5] == "ÖLDÜ" else DK.C_DIM)
		var cc := CenterContainer.new()
		cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cc.add_child(DK.chip(DK.G_CROWN if win else ([] as Array), str(r[5]), res_col, DK.FS_LABEL))
		hb.add_child(cc)
		rowp.add_child(hb)
		mv.add_child(rowp)
	mv.add_child(DK.sp(0, 4))
	mv.add_child(DK.lbl("Koşu başına ortalama  18:45  ·  295 öldürme", DK.FS_LABEL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	## sağ: kahramanlar + başarımlar
	var played: int = 0
	for cid: int in HERO_ORDER:
		if int(HERO_BEST[cid]) > 0:
			played += 1
	var rv := _D_panel(rc, Vector2(1384, 128), Vector2(488, 904), "KAHRAMANLAR", DK.lbl("%d / %d oynandı" % [played, HERO_ORDER.size()], DK.FS_LABEL, DK.C_DIM))
	var hg := GridContainer.new()
	hg.columns = 4
	hg.add_theme_constant_override("h_separation", 10)
	hg.add_theme_constant_override("v_separation", 8)
	for cid: int in HERO_ORDER:
		var best: int = HERO_BEST[cid]
		var cell: VBoxContainer = DK.v(2)
		cell.custom_minimum_size.x = 104
		var tile: PanelContainer = DK.box(DK.C_PANEL3 if best >= 16 else (DK.C_INSET if best <= 0 else DK.C_PANEL2),
				DK.C_ACCENT if best >= 16 else DK.C_LINE, 6, 2 if best < 16 else 3, 4)
		var fc := Control.new()
		fc.custom_minimum_size = Vector2(64, 64)
		fc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face: TextureRect = _tr(_face(cid), 48)
		fc.add_child(face)
		face.position = Vector2(8, 8)
		if best < 0:
			face.modulate = Color(0.15, 0.17, 0.17)
			var lk: Control = DK.glyph(DK.G_LOCK, DK.C_DIM, 3)
			fc.add_child(lk)
			lk.position = Vector2(22, 22)
		elif best == 0:
			face.modulate = Color(0.55, 0.6, 0.6)
		if best >= 16:
			var cr: Control = DK.glyph(DK.G_CROWN, DK.C_PRICE, 3)
			fc.add_child(cr)
			cr.position = Vector2(42, -2)
		tile.add_child(fc)
		var tcc := CenterContainer.new()
		tcc.add_child(tile)
		cell.add_child(tcc)
		var tt: String = "kilitli" if best < 0 else ("-" if best == 0 else _tier_txt(best))
		cell.add_child(DK.lbl(tt, DK.FS_LABEL if best != 0 else DK.FS_LABEL,
				DK.C_PRICE if best >= 16 else (DK.C_DIM if best <= 0 else DK.C_TEXT), HORIZONTAL_ALIGNMENT_CENTER))
		hg.add_child(cell)
	rv.add_child(hg)
	rv.add_child(DK.sp(0, 6))
	rv.add_child(DK.title_bar("BAŞARIMLAR", DK.lbl("%d / %d" % [UNLOCKED.size(), ach_defs.size()], DK.FS_LABEL, DK.C_TEXT)))
	rv.add_child(DK.hline(3.0))
	var ag := GridContainer.new()
	ag.columns = 6
	ag.add_theme_constant_override("h_separation", 12)
	ag.add_theme_constant_override("v_separation", 8)
	for d: Dictionary in ach_defs:
		ag.add_child(_medal(str(d["id"]), "disk", 60, 60, 3, {"outline": Color("#07100e"), "dark_fill": DK.C_INSET,
				"dark_rim": DK.C_LINE, "lock_col": DK.C_DIM}))
	var agc := CenterContainer.new()
	agc.add_child(ag)
	rv.add_child(agc)
	rv.add_child(DK.sp(0, 4))
	var nd: Dictionary = _def("total_kills_10000")
	var nx: HBoxContainer = DK.h(10)
	nx.add_child(DK.lbl("Sıradaki:", DK.FS_LABEL, DK.C_DIM))
	var nn: Label = DK.lbl(str(nd["name"]), DK.FS_LABEL, DK.C_ACCENT)
	nn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nx.add_child(nn)
	nx.add_child(DK.lbl(_ach_count(nd), DK.FS_LABEL, DK.C_TEXT))
	rv.add_child(nx)
	rv.add_child(PBar.new().setup(_ach_frac(nd), DK.C_ACCENT, DK.C_INSET, DK.C_LINE, 0, 14))


## ================================================================== akış
func _write_fake_records(rr: GDScript) -> void:
	var data: Dictionary = rr.call("_defaults")
	for k: String in REC.keys():
		data[k] = REC[k]
	var ach: Dictionary = {}
	for id: String in UNLOCKED.keys():
		ach[id] = Time.get_unix_time_from_datetime_string(str(UNLOCKED[id]) + "T21:00:00")
	data["achievements"] = ach
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	rr.call("set_path_override", ProjectSettings.globalize_path(FAKE_CFG))
	rr.call("_save", data)


func _menu_visible(on: bool) -> void:
	for n: String in ["TitleSign", "MenuPanel", "PartyLine", "DebugButton"]:
		var c := current_scene.get_node_or_null(n) as CanvasItem
		if c:
			c.visible = on


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var only: String = OS.get_environment("REKOR_ONLY")
	var kinds: Array = ["A", "A_basarim", "B", "C", "D"]
	if only != "":
		kinds = Array(only.split(","))
	font = load("res://assets/fonts/m5x7.ttf")
	FM = load("res://scripts/fire_menu_kit.gd")
	DK = load("res://scripts/menu_dark_kit.gd")
	SDK = load("res://scripts/shop_dark_kit.gd")
	LobbyUI = load("res://scripts/menu_lobby_ui.gd")
	chars = load("res://scripts/characters.gd")
	var ach_script = load("res://scripts/achievements.gd")
	ach_defs = ach_script.DEFS
	tex_kadeh = load("res://assets/items/kralin_kadehi.png")
	tex_madalyon = load("res://assets/items/lutuf_madalyonu.png")
	var rr: GDScript = load("res://scripts/run_records.gd")
	_write_fake_records(rr)
	root.get_node("UISound").set("show_fps", false)
	change_scene_to_file("res://scenes/main_menu.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "MainMenu") and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	Input.warp_mouse(Vector2(1910, 1070))
	await _wait(2.5)

	var shots: Dictionary = {}
	for k: String in kinds:
		var layers: Array = []
		var rs: Node = null
		if k == "simdi" or k.begins_with("oyunda"):
			current_scene.call("_on_records_pressed")
			await _wait(0.2)
			rs = current_scene.get_node_or_null("RecordsScreen")
			if rs and k == "oyunda_basarim":
				rs.call("_set_category", 1, false)
		else:
			if k in ["A", "A_basarim", "D"]:
				_menu_visible(false)
			var l := CanvasLayer.new()
			l.layer = 96
			root.add_child(l)
			layers.append(l)
			var rc := _full(l)
			match k:
				"A":
					_A(rc, "rekor")
				"A_basarim":
					_A(rc, "basarim")
				"B":
					_B(rc)
				"C":
					_C(rc)
				"D":
					_D(rc)
		var cl := CanvasLayer.new()
		layers.append(cl)
		_caption(cl, k)
		root.add_child(cl)
		await _wait(1.0)
		shots[k] = await _shot(k)
		if rs:
			rs.call("close")
		for l: Node in layers:
			l.queue_free()
		_menu_visible(true)
		await _wait(0.3)

	var names := ["A", "B", "C", "D"]
	var ok := true
	for n: String in names:
		ok = ok and shots.has(n)
	if ok:
		var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
		for i in 4:
			var im: Image = (shots[names[i]] as Image).duplicate()
			im.convert(Image.FORMAT_RGBA8)
			im.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			@warning_ignore("integer_division")
			sheet.blit_rect(im, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
		sheet.save_png(ProjectSettings.globalize_path(OUT + "ozet.png"))
		print("SHOT ozet")
	rr.call("set_path_override", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FAKE_CFG))
	quit()
