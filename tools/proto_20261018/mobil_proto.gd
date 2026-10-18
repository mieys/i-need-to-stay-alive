extends SceneTree

## MOBİL ARAYÜZ PROTOTİPLERİ (2026-10-18). Kullanıcı: "oyunumun android sürümündeki BÜTÜN arayüzü ve tasarımı baştan mobile uyumlu
## olacak şekilde güncellediğin 4 prototip hazırlar mısın (herşey olacak dükkan seyyar satıcı demirci ana menü herşey)".
## Bugün telefon = masaüstü ekranlarının RootFitter/MenuFitter ile küçültülmüşü (mobile_menu_fit.gd); madde 185-250'deki yeni masaüstü
## ekranları (Seçim D, Ocak Başı, Klasik Pazar, Örs Vitrini, Ruh Mağazası F, Ateş Işığı, Ahşap Pano) telefona hiç uyarlanmadı.
## Oyuna BAĞLI DEĞİL. 2400x1080 = 20:9 yatay telefon (oyunun 1080 satırlık tuvali EXPAND), yan güvenli kenar 96 px (çentik/köşe),
## dokunma hedefi >= 112 px, yazı m5x7 32/48/64/96 (16'nın tam katları = keskin). Arka planlar GERÇEK: menü ekranları canlı Ocak Başı
## sahnesi (menu_hearth_bg.gd), oyun içi ekranlar gerçek main.tscn karesi (telefon kamerası, --mobile-ui). Sanat oyundaki dokular
## (portre, karakter sprite'ı, eşya/silah/yetenek/stat ikonları, sandık + ışık sütunu, minimap); veri gerçek kataloglar + sahte koşu.
##  A Ateş Işığı / Başparmak Çubuğu : üst şerit (geri + başlık + para), ortada yatay kayan büyük kartlar (seçili kart açılır),
##      ALT ÇUBUK: solda ikincil eylemler (sol başparmak), sağda tek büyük birincil eylem (sağ başparmak). HUD klasik (joystick + yay).
##  B Gece Sıvası / Yan Ray + Detay : solda dikey ikon rayı (sekmeler), ortada ızgara/liste, sağda detay paneli + en altta birincil eylem.
##      HUD kenar sütunları (solda can + grup, sağda kare minimap + L biçimli yetenekler, sabit joystick).
##  C Kayrak / Alt Çekmece          : sahne üstte görünür kalır, içerik alttan çıkan çekmecede (sekmeler + yatay şerit), seçilenin vitrini
##      sahnenin üstünde, birincil eylem çekmecenin sağ üstünde. HUD alt konsol (can/kalkan/XP altta ortada, 2x2 yetenek).
##  D Kısık Ahşap / Tek Odak        : ortada tek büyük kart (yanlarda soluk komşular), kenarlarda dev oklar, altta dev birincil düğme,
##      köşelerde başparmak hapları. HUD minimal (görünmez joystick, ince üst çubuk, gerisi menü/çanta arkasında).
## Kullanım: Godot --path . --windowed --resolution 2400x1080 -s tools/proto_20261018/mobil_proto.gd -- --mobile-ui
##   MOBIL_ONLY = "A" / "A:hud,B:seyyar" / "*:hud" seçili çekimler (boşsa hepsi + özet sayfaları). Çıktı out/mobil/.

const OUT := "res://tools/proto_20261018/out/mobil/"
const SW := 2400.0
const SH := 1080.0
const SX := 96.0
const SY := 28.0
const RX := 2304.0
const DIRS := ["A", "B", "C", "D"]
const SCREENS := ["ana_menu", "oda", "karakter", "hud", "level", "sandik", "envanter", "seyyar", "demirci", "ruh", "duraklat",
		"ayarlar", "oyun_bitti", "rekor"]
const MENU_SCREENS := ["ana_menu", "oda", "karakter", "ruh", "ayarlar", "rekor"]
const SCREEN_NAMES := {
	"ana_menu": "Ana menü", "oda": "Çok oyunculu / odalar", "karakter": "Karakter seçimi", "hud": "Oyun içi arayüz",
	"level": "Level atlama", "sandik": "Sandık ödülü", "envanter": "Envanter", "seyyar": "Seyyar Satıcı", "demirci": "Demirci",
	"ruh": "Ruh Mağazası", "duraklat": "Duraklatma", "ayarlar": "Ayarlar (dokunmatik)", "oyun_bitti": "Oyun Bitti", "rekor": "Rekorlar",
	"level_2": "Level atlama (2)", "sandik_2": "Sandık ödülü (2)", "oda_2": "Çok oyunculu (2)",
}
const DIR_NAMES := {
	"S": "SEÇİLEN SET: ana menü / duraklatma / ayarlar = A düzeni + B renkleri, diğerleri B",
	"A": "A - Ateş Işığı: Başparmak Çubuğu", "B": "B - Gece Sıvası: Yan Ray + Detay",
	"C": "C - Kayrak: Alt Çekmece", "D": "D - Kısık Ahşap: Tek Odak",
}

const SKINS := {
	"A": {"panel": Color("#1d1611"), "panel2": Color("#2b2119"), "panel3": Color("#3b2f24"), "inset": Color("#130d08"),
		"line": Color("#4a3826"), "line_hi": Color("#8a6a42"), "text": Color("#efe2c6"), "dim": Color("#b09878"),
		"accent": Color("#f4c56e"), "accent_dk": Color("#6a4416"), "accent_text": Color("#24160a"), "good": Color("#a9c96e"),
		"bad": Color("#dc7f60"), "price": Color("#f2c674"), "rim": Color("#8a6a42"), "dimbg": Color(0.05, 0.03, 0.02), "rad": 0, "bw": 4},
	"B": {"panel": Color("#1a1a2c"), "panel2": Color("#23233a"), "panel3": Color("#302f4c"), "inset": Color("#12121f"),
		"line": Color("#3b3a5a"), "line_hi": Color("#5f5c86"), "text": Color("#efe6d6"), "dim": Color("#a7a2c0"),
		"accent": Color("#f4c56e"), "accent_dk": Color("#6a5226"), "accent_text": Color("#231a0a"), "good": Color("#a8d69a"),
		"bad": Color("#e38c7c"), "price": Color("#f0da94"), "rim": Color("#5f5c86"), "dimbg": Color(0.03, 0.03, 0.06), "rad": 14, "bw": 3},
	"C": {"panel": Color("#1b212e"), "panel2": Color("#242c3b"), "panel3": Color("#2f3a4f"), "inset": Color("#121722"),
		"line": Color("#353f55"), "line_hi": Color("#56657f"), "text": Color("#ece6d7"), "dim": Color("#96a0b2"),
		"accent": Color("#d9b46a"), "accent_dk": Color("#6e5426"), "accent_text": Color("#21180a"), "good": Color("#94c97e"),
		"bad": Color("#dc8676"), "price": Color("#eccb7e"), "rim": Color("#56657f"), "dimbg": Color(0.03, 0.04, 0.07), "rad": 6, "bw": 3},
	"D": {"panel": Color("#5a4734"), "panel2": Color("#3e2b1c"), "panel3": Color("#6e5238"), "inset": Color("#271a11"),
		"line": Color("#20150d"), "line_hi": Color("#86623f"), "text": Color("#f3e6cc"), "dim": Color("#c4b090"),
		"accent": Color("#f0c070"), "accent_dk": Color("#7a4e18"), "accent_text": Color("#24160a"), "good": Color("#b5d98a"),
		"bad": Color("#f09a80"), "price": Color("#f6d27e"), "rim": Color("#6a4a30"), "dimbg": Color(0.06, 0.04, 0.02), "rad": 0, "bw": 4},
}

const LV_COL := [Color("#b8b0a0"), Color("#6f9df2"), Color("#b98af2"), Color("#f0c070")]
const LV_NAMES := ["SIRADAN", "NADİR", "EPİK", "EFSANEVİ"]
const IT_COL := [Color("#c39a64"), Color("#6f9df2"), Color("#b98af2")]
const IT_NAMES := ["PARÇA", "EPİK", "EFSANEVİ"]
const ENCH_COL := [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.47, 0.91, 0.35), Color(0.31, 0.63, 1.0), Color(0.73, 0.49, 1.0),
		Color(1.0, 0.33, 0.28)]
const ROMAN := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV"]
const HP_COL := Color("#d04a3e")
const SH_COL := Color("#76b6ee")
const XP_COL := Color("#9ad06a")
const SOUL_COL := Color("#b4f1f5")
const SPIRIT_COL := Color("#a77ee0")

## ------------------------------------------------------------------ sahte koşu (gerçek kataloglarla)
const ME := 2
const TEAM := [
	{"name": "Sen", "char": 2, "hp": 412.0, "mhp": 520.0, "sh": 180.0, "msh": 240.0, "lv": 12, "dmg": 48210, "ready": true},
	{"name": "Mira", "char": 10, "hp": 300.0, "mhp": 610.0, "sh": 40.0, "msh": 200.0, "lv": 12, "dmg": 31800, "ready": true},
	{"name": "Kerem", "char": 5, "hp": 90.0, "mhp": 430.0, "sh": 60.0, "msh": 160.0, "lv": 11, "dmg": 52740, "ready": false},
	{"name": "Deniz", "char": 15, "hp": 380.0, "mhp": 380.0, "sh": 120.0, "msh": 120.0, "lv": 12, "dmg": 27110, "ready": false},
]
const GOLD := 1240
const WSHARD := 6
const SOUL := 520
const LEVEL := 12
const TIER := 7
const RUN_TIME := "18:42"
const KILLS := 1204
const WEAPONS := [["tufek", 3], ["dagger", 2], ["fire_staff", 1]]
const BAG := ["anka_kusunun_kalbi", "zaman_kiran", "ruzgar_eldiveni", "sarsilmaz_kabuk", "ceviklik_yuzugu", "bile_tasi", "tornavida"]
const BAG_SEL := "zaman_kiran"
const PET := "peri"
const SPIRIT := "can"
const SHOP_SEL := "ruzgar_eldiveni"
const LOCKED_CHARS := [13, 14]
const SOUL_SEL := 13
const LV_OPTS := [
	{"stat": "max_health", "name": "Can", "val": "+50", "tier": 2, "desc": "Azami canın 50 artar.", "now": "520 -> 570", "count": 2},
	{"stat": "fire_rate", "name": "Saldırı Hızı", "val": "+%8", "tier": 1, "desc": "Tüm silahların %8 daha sık saldırır.",
		"now": "%34 -> %42", "count": 3},
	{"stat": "crit_chance", "name": "Kritik Şansı", "val": "+%9", "tier": 3, "desc": "Vuruşların %9 daha sık kritik olur.",
		"now": "%12 -> %21", "count": 0},
]
const ROOMS := [
	{"name": "Mira'nın odası", "host": 10, "players": [10, 5], "lock": false, "ping": 38, "stage": "Karakter seçiyor"},
	{"name": "gece avı", "host": 8, "players": [8, 1, 12], "lock": true, "ping": 64, "stage": "Karakter seçiyor"},
	{"name": "yeni başlayan", "host": 3, "players": [3], "lock": false, "ping": 121, "stage": "Bekliyor"},
	{"name": "K15 deneme", "host": 11, "players": [11, 4, 9, 7], "lock": false, "ping": 52, "stage": "Dolu"},
]
const RECORDS := [
	["EN UZUN KOŞU", "52:30", "clock", false],
	["EN YÜKSEK KADEME", "FİNAL", "horns", false],
	["TEK KOŞUDA ÖLDÜRME", "3.412", "skull", true],
	["EN HIZLI ZAFER", "47:12", "crown", false],
	["SONSUZ KAT", "2", "sword", false],
]
const UNLOCKED := {
	"tier_5": "05.10.2026", "time_15": "05.10.2026", "kills_500": "06.10.2026", "tier_10": "08.10.2026",
	"runs_10": "09.10.2026", "time_30": "11.10.2026", "kills_3000": "13.10.2026", "tier_15": "14.10.2026",
	"final": "16.10.2026", "victory": "16.10.2026", "victory_coop": "16.10.2026",
}
const GO := {"time": "24:12", "tier": 9, "kills": 1986, "level": 17, "gold": 3420, "soul": 86}
const SET_CATS := ["GENEL", "GRAFİK", "DOKUNMATİK", "SES"]
## Ayar satırları [ad, tür, değer, (eski açıklama alanı - boş: 2026-10-18 "yapay zekâ gibi" turunda satır açıklamaları kalktı), yazı].
const SET_ROWS := [
	["Joystick", "cycle", "Yüzen", "", ""],
	["Düğme boyutu", "slider", 0.6, "", "%110"],
	["Arayüz saydamlığı", "slider", 0.85, "", "%85"],
	["Solak düzen", "toggle", false, "", ""],
	["Titreşim", "toggle", true, "", ""],
	["Hasar sayıları", "toggle", true, "", ""],
	["Düğmeleri yerleştir", "button", "DÜZENLE", "", ""],
]
const UPG_LV := {"pickup": 3, "attack": 5, "atk_speed": 2, "hp": 4, "shield": 0, "regen": 1, "speed": 2, "luck": 0}

## ------------------------------------------------------------------ piksel simgeler (# ana, h açık, k koyu)
const G_BACK := ["...#......", "..##......", ".#########", "##########", ".#########", "..##......", "...#......"]
const G_X := ["##...##", "###.###", ".#####.", "..###..", ".#####.", "###.###", "##...##"]
const G_PLAY := ["##.......", "####.....", "######...", "########.", "#########", "########.", "######...", "####.....", "##......."]
const G_PLUS := ["..###..", "..###..", "#######", "#######", "#######", "..###..", "..###.."]
const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###k###", "###k###", "#######"]
const G_REROLL := ["..####.#", ".#....##", "#....###", "#.......", ".......#", "###....#", "##....#.", "#.####.."]
const G_GEAR := ["...#.#...", ".#######.", ".##...##.", "##.....##", ".#.....#.", "##.....##", ".##...##.", ".#######.", "...#.#..."]
const G_TROPHY := ["#########", "#.#####.#", "#.#####.#", ".#######.", "..#####..", "...###...", "....#....", "..#####..", ".#######."]
const G_BAG := ["...###...", "..#...#..", ".#######.", "#########", "####h####", "#########", "#########", ".#######."]
const G_USER := ["...###...", "..#####..", "..#####..", "...###...", ".........", ".#######.", "#########", "#########"]
const G_USERS := [".##...##.", "####.####", "####.####", ".##...##.", ".........", "####.####", "####.####"]
const G_CHAT := [".#######.", "#########", "##.#.#.##", "#########", ".#######.", "..##.....", ".#......."]
const G_PAUSE := ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##"]
const G_HEART := [".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."]
const G_STAR := ["....#....", "...###...", "#########", ".#######.", "..#####..", ".###.###.", "##.....##"]
const G_HAMMER := ["######...", "######...", "######...", "..##.....", "...##....", "....##...", ".....##..", "......##."]
const G_HOME := ["....#....", "...###...", "..#####..", ".#######.", "#########", ".##...##.", ".##...##.", ".##...##."]
const G_CHEV_L := ["....#", "...##", "..##.", ".##..", "##...", ".##..", "..##.", "...##", "....#"]
const G_CHEV_R := ["#....", "##...", ".##..", "..##.", "...##", "..##.", ".##..", "##...", "#...."]
const G_HAND := ["..#......", ".###.....", ".###.#...", ".#######.", ".########", "#########", "#########", ".#######.", "..#####.."]
const G_SPEAKER := ["...#.....", "..##..#..", "####...#.", "####.#.#.", "####...#.", "..##..#..", "...#....."]
const G_GRID := ["###.###", "###.###", "###.###", ".......", "###.###", "###.###", "###.###"]
const G_BAN := ["..#####..", ".##...##.", "##...####", "#...###.#", "#..###..#", "#.###...#", "####...##", ".##...##.", "..#####.."]
const G_SHIELD := ["#########", "#########", "####h####", "#########", ".#######.", ".#######.", "..#####..", "...###...", "....#...."]
const G_UP := ["...#...", "..###..", ".#####.", "#######", "..###..", "..###..", "..###.."]
const G_KEY := [".###.....", "#...#####", "#...#.#.#", ".###....."]
const G_MENU := ["#######", ".......", "#######", ".......", "#######"]
const G_MAP := ["###.###.#", "#.###.###", "#..#...##", "##.#.#..#", "#.###.###", "###.###.#"]
const G_CLOCK := ["..#####..", ".#.....#.", "#...#...#", "#...#...#", "#...###.#", "#.......#", ".#.....#.", "..#####.."]
const G_WIFI := [".#######.", "#.......#", "..#####..", ".#.....#.", "...###...", "....#...."]
const G_LAN := ["..###..", "..#.#..", "..###..", "...#...", "#######", "#..#..#", "##.#.##"]
const G_SKULL := ["..#####..", ".#######.", "#########", "#kk###kk#", "#kk###kk#", ".###k###.", "..#####..", "..#k#k#.."]
const G_HORNS := ["#.......#", "##.....##", ".#######.", "#########", "#kk###kk#", "#kk###kk#", ".###k###.", "..#k#k#.."]
const G_CROWN := ["#...#...#", "##.###.##", "#########", "#h##h##h#", "#########", ".#######."]
const G_SWORD := [".......hh", "......h#h", ".....h#h.", "....h#h..", "k..h#h...", ".k##h....", "..kk.....", ".k..k....", "k........"]
const G_DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]
const G_FLAG := ["#######.", "#######.", "#######.", "#.......", "#.......", "#.......", "#......."]
const GLYPH_BY_NAME := {"clock": G_CLOCK, "horns": G_HORNS, "skull": G_SKULL, "crown": G_CROWN, "sword": G_SWORD, "flag": G_FLAG,
		"star": G_STAR, "trophy": G_TROPHY}


## ------------------------------------------------------------------ çizim sınıfları
class Glyph extends Control:
	var pat: Array = []
	var col: Color = Color.WHITE
	var px: float = 4.0

	func setup(pt: Array, c: Color, cell: float) -> Glyph:
		pat = pt
		col = c
		px = cell
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w: int = 0
		for row: String in pt:
			w = maxi(w, row.length())
		custom_minimum_size = Vector2(w * cell, pt.size() * cell)
		size = custom_minimum_size
		return self

	func _draw() -> void:
		for y in pat.size():
			var row: String = pat[y]
			for x in row.length():
				var ch: String = row[x]
				if ch == ".":
					continue
				var c: Color = col
				if ch == "h":
					c = col.lightened(0.45)
				elif ch == "k":
					c = col.darkened(0.65)
				draw_rect(Rect2(x * px, y * px, px, px), c)


class Disk extends Control:
	var fill := Color(0, 0, 0, 0)
	var ring := Color(0, 0, 0, 0)
	var rw: float = 0.0
	var sweep: float = 0.0
	var sweep_col := Color(0, 0, 0, 0.62)
	var dashed: bool = false
	var arc_frac: float = -1.0
	var arc_col := Color.WHITE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		if absf(size.x - size.y) > 0.5:
			draw_set_transform(c, 0.0, Vector2(1.0, size.y / size.x))
			draw_circle(Vector2.ZERO, size.x * 0.5, fill)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		var r: float = size.x * 0.5
		if fill.a > 0.0:
			draw_circle(c, r, fill)
		if sweep > 0.0:
			var pts := PackedVector2Array([c])
			var a0: float = -PI * 0.5
			for i in 41:
				pts.append(c + Vector2.from_angle(a0 + TAU * sweep * float(i) / 40.0) * (r - 1.0))
			draw_colored_polygon(pts, sweep_col)
		if rw > 0.0 and ring.a > 0.0:
			if dashed:
				for i in 28:
					if i % 2 == 0:
						draw_arc(c, r - rw * 0.5, TAU * i / 28.0, TAU * (i + 1) / 28.0, 6, ring, rw)
			else:
				draw_arc(c, r - rw * 0.5, 0.0, TAU, 96, ring, rw)
		if arc_frac >= 0.0 and rw > 0.0:
			draw_arc(c, r - rw * 0.5, -PI * 0.5, -PI * 0.5 + TAU * arc_frac, 64, arc_col, rw)


## Basamaklı (düz bantlı, dither'sız) solma: dir 0 = üst koyu, 1 = alt koyu, 2 = sol koyu, 3 = sağ koyu.
class Fade extends Control:
	var col := Color.BLACK
	var dir: int = 0
	var a0: float = 0.8
	var steps: int = 8

	func _draw() -> void:
		for i in steps:
			var a: float = a0 * (1.0 - float(i) / float(steps))
			var rr := Rect2()
			match dir:
				0:
					rr = Rect2(0, size.y * i / steps, size.x, ceilf(size.y / steps))
				1:
					rr = Rect2(0, size.y - size.y * (i + 1) / steps, size.x, ceilf(size.y / steps))
				2:
					rr = Rect2(size.x * i / steps, 0, ceilf(size.x / steps), size.y)
				_:
					rr = Rect2(size.x - size.x * (i + 1) / steps, 0, ceilf(size.x / steps), size.y)
			draw_rect(rr, Color(col, a))


## Daireye kırpılmış doku (yetenek ikonları, minimap).
class CircleTex extends Control:
	var tex: Texture2D = null
	var region := Rect2()
	var tint := Color.WHITE

	func _draw() -> void:
		if tex == null:
			return
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		var ts: Vector2 = tex.get_size()
		var reg: Rect2 = region if region.size.x > 0.0 else Rect2(Vector2.ZERO, ts)
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 64:
			var d: Vector2 = Vector2.from_angle(TAU * float(i) / 64.0)
			pts.append(c + d * r)
			uvs.append((reg.position + reg.size * (Vector2(0.5, 0.5) + d * 0.5)) / ts)
		draw_colored_polygon(pts, tint, uvs, tex)


## Ruh Kıymığı kristali (soul_shop_screen.gd ShardIcon ile aynı biçim).
class Gem extends Control:
	var k: float = 1.0

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		var o: Vector2 = (size - Vector2(s, s)) * 0.5
		var top: Vector2 = o + Vector2(s * 0.5, s * 0.04)
		var my: float = o.y + s * 0.38
		var l := Vector2(o.x + s * 0.12, my)
		var r := Vector2(o.x + s * 0.88, my)
		var bot: Vector2 = o + Vector2(s * 0.5, s * 0.96)
		var m := Vector2(o.x + s * 0.5, my)
		var t := Color(k, k, k, 1)
		draw_colored_polygon(PackedVector2Array([top, m, l]), Color("#b4f1f5") * t)
		draw_colored_polygon(PackedVector2Array([top, r, m]), Color("#73d2dc") * t)
		draw_colored_polygon(PackedVector2Array([l, m, bot]), Color("#3f9fb0") * t)
		draw_colored_polygon(PackedVector2Array([m, r, bot]), Color("#2b7d8f") * t)


## ------------------------------------------------------------------ durum
var S: Dictionary = {}
var cur: String = "A"
var font: Font
var CH
var IT
var WC
var PC
var WTA
var MU
var SPI
var ACH
var MHB
var game_tex: Texture2D = null
var coin_tex: Texture2D
var wshard_tex: Texture2D
var minimap_tex: Texture2D
var trim_tex: Texture2D
var candles_tex: Texture2D
var chest_tex: Texture2D
var beam_tex: Texture2D
var shots: Dictionary = {}


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
func col(n: String) -> Color:
	return S[n]


func _num(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _def(cid: int) -> Dictionary:
	return CH.call("get_def", cid)


func _cname(cid: int) -> String:
	return str(_def(cid).get("name", "?"))


func _ptex(cid: int) -> Texture2D:
	var p: String = str(_def(cid).get("portrait", ""))
	return load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null


func _roster() -> Array:
	var ids: Array = CH.DEFS.keys()
	ids.sort()
	return ids


func _items(k: int) -> Array:
	var out: Array = []
	for key: String in IT.KEYS:
		if int(IT.call("kademe", key)) == k:
			out.append(key)
	return out


func _iname(key: String) -> String:
	return str(IT.call("item_name", key))


func _itex(key: String) -> Texture2D:
	return IT.call("icon", key) as Texture2D


func _ik(key: String) -> int:
	return clampi(int(IT.call("kademe", key)), 1, 3)


func _icost(key: String) -> int:
	return int(IT.call("cost", key))


func _bag() -> Array:
	var out: Array = []
	for k: String in BAG:
		if IT.DEFS.has(k):
			out.append(k)
	return out


func _wname(key: String) -> String:
	return str(WC.call("display_name", key))


func _wtex(key: String, tier: int) -> Texture2D:
	var t: Texture2D = WTA.call("texture", key, tier) as Texture2D
	return t if t else WC.call("icon", key) as Texture2D


func _skills(cid: int) -> Array:
	var d: Dictionary = _def(cid)
	return [
		["P", str(d.get("passive_name", "Pasif")), str(d.get("passive_icon", ""))],
		["Q", str(d.get("skill_name", "")), str(d.get("skill_icon", ""))],
		["E", str(d.get("skill2_name", "")), str(d.get("skill2_icon", ""))],
		["R", str(d.get("skill3_name", "")), str(d.get("skill3_icon", ""))],
	]


func _stex(path: String) -> Texture2D:
	return load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null


func _spirit(id: String) -> Dictionary:
	return SPI.call("get_def", id)


func _stat_tex(stat: String) -> Texture2D:
	var p: String = "res://assets/ui/level_up_icons/stat_%s.png" % stat
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


func _base(cid: int) -> Dictionary:
	return CH.get_base_stats(cid)


func _ach_defs() -> Array:
	return ACH.DEFS


func _desc(key: String) -> String:
	return str(IT.call("describe", key))


func _w_stats(tier: int) -> Array:
	return ["+%%%d" % ((tier - 1) * 10), "-%%%d" % ((tier - 1) * 5)]


func _w_cost(tier: int) -> Array:
	if tier >= 4:
		return [400, 10]
	return [100 + 30 * (tier - 1), 5]


## ------------------------------------------------------------------ temel parçalar (hepsi MUTLAK konumlu, ebeveyn = rc)
func _ctl(p: Control, r: Rect2, clip: bool = false) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.clip_contents = clip
	p.add_child(c)
	c.position = r.position
	c.size = r.size
	return c


func _rect(p: Control, r: Rect2, c: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.color = c
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(cr)
	cr.position = r.position
	cr.size = r.size
	return cr


func _sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, rad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	sb.anti_aliasing = false
	return sb


func _box(p: Control, r: Rect2, fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, rad: int = 0) -> Panel:
	var pn := Panel.new()
	pn.add_theme_stylebox_override("panel", _sb(fill, border, bw, rad))
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pn)
	pn.position = r.position
	pn.size = r.size
	return pn


## Yöne göre çerçeve: A kare + kalın kenar + iç ışık çizgisi, B yuvarlak sıva, C ince kayrak, D dış kontur + ahşap kenar.
func _frame(p: Control, r: Rect2, fill: Color, bd: Color, thick: bool = false) -> void:
	match cur:
		"A":
			_box(p, r, fill, bd, 4 if not thick else 6, 0)
			_rect(p, Rect2(r.position + Vector2(6 if not thick else 8, 6 if not thick else 8), Vector2(r.size.x - (12 if not thick else 16), 2)),
					Color(1, 0.9, 0.7, 0.08))
		"B":
			_box(p, r, fill, bd, 3 if not thick else 4, 14 if r.size.y > 60 else int(r.size.y * 0.3))
		"C":
			_box(p, r, fill, bd, 2 if not thick else 4, 6)
		_:
			_box(p, r, col("line"), Color(0, 0, 0, 0), 0, 0)
			_box(p, r.grow(-4), fill, bd, 4, 0)
			_rect(p, Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, 4)), Color(1, 0.9, 0.7, 0.10))


func _panel(p: Control, r: Rect2, kind: String = "panel", alpha: float = 0.95, thick: bool = false) -> void:
	var f: Color = col(kind)
	f.a = alpha
	_frame(p, r, f, col("rim") if cur == "D" else (col("line_hi") if thick else col("line")), thick)


func _font_label(s: String, fs: int, c: Color, sh: bool) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("line_spacing", 0)
	if sh:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("shadow_offset_x", maxi(1, fs / 16))
		l.add_theme_constant_override("shadow_offset_y", maxi(1, fs / 16))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _tw_of(s: String, fs: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## Dikdörtgen içinde dikey ortalı yazı (al: 0 sol, 1 orta, 2 sağ).
func _t(p: Control, s: String, r: Rect2, fs: int = 48, c: Color = Color.WHITE, al: int = 0, sh: bool = true) -> Label:
	var l := _font_label(s, fs, c, sh)
	l.horizontal_alignment = al
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(l)
	l.position = r.position
	l.size = r.size
	return l


## Kaydırmalı çok satır yazı (en fazla r.size.y'ye sığan satır).
func _tw(p: Control, s: String, r: Rect2, fs: int = 32, c: Color = Color.WHITE, al: int = 0) -> Label:
	var l := _font_label(s, fs, c, false)
	l.horizontal_alignment = al
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = maxi(1, int(r.size.y / float(fs)))
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.add_child(l)
	l.position = r.position
	l.size = Vector2(r.size.x, 0)
	return l


func _img(p: Control, tex: Texture2D, r: Rect2, nearest: bool = true, mod: Color = Color.WHITE) -> TextureRect:
	if tex == null:
		return null
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.modulate = mod
	p.add_child(t)
	t.position = r.position
	t.size = r.size
	return t


func _glyph(p: Control, pat: Array, center: Vector2, cell: float, c: Color) -> Glyph:
	var g: Glyph = Glyph.new().setup(pat, c, cell)
	p.add_child(g)
	g.position = (center - g.size * 0.5).round()
	return g


func _disk(p: Control, center: Vector2, rad: float, fill: Color, ring: Color = Color(0, 0, 0, 0), rw: float = 0.0) -> Disk:
	var d := Disk.new()
	d.fill = fill
	d.ring = ring
	d.rw = rw
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(d)
	d.position = center - Vector2(rad, rad)
	d.size = Vector2(rad * 2.0, rad * 2.0)
	return d


func _ellipse(p: Control, center: Vector2, w: float, h: float, c: Color) -> void:
	var d := Disk.new()
	d.fill = c
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(d)
	d.position = center - Vector2(w, h) * 0.5
	d.size = Vector2(w, h)


func _fade(p: Control, r: Rect2, c: Color, dir: int, a0: float = 0.8, steps: int = 8) -> void:
	var f := Fade.new()
	f.col = c
	f.dir = dir
	f.a0 = a0
	f.steps = steps
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(f)
	f.position = r.position
	f.size = r.size


func _ctex(p: Control, tex: Texture2D, center: Vector2, rad: float, region: Rect2 = Rect2(), tint: Color = Color.WHITE, nearest: bool = false) -> void:
	var c := CircleTex.new()
	c.tex = tex
	c.region = region
	c.tint = tint
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)
	c.position = center - Vector2(rad, rad)
	c.size = Vector2(rad * 2.0, rad * 2.0)


func _gem(p: Control, r: Rect2, dimmed: bool = false) -> void:
	var g := Gem.new()
	g.k = 0.5 if dimmed else 1.0
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(g)
	g.position = r.position
	g.size = r.size


## Simge: Array = piksel desen, Texture2D = doku, "coin"/"wshard"/"soul" = para birimi.
func _icon(p: Control, ic: Variant, center: Vector2, sz: float, c: Color) -> void:
	if ic == null:
		return
	if ic is Array:
		var pat: Array = ic
		var w: int = 0
		for row: String in pat:
			w = maxi(w, row.length())
		var cell: float = maxf(2.0, floorf(sz / float(maxi(w, pat.size()))))
		_glyph(p, pat, center, cell, c)
	elif ic is Texture2D:
		var t: Texture2D = ic
		var ts: Vector2 = t.get_size()
		var k: float = sz / maxf(ts.x, ts.y)
		if k >= 1.0:
			k = floorf(k)
		var s2: Vector2 = ts * k
		_img(p, t, Rect2(center - s2 * 0.5, s2), ts.x <= 64.0)
	elif ic is String:
		_money_icon(p, str(ic), Rect2(center - Vector2(sz, sz) * 0.5, Vector2(sz, sz)))


func _money_icon(p: Control, kind: String, r: Rect2) -> void:
	match kind:
		"coin":
			var k: float = maxf(1.0, floorf(r.size.y / 16.0))
			_img(p, coin_tex, Rect2(r.get_center() - Vector2(8, 8) * k, Vector2(16, 16) * k))
		"wshard":
			var k2: float = maxf(1.0, floorf(r.size.y / 22.0))
			_img(p, wshard_tex, Rect2(r.get_center() - Vector2(11, 11) * k2, Vector2(22, 22) * k2))
		"soul":
			_gem(p, r)


## Düğme. kind: primary / secondary / selected / ghost / danger / disabled.
func _btn(p: Control, r: Rect2, txt: String, kind: String = "secondary", ic: Variant = null, fs: int = 48, sub: String = "") -> void:
	var fill: Color
	var bd: Color
	var tc: Color
	match kind:
		"primary":
			fill = col("accent")
			bd = col("accent_dk")
			tc = col("accent_text")
		"selected":
			fill = col("panel3")
			bd = col("accent")
			tc = col("accent")
		"ghost":
			fill = Color(col("inset"), 0.6)
			bd = col("line")
			tc = col("dim")
		"danger":
			fill = Color("#4e2018")
			bd = col("bad")
			tc = Color("#ffd8c8")
		"disabled":
			fill = Color(col("inset"), 0.92)
			bd = col("line")
			tc = Color(col("dim"), 0.55)
		_:
			fill = col("panel3") if cur != "D" else col("panel2")
			bd = col("line_hi")
			tc = col("text")
	if cur == "D":
		_box(p, r, col("line"))
		_box(p, r.grow(-4), fill, bd if kind != "secondary" else col("rim"), 4, 0)
	elif cur == "B" or cur == "C":
		_box(p, r, fill, bd, 3, mini(int(r.size.y * 0.5), 18 if cur == "B" else 8))
	else:
		_box(p, r, fill, bd, 4, 0)
	if kind == "primary":
		var inset: float = 8.0 if cur == "D" else 4.0
		_rect(p, Rect2(r.position + Vector2(inset + 4, inset), Vector2(r.size.x - inset * 2 - 8, 4)), Color(1, 1, 1, 0.28))
		_rect(p, Rect2(r.position.x + inset + 4, r.end.y - inset - 6, r.size.x - inset * 2 - 8, 4), Color(0, 0, 0, 0.18))
	var tw: float = _tw_of(txt, fs) if txt != "" else 0.0
	var isz: float = float(fs) * (0.9 if ic is Array else 1.0)
	if ic is Texture2D:
		isz = minf(r.size.y - 24.0, float(fs) * 1.34)
	var gap: float = 20.0 if (ic != null and txt != "") else 0.0
	var total: float = (isz if ic != null else 0.0) + gap + tw
	if sub != "":
		total = maxf(total, (isz if ic != null else 0.0) + gap + _tw_of(sub, 32))
	var x0: float = r.position.x + (r.size.x - total) * 0.5
	var cy: float = r.get_center().y
	if ic != null:
		_icon(p, ic, Vector2(x0 + isz * 0.5, cy), isz, tc)
	if txt != "":
		var tx: float = x0 + (isz if ic != null else 0.0) + gap
		if sub != "":
			_t(p, txt, Rect2(tx, cy - fs * 0.5 - 16, tw + 8, fs), fs, tc, 0, kind != "primary")
			_t(p, sub, Rect2(tx, cy + fs * 0.5 - 18, r.end.x - tx, 32), 32, Color(tc, 0.75), 0, false)
		else:
			_t(p, txt, Rect2(tx, cy - fs * 0.5 - 2, tw + 8, fs), fs, tc, 0, kind != "primary")


func _round_btn(p: Control, center: Vector2, rad: float, ic: Variant, kind: String = "secondary") -> void:
	var fill: Color = col("accent") if kind == "primary" else Color(col("panel2") if cur == "D" else col("panel3"), 0.94)
	var bd: Color = col("accent_dk") if kind == "primary" else (col("rim") if cur == "D" else col("line_hi"))
	var tc: Color = col("accent_text") if kind == "primary" else col("text")
	_disk(p, center, rad + 4, col("line") if cur == "D" else Color(0, 0, 0, 0.35))
	_disk(p, center, rad, fill, bd, 4.0 if cur != "C" else 3.0)
	_icon(p, ic, center, rad * 0.8, tc)


func _sq_btn(p: Control, r: Rect2, ic: Variant, kind: String = "secondary") -> void:
	_btn(p, r, "", kind, ic, 48)


## Para hapı, sağ kenardan sola; döner = hapın sol x'i.
func _money(p: Control, right_x: float, y: float, kind: String, amount: int, h: float = 88.0, fs: int = 48) -> float:
	var txt: String = _num(amount)
	var tw: float = _tw_of(txt, fs)
	var iw: float = 48.0
	var w: float = 22.0 + iw + 14.0 + tw + 26.0
	var r := Rect2(right_x - w, y, w, h)
	if cur == "D":
		_box(p, r, col("line"))
		_box(p, r.grow(-4), col("inset"), col("rim"), 3, 0)
	else:
		_box(p, r, Color(col("inset"), 0.88), col("line"), 3, int(h * 0.5) if cur != "A" else 0)
	_money_icon(p, kind, Rect2(r.position.x + 22, y + (h - iw) * 0.5, iw, iw))
	var tc: Color = SOUL_COL if kind == "soul" else (Color("#b8e0f4") if kind == "wshard" else col("price"))
	_t(p, txt, Rect2(r.position.x + 22 + iw + 14, y, tw + 10, h), fs, tc)
	return r.position.x


## Yazı hapı (etiket). döner = genişlik.
func _chip(p: Control, pos: Vector2, txt: String, c: Color, fs: int = 32, h: float = 52.0, filled: bool = false) -> float:
	var w: float = _tw_of(txt, fs) + 36.0
	var r := Rect2(pos, Vector2(w, h))
	_box(p, r, c if filled else Color(c, 0.16), c, 3, int(h * 0.5) if cur == "B" or cur == "C" else 0)
	_t(p, txt, Rect2(pos.x, pos.y - 2, w, h), fs, Color("#1c120a") if filled else c.lightened(0.15), 1, false)
	return w


## Bölümlü seçici (sekmeler). döner = toplam genişlik.
func _tabs(p: Control, r: Rect2, labels: Array, sel: int, fs: int = 48) -> void:
	var n: int = labels.size()
	var gap: float = 12.0
	var w: float = (r.size.x - gap * (n - 1)) / float(n)
	for i in n:
		var rr := Rect2(r.position.x + i * (w + gap), r.position.y, w, r.size.y)
		_btn(p, rr, str(labels[i]), "selected" if i == sel else "ghost", null, fs)


func _bar(p: Control, r: Rect2, frac: float, fill: Color, bg: Color = Color(0, 0, 0, 0), bd: Color = Color(0, 0, 0, 0), bw: int = 3) -> void:
	if bg.a <= 0.0:
		bg = col("inset")
	if bd.a <= 0.0:
		bd = Color("#120c08")
	_box(p, r, bg, bd, bw)
	var f: float = clampf(frac, 0.0, 1.0)
	if f > 0.0:
		var inner := Rect2(r.position + Vector2(bw, bw), Vector2((r.size.x - 2 * bw) * f, r.size.y - 2 * bw))
		_rect(p, inner, fill)
		if inner.size.y >= 10.0:
			_rect(p, Rect2(inner.position, Vector2(inner.size.x, maxf(2.0, floorf(inner.size.y * 0.22)))), fill.lightened(0.3))


func _hp(p: Control, r: Rect2, t: Dictionary, num_fs: int = 32, sh_h: float = 0.0) -> void:
	var shh: float = sh_h if sh_h > 0.0 else maxf(10.0, floorf(r.size.y * 0.32))
	if float(t["msh"]) > 0.0:
		_bar(p, Rect2(r.position, Vector2(r.size.x, shh)), float(t["sh"]) / float(t["msh"]), SH_COL, Color("#0c1420"))
	var hr := Rect2(r.position.x, r.position.y + shh + 4, r.size.x, r.size.y - shh - 4)
	_bar(p, hr, float(t["hp"]) / float(t["mhp"]), HP_COL, Color("#1c0a08"))
	if num_fs > 0 and hr.size.y >= float(num_fs) - 4.0:
		_t(p, "%d / %d" % [int(t["hp"]), int(t["mhp"])], Rect2(hr.position.x, hr.position.y - 2, hr.size.x, hr.size.y), num_fs, Color.WHITE, 1)


## Portrenin baş kısmı (24x24, x4 = 96): HUD yüzleri tam boy portrede çok küçük kalıyordu.
func _face_tex(cid: int) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = _ptex(cid)
	at.region = Rect2(12, 4, 24, 24)
	return at


func _face(p: Control, cid: int, r: Rect2, bd: Color = Color(0, 0, 0, 0)) -> void:
	if bd.a <= 0.0:
		bd = col("line_hi")
	_box(p, r, col("inset"), bd, 3, 0 if cur == "A" or cur == "D" else 8)
	var k: float = maxf(1.0, floorf(minf(r.size.x, r.size.y) / 24.0))
	_img(p, _face_tex(cid), Rect2(r.get_center() - Vector2(12, 12) * k, Vector2(24, 24) * k))


func _portrait(p: Control, cid: int, r: Rect2, bd: Color = Color(0, 0, 0, 0), dimmed: bool = false) -> void:
	if bd.a <= 0.0:
		bd = col("line_hi")
	_box(p, r, col("inset"), bd, 3 if r.size.x < 120 else 4, 0 if cur == "A" or cur == "D" else 8)
	var k: float = maxf(1.0, floorf(minf(r.size.x, r.size.y) / 48.0))
	_img(p, _ptex(cid), Rect2(r.get_center() - Vector2(24, 24) * k, Vector2(48, 48) * k), true,
			Color(0.35, 0.35, 0.4) if dimmed else Color.WHITE)


## Karakter sprite'ı (ayak = foot), k = piksel ölçeği.
func _sprite(p: Control, cid: int, foot: Vector2, k: float, anim: String = "idle_down", tint: Color = Color.WHITE) -> void:
	var path: String = str(_def(cid).get("frames", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var sf: SpriteFrames = load(path) as SpriteFrames
	var a: String = anim if sf.has_animation(anim) else str(sf.get_animation_names()[0])
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.animation = a
	s.play()
	s.scale = Vector2(k, k)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.modulate = tint
	var tex: Texture2D = sf.get_frame_texture(a, 0)
	var fh: float = tex.get_size().y if tex else 48.0
	s.centered = true
	s.offset = Vector2(0, -fh * 0.5 + fh * 0.06)
	_ellipse(p, foot, 30.0 * k, 9.0 * k, Color(0, 0, 0, 0.35))
	p.add_child(s)
	s.position = foot


func _pet_sprite(p: Control, key: String, center: Vector2, k: float) -> void:
	var spec: Array = PC.FRAMES.get(key, [])
	if spec.is_empty():
		return
	var sf: SpriteFrames = load(str(spec[0])) as SpriteFrames
	if sf == null:
		return
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.animation = spec[1]
	s.play()
	s.scale = Vector2(k, k)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(s)
	s.position = center


func _dim(p: Control, a: float) -> void:
	_rect(p, Rect2(0, 0, SW, SH), Color(col("dimbg"), a))


func _title_logo(p: Control, pos: Vector2, big: int = 112, centered: bool = false) -> void:
	var w: float = 1000.0
	var x: float = pos.x - (w * 0.5 if centered else 0.0)
	_t(p, "I NEED TO", Rect2(x, pos.y, w, 64), 64, Color("#efe2c6"), 1 if centered else 0)
	_t(p, "STAY ALIVE", Rect2(x, pos.y + 56, w, big), big, Color("#f4c56e"), 1 if centered else 0)
	var tr := _img(p, trim_tex, Rect2((pos.x - 240.0) if centered else pos.x, pos.y + 56 + big + 8, 480, 48), true, Color(1, 1, 1, 0.9))
	tr.stretch_mode = TextureRect.STRETCH_TILE


func _scroll_hint(p: Control, r: Rect2, horizontal: bool = true) -> void:
	if horizontal:
		_fade(p, Rect2(r.end.x - 160, r.position.y, 160, r.size.y), col("dimbg"), 3, 0.85, 6)
	else:
		_fade(p, Rect2(r.position.x, r.end.y - 120, r.size.x, 120), col("panel"), 1, 0.95, 6)


func _dots(p: Control, center: Vector2, n: int, sel: int) -> void:
	var gap: float = 36.0
	var x0: float = center.x - gap * (n - 1) * 0.5
	for i in n:
		var c := Vector2(x0 + gap * i, center.y)
		if i == sel:
			_disk(p, c, 12, col("accent"))
		else:
			_disk(p, c, 8, Color(col("dim"), 0.5))


## ------------------------------------------------------------------ içerik çizicileri
func _item_tile(p: Control, r: Rect2, key: String, sel: bool = false, owned: bool = false, show_price: bool = true, show_name: bool = true) -> void:
	var k: int = _ik(key)
	var tc: Color = IT_COL[k - 1]
	_box(p, r, Color(col("inset"), 0.92) if not sel else col("panel3"), col("accent") if sel else tc, 6 if sel else 3,
			0 if cur == "A" or cur == "D" else 8)
	var name_h: float = 72.0 if show_name else 0.0
	var price_h: float = 52.0 if show_price else 0.0
	var room: float = minf(r.size.x - 24.0, r.size.y - name_h - price_h - 20.0)
	var sc: float = maxf(1.0, floorf(room / 32.0))
	var isz: float = 32.0 * sc
	var top: float = r.position.y + 12.0 + (r.size.y - 24.0 - name_h - price_h - isz) * 0.5
	_img(p, _itex(key), Rect2(r.position.x + (r.size.x - isz) * 0.5, top, isz, isz))
	var y: float = top + isz + 6.0
	if show_name:
		_tw(p, _iname(key), Rect2(r.position.x + 8, y, r.size.x - 16, 64), 32, col("text"), 1)
		y += name_h
	if show_price:
		var pt: String = _num(_icost(key))
		var tw: float = _tw_of(pt, 32) + 40.0
		var px: float = r.position.x + (r.size.x - tw) * 0.5
		_money_icon(p, "coin", Rect2(px, r.end.y - 48, 32, 32))
		_t(p, pt, Rect2(px + 40, r.end.y - 52, tw, 40), 32, col("price"))
	if owned:
		_box(p, Rect2(r.end.x - 44, r.position.y + 6, 38, 38), col("good"), Color("#1c2a12"), 2, 0)
		_glyph(p, G_CHECK, Vector2(r.end.x - 25, r.position.y + 25), 4, Color("#16220c"))


func _item_slot(p: Control, r: Rect2, key: String, k: int, sel: bool = false) -> void:
	var tc: Color = IT_COL[k - 1]
	if key == "":
		_box(p, r, Color(col("inset"), 0.55), Color(tc, 0.35), 2, 0 if cur == "A" or cur == "D" else 8)
		return
	_box(p, r, col("panel3") if sel else Color(col("inset"), 0.92), col("accent") if sel else tc, 6 if sel else 3, 0 if cur == "A" or cur == "D" else 8)
	var sc: float = maxf(1.0, floorf((minf(r.size.x, r.size.y) - 20.0) / 32.0))
	_img(p, _itex(key), Rect2(r.get_center() - Vector2(16, 16) * sc, Vector2(32, 32) * sc))


## Eşya ayrıntısı (dikey akış). döner = kullanılan alt y.
func _item_detail(p: Control, r: Rect2, key: String, big: bool = true) -> float:
	var k: int = _ik(key)
	var tc: Color = IT_COL[k - 1]
	var isz: float = 128.0 if big else 96.0
	_box(p, Rect2(r.position, Vector2(isz + 24, isz + 24)), col("inset"), tc, 4, 0 if cur == "A" or cur == "D" else 10)
	_img(p, _itex(key), Rect2(r.position + Vector2(12, 12), Vector2(isz, isz)))
	var x: float = r.position.x + isz + 48
	_t(p, _iname(key), Rect2(x, r.position.y, r.end.x - x, 64), 64 if big else 48, col("text"))
	var cw: float = _chip(p, Vector2(x, r.position.y + 72), IT_NAMES[k - 1], tc, 32, 52)
	var pt: String = _num(_icost(key))
	_money_icon(p, "coin", Rect2(x + cw + 24, r.position.y + 74, 48, 48))
	_t(p, pt, Rect2(x + cw + 80, r.position.y + 70, 300, 56), 48, col("price"))
	var y: float = r.position.y + isz + 44
	var lines: PackedStringArray = _desc(key).split("\n")
	for ln: String in lines:
		if y > r.end.y - 40:
			break
		if ln == "":
			y += 12
			continue
		if ln.begins_with("Pasif:"):
			var l := _tw(p, ln, Rect2(r.position.x, y, r.size.x, minf(r.end.y - y, 112)), 32, col("dim"))
			y += maxf(40.0, l.get_line_count() * 32.0 + 8.0)
		else:
			_t(p, ln, Rect2(r.position.x, y, r.size.x, 48), 48 if big else 32, col("good"))
			y += 52 if big else 40
	return y


## Tarif satırı: [ana] = [parça] + [parça] (sahip olunan parça tikli).
func _recipe(p: Control, pos: Vector2, key: String, tile: float, max_w: float) -> float:
	var rec: Array = IT.call("recipe", key)
	if rec.is_empty():
		return pos.y
	_t(p, "TARİF", Rect2(pos.x, pos.y, 300, 40), 32, col("dim"))
	var x: float = pos.x
	var y: float = pos.y + 44
	var owned: Array = _bag()
	for i in rec.size():
		var ck: String = rec[i]
		if x + tile > pos.x + max_w:
			break
		var have: bool = owned.has(ck)
		_item_slot(p, Rect2(x, y, tile, tile), ck, _ik(ck), false)
		if have:
			_box(p, Rect2(x + tile - 34, y + 4, 30, 30), col("good"), Color("#1c2a12"), 2, 0)
			_glyph(p, G_CHECK, Vector2(x + tile - 19, y + 19), 3, Color("#16220c"))
		x += tile
		if i < rec.size() - 1:
			_t(p, "+", Rect2(x, y, 40, tile), 48, col("dim"), 1)
			x += 40
	return y + tile


func _weapon_tile(p: Control, r: Rect2, key: String, tier: int, sel: bool = false, owned: bool = true, show_name: bool = true) -> void:
	var ec: Color = ENCH_COL[clampi(tier, 0, 5)]
	var bd: Color = col("accent") if sel else (ec if ec.a > 0.0 else col("line_hi"))
	_box(p, r, col("panel3") if sel else Color(col("inset"), 0.92), bd, 6 if sel else 3, 0 if cur == "A" or cur == "D" else 10)
	var name_h: float = 56.0 if show_name else 0.0
	var sc: float = maxf(1.0, floorf((minf(r.size.x - 16.0, r.size.y - name_h - 16.0)) / 48.0))
	var isz: float = 48.0 * sc
	var top: float = r.position.y + (r.size.y - name_h - isz) * 0.5
	_img(p, _wtex(key, maxi(tier, 1)), Rect2(r.position.x + (r.size.x - isz) * 0.5, top, isz, isz), true,
			Color.WHITE if owned else Color(0.55, 0.55, 0.6))
	if show_name:
		_t(p, _wname(key), Rect2(r.position.x + 6, r.end.y - name_h - 4, r.size.x - 12, name_h), 32, col("text"), 1)
	if tier >= 1 and owned:
		var rt: String = ROMAN[tier]
		_t(p, rt, Rect2(r.position.x + 10, r.position.y + 6, 120, 44), 32, ec.lightened(0.2) if ec.a > 0.0 else col("dim"))


func _tier_path(p: Control, r: Rect2, tier: int) -> void:
	var w: float = (r.size.x - 16.0 * 4) / 5.0
	for i in 5:
		var t: int = i + 1
		var rr := Rect2(r.position.x + i * (w + 16.0), r.position.y, w, r.size.y)
		var ec: Color = ENCH_COL[t] if t >= 2 else col("line_hi")
		if t <= tier:
			_box(p, rr, Color(ec, 0.35), ec, 3, 0 if cur == "A" or cur == "D" else 8)
		elif t == tier + 1:
			_box(p, rr, col("panel3"), col("accent"), 4, 0 if cur == "A" or cur == "D" else 8)
		else:
			_box(p, rr, Color(col("inset"), 0.8), col("line"), 2, 0 if cur == "A" or cur == "D" else 8)
		_t(p, ROMAN[t], rr, 32 if r.size.y < 60 else 48, col("text") if t <= tier + 1 else Color(col("dim"), 0.6), 1)


func _weapon_detail(p: Control, r: Rect2, key: String, tier: int, art: float = 192.0) -> float:
	var ec: Color = ENCH_COL[tier]
	_box(p, Rect2(r.position, Vector2(art + 32, art + 32)), col("inset"), ec if ec.a > 0 else col("line_hi"), 4, 0 if cur == "A" or cur == "D" else 12)
	_img(p, _wtex(key, tier), Rect2(r.position + Vector2(16, 16), Vector2(art, art)))
	var x: float = r.position.x + art + 56
	_t(p, _wname(key), Rect2(x, r.position.y, r.end.x - x, 64), 64, col("text"))
	var cw: float = _chip(p, Vector2(x, r.position.y + 76), str(WC.call("category_label", key)).to_upper(), WC.call("category_color", key), 32, 52)
	_chip(p, Vector2(x + cw + 16, r.position.y + 76), "SEVİYE " + ROMAN[tier], ec if ec.a > 0 else col("dim"), 32, 52)
	_tw(p, "Bu oyunda: 48.210 hasar", Rect2(x, r.position.y + 148, r.end.x - x, 40), 32, col("dim"))
	var y: float = r.position.y + art + 56
	_tier_path(p, Rect2(r.position.x, y, r.size.x, 64), tier)
	y += 88
	var a: Array = _w_stats(tier)
	var b: Array = _w_stats(tier + 1)
	for row: Array in [["Hasar", a[0], b[0]], ["Atış aralığı", a[1], b[1]]]:
		_t(p, row[0], Rect2(r.position.x, y, 420, 56), 48, col("text"))
		_t(p, row[1], Rect2(r.position.x + 440, y, 200, 56), 48, col("dim"))
		_t(p, "->", Rect2(r.position.x + 620, y, 80, 56), 48, col("dim"), 1)
		_t(p, row[2], Rect2(r.position.x + 700, y, 220, 56), 48, col("good"))
		y += 64
	return y


func _cost_row(p: Control, pos: Vector2, gold: int, shards: int, fs: int = 48) -> void:
	_money_icon(p, "coin", Rect2(pos.x, pos.y, 48, 48))
	var g: String = _num(gold)
	_t(p, g, Rect2(pos.x + 56, pos.y - 4, 200, 56), fs, col("price"))
	var x: float = pos.x + 56 + _tw_of(g, fs) + 28
	if shards > 0:
		_money_icon(p, "wshard", Rect2(x, pos.y, 44, 44))
		_t(p, str(shards), Rect2(x + 52, pos.y - 4, 120, 56), fs, Color("#b8e0f4"))


func _char_tile(p: Control, r: Rect2, cid: int, sel: bool = false, show_name: bool = true, taken: String = "") -> void:
	var locked: bool = LOCKED_CHARS.has(cid)
	var bd: Color = col("accent") if sel else col("line_hi")
	_box(p, r, col("panel3") if sel else Color(col("inset"), 0.9), bd, 6 if sel else 3, 0 if cur == "A" or cur == "D" else 12)
	var name_h: float = 48.0 if show_name else 0.0
	var k: float = maxf(1.0, floorf(minf(r.size.x - 16.0, r.size.y - name_h - 12.0) / 48.0))
	var ps: float = 48.0 * k
	_img(p, _ptex(cid), Rect2(r.position.x + (r.size.x - ps) * 0.5, r.position.y + 8 + (r.size.y - name_h - 12 - ps) * 0.5, ps, ps), true,
			Color(0.3, 0.3, 0.36) if locked else Color.WHITE)
	if show_name:
		_t(p, _cname(cid), Rect2(r.position.x + 4, r.end.y - name_h - 4, r.size.x - 8, name_h), 32, col("dim") if locked else col("text"), 1)
	if locked:
		_glyph(p, G_LOCK, r.position + Vector2(r.size.x * 0.5, (r.size.y - name_h) * 0.45), 6, col("dim"))
		var cost: int = int(MetaCosts.CHAR.get(cid, 400))
		_gem(p, Rect2(r.position.x + 10, r.position.y + 10, 32, 32))
		_t(p, str(cost), Rect2(r.position.x + 48, r.position.y + 6, 120, 40), 32, SOUL_COL)
	if taken != "":
		var tw: float = _tw_of(taken, 32) + 24
		_box(p, Rect2(r.end.x - tw - 6, r.position.y + 6, tw, 44), Color("#3d6fd0"), Color("#9ab8f0"), 2, 0)
		_t(p, taken, Rect2(r.end.x - tw - 6, r.position.y + 4, tw, 44), 32, Color.WHITE, 1, false)


## Yetenek ikon sırası (P Q E R). döner = alt y.
func _skill_icons(p: Control, pos: Vector2, cid: int, sz: float, gap: float, names: bool = false, name_w: float = 0.0) -> float:
	var x: float = pos.x
	for s: Array in _skills(cid):
		var r := Rect2(x, pos.y, sz, sz)
		_box(p, r.grow(4), col("line") if cur == "D" else Color("#0a0806"), Color(0, 0, 0, 0), 0, 0 if cur == "A" or cur == "D" else 8)
		_img(p, _stex(s[2]), r, false)
		_box(p, Rect2(r.position.x - 4, r.end.y - 36, 40, 40), col("inset"), col("accent") if s[0] == "R" else col("line_hi"), 2, 0)
		_t(p, s[0], Rect2(r.position.x - 4, r.end.y - 38, 40, 40), 32, col("accent") if s[0] == "R" else col("text"), 1, false)
		if names:
			_tw(p, s[1], Rect2(x - 8, pos.y + sz + 10, maxf(sz + 16, name_w), 64), 32, col("dim"), 1)
		x += maxf(sz, name_w) + gap
	return pos.y + sz + (74.0 if names else 0.0)


func _stat_bars(p: Control, r: Rect2, cid: int, fs: int = 32) -> void:
	var b: Dictionary = _base(cid)
	var rows: Array = [["Can", float(b.get("hp", 100.0)), 120.0, HP_COL], ["Hız", float(b.get("speed", 250.0)), 280.0, SH_COL],
			["Saldırı Gücü", float(b.get("ap", 10.0)), 18.0, col("accent")], ["Saldırı Hızı", float(b.get("atk", 0.0)) + 20.0, 40.0, XP_COL]]
	var rh: float = r.size.y / 4.0
	for i in 4:
		var row: Array = rows[i]
		var y: float = r.position.y + i * rh
		_t(p, row[0], Rect2(r.position.x, y, 300, rh), fs, col("dim"))
		var val: String = str(int(row[1])) if i < 3 else ("%+d%%" % int(float(b.get("atk", 0.0))))
		_t(p, val, Rect2(r.position.x + 300, y, 110, rh), fs, col("text"), 2)
		_bar(p, Rect2(r.position.x + 430, y + rh * 0.5 - 9, r.size.x - 430, 18), float(row[1]) / float(row[2]), row[3], col("inset"), Color("#0a0806"), 2)


func _lv_card(p: Control, r: Rect2, o: Dictionary, mode: String = "big", sel: bool = false) -> void:
	var t: int = int(o["tier"])
	var tc: Color = LV_COL[t]
	_box(p, r, Color(col("panel"), 0.97), col("accent") if sel else tc, 6 if sel else 4, 0 if cur == "A" or cur == "D" else 14)
	var ic: Texture2D = _stat_tex(str(o["stat"]))
	match mode:
		"big":
			_box(p, Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 72)), Color(tc, 0.28), Color(0, 0, 0, 0), 0, 0)
			_t(p, LV_NAMES[t], Rect2(r.position.x, r.position.y + 6, r.size.x, 72), 48, tc.lightened(0.2), 1)
			var isz: float = 192.0 if r.size.y > 600 else 144.0
			_img(p, ic, Rect2(r.position.x + (r.size.x - isz) * 0.5, r.position.y + 104, isz, isz), false)
			var y: float = r.position.y + 120 + isz
			_t(p, str(o["val"]), Rect2(r.position.x, y, r.size.x, 96), 96, col("text"), 1)
			_t(p, str(o["name"]), Rect2(r.position.x, y + 100, r.size.x, 64), 64, tc.lightened(0.25), 1)
			_tw(p, str(o["desc"]), Rect2(r.position.x + 32, y + 176, r.size.x - 64, 96), 32, col("dim"), 1)
			if int(o["count"]) > 0:
				_t(p, "%d kez aldın" % int(o["count"]), Rect2(r.position.x, r.end.y - 60, r.size.x, 48), 32, Color(col("dim"), 0.8), 1)
		"row":
			_box(p, Rect2(r.position + Vector2(6, 6), Vector2(20, r.size.y - 12)), tc)
			var isz2: float = minf(r.size.y - 32.0, 144.0)
			_img(p, ic, Rect2(r.position.x + 48, r.position.y + (r.size.y - isz2) * 0.5, isz2, isz2), false)
			var x: float = r.position.x + 72 + isz2
			_t(p, str(o["name"]), Rect2(x, r.position.y + 16, 600, 64), 64, col("text"))
			_chip(p, Vector2(x, r.end.y - 72), LV_NAMES[t], tc, 32, 52)
			_t(p, str(o["val"]), Rect2(r.end.x - 360, r.position.y, 320, r.size.y), 96, tc.lightened(0.25), 2)
		"wide":
			_box(p, Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 64)), Color(tc, 0.28))
			_t(p, LV_NAMES[t], Rect2(r.position.x + 28, r.position.y + 6, 500, 64), 48, tc.lightened(0.2))
			if int(o["count"]) > 0:
				_t(p, "%d kez aldın" % int(o["count"]), Rect2(r.end.x - 300, r.position.y + 6, 270, 64), 32, col("dim"), 2)
			_img(p, ic, Rect2(r.position.x + 32, r.position.y + 104, 192, 192), false)
			_t(p, str(o["val"]), Rect2(r.position.x + 256, r.position.y + 96, r.size.x - 280, 96), 96, col("text"))
			_t(p, str(o["name"]), Rect2(r.position.x + 256, r.position.y + 200, r.size.x - 280, 64), 64, tc.lightened(0.25))
			_tw(p, str(o["desc"]), Rect2(r.position.x + 32, r.position.y + 320, r.size.x - 64, 96), 32, col("dim"))


func _room_card(p: Control, r: Rect2, room: Dictionary, sel: bool = false) -> void:
	var full: bool = (room["players"] as Array).size() >= 4
	_box(p, r, col("panel3") if sel else Color(col("panel"), 0.95), col("accent") if sel else col("line"), 6 if sel else 3, 0 if cur == "A" or cur == "D" else 14)
	_portrait(p, int(room["host"]), Rect2(r.position + Vector2(24, 24), Vector2(152, 152)))
	var x: float = r.position.x + 200
	_t(p, str(room["name"]), Rect2(x, r.position.y + 24, r.end.x - x - 24, 64), 48, col("text"))
	_t(p, "Kurucu: " + _cname(int(room["host"])), Rect2(x, r.position.y + 84, r.end.x - x - 24, 48), 32, col("dim"))
	var pc: Color = col("good") if int(room["ping"]) < 80 else col("price")
	var cw: float = _chip(p, Vector2(x, r.position.y + 132), "%d ms" % int(room["ping"]), pc, 32, 48)
	if room["lock"]:
		_box(p, Rect2(x + cw + 16, r.position.y + 132, 56, 48), Color(col("bad"), 0.2), col("bad"), 3, 0)
		_glyph(p, G_LOCK, Vector2(x + cw + 44, r.position.y + 156), 4, col("bad"))
	var y: float = r.position.y + 216
	var slot: float = minf(120.0, (r.size.x - 48.0 - 3 * 16.0) / 4.0)
	for i in 4:
		var sr := Rect2(r.position.x + 24 + i * (slot + 16), y, slot, slot)
		if i < (room["players"] as Array).size():
			_portrait(p, int(room["players"][i]), sr)
		else:
			_box(p, sr, Color(col("inset"), 0.5), Color(col("line_hi"), 0.5), 2, 0 if cur == "A" or cur == "D" else 10)
			_t(p, "+", sr, 64, Color(col("dim"), 0.5), 1)
	y += slot + 20
	_t(p, "%d / 4  ·  %s" % [(room["players"] as Array).size(), str(room["stage"])], Rect2(r.position.x + 24, y, r.size.x - 48, 48), 32,
			col("bad") if full else col("dim"))
	if r.size.y > 520:
		_btn(p, Rect2(r.position.x + 24, r.end.y - 144, r.size.x - 48, 120), "DOLU" if full else "KATIL",
				"disabled" if full else ("primary" if sel else "secondary"), null, 48)


func _team_row(p: Control, r: Rect2, t: Dictionary, fs: int = 32, ready_chip: bool = false) -> void:
	var ps: float = minf(r.size.y, 144.0)
	_portrait(p, int(t["char"]), Rect2(r.position, Vector2(ps, ps)))
	var x: float = r.position.x + ps + 20
	_t(p, str(t["name"]), Rect2(x, r.position.y, r.end.x - x, fs + 8), fs + 16 if fs < 48 else fs, col("text"))
	_t(p, _cname(int(t["char"])), Rect2(x, r.position.y + fs + 16, r.end.x - x, fs), fs, col("dim"))
	if ready_chip:
		var ok: bool = bool(t.get("ready", false))
		_chip(p, Vector2(r.end.x - 200, r.position.y + (ps - 52) * 0.5), "HAZIR" if ok else "SEÇİYOR", col("good") if ok else col("dim"), 32, 52)


func _stat_tile(p: Control, r: Rect2, val: String, label: String, c: Color, ic: Variant = null) -> void:
	_panel(p, r, "panel2", 0.92)
	var vfs: int = 96 if r.size.y >= 200 else 64
	var y0: float = r.position.y + (r.size.y - vfs - 44) * 0.5
	if ic != null:
		_icon(p, ic, Vector2(r.position.x + 64, y0 + vfs * 0.5), 64, c)
		_t(p, val, Rect2(r.position.x + 108, y0 - 4, r.size.x - 120, vfs), vfs, c)
		_t(p, label, Rect2(r.position.x + 108, y0 + vfs, r.size.x - 120, 40), 32, col("dim"))
	else:
		_t(p, val, Rect2(r.position.x, y0 - 4, r.size.x, vfs), vfs, c, 1)
		_t(p, label, Rect2(r.position.x, y0 + vfs, r.size.x, 40), 32, col("dim"), 1)


func _medal(p: Control, center: Vector2, rad: float, glyph: Array, metal: Color, locked: bool) -> void:
	var m: Color = Color(0.22, 0.2, 0.22) if locked else metal
	_disk(p, center, rad + 4, Color("#0c0806"))
	_disk(p, center, rad, m.darkened(0.25), m.lightened(0.2), maxf(4.0, rad * 0.12))
	_glyph(p, glyph, center, maxf(3.0, floorf(rad * 1.1 / 9.0)), m.darkened(0.6) if not locked else Color(0.42, 0.4, 0.44))
	if locked:
		_glyph(p, G_LOCK, center + Vector2(rad * 0.6, rad * 0.6), 4, col("dim"))


func _ach_list() -> Array:
	var out: Array = []
	var metals: Array = [Color("#b8875a"), Color("#c8ccd4"), Color("#f0c070"), Color("#e06a52")]
	var i: int = 0
	for d: Dictionary in _ach_defs():
		var id: String = str(d.get("id", ""))
		var g: Array = G_STAR
		var kk: String = str(d.get("key", ""))
		if kk == "tier":
			g = G_HORNS if id == "final" else G_SKULL
		elif kk == "kills":
			g = G_SWORD
		elif kk == "time":
			g = G_CLOCK
		elif kk.begins_with("vict") or id.begins_with("vict"):
			g = G_CROWN
		elif kk == "runs":
			g = G_FLAG
		out.append({"id": id, "name": str(d.get("name", "")), "desc": str(d.get("desc", "")), "glyph": g,
				"metal": metals[i % 4], "date": str(UNLOCKED.get(id, "")), "frac": 1.0 if UNLOCKED.has(id) else [0.91, 0.62, 0.4, 0.18][i % 4]})
		i += 1
	return out


func _set_row(p: Control, r: Rect2, row: Array, sel: bool = false, fs: int = 48) -> void:
	## Görünüş turu (kullanıcı 2026-10-18 "yapay zekâ gibi"): satır açıklaması yok; odak = PC ayarları (altın %9 zemin + 6 px altın
	## sol kenar, köşesiz); iOS aç/kapa anahtarı ve yuvarlak düğmeli kaydırıcı yerine PC'nin "< Açık >" seçicisi + FireSlider'ı.
	if sel:
		_rect(p, r, Color(col("accent"), 0.09))
		_rect(p, Rect2(r.position, Vector2(6, r.size.y)), col("accent"))
	var lw: float = r.size.x * 0.48
	_t(p, str(row[0]), Rect2(r.position.x + 32, r.position.y, lw, r.size.y), fs, col("accent") if sel else col("text"))
	var cx: float = r.position.x + lw + 24
	var cw: float = r.end.x - cx - 24
	var cy: float = r.get_center().y
	match str(row[1]):
		"toggle":
			_carousel(p, Rect2(cx, cy - 44, cw, 88), "Açık" if bool(row[2]) else "Kapalı", sel)
		"cycle":
			_carousel(p, Rect2(cx, cy - 44, cw, 88), str(row[2]), sel)
		"slider":
			_t(p, str(row[4]), Rect2(cx, cy - 32, 150, 64), fs, col("text"))
			_fire_slider(p, Rect2(cx + 170, cy - 32, cw - 170, 64), float(row[2]))
		"button":
			_btn(p, Rect2(r.end.x - 24 - 380, cy - 52, 380, 104), str(row[2]), "secondary", null, fs)


## PC ayarlarının "< değer >" seçicisi (settings_screen.gd Carousel): iki uçta altın piksel ok, ortada değer; telefonda dokunma alanı
## belli olsun diye köşeli koyu kuyu içinde (sol yarı önceki, sağ yarı sonraki).
const G_AR_L := ["...##", "..###", ".####", "#####", ".####", "..###", "...##"]
const G_AR_R := ["##...", "###..", "####.", "#####", "####.", "###..", "##..."]


func _carousel(p: Control, r: Rect2, val: String, sel: bool) -> void:
	_rect(p, r, col("line"))
	_rect(p, r.grow(-3.0), Color(col("inset"), 0.92))
	_glyph(p, G_AR_L, Vector2(r.position.x + 44, r.get_center().y), 6.0, col("accent"))
	_glyph(p, G_AR_R, Vector2(r.end.x - 44, r.get_center().y), 6.0, col("accent"))
	_t(p, val, Rect2(r.position.x + 88, r.position.y, r.size.x - 176, r.size.y), 48, col("accent") if sel else col("text"), 1)


## PC FireSlider (settings_screen.gd) 2x: çizgi renginde yuva + karanlık iç, altın dolgu + açık üst şerit, çeyrek çentikler, köşeli
## düğme (koyu + krem + açık üst). Yuvarlak düğme / yuvarlak kanal yok.
func _fire_slider(p: Control, r: Rect2, f: float) -> void:
	var x0: float = r.position.x
	var w: float = r.size.x
	var ty: float = roundf(r.get_center().y - 14.0)
	_rect(p, Rect2(x0, ty, w, 28), col("line"))
	_rect(p, Rect2(x0 + 6, ty + 6, w - 12, 16), col("inset"))
	var fx: float = roundf(6.0 + (w - 12.0) * f)
	_rect(p, Rect2(x0 + 6, ty + 6, fx - 6.0, 16), col("accent"))
	_rect(p, Rect2(x0 + 6, ty + 6, fx - 6.0, 6), col("accent").lightened(0.3))
	for i in range(1, 4):
		var tx: float = roundf(6.0 + (w - 12.0) * float(i) / 4.0)
		if tx > fx + 24.0:
			_rect(p, Rect2(x0 + tx - 3.0, ty + 6, 6, 16), col("line"))
	var kw := 36.0
	var kx: float = clampf(x0 + fx - kw * 0.5, x0, x0 + w - kw)
	_rect(p, Rect2(kx, r.position.y + 4, kw, r.size.y - 8), Color(0.04, 0.03, 0.06))
	_rect(p, Rect2(kx + 6, r.position.y + 10, kw - 12, r.size.y - 20), col("text"))
	_rect(p, Rect2(kx + 6, r.position.y + 10, kw - 12, 6), col("text").lightened(0.35))


## Dokunmatik düzen önizlemesi (küçük telefon).
func _touch_preview(p: Control, r: Rect2) -> void:
	_box(p, r.grow(10), Color("#0a0a0c"), Color("#2a2a30"), 6, 24)
	if game_tex:
		_img(p, game_tex, r, false)
	else:
		_rect(p, r, Color("#2d3b22"))
	var k: float = r.size.x / SW
	_disk(p, r.position + Vector2(360, 820) * k, 150 * k, Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.5), 3)
	_disk(p, r.position + Vector2(400, 790) * k, 60 * k, Color(1, 1, 1, 0.45))
	for s: Array in [[Vector2(2140, 870), 112.0], [Vector2(1900, 960), 80.0], [Vector2(1950, 735), 80.0], [Vector2(2130, 620), 66.0]]:
		_disk(p, r.position + (s[0] as Vector2) * k, float(s[1]) * k * 1.1, Color(col("accent"), 0.35), col("accent"), 3)
	_box(p, Rect2(r.position + Vector2(96, 28) * k, Vector2(700, 90) * k), Color(HP_COL, 0.7))
	_disk(p, r.position + Vector2(2170, 160) * k, 130 * k, Color(0.2, 0.3, 0.2, 0.8), Color(1, 1, 1, 0.6), 2)


## ------------------------------------------------------------------ HUD ortak parçalar
func _skill_btn(p: Control, center: Vector2, rad: float, icon_path: String, ring: Color, cd: float = 0.0, cd_txt: String = "") -> void:
	_disk(p, center, rad + 6, Color(0.05, 0.03, 0.02, 0.9))
	_ctex(p, _stex(icon_path), center, rad - 8)
	var d := _disk(p, center, rad, Color(0, 0, 0, 0), ring, 10.0 if rad > 80 else 8.0)
	if cd > 0.0:
		d.sweep = cd
		d.queue_redraw()
		_disk(p, center, rad - 8, Color(0, 0, 0, 0.35))
		_t(p, cd_txt, Rect2(center - Vector2(rad, 40), Vector2(rad * 2, 80)), 64, Color.WHITE, 1)


func _minimap_circle(p: Control, center: Vector2, rad: float) -> void:
	_disk(p, center, rad + 8, Color(0.05, 0.03, 0.02, 0.9))
	_ctex(p, minimap_tex, center, rad, Rect2(56, 70, 72, 72), Color.WHITE, true)
	_disk(p, center, rad, Color(0, 0, 0, 0), Color("#86623f"), 8)
	_disk(p, center, 9, Color.WHITE, Color("#20150d"), 3)
	for v: Vector2 in [Vector2(-40, -22), Vector2(30, 46), Vector2(58, -30)]:
		_disk(p, center + v, 7, Color("#7ab8f0"), Color("#0c1420"), 2)


func _weapon_icons(p: Control, pos: Vector2, sz: float, gap: float, vertical: bool = false) -> void:
	var i: int = 0
	for w: Array in WEAPONS:
		var r := Rect2(pos + (Vector2(0, (sz + gap) * i) if vertical else Vector2((sz + gap) * i, 0)), Vector2(sz, sz))
		var ec: Color = ENCH_COL[int(w[1])]
		_box(p, r, Color(0.05, 0.03, 0.02, 0.72), ec if ec.a > 0 else Color("#86623f"), 3, 0 if cur == "A" or cur == "D" else 8)
		_img(p, _wtex(str(w[0]), int(w[1])), r.grow(-6))
		i += 1


func _hearts(p: Control, pos: Vector2, n: int, cell: float = 4.0) -> void:
	for i in 3:
		_glyph(p, G_HEART, pos + Vector2(i * (8 * cell + 8) + 3.5 * cell, 3.5 * cell), cell, HP_COL if i < n else Color(0.25, 0.2, 0.2))


func _chat_lines(p: Control, pos: Vector2, w: float) -> void:
	var lines: Array = [["Mira", "sandık bende, gelin"], ["Kerem", "can az, Melek iyileştir"]]
	var y: float = pos.y
	for l: Array in lines:
		_box(p, Rect2(pos.x, y, w, 48), Color(0, 0, 0, 0.35))
		_t(p, "%s: %s" % [l[0], l[1]], Rect2(pos.x + 12, y - 2, w - 24, 48), 32, Color("#efe2c6"))
		y += 54


func _party_face(p: Control, r: Rect2, t: Dictionary) -> void:
	_face(p, int(t["char"]), r)
	_bar(p, Rect2(r.position.x, r.end.y + 4, r.size.x, 12), float(t["hp"]) / float(t["mhp"]), HP_COL, Color("#1c0a08"), Color("#0a0604"), 2)
	_bar(p, Rect2(r.position.x, r.end.y + 18, r.size.x, 8), float(t["sh"]) / float(t["msh"]), SH_COL, Color("#0c1420"), Color("#0a0604"), 2)


## ------------------------------------------------------------------ çalıştırma
func _plan() -> Array:
	var only: String = OS.get_environment("MOBIL_ONLY")
	var out: Array = []
	if only == "":
		for d: String in DIRS:
			for s: String in SCREENS:
				out.append([d, s])
		return out
	for part: String in only.split(","):
		var bits: PackedStringArray = part.split(":")
		var ds: Array = DIRS if bits[0] == "*" else [bits[0]]
		var ss: Array = SCREENS if bits.size() < 2 or bits[1] == "*" else [bits[1]]
		for d: String in ds:
			for s: String in ss:
				out.append([d, s])
	return out


func _load_refs() -> void:
	font = load("res://assets/fonts/m5x7.ttf")
	CH = load("res://scripts/characters.gd")
	IT = load("res://scripts/items.gd")
	WC = load("res://scripts/weapon_catalog.gd")
	PC = load("res://scripts/pet_catalog.gd")
	WTA = load("res://scripts/weapon_tier_art.gd")
	MU = load("res://scripts/meta_upgrades.gd")
	SPI = load("res://scripts/spiritual_skills.gd")
	ACH = load("res://scripts/achievements.gd")
	MHB = load("res://scripts/menu_hearth_bg.gd")
	coin_tex = load("res://assets/ui/newui/icon_gold_coin.png")
	wshard_tex = load("res://assets/pickups/weapon_shard/shard_icon.png")
	minimap_tex = load("res://assets/ui/minimap_map.png")
	trim_tex = load("res://assets/ui/ana_menu/kiris_suslu.png")
	candles_tex = load("res://harita/Ev içi/Candles.png")
	var ce: Texture2D = load("res://assets/sprites/chests/chest_elite.png")
	var at := AtlasTexture.new()
	at.atlas = ce
	at.region = Rect2(96 * 15, 0, 96, 96)
	chest_tex = at
	var be: Texture2D = load("res://assets/sprites/chests/chest_beam_elite.png")
	var bt := AtlasTexture.new()
	bt.atlas = be
	bt.region = Rect2(128 * 12, 0, 128, 192)
	beam_tex = bt


func _capture_game_bg() -> void:
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", ME)
	gm.set("selected_character", _def(ME).get("skill", 1))
	gm.set("selected_pet", PET)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.0)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(5.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player:
		player.set("health", float(player.get("max_health")) * 0.8)
	await _wait(1.0)
	for n: Node in current_scene.find_children("*", "CanvasLayer", true, false):
		var cl: CanvasLayer = n as CanvasLayer
		print("LAYER %s %d follow=%s" % [cl.name, cl.layer, str(cl.follow_viewport_enabled)])
		if (cl.name == "HUD" or cl.layer >= 30) and not cl.follow_viewport_enabled:
			cl.visible = false
	for n: Node in root.get_children():
		if n is CanvasLayer and (n as CanvasLayer).layer >= 30:
			(n as CanvasLayer).visible = false
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	img.save_png(ProjectSettings.globalize_path(OUT + "_oyun_arka.png"))
	game_tex = ImageTexture.create_from_image(img)
	var ps := PackedScene.new()
	var empty := Node2D.new()
	empty.name = "Bos"
	ps.pack(empty)
	change_scene_to_packed(ps)
	await _wait(0.5)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	_load_refs()
	var missing: String = ""
	for ch: String in "İıŞşĞğÇçÖöÜü·->%+":
		if not font.has_char(ch.unicode_at(0)):
			missing += ch
	print("FONT_MISSING [%s]" % missing)
	var plan: Array = _plan()
	var set_s: bool = OS.get_environment("MOBIL_ONLY") == "S"
	if set_s:
		plan = []
		for sc: String in SCREENS:
			plan.append(["S", sc])
		for sc: String in S_VARIANTS:
			plan.append(["S", sc])
	var bg_path: String = OUT + "_oyun_arka.png"
	if OS.get_environment("MOBIL_REUSE_BG") != "" and FileAccess.file_exists(ProjectSettings.globalize_path(bg_path)):
		var im := Image.load_from_file(ProjectSettings.globalize_path(bg_path))
		game_tex = ImageTexture.create_from_image(im)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(2400, 1080))
		await _wait(1.0)
	else:
		await _capture_game_bg()
	if OS.get_environment("MOBIL_ONLY") == "ML":
		mlfont = load("res://assets/fonts/Nunito-SemiBold.ttf")
		for st: String in ["takim", "sohbet", "altin", "istatistik"]:
			await _render_ml(st)
		await _sheet_ml()
		quit()
		return
	if OS.get_environment("MOBIL_ONLY") == "HUD":
		for v: String in HUD_VARIANTS:
			for st: String in ["acik", "kapali"]:
				await _render_hud(v, st)
		await _sheets_hud()
		quit()
		return
	for e: Array in plan:
		await _render(str(e[0]), str(e[1]))
	if OS.get_environment("MOBIL_ONLY") == "":
		await _sheets()
	elif set_s:
		await _sheets_s()
	quit()


## "S" = kullanıcının seçtiği set (2026-10-18): B derisi; ana menü/duraklatma/ayarlar A düzeni, sandık/level/oda YENİ dostane
## sürümler (S_<ekran> = 1. seçenek, S_<ekran>_2 = 2. seçenek), geri kalanı B_<ekran>.
const S_FROM_A := ["ana_menu", "duraklat", "ayarlar"]
const S_VARIANTS := ["level_2", "sandik_2", "oda_2"]


func _render(d: String, sc: String) -> void:
	var fn: String = d + "_" + sc
	cur = d
	if d == "S":
		cur = "B"
		fn = "S_" + sc if has_method("S_" + sc) else (("A_" if S_FROM_A.has(sc) else "B_") + sc)
	S = SKINS[cur]
	var l := CanvasLayer.new()
	l.layer = 96
	root.add_child(l)
	var rc := Control.new()
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(rc)
	rc.position = Vector2.ZERO
	rc.size = Vector2(SW, SH)
	if MENU_SCREENS.has(sc.trim_suffix("_2")):
		MHB.call("add_to", rc, 0.0)
	elif game_tex:
		_img(rc, game_tex, Rect2(0, 0, SW, SH), true)
	call(fn, rc)
	await _wait(0.5)
	shots[d + "_" + sc] = await _shot(d + "_" + sc)
	l.queue_free()
	await process_frame


func _sheets() -> void:
	for d: String in DIRS:
		cur = d
		S = SKINS[d]
		var l := CanvasLayer.new()
		l.layer = 97
		root.add_child(l)
		var rc := _ctl_root(l)
		_rect(rc, Rect2(0, 0, SW, SH), Color("#141210"))
		_t(rc, DIR_NAMES[d], Rect2(40, 12, 2000, 72), 64, col("accent"))
		for i in SCREENS.size():
			var key: String = d + "_" + SCREENS[i]
			if not shots.has(key):
				continue
			@warning_ignore("integer_division")
			var cx: float = 40 + (i % 5) * 470
			@warning_ignore("integer_division")
			var cy: float = 100 + (i / 5) * 320
			_img(rc, _thumb(shots[key], 448, 202), Rect2(cx, cy, 448, 202), true)
			_box(rc, Rect2(cx, cy, 448, 202), Color(0, 0, 0, 0), Color("#3a3028"), 2)
			_t(rc, "%d. %s" % [i + 1, SCREEN_NAMES[SCREENS[i]]], Rect2(cx, cy + 206, 448, 44), 32, Color("#efe2c6"))
		await _wait(0.3)
		await _shot("ozet_" + d)
		l.queue_free()
	for sc: String in SCREENS:
		var l2 := CanvasLayer.new()
		l2.layer = 97
		root.add_child(l2)
		var rc2 := _ctl_root(l2)
		_rect(rc2, Rect2(0, 0, SW, SH), Color("#141210"))
		for i in 4:
			var key2: String = DIRS[i] + "_" + sc
			if not shots.has(key2):
				continue
			@warning_ignore("integer_division")
			var r := Rect2(50 + (i % 2) * 1200, 44 + (i / 2) * 538, 1100, 495)
			_img(rc2, _thumb(shots[key2], 1100, 495), r, true)
			cur = DIRS[i]
			S = SKINS[DIRS[i]]
			_t(rc2, DIR_NAMES[DIRS[i]], Rect2(r.position.x, r.position.y - 42, 1100, 40), 32, col("accent"))
		await _wait(0.3)
		await _shot("karsi_" + sc)
		l2.queue_free()


func _ctl_root(l: CanvasLayer) -> Control:
	var rc := Control.new()
	rc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(rc)
	rc.size = Vector2(SW, SH)
	return rc


func _thumb(img: Image, w: int, h: int) -> Texture2D:
	var im: Image = img.duplicate()
	im.convert(Image.FORMAT_RGBA8)
	im.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(im)


## ====================================================================================== A - ATEŞ IŞIĞI / BAŞPARMAK ÇUBUĞU
## Üst şerit (geri + başlık + para) / içerik y 176-892 / alt çubuk y 916-1052: solda ikinciller, sağda tek birincil.
func _A_frame(rc: Control, title: String, sub: String, money: Array, primary: String, pic: Variant, secs: Array, back: bool = true, dim: float = 0.62) -> void:
	_dim(rc, dim)
	_fade(rc, Rect2(0, 0, SW, 200), col("dimbg"), 0, 0.75)
	_fade(rc, Rect2(0, SH - 230, SW, 230), col("dimbg"), 1, 0.85)
	var tx: float = SX
	if back:
		_sq_btn(rc, Rect2(SX, SY, 120, 120), G_BACK)
		tx = SX + 152
	_t(rc, title, Rect2(tx, SY - 4, 1200, 80), 64, col("accent"))
	if sub != "":
		_t(rc, sub, Rect2(tx, SY + 70, 1200, 48), 32, col("dim"))
	var x: float = RX
	for m: Array in money:
		x = _money(rc, x, SY + 16, str(m[0]), int(m[1])) - 16
	var bx: float = SX
	for s: Array in secs:
		_btn(rc, Rect2(bx, 916, float(s[2]), 136), str(s[0]), str(s[3]) if s.size() > 3 else "secondary", s[1], 48)
		bx += float(s[2]) + 20
	if primary != "":
		_btn(rc, Rect2(RX - 620, 916, 620, 136), primary, "primary", pic, 64)


func A_ana_menu(rc: Control) -> void:
	_fade(rc, Rect2(0, 0, 1500, SH), col("dimbg"), 2, 0.9, 10)
	_title_logo(rc, Vector2(SX + 8, 40))
	var items: Array = [
		["TEK OYUNCU", "Tek başına hayatta kal", G_PLAY], ["ÇOK OYUNCU", "İnternet ya da LAN odası", G_USERS],
		["RUH MAĞAZASI", "Kilit aç, kalıcı geliştir", "soul"], ["REKORLAR", "En iyiler + başarımlar", G_TROPHY],
		["AYARLAR", "Ses, grafik, dokunmatik", G_GEAR],
	]
	var y: float = 352.0
	for i in items.size():
		var it: Array = items[i]
		var sel: bool = i == 0
		var r := Rect2(SX, y, 900, 132)
		if sel:
			_box(rc, r, Color(col("accent"), 0.14))
			_rect(rc, Rect2(r.position, Vector2(8, r.size.y)), col("accent"))
			var at := AtlasTexture.new()
			at.atlas = candles_tex
			at.region = Rect2(96, 0, 32, 32)
			_img(rc, at, Rect2(r.position.x + 24, r.position.y + 18, 96, 96))
		else:
			_glyph(rc, G_DIAMOND, Vector2(r.position.x + 72, r.get_center().y), 5, Color(col("dim"), 0.6))
		_icon(rc, it[2], Vector2(r.position.x + 192, r.get_center().y), 64, col("accent") if sel else col("text"))
		_t(rc, it[0], Rect2(r.position.x + 264, r.position.y + 8, 640, 72), 64, col("accent") if sel else col("text"))
		_t(rc, it[1], Rect2(r.position.x + 264, r.position.y + 76, 640, 44), 32, col("dim"))
		y += 140
	_money(rc, RX, SY + 16, "soul", SOUL)
	_box(rc, Rect2(RX - 700, 760, 700, 136), Color(col("panel"), 0.85), col("line"), 4)
	_portrait(rc, ME, Rect2(RX - 684, 776, 104, 104))
	_t(rc, "Son seçim", Rect2(RX - 560, 776, 520, 44), 32, col("dim"))
	_t(rc, "Oakley, Peri, Tüfek", Rect2(RX - 560, 820, 540, 56), 48, col("text"))
	_btn(rc, Rect2(RX - 700, 916, 700, 136), "HIZLI BAŞLA", "primary", G_PLAY, 64)


func A_oda(rc: Control) -> void:
	_A_frame(rc, "ÇOK OYUNCU", "Odaya dokun, katıl", [], "ODA KUR", G_PLUS, [["YENİLE", G_REROLL, 320], ["KODLA GİR", G_KEY, 400]])
	_tabs(rc, Rect2(RX - 640, SY + 8, 640, 104), ["İNTERNET", "LAN"], 0)
	var clip := _ctl(rc, Rect2(SX, 176, RX - SX, 720), true)
	var x: float = 0.0
	for i in ROOMS.size():
		_room_card(clip, Rect2(x, 8, 560, 700), ROOMS[i], i == 0)
		x += 592
	_scroll_hint(rc, Rect2(SX, 176, RX - SX, 720))


func A_karakter(rc: Control) -> void:
	var pet_tex: Texture2D = PC.call("icon", PET)
	_A_frame(rc, "KARAKTER SEÇ", "Kaydır, dokun, HAZIR", [], "HAZIR", G_CHECK,
			[["Peri", pet_tex, 300], ["Tüfek", _wtex("tufek", 1), 320], ["Can", _stex(str(_spirit(SPIRIT).get("icon", ""))), 280]])
	var fx: float = RX
	for i in range(TEAM.size() - 1, 0, -1):
		var t: Dictionary = TEAM[i]
		_portrait(rc, int(t["char"]), Rect2(fx - 104, SY + 8, 104, 104), col("good") if t["ready"] else col("line_hi"))
		if t["ready"]:
			_box(rc, Rect2(fx - 40, SY + 76, 36, 36), col("good"), Color("#1c2a12"), 2)
			_glyph(rc, G_CHECK, Vector2(fx - 22, SY + 94), 3, Color("#16220c"))
		fx -= 120
	_t(rc, "Mira'nın odası · 2/4 hazır", Rect2(fx - 520, SY + 8, 500, 104), 32, col("dim"), 2)
	var clip := _ctl(rc, Rect2(0, 168, SW, 736), true)
	var ids: Array = [1, ME, 3, 4, 5, 7, 8]
	var x: float = SX - 200
	for cid: int in ids:
		if cid == ME:
			var r := Rect2(x, 8, 900, 720)
			_box(clip, r, Color(col("panel"), 0.96), col("accent"), 6)
			_box(clip, Rect2(r.position + Vector2(24, 24), Vector2(320, 420)), Color(col("inset"), 0.8), col("line"), 3)
			_sprite(clip, cid, Vector2(r.position.x + 184, r.position.y + 410), 7.0)
			_t(clip, _cname(cid), Rect2(r.position.x + 372, r.position.y + 20, 500, 80), 64, col("accent"))
			_tw(clip, "Arılarla saldırır, takımını iyileştirir.", Rect2(r.position.x + 372, r.position.y + 100, 500, 80), 32, col("dim"))
			_stat_bars(clip, Rect2(r.position.x + 372, r.position.y + 200, 500, 240), cid)
			_skill_icons(clip, Vector2(r.position.x + 40, r.position.y + 480), cid, 144, 64, true, 152)
			x += 932
		else:
			_char_tile(clip, Rect2(x, 120, 300, 520), cid, false, true, "Mira" if cid == 10 else "")
			x += 332
	_fade(rc, Rect2(0, 168, 220, 736), col("dimbg"), 2, 0.85, 6)
	_scroll_hint(rc, Rect2(0, 168, SW, 736))


func A_hud(rc: Control) -> void:
	_fade(rc, Rect2(0, 0, SW, 180), Color(0, 0, 0), 0, 0.35, 6)
	var lv := Vector2(SX + 56, SY + 60)
	_disk(rc, lv, 60, Color("#20150d"), Color("#f0c070"), 6)
	_t(rc, str(LEVEL), Rect2(lv - Vector2(60, 34), Vector2(120, 64)), 64, Color("#f3e6cc"), 1)
	_hp(rc, Rect2(SX + 136, SY + 6, 640, 76), TEAM[0], 32, 18)
	_bar(rc, Rect2(SX + 136, SY + 90, 640, 14), 0.62, XP_COL, Color("#0e1a08"), Color("#0a0604"), 2)
	_hearts(rc, Vector2(SX + 136, SY + 116), 2, 4)
	_money_icon(rc, "coin", Rect2(SX + 300, SY + 114, 32, 32))
	_t(rc, _num(GOLD), Rect2(SX + 340, SY + 108, 200, 44), 32, Color("#f6d27e"))
	for i in range(1, TEAM.size()):
		_party_face(rc, Rect2(SX, 250 + (i - 1) * 150, 96, 96), TEAM[i])
		_t(rc, str(TEAM[i]["name"]), Rect2(SX + 108, 250 + (i - 1) * 150, 220, 40), 32, Color("#efe2c6"))
	_box(rc, Rect2(SW * 0.5 - 220, SY, 440, 72), Color(0.08, 0.05, 0.03, 0.72), Color("#86623f"), 3)
	_t(rc, "KADEME VII  ·  18:42", Rect2(SW * 0.5 - 220, SY, 440, 72), 48, Color("#f0c070"), 1)
	_minimap_circle(rc, Vector2(RX - 136, SY + 136), 128)
	_sq_btn(rc, Rect2(RX - 432, SY + 8, 112, 112), G_PAUSE)
	_sq_btn(rc, Rect2(RX - 432, SY + 136, 112, 112), G_BAG)
	_chat_lines(rc, Vector2(SW * 0.5 - 380, SY + 96), 760)
	var jc := Vector2(380, 860)
	_disk(rc, jc, 156, Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.38), 6)
	_disk(rc, jc + Vector2(44, -30), 66, Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.6), 4)
	var sk: Array = _skills(ME)
	_skill_btn(rc, Vector2(2150, 880), 108, sk[3][2], Color("#f0c070"))
	_skill_btn(rc, Vector2(1906, 968), 80, sk[1][2], Color("#86623f"))
	_skill_btn(rc, Vector2(1940, 752), 80, sk[2][2], Color("#86623f"), 0.55, "4")
	_skill_btn(rc, Vector2(2118, 636), 66, str(_spirit(SPIRIT).get("icon", "")), SPIRIT_COL)
	_weapon_icons(rc, Vector2(SW * 0.5 - 150, 976), 88, 18)
	var ir := Rect2(SW * 0.5 - 230, 820, 460, 112)
	_box(rc, ir, Color(0.05, 0.03, 0.02, 0.8), Color("#f0c070"), 4)
	_glyph(rc, G_HAND, Vector2(ir.position.x + 64, ir.get_center().y), 6, Color("#f0c070"))
	_t(rc, "SATICI", Rect2(ir.position.x + 120, ir.position.y, 320, 112), 64, Color("#f3e6cc"))


func A_level(rc: Control) -> void:
	_A_frame(rc, "SEVİYE %d!" % LEVEL, "Bir karta dokun - hemen seçilir", [], "", null, [["KARIŞTIR  2", G_REROLL, 440], ["YASAKLA  1", G_BAN, 420]], false, 0.7)
	var w: float = 680.0
	var gap: float = (RX - SX - w * 3) / 2.0
	for i in 3:
		_lv_card(rc, Rect2(SX + i * (w + gap), 172, w, 720), LV_OPTS[i], "big", false)
	var d := _disk(rc, Vector2(RX - 68, 984), 64, Color(col("inset"), 0.9), Color(col("line"), 1), 8)
	d.arc_frac = 0.68
	d.arc_col = col("accent")
	_t(rc, "17", Rect2(RX - 132, 950, 128, 64), 64, col("text"), 1)
	_t(rc, "Mira ve Deniz seçiyor", Rect2(RX - 760, 950, 600, 64), 32, col("dim"), 2)


func A_sandik(rc: Control) -> void:
	var key: String = (_items(3) as Array)[1]
	_A_frame(rc, "ELİT SANDIK", "Sıra sende: al ya da sat", [["coin", GOLD]], "AL", G_CHECK, [["SAT  +%s" % _num(int(_icost(key) * 0.5)), "coin", 520]], false, 0.66)
	var cr := Rect2(SW * 0.5 - 330, 176, 660, 720)
	_img(rc, beam_tex, Rect2(cr.get_center().x - 256, 110, 512, 768), true, Color(1, 1, 1, 0.75))
	_panel(rc, cr, "panel", 0.96, true)
	_box(rc, Rect2(cr.position + Vector2(6, 6), Vector2(cr.size.x - 12, 72)), Color(IT_COL[2], 0.3))
	_t(rc, "EFSANEVİ", Rect2(cr.position.x, cr.position.y + 6, cr.size.x, 72), 48, IT_COL[2].lightened(0.25), 1)
	_img(rc, _itex(key), Rect2(cr.get_center().x - 96, cr.position.y + 104, 192, 192))
	_t(rc, _iname(key), Rect2(cr.position.x, cr.position.y + 312, cr.size.x, 72), 64, col("text"), 1)
	var y: float = cr.position.y + 400
	for ln: String in _desc(key).split("\n"):
		if ln == "":
			continue
		if ln.begins_with("Pasif:"):
			_tw(rc, ln, Rect2(cr.position.x + 40, y + 8, cr.size.x - 80, 128), 32, col("dim"), 1)
			break
		_t(rc, ln, Rect2(cr.position.x, y, cr.size.x, 52), 48, col("good"), 1)
		y += 54
	_t(rc, "Çanta: Efsanevi 2 / 5", Rect2(SX, 420, 560, 56), 48, col("dim"))
	_t(rc, "Sıradaki", Rect2(RX - 420, 360, 420, 44), 32, col("dim"), 2)
	for i in range(1, TEAM.size()):
		_portrait(rc, int(TEAM[i]["char"]), Rect2(RX - 104 - (i - 1) * 120, 416, 104, 104))


func A_envanter(rc: Control) -> void:
	_A_frame(rc, "ÇANTA", "Eşyaya dokun: ayrıntı + sat", [["wshard", WSHARD], ["coin", GOLD]], "SAT  +%s" % _num(int(_icost(BAG_SEL) * 0.5)), "coin",
			[["ÇANTA", G_BAG, 340, "selected"], ["ÖZELLİKLER", G_STAR, 440]])
	_panel(rc, Rect2(SX, 176, 380, 716), "panel", 0.9)
	_t(rc, "SİLAHLAR 3/3", Rect2(SX + 24, 188, 340, 48), 32, col("dim"))
	for i in WEAPONS.size():
		var w: Array = WEAPONS[i]
		_weapon_tile(rc, Rect2(SX + 24, 244 + i * 212, 332, 196), str(w[0]), int(w[1]), false, true, true)
	var gx: float = SX + 404
	_panel(rc, Rect2(gx, 176, 928, 716), "panel", 0.9)
	var bag: Array = _bag()
	var leg: Array = []
	var epi: Array = []
	var par: Array = []
	for k: String in bag:
		match _ik(k):
			3:
				leg.append(k)
			2:
				epi.append(k)
			_:
				par.append(k)
	var rows: Array = [["EFSANEVİ %d/5" % leg.size(), leg, 5, 3], ["EPİK %d/10" % epi.size(), epi, 10, 2], ["PARÇA", par, 5, 1]]
	var y: float = 188.0
	for row: Array in rows:
		_t(rc, row[0], Rect2(gx + 24, y, 600, 44), 32, IT_COL[int(row[3]) - 1])
		y += 48
		var n: int = int(row[2])
		var per_row: int = 5
		for j in n:
			@warning_ignore("integer_division")
			var rr := Rect2(gx + 24 + (j % per_row) * 176, y + (j / per_row) * 152, 160, 140)
			var key: String = (row[1] as Array)[j] if j < (row[1] as Array).size() else ""
			_item_slot(rc, rr, key, int(row[3]), key == BAG_SEL)
		@warning_ignore("integer_division")
		y += ((n + per_row - 1) / per_row) * 152 + 8
	var dx: float = gx + 952
	_panel(rc, Rect2(dx, 176, RX - dx, 716), "panel", 0.94, true)
	_item_detail(rc, Rect2(dx + 32, 208, RX - dx - 64, 660), BAG_SEL, true)


func A_seyyar(rc: Control) -> void:
	_A_frame(rc, "SEYYAR SATICI", "Kalan süre 01:42", [["coin", GOLD]], "SATIN AL  %s" % _num(_icost(SHOP_SEL)), "coin",
			[["ÇANTA  7/15", G_BAG, 460]])
	var clip := _ctl(rc, Rect2(0, 168, SW, 740), true)
	var epi: Array = _items(2)
	var leg: Array = _items(3)
	var x: float = SX - 160
	var shown: Array = []
	var si: int = epi.find(SHOP_SEL)
	for j in range(maxi(0, si - 1), mini(epi.size(), si + 3)):
		shown.append(epi[j])
	_chip(clip, Vector2(x + 160, 4), "EPİK", IT_COL[1], 32, 48)
	for key: String in shown:
		if key == SHOP_SEL:
			var r := Rect2(x, 64, 980, 664)
			_box(clip, r, Color(col("panel"), 0.97), col("accent"), 6)
			var by: float = _item_detail(clip, Rect2(r.position.x + 32, r.position.y + 28, r.size.x - 64, 380), key, true)
			var ry: float = by + 24
			_recipe(clip, Vector2(r.position.x + 32, ry), key, 128, 440)
			var bi: Array = IT.call("builds_into", key)
			if not bi.is_empty():
				_t(clip, "DÖNÜŞÜR", Rect2(r.position.x + 480, ry, 300, 40), 32, col("dim"))
				for j in mini(3, bi.size()):
					_item_slot(clip, Rect2(r.position.x + 480 + j * 144, ry + 44, 128, 128), str(bi[j]), _ik(str(bi[j])))
			_t(clip, "Parçalar çantadan kullanılır  ·  kalan stok 1", Rect2(r.position.x + 32, r.end.y - 72, r.size.x - 64, 48), 32, col("dim"))
			x += 1012
		else:
			_item_tile(clip, Rect2(x, 120, 300, 560), key, false, false, true, true)
			x += 332
	_chip(clip, Vector2(x, 4), "EFSANEVİ", IT_COL[2], 32, 48)
	for j in mini(3, leg.size()):
		_item_tile(clip, Rect2(x, 120, 300, 560), leg[j], false, false, true, true)
		x += 332
	_fade(rc, Rect2(0, 168, 200, 740), col("dimbg"), 2, 0.85, 6)
	_scroll_hint(rc, Rect2(0, 168, SW, 740))


func A_demirci(rc: Control) -> void:
	var c: Array = _w_cost(3)
	_A_frame(rc, "DEMİRCİ", "Silahını geliştir ya da yenisini al", [["wshard", WSHARD], ["coin", GOLD]], "GELİŞTİR  %d" % int(c[0]), G_HAMMER,
			[["SİLAHLARIM", null, 400, "selected"], ["YENİ SİLAH", null, 380], ["KALKAN", G_SHIELD, 320]])
	var r := Rect2(SX, 176, 1180, 716)
	_box(rc, r, Color(col("panel"), 0.97), col("accent"), 6)
	var y: float = _weapon_detail(rc, Rect2(r.position.x + 32, r.position.y + 32, r.size.x - 64, 520), "tufek", 3, 192)
	_t(rc, "Bedel", Rect2(r.position.x + 32, y + 16, 200, 56), 48, col("dim"))
	_cost_row(rc, Vector2(r.position.x + 240, y + 20), int(c[0]), int(c[1]))
	var x: float = SX + 1212
	for i in range(1, WEAPONS.size()):
		_weapon_tile(rc, Rect2(x, 240, 330, 600), str(WEAPONS[i][0]), int(WEAPONS[i][1]), false, true, true)
		x += 362
	_box(rc, Rect2(x, 240, RX - x, 600), Color(col("inset"), 0.5), Color(col("line_hi"), 0.5), 3)
	_glyph(rc, G_LOCK, Vector2(x + (RX - x) * 0.5, 480), 8, Color(col("dim"), 0.6))
	_tw(rc, "Yuvalar dolu (3/3)", Rect2(x + 16, 560, RX - x - 32, 96), 32, col("dim"), 1)


func A_ruh(rc: Control) -> void:
	var cost: int = int(MetaCosts.CHAR.get(SOUL_SEL, 400))
	_A_frame(rc, "RUH MAĞAZASI", "Kıymıklarınla kilit aç", [["soul", SOUL]], "KİLİDİ AÇ  %d" % cost, "soul",
			[["KAHRAMAN", null, 300, "selected"], ["SİLAH", null, 220], ["EVCİL", null, 220], ["RUHANİ", null, 240], ["GELİŞTİR", null, 280]])
	var clip := _ctl(rc, Rect2(0, 168, SW, 740), true)
	var x: float = SX - 180
	for cid: int in [12, SOUL_SEL, 14, 15, 1, 2]:
		if cid == SOUL_SEL:
			var r := Rect2(x, 8, 980, 724)
			_box(clip, r, Color(col("panel"), 0.97), col("accent"), 6)
			_box(clip, Rect2(r.position + Vector2(24, 24), Vector2(340, 440)), Color(col("inset"), 0.8), col("line"), 3)
			_sprite(clip, cid, Vector2(r.position.x + 194, r.position.y + 430), 7.0)
			_t(clip, _cname(cid), Rect2(r.position.x + 392, r.position.y + 24, 560, 80), 64, col("accent"))
			_gem(clip, Rect2(r.position.x + 392, r.position.y + 116, 48, 48))
			_t(clip, "%d  ·  KİLİTLİ" % cost, Rect2(r.position.x + 452, r.position.y + 108, 500, 64), 48, SOUL_COL)
			_stat_bars(clip, Rect2(r.position.x + 392, r.position.y + 200, 560, 240), cid)
			_skill_icons(clip, Vector2(r.position.x + 40, r.position.y + 488), cid, 144, 72, true, 160)
			x += 1012
		else:
			_char_tile(clip, Rect2(x, 120, 300, 520), cid, false, true)
			if not LOCKED_CHARS.has(cid) and cid != 15:
				_chip(clip, Vector2(x + 16, 136), "AÇIK", col("good"), 32, 48)
			x += 332
	_fade(rc, Rect2(0, 168, 200, 740), col("dimbg"), 2, 0.85, 6)
	_scroll_hint(rc, Rect2(0, 168, SW, 740))


func A_duraklat(rc: Control) -> void:
	_dim(rc, 0.5)
	_fade(rc, Rect2(0, 0, 1300, SH), col("dimbg"), 2, 0.92, 10)
	_t(rc, "DURAKLATILDI", Rect2(SX, 40, 1100, 112), 96, col("accent"))
	_t(rc, "Çok oyunculu: oyun arkada sürüyor", Rect2(SX, 152, 1100, 56), 32, col("bad"))
	## Kullanıcı (2026-10-18): "duraklatmada sohbet seçeneği olmasın".
	var items: Array = [["DEVAM ET", G_PLAY], ["AYARLAR", G_GEAR], ["ANA MENÜ", G_HOME]]
	for i in items.size():
		var r := Rect2(SX, 280 + i * 168, 900, 148)
		if i == 0:
			_box(rc, r, Color(col("accent"), 0.16))
			_rect(rc, Rect2(r.position, Vector2(8, r.size.y)), col("accent"))
		_icon(rc, items[i][1], Vector2(r.position.x + 96, r.get_center().y), 72, col("accent") if i == 0 else col("text"))
		_t(rc, items[i][0], Rect2(r.position.x + 184, r.position.y, 700, r.size.y), 64, col("accent") if i == 0 else (col("bad") if items[i][0] == "ANA MENÜ" else col("text")))
	var px: float = 1440.0
	_panel(rc, Rect2(px, 64, RX - px, 952), "panel", 0.92)
	_t(rc, "KOŞU", Rect2(px + 32, 80, 400, 56), 48, col("dim"))
	var stats: Array = [["Süre", RUN_TIME], ["Kademe", "VII"], ["Seviye", str(LEVEL)], ["Öldürme", _num(KILLS)], ["Altın", _num(GOLD)]]
	for i in stats.size():
		var y: float = 144 + i * 72
		_t(rc, stats[i][0], Rect2(px + 32, y, 400, 64), 48, col("dim"))
		_t(rc, stats[i][1], Rect2(px + 400, y, RX - px - 432, 64), 48, col("text"), 2)
	_t(rc, "TAKIM", Rect2(px + 32, 520, 400, 56), 48, col("dim"))
	for i in TEAM.size():
		var y2: float = 584 + i * 108
		_portrait(rc, int(TEAM[i]["char"]), Rect2(px + 32, y2, 96, 96))
		_t(rc, str(TEAM[i]["name"]), Rect2(px + 148, y2, 260, 52), 48, col("text"))
		_pc_bars(rc, Vector2(px + 420, y2 + 30), floorf((RX - px - 460) / 3.0), 8.0, 3.0, TEAM[i], false)


func A_ayarlar(rc: Control) -> void:
	## Görünüş turu (kullanıcı 2026-10-18 "yapay zekâ gibi"): "Değişiklikler hemen kaydedilir" alt yazısı, satır açıklamaları ve
	## sekme simgeleri kalktı; satırlar ayrı kart değil, PC ayarları gibi tek levhada ince çizgiyle ayrılır.
	_A_frame(rc, "AYARLAR", "", [], "", null,
			[["GENEL", null, 300], ["GRAFİK", null, 300], ["DOKUNMATİK", null, 460, "selected"], ["SES", null, 260]], true, 0.72)
	_btn(rc, Rect2(RX - 420, 916, 420, 136), "VARSAYILAN", "ghost", null, 48)
	var area := Rect2(SX, 160, RX - SX - 40, 740)
	_box(rc, area, Color(col("panel"), 0.9), col("line"), 3, int(S["rad"]))
	var clip := _ctl(rc, area.grow(-3.0), true)
	for i in SET_ROWS.size():
		var r := Rect2(0, 4 + i * 124, area.size.x - 6, 120)
		_set_row(clip, r, SET_ROWS[i], i == 1)
		if i < SET_ROWS.size() - 1:
			_rect(clip, Rect2(28, r.end.y + 1, r.size.x - 56, 2), Color(col("accent"), 0.16))
	_box(rc, Rect2(RX - 16, 176, 12, 716), Color(col("inset"), 0.8))
	_box(rc, Rect2(RX - 16, 176, 12, 520), col("line_hi"))
	_scroll_hint(rc, area, false)


func A_oyun_bitti(rc: Control) -> void:
	_dim(rc, 0.78)
	_t(rc, "OYUN BİTTİ", Rect2(0, 36, SW, 128), 128, col("bad"), 1)
	_t(rc, "Kademe IX'da düştün  ·  %s" % str(GO["time"]), Rect2(0, 164, SW, 56), 48, col("dim"), 1)
	var stats: Array = [[str(GO["time"]), "SÜRE", G_CLOCK], ["IX", "KADEME", G_SKULL], [_num(int(GO["kills"])), "ÖLDÜRME", G_SWORD],
			[str(GO["level"]), "SEVİYE", G_STAR], ["+%d" % int(GO["soul"]), "RUH KIYMIĞI", "soul"]]
	var w: float = (RX - SX - 4 * 24) / 5.0
	for i in 5:
		_stat_tile(rc, Rect2(SX + i * (w + 24), 248, w, 220), stats[i][0], stats[i][1], SOUL_COL if i == 4 else col("text"), stats[i][2])
	var tw: float = (RX - SX - 3 * 24) / 4.0
	for i in TEAM.size():
		var t: Dictionary = TEAM[i]
		var r := Rect2(SX + i * (tw + 24), 500, tw, 380)
		_panel(rc, r, "panel", 0.94, i == 2)
		_portrait(rc, int(t["char"]), Rect2(r.position + Vector2(24, 24), Vector2(152, 152)))
		_t(rc, str(t["name"]), Rect2(r.position.x + 196, r.position.y + 28, tw - 210, 64), 64, col("text"))
		_t(rc, _cname(int(t["char"])), Rect2(r.position.x + 196, r.position.y + 100, tw - 210, 48), 32, col("dim"))
		_t(rc, _num(int(t["dmg"])), Rect2(r.position.x + 24, r.position.y + 200, tw - 48, 96), 96, col("price"))
		_t(rc, "hasar", Rect2(r.position.x + 24, r.position.y + 292, 200, 44), 32, col("dim"))
		if i == 2:
			_chip(rc, Vector2(r.end.x - 240, r.position.y + 300), "EN ÇOK HASAR", col("accent"), 32, 52, true)
	_btn(rc, Rect2(SX, 916, 460, 136), "İSTATİSTİK", "secondary", G_GRID, 48)
	_btn(rc, Rect2(SX + 480, 916, 380, 136), "TEKRAR", "secondary", G_REROLL, 48)
	_btn(rc, Rect2(RX - 620, 916, 620, 136), "ANA MENÜ", "primary", G_HOME, 64)


func A_rekor(rc: Control) -> void:
	_A_frame(rc, "REKORLAR", "31 koşu  ·  1 zafer  ·  9 sa 41 dk", [], "", null,
			[["EN İYİLER", G_TROPHY, 420, "selected"], ["BAŞARIMLAR  11/17", G_STAR, 580]], true, 0.66)
	var clip := _ctl(rc, Rect2(0, 168, SW, 740), true)
	var x: float = SX
	for i in RECORDS.size():
		var rec: Array = RECORDS[i]
		var r := Rect2(x, 8, 480, 400)
		_panel(clip, r, "panel", 0.95, bool(rec[3]))
		_medal(clip, Vector2(r.position.x + 96, r.position.y + 100), 64, GLYPH_BY_NAME[rec[2]], Color("#f0c070"), false)
		if rec[3]:
			_chip(clip, Vector2(r.end.x - 140, r.position.y + 24), "YENİ", col("bad"), 32, 52, true)
		_t(clip, rec[1], Rect2(r.position.x + 32, r.position.y + 190, r.size.x - 64, 112), 112, col("text"))
		_t(clip, rec[0], Rect2(r.position.x + 32, r.position.y + 310, r.size.x - 64, 56), 32, col("dim"))
		x += 512
	_t(clip, "SIRADAKİ BAŞARIMLAR", Rect2(SX, 432, 900, 52), 48, col("dim"))
	var ach: Array = _ach_list()
	var ax: float = SX
	for a: Dictionary in ach:
		if a["date"] != "":
			continue
		var r2 := Rect2(ax, 496, 560, 220)
		_panel(clip, r2, "panel2", 0.92)
		_medal(clip, Vector2(r2.position.x + 88, r2.position.y + 92), 56, a["glyph"], a["metal"], true)
		_t(clip, a["name"], Rect2(r2.position.x + 172, r2.position.y + 20, 370, 56), 48, col("text"))
		_tw(clip, a["desc"], Rect2(r2.position.x + 172, r2.position.y + 80, 370, 64), 32, col("dim"))
		_bar(clip, Rect2(r2.position.x + 24, r2.position.y + 172, r2.size.x - 48, 24), float(a["frac"]), col("accent"))
		ax += 592
	_scroll_hint(rc, Rect2(0, 168, SW, 740))


## ====================================================================================== B - GECE SIVASI / YAN RAY + DETAY
## Sol ray (x 0-272: geri + dikey sekmeler) / orta ızgara / sağ detay (birincil eylem en altta). döner {"mid", "det"}.
func _B_frame(rc: Control, title: String, rail: Array, rsel: int, back: bool = true, det_w: float = 860.0, dim: float = 0.55,
		mid_panel: bool = true) -> Dictionary:
	_dim(rc, dim)
	_box(rc, Rect2(-20, -20, 292, SH + 40), Color(col("panel"), 0.97), col("line"), 3, 0)
	var y: float = SY
	if back:
		_btn(rc, Rect2(SX - 8, y, 176, 112), "", "ghost", G_BACK)
		y += 136
	for i in rail.size():
		var it: Array = rail[i]
		var r := Rect2(SX - 8, y, 176, 156)
		var sel: bool = i == rsel
		if sel:
			_box(rc, r, col("panel3"), col("accent"), 3, 16)
			_rect(rc, Rect2(0, r.position.y + 12, 10, r.size.y - 24), col("accent"))
		_icon(rc, it[1], Vector2(r.get_center().x, r.position.y + 56), 64, col("accent") if sel else col("text"))
		_t(rc, it[0], Rect2(r.position.x, r.position.y + 96, r.size.x, 48), 32, col("accent") if sel else col("dim"), 1)
		y += 168
	var det_x: float = RX - det_w
	var mid := Rect2(296, SY, det_x - 24 - 296, SH - SY * 2)
	if mid_panel:
		_box(rc, mid, Color(col("panel"), 0.9), col("line"), 3, 18)
	_box(rc, Rect2(det_x, -20, det_w + 120, SH + 40), Color(col("panel2"), 0.98), col("line_hi"), 3, 0)
	if title != "":
		_t(rc, title, Rect2(mid.position.x + 32, mid.position.y + 12, mid.size.x - 64, 80), 64, col("accent"))
	return {"mid": mid.grow(-32), "det": Rect2(det_x + 40, SY + 12, det_w - 40, SH - SY * 2 - 24)}


func _B_primary(rc: Control, det: Rect2, txt: String, ic: Variant, kind: String = "primary", sub: String = "") -> void:
	_btn(rc, Rect2(det.position.x, det.end.y - 144, det.size.x, 144), txt, kind, ic, 64, sub)


func B_ana_menu(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "", [["OYNA", G_PLAY], ["RUH", "soul"], ["REKOR", G_TROPHY], ["AYAR", G_GEAR]], 0, false, 820.0, 0.0, false)
	_fade(rc, Rect2(272, 0, 900, 420), Color(0.03, 0.02, 0.04), 0, 0.7, 6)
	_title_logo(rc, Vector2(336, 40))
	var det: Rect2 = f["det"]
	_t(rc, "OYNA", Rect2(det.position.x, det.position.y, det.size.x, 80), 64, col("accent"))
	_money(rc, RX, det.position.y + 4, "soul", SOUL, 80)
	var cr := Rect2(det.position.x, det.position.y + 112, det.size.x, 300)
	_box(rc, cr, Color(col("inset"), 0.85), col("line"), 3, 16)
	_sprite(rc, ME, Vector2(cr.position.x + 150, cr.end.y - 30), 6.0)
	_t(rc, "SON SEÇİM", Rect2(cr.position.x + 300, cr.position.y + 24, 460, 44), 32, col("dim"))
	_t(rc, _cname(ME), Rect2(cr.position.x + 300, cr.position.y + 64, 460, 72), 64, col("text"))
	_pet_sprite(rc, PET, Vector2(cr.position.x + 340, cr.position.y + 200), 3.0)
	_img(rc, _wtex("tufek", 1), Rect2(cr.position.x + 420, cr.position.y + 152, 96, 96))
	_img(rc, _stex(str(_spirit(SPIRIT).get("icon", ""))), Rect2(cr.position.x + 540, cr.position.y + 152, 96, 96), false)
	_btn(rc, Rect2(det.position.x, det.position.y + 444, det.size.x, 150), "TEK OYUNCU", "primary", G_PLAY, 64, "Hemen başla")
	_btn(rc, Rect2(det.position.x, det.position.y + 618, det.size.x, 150), "ÇOK OYUNCU", "secondary", G_USERS, 64, "4 oda açık")
	_btn(rc, Rect2(det.position.x, det.position.y + 792, det.size.x, 120), "KODLA KATIL", "ghost", G_KEY, 48)


func B_oda(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "ODALAR", [["İNTERNET", G_WIFI], ["LAN", G_LAN], ["ODA KUR", G_PLUS]], 0)
	var mid: Rect2 = f["mid"]
	_btn(rc, Rect2(mid.end.x - 300, mid.position.y - 16, 300, 104), "YENİLE", "ghost", G_REROLL, 48)
	var y: float = mid.position.y + 112
	for i in ROOMS.size():
		var room: Dictionary = ROOMS[i]
		var r := Rect2(mid.position.x, y, mid.size.x, 184)
		var sel: bool = i == 0
		_box(rc, r, col("panel3") if sel else Color(col("inset"), 0.7), col("accent") if sel else col("line"), 4 if sel else 3, 16)
		_portrait(rc, int(room["host"]), Rect2(r.position.x + 20, r.position.y + 20, 144, 144))
		_t(rc, str(room["name"]), Rect2(r.position.x + 188, r.position.y + 20, 520, 64), 48, col("text"))
		_t(rc, "%d / 4  ·  %s" % [(room["players"] as Array).size(), str(room["stage"])], Rect2(r.position.x + 188, r.position.y + 96, 560, 48), 32, col("dim"))
		var fx: float = r.end.x - 24
		var pc: Color = col("good") if int(room["ping"]) < 80 else col("price")
		var cw: float = _tw_of("%d ms" % int(room["ping"]), 32) + 36
		_chip(rc, Vector2(fx - cw, r.position.y + 24), "%d ms" % int(room["ping"]), pc, 32, 52)
		if room["lock"]:
			_glyph(rc, G_LOCK, Vector2(fx - cw - 48, r.position.y + 50), 5, col("bad"))
		for j in range((room["players"] as Array).size()):
			_portrait(rc, int(room["players"][j]), Rect2(r.end.x - 24 - (j + 1) * 84, r.position.y + 96, 72, 72))
		y += 204
	var det: Rect2 = f["det"]
	var room0: Dictionary = ROOMS[0]
	_t(rc, str(room0["name"]), Rect2(det.position.x, det.position.y, det.size.x, 80), 64, col("accent"))
	_t(rc, "Kurucu: %s  ·  38 ms" % _cname(int(room0["host"])), Rect2(det.position.x, det.position.y + 80, det.size.x, 48), 32, col("dim"))
	for i in 4:
		var r2 := Rect2(det.position.x, det.position.y + 152 + i * 132, det.size.x, 116)
		if i < (room0["players"] as Array).size():
			var t: Dictionary = {"name": ["Mira", "Kerem"][i], "char": int(room0["players"][i]), "ready": i == 0}
			_team_row(rc, r2, t, 32, true)
		else:
			_box(rc, r2, Color(col("inset"), 0.5), Color(col("line_hi"), 0.5), 2, 16)
			_t(rc, "Boş yer", r2, 48, Color(col("dim"), 0.6), 1)
	_t(rc, "Şifre yok  ·  Seçim aşamasında katılabilirsin", Rect2(det.position.x, det.end.y - 210, det.size.x, 48), 32, col("dim"))
	_B_primary(rc, det, "KATIL", G_PLAY)


func B_karakter(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "KAHRAMAN", [["KAHRAMAN", G_USER], ["EVCİL", PC.call("icon", PET)], ["SİLAH", _wtex("tufek", 1)],
			["RUHANİ", _stex(str(_spirit(SPIRIT).get("icon", "")))]], 0)
	var mid: Rect2 = f["mid"]
	var ids: Array = _roster()
	var cols: int = 5
	var tw: float = (mid.size.x - 16 * (cols - 1)) / cols
	for i in ids.size():
		@warning_ignore("integer_division")
		var r := Rect2(mid.position.x + (i % cols) * (tw + 16), mid.position.y + 104 + (i / cols) * 236, tw, 220)
		_char_tile(rc, r, int(ids[i]), int(ids[i]) == ME, true, "Mira" if int(ids[i]) == 10 else "")
	var det: Rect2 = f["det"]
	_box(rc, Rect2(det.position.x, det.position.y, det.size.x, 360), Color(col("inset"), 0.8), col("line"), 3, 18)
	_sprite(rc, ME, Vector2(det.position.x + det.size.x * 0.5, det.position.y + 330), 8.0)
	_t(rc, _cname(ME), Rect2(det.position.x, det.position.y + 380, det.size.x, 80), 64, col("accent"))
	_stat_bars(rc, Rect2(det.position.x, det.position.y + 464, det.size.x, 168), ME)
	_skill_icons(rc, Vector2(det.position.x, det.position.y + 648), ME, 96, 112, false)
	_t(rc, "Peri, Tüfek, Can", Rect2(det.position.x, det.end.y - 200, det.size.x, 48), 32, col("dim"))
	_B_primary(rc, det, "HAZIR", G_CHECK)


func B_hud(rc: Control) -> void:
	var cardr := Rect2(SX - 16, SY - 8, 440, 200)
	_box(rc, cardr, Color(0.04, 0.04, 0.08, 0.66), Color("#5f5c86"), 3, 16)
	_face(rc, ME, Rect2(SX, SY + 8, 112, 112), Color("#f4c56e"))
	_t(rc, "Sen", Rect2(SX + 128, SY + 4, 200, 48), 48, Color("#efe6d6"))
	_chip(rc, Vector2(SX + 260, SY + 8), "Sv %d" % LEVEL, Color("#f4c56e"), 32, 44, true)
	_hearts(rc, Vector2(SX + 128, SY + 64), 2, 4)
	_money_icon(rc, "coin", Rect2(SX + 240, SY + 64, 32, 32))
	_t(rc, _num(GOLD), Rect2(SX + 280, SY + 58, 140, 44), 32, Color("#f0da94"))
	_hp(rc, Rect2(SX, SY + 132, 408, 44), TEAM[0], 32, 12)
	_bar(rc, Rect2(SX, SY + 180, 408, 10), 0.62, XP_COL, Color("#0e1a08"), Color("#0a0604"), 2)
	for i in range(1, TEAM.size()):
		var y: float = 252 + (i - 1) * 112
		_box(rc, Rect2(SX - 16, y - 8, 440, 104), Color(0.04, 0.04, 0.08, 0.55), Color(0, 0, 0, 0), 0, 14)
		_face(rc, int(TEAM[i]["char"]), Rect2(SX, y, 88, 88))
		_t(rc, str(TEAM[i]["name"]), Rect2(SX + 104, y - 4, 300, 44), 32, Color("#efe6d6"))
		_hp(rc, Rect2(SX + 104, y + 40, 304, 40), TEAM[i], 0, 12)
	var mr := Rect2(RX - 280, SY, 280, 280)
	_box(rc, mr.grow(6), Color(0.04, 0.04, 0.08, 0.85), Color("#5f5c86"), 4, 16)
	_img(rc, minimap_tex, mr, true)
	_disk(rc, mr.get_center(), 8, Color.WHITE, Color("#20150d"), 3)
	_t(rc, "VII  ·  18:42", Rect2(RX - 600, SY, 300, 56), 48, Color("#f4c56e"), 2)
	_t(rc, "%s öldürme" % _num(KILLS), Rect2(RX - 600, SY + 56, 300, 48), 32, Color("#a7a2c0"), 2)
	_btn(rc, Rect2(RX - 412, SY + 120, 112, 112), "", "secondary", G_PAUSE)
	_weapon_icons(rc, Vector2(RX - 280, SY + 312), 80, 20)
	var jc := Vector2(360, 840)
	_disk(rc, jc, 168, Color(0.05, 0.05, 0.1, 0.4), Color("#5f5c86"), 6)
	_disk(rc, jc, 100, Color(0, 0, 0, 0), Color(1, 1, 1, 0.15), 3)
	_disk(rc, jc + Vector2(36, -28), 70, Color("#302f4c"), Color("#a7a2c0"), 5)
	var sk: Array = _skills(ME)
	_skill_btn(rc, Vector2(2190, 940), 104, sk[3][2], Color("#f4c56e"))
	_skill_btn(rc, Vector2(1970, 984), 76, sk[1][2], Color("#5f5c86"))
	_skill_btn(rc, Vector2(2200, 724), 76, sk[2][2], Color("#5f5c86"), 0.55, "4")
	_skill_btn(rc, Vector2(2210, 548), 60, str(_spirit(SPIRIT).get("icon", "")), SPIRIT_COL)
	_chat_lines(rc, Vector2(SX, 600), 560)
	var ir := Rect2(SW * 0.5 - 200, 900, 400, 112)
	_box(rc, ir, Color(0.05, 0.05, 0.1, 0.8), Color("#f4c56e"), 3, 56)
	_glyph(rc, G_HAND, Vector2(ir.position.x + 64, ir.get_center().y), 6, Color("#f4c56e"))
	_t(rc, "SATICI", Rect2(ir.position.x + 120, ir.position.y, 260, 112), 64, Color("#efe6d6"))


func B_level(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "SEVİYE %d  ·  SEÇ" % LEVEL, [["KARIŞTIR 2", G_REROLL], ["YASAKLA 1", G_BAN]], -1, false, 860.0, 0.62)
	var d := _disk(rc, Vector2(SX + 80, 940), 72, Color(col("inset"), 0.9), col("line"), 8)
	d.arc_frac = 0.68
	d.arc_col = col("accent")
	_t(rc, "17", Rect2(SX + 8, 908, 144, 64), 64, col("text"), 1)
	var mid: Rect2 = f["mid"]
	for i in 3:
		_lv_card(rc, Rect2(mid.position.x, mid.position.y + 112 + i * 268, mid.size.x, 248), LV_OPTS[i], "row", i == 2)
	var det: Rect2 = f["det"]
	var o: Dictionary = LV_OPTS[2]
	var tc: Color = LV_COL[int(o["tier"])]
	_box(rc, Rect2(det.position.x, det.position.y, det.size.x, 72), Color(tc, 0.28), Color(0, 0, 0, 0), 0, 14)
	_t(rc, LV_NAMES[int(o["tier"])], Rect2(det.position.x, det.position.y, det.size.x, 72), 48, tc.lightened(0.2), 1)
	_img(rc, _stat_tex(str(o["stat"])), Rect2(det.get_center().x - 120, det.position.y + 104, 240, 240), false)
	_t(rc, str(o["val"]), Rect2(det.position.x, det.position.y + 360, det.size.x, 128), 128, col("text"), 1)
	_t(rc, str(o["name"]), Rect2(det.position.x, det.position.y + 488, det.size.x, 72), 64, tc.lightened(0.25), 1)
	_tw(rc, str(o["desc"]), Rect2(det.position.x, det.position.y + 576, det.size.x, 100), 48, col("dim"), 1)
	_t(rc, "Şu an: " + str(o["now"]), Rect2(det.position.x, det.position.y + 700, det.size.x, 56), 48, col("good"), 1)
	_B_primary(rc, det, "SEÇ", G_CHECK)


func B_sandik(rc: Control) -> void:
	var key: String = (_items(3) as Array)[1]
	var f: Dictionary = _B_frame(rc, "ELİT SANDIK", [["SEN", G_USER], ["MİRA", G_USER], ["KEREM", G_USER], ["DENİZ", G_USER]], 0, false, 860.0, 0.6)
	var mid: Rect2 = f["mid"]
	var c: Vector2 = mid.get_center() + Vector2(0, 80)
	_img(rc, beam_tex, Rect2(c.x - 256, c.y - 620, 512, 768), true, Color(1, 1, 1, 0.85))
	_img(rc, chest_tex, Rect2(c.x - 192, c.y - 240, 384, 384))
	_img(rc, _itex(key), Rect2(c.x - 96, mid.position.y + 120, 192, 192))
	var det: Rect2 = f["det"]
	_item_detail(rc, Rect2(det.position.x, det.position.y + 8, det.size.x, 560), key, true)
	_t(rc, "Çanta: Efsanevi 2 / 5", Rect2(det.position.x, det.end.y - 336, det.size.x, 56), 48, col("dim"))
	_btn(rc, Rect2(det.position.x, det.end.y - 272, det.size.x, 112), "SAT  +%s" % _num(int(_icost(key) * 0.5)), "secondary", "coin", 48)
	_B_primary(rc, det, "AL", G_CHECK)


func B_envanter(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "ÇANTA", [["ÇANTA", G_BAG], ["ÖZELLİK", G_STAR], ["SİLAHLAR", _wtex("tufek", 3)]], 0, true, 820.0, 0.6)
	var mid: Rect2 = f["mid"]
	_money(rc, mid.end.x, mid.position.y - 12, "coin", GOLD, 80)
	var bag: Array = _bag()
	var groups: Array = [[3, 5], [2, 10], [1, 5]]
	var y: float = mid.position.y + 104
	var sz: float = (mid.size.x - 4 * 16) / 5.0
	sz = minf(sz, 168.0)
	for g: Array in groups:
		var k: int = g[0]
		var keys: Array = []
		for b: String in bag:
			if _ik(b) == k:
				keys.append(b)
		_t(rc, "%s  %d/%d" % [IT_NAMES[k - 1], keys.size(), g[1]] if k > 1 else IT_NAMES[0], Rect2(mid.position.x, y, 600, 44), 32, IT_COL[k - 1])
		y += 48
		var n: int = mini(int(g[1]), 5) if k != 2 else 5
		for j in n:
			var key: String = keys[j] if j < keys.size() else ""
			_item_slot(rc, Rect2(mid.position.x + j * (sz + 16), y, sz, sz * 0.86), key, k, key == BAG_SEL)
		y += sz * 0.86 + 24
	var det: Rect2 = f["det"]
	_item_detail(rc, Rect2(det.position.x, det.position.y + 8, det.size.x, 700), BAG_SEL, true)
	_B_primary(rc, det, "SAT  +%s" % _num(int(_icost(BAG_SEL) * 0.5)), "coin", "danger")


func B_seyyar(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "SEYYAR SATICI", [["PAZAR", "coin"], ["ÇANTA 7", G_BAG]], 0, true, 900.0, 0.55)
	_t(rc, "Kalan", Rect2(SX - 8, 820, 176, 44), 32, col("dim"), 1)
	_t(rc, "01:42", Rect2(SX - 8, 864, 176, 64), 48, col("price"), 1)
	var mid: Rect2 = f["mid"]
	_money(rc, mid.end.x, mid.position.y - 12, "coin", GOLD, 80)
	var clip := _ctl(rc, Rect2(mid.position.x, mid.position.y + 96, mid.size.x, mid.size.y - 96), true)
	var y: float = 0.0
	var tw: float = (mid.size.x - 3 * 16) / 4.0
	for k: int in [2, 3, 1]:
		var keys: Array = _items(k)
		_t(clip, IT_NAMES[k - 1], Rect2(0, y, 400, 44), 32, IT_COL[k - 1])
		y += 48
		for j in mini(keys.size(), 8 if k == 2 else 4):
			@warning_ignore("integer_division")
			var r := Rect2((j % 4) * (tw + 16), y + (j / 4) * 236, tw, 220)
			_item_tile(clip, r, keys[j], keys[j] == SHOP_SEL, _bag().has(keys[j]), true, false)
		@warning_ignore("integer_division")
		y += ((mini(keys.size(), 8 if k == 2 else 4) + 3) / 4) * 236 + 12
	_scroll_hint(rc, Rect2(mid.position.x, mid.position.y + 96, mid.size.x, mid.size.y - 96), false)
	var det: Rect2 = f["det"]
	var by: float = _item_detail(rc, Rect2(det.position.x, det.position.y + 8, det.size.x, 470), SHOP_SEL, true)
	var ry: float = _recipe(rc, Vector2(det.position.x, by + 24), SHOP_SEL, 120, det.size.x)
	var bi: Array = IT.call("builds_into", SHOP_SEL)
	if not bi.is_empty():
		_t(rc, "DÖNÜŞÜR", Rect2(det.position.x, ry + 24, 400, 40), 32, col("dim"))
		for j in mini(5, bi.size()):
			_item_slot(rc, Rect2(det.position.x + j * 136, ry + 68, 120, 120), str(bi[j]), _ik(str(bi[j])))
	_t(rc, "Parçalar çantadan kullanılır", Rect2(det.position.x, det.end.y - 210, det.size.x, 48), 32, col("dim"))
	_B_primary(rc, det, "SATIN AL  %s" % _num(_icost(SHOP_SEL)), "coin")


func B_demirci(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "DEMİRCİ", [["SİLAHIM", _wtex("tufek", 3)], ["YENİ", G_PLUS], ["KALKAN", G_SHIELD]], 0, true, 900.0, 0.55)
	var mid: Rect2 = f["mid"]
	_money(rc, mid.end.x, mid.position.y - 12, "coin", GOLD, 80)
	_money(rc, mid.end.x - 260, mid.position.y - 12, "wshard", WSHARD, 80)
	var keys: Array = WC.KEYS
	var cols: int = 4
	var tw: float = (mid.size.x - 16 * (cols - 1)) / cols
	var owned: Dictionary = {}
	for w: Array in WEAPONS:
		owned[w[0]] = int(w[1])
	for i in mini(keys.size(), 12):
		var k: String = keys[i]
		@warning_ignore("integer_division")
		var r := Rect2(mid.position.x + (i % cols) * (tw + 16), mid.position.y + 104 + (i / cols) * 232, tw, 216)
		_weapon_tile(rc, r, k, int(owned.get(k, 1)), k == "tufek", owned.has(k), true)
		if owned.has(k):
			_box(rc, Rect2(r.end.x - 44, r.position.y + 6, 38, 38), col("good"), Color("#1c2a12"), 2)
			_glyph(rc, G_CHECK, Vector2(r.end.x - 25, r.position.y + 25), 4, Color("#16220c"))
	_scroll_hint(rc, Rect2(mid.position.x, mid.position.y + 96, mid.size.x, mid.size.y - 96), false)
	var det: Rect2 = f["det"]
	var y: float = _weapon_detail(rc, Rect2(det.position.x, det.position.y + 8, det.size.x, 560), "tufek", 3, 192)
	var c: Array = _w_cost(3)
	_t(rc, "Bedel", Rect2(det.position.x, y + 12, 200, 56), 48, col("dim"))
	_cost_row(rc, Vector2(det.position.x + 200, y + 16), int(c[0]), int(c[1]))
	_B_primary(rc, det, "GELİŞTİR  III -> IV", G_HAMMER)


func B_ruh(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "RUH MAĞAZASI", [["KAHRAMAN", G_USER], ["SİLAH", _wtex("buz_asasi", 1)], ["EVCİL", PC.call("icon", "kirpi")],
			["RUHANİ", _stex(str(_spirit("tank").get("icon", "")))], ["GELİŞTİR", G_UP]], 0, true, 860.0, 0.55)
	var mid: Rect2 = f["mid"]
	_money(rc, mid.end.x, mid.position.y - 12, "soul", SOUL, 80)
	var ids: Array = _roster()
	var cols: int = 5
	var tw: float = (mid.size.x - 16 * (cols - 1)) / cols
	for i in ids.size():
		@warning_ignore("integer_division")
		var r := Rect2(mid.position.x + (i % cols) * (tw + 16), mid.position.y + 104 + (i / cols) * 236, tw, 220)
		_char_tile(rc, r, int(ids[i]), int(ids[i]) == SOUL_SEL, true)
	var det: Rect2 = f["det"]
	_box(rc, Rect2(det.position.x, det.position.y, det.size.x, 340), Color(col("inset"), 0.8), col("line"), 3, 18)
	_sprite(rc, SOUL_SEL, Vector2(det.position.x + det.size.x * 0.5, det.position.y + 310), 8.0)
	_t(rc, _cname(SOUL_SEL), Rect2(det.position.x, det.position.y + 360, det.size.x, 80), 64, col("accent"))
	_skill_icons(rc, Vector2(det.position.x, det.position.y + 460), SOUL_SEL, 96, 112, false)
	_tw(rc, "Kalıcı açılır: her koşuda seçebilirsin. Kıymıklar koşu sürdükçe ve kademe atladıkça birikir.",
			Rect2(det.position.x, det.position.y + 600, det.size.x, 140), 32, col("dim"))
	var cost: int = int(MetaCosts.CHAR.get(SOUL_SEL, 400))
	_B_primary(rc, det, "KİLİDİ AÇ  %d" % cost, "soul", "primary", "Kalan: %d" % (SOUL - cost))


func B_duraklat(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "DURAKLATILDI", [["DEVAM", G_PLAY], ["AYARLAR", G_GEAR], ["SOHBET", G_CHAT], ["MENÜ", G_HOME]], 0, false, 820.0, 0.62)
	var mid: Rect2 = f["mid"]
	_chip(rc, Vector2(mid.position.x, mid.position.y + 96), "Çok oyunculu: oyun arkada sürüyor", col("bad"), 32, 56)
	var stats: Array = [[RUN_TIME, "SÜRE", G_CLOCK], ["VII", "KADEME", G_SKULL], [str(LEVEL), "SEVİYE", G_STAR], [_num(KILLS), "ÖLDÜRME", G_SWORD],
			[_num(GOLD), "ALTIN", "coin"], ["2", "KALP", G_HEART]]
	var tw: float = (mid.size.x - 24) / 2.0
	for i in stats.size():
		@warning_ignore("integer_division")
		var r := Rect2(mid.position.x + (i % 2) * (tw + 24), mid.position.y + 184 + (i / 2) * 244, tw, 220)
		_stat_tile(rc, r, stats[i][0], stats[i][1], col("text"), stats[i][2])
	var det: Rect2 = f["det"]
	_t(rc, "TAKIM", Rect2(det.position.x, det.position.y, det.size.x, 72), 64, col("accent"))
	for i in TEAM.size():
		var y: float = det.position.y + 96 + i * 168
		_team_row(rc, Rect2(det.position.x, y, det.size.x, 96), TEAM[i], 32)
		_hp(rc, Rect2(det.position.x + 116, y + 104, det.size.x - 116, 44), TEAM[i], 0, 12)
	_B_primary(rc, det, "DEVAM ET", G_PLAY)


func B_ayarlar(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "DOKUNMATİK", [["GENEL", G_GEAR], ["GRAFİK", G_GRID], ["DOKUN", G_HAND], ["SES", G_SPEAKER]], 2, true, 860.0, 0.6)
	var mid: Rect2 = f["mid"]
	for i in SET_ROWS.size():
		var r := Rect2(mid.position.x - 16, mid.position.y + 100 + i * 124, mid.size.x + 32, 116)
		_set_row(rc, r, SET_ROWS[i], i == 1, 48)
		if i < SET_ROWS.size() - 1:
			_rect(rc, Rect2(r.position.x + 24, r.end.y + 3, r.size.x - 48, 2), col("line"))
	var det: Rect2 = f["det"]
	_t(rc, "ÖNİZLEME", Rect2(det.position.x, det.position.y, det.size.x, 72), 64, col("accent"))
	_touch_preview(rc, Rect2(det.position.x + 10, det.position.y + 104, det.size.x - 20, (det.size.x - 20) * SH / SW))
	_tw(rc, "Düğme boyutu ve saydamlık önizlemede anında görünür. Düğmeleri sürükleyip yerleştirmek için DÜZENLE.",
			Rect2(det.position.x, det.position.y + 520, det.size.x, 150), 32, col("dim"))
	_B_primary(rc, det, "DÜZENLE", G_HAND, "secondary")


func B_oyun_bitti(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "", [["ÖZET", G_GRID], ["HASAR", G_SWORD], ["ÖDÜL", "soul"]], 0, false, 860.0, 0.74)
	var mid: Rect2 = f["mid"]
	_t(rc, "OYUN BİTTİ", Rect2(mid.position.x, mid.position.y - 8, mid.size.x, 112), 96, col("bad"))
	_t(rc, "Kademe IX'da düştün", Rect2(mid.position.x, mid.position.y + 100, mid.size.x, 56), 48, col("dim"))
	var stats: Array = [[str(GO["time"]), "SÜRE", G_CLOCK], ["IX", "KADEME", G_SKULL], [_num(int(GO["kills"])), "ÖLDÜRME", G_SWORD],
			[str(GO["level"]), "SEVİYE", G_STAR], [_num(int(GO["gold"])), "ALTIN", "coin"], ["+%d" % int(GO["soul"]), "RUH KIYMIĞI", "soul"]]
	var tw: float = (mid.size.x - 24) / 2.0
	for i in stats.size():
		@warning_ignore("integer_division")
		var r := Rect2(mid.position.x + (i % 2) * (tw + 24), mid.position.y + 184 + (i / 2) * 236, tw, 212)
		_stat_tile(rc, r, stats[i][0], stats[i][1], SOUL_COL if i == 5 else col("text"), stats[i][2])
	var det: Rect2 = f["det"]
	_t(rc, "HASAR SIRASI", Rect2(det.position.x, det.position.y, det.size.x, 72), 64, col("accent"))
	var order: Array = TEAM.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["dmg"]) > int(b["dmg"]))
	for i in order.size():
		var t: Dictionary = order[i]
		var y: float = det.position.y + 96 + i * 144
		_t(rc, str(i + 1), Rect2(det.position.x, y, 60, 112), 64, col("accent") if i == 0 else col("dim"))
		_portrait(rc, int(t["char"]), Rect2(det.position.x + 64, y, 112, 112))
		_t(rc, str(t["name"]), Rect2(det.position.x + 196, y, 400, 56), 48, col("text"))
		_bar(rc, Rect2(det.position.x + 196, y + 64, det.size.x - 380, 28), float(t["dmg"]) / 52740.0, col("accent"))
		_t(rc, _num(int(t["dmg"])), Rect2(det.end.x - 180, y + 40, 180, 64), 48, col("price"), 2)
	_btn(rc, Rect2(det.position.x, det.end.y - 280, det.size.x, 112), "TEKRAR OYNA", "secondary", G_REROLL, 48)
	_B_primary(rc, det, "ANA MENÜ", G_HOME)


func B_rekor(rc: Control) -> void:
	var f: Dictionary = _B_frame(rc, "EN İYİLER", [["EN İYİ", G_TROPHY], ["BAŞARIM", G_STAR]], 0, true, 820.0, 0.6)
	var mid: Rect2 = f["mid"]
	for i in RECORDS.size():
		var rec: Array = RECORDS[i]
		var r := Rect2(mid.position.x, mid.position.y + 104 + i * 136, mid.size.x, 120)
		_box(rc, r, Color(col("inset"), 0.7), col("accent") if rec[3] else col("line"), 4 if rec[3] else 3, 16)
		_medal(rc, Vector2(r.position.x + 72, r.get_center().y), 44, GLYPH_BY_NAME[rec[2]], Color("#f0c070"), false)
		_t(rc, rec[0], Rect2(r.position.x + 140, r.position.y, 600, r.size.y), 48, col("text"))
		if rec[3]:
			_chip(rc, Vector2(r.end.x - 460, r.position.y + 34), "YENİ", col("bad"), 32, 52, true)
		_t(rc, rec[1], Rect2(r.end.x - 360, r.position.y, 336, r.size.y), 96, col("price"), 2)
	_t(rc, "Toplam 31 koşu, 1 zafer", Rect2(mid.position.x, mid.end.y - 56, mid.size.x, 56), 32, col("dim"))
	var det: Rect2 = f["det"]
	var ach: Array = _ach_list()
	var nx: Dictionary = {}
	for a: Dictionary in ach:
		if a["date"] == "":
			nx = a
			break
	_t(rc, "SIRADAKİ", Rect2(det.position.x, det.position.y, det.size.x, 72), 64, col("accent"))
	if not nx.is_empty():
		_medal(rc, Vector2(det.get_center().x, det.position.y + 220), 112, nx["glyph"], nx["metal"], true)
		_t(rc, nx["name"], Rect2(det.position.x, det.position.y + 360, det.size.x, 72), 64, col("text"), 1)
		_tw(rc, nx["desc"], Rect2(det.position.x, det.position.y + 440, det.size.x, 100), 48, col("dim"), 1)
		_bar(rc, Rect2(det.position.x, det.position.y + 560, det.size.x, 32), float(nx["frac"]), col("accent"))
	_t(rc, "SON AÇILANLAR", Rect2(det.position.x, det.position.y + 640, det.size.x, 56), 48, col("dim"))
	var x: float = det.position.x
	var n: int = 0
	for a: Dictionary in ach:
		if a["date"] == "" or n >= 5:
			continue
		_medal(rc, Vector2(x + 64, det.position.y + 780), 56, a["glyph"], a["metal"], false)
		x += 152
		n += 1


## ====================================================================================== C - KAYRAK / ALT ÇEKMECE
## Sahne üstte görünür; çekmece y sheet_y'den aşağı, en üstünde sekmeler + sağda birincil eylem. döner = çekmece içerik dikdörtgeni.
func _C_frame(rc: Control, title: String, tabs: Array, tsel: int, money: Array, primary: String, pic: Variant, sheet_y: float = 440.0,
		back: bool = true, dim: float = 0.22, pkind: String = "primary") -> Rect2:
	_dim(rc, dim)
	_fade(rc, Rect2(0, 0, SW, 190), col("dimbg"), 0, 0.65, 6)
	var tx: float = SX
	if back:
		_round_btn(rc, Vector2(SX + 60, SY + 60), 60, G_BACK)
		tx = SX + 144
	if title != "":
		var tw: float = _tw_of(title, 48) + 56
		_box(rc, Rect2(tx, SY + 16, tw, 88), Color(col("panel"), 0.9), col("line_hi"), 3, 44)
		_t(rc, title, Rect2(tx, SY + 16, tw, 88), 48, col("accent"), 1)
	var x: float = RX
	for m: Array in money:
		x = _money(rc, x, SY + 16, str(m[0]), int(m[1])) - 16
	var sb := _sb(Color(col("panel"), 0.97), col("line_hi"), 3, 0)
	sb.corner_radius_top_left = 36
	sb.corner_radius_top_right = 36
	sb.border_width_bottom = 0
	var pn := Panel.new()
	pn.add_theme_stylebox_override("panel", sb)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rc.add_child(pn)
	pn.position = Vector2(-4, sheet_y)
	pn.size = Vector2(SW + 8, SH - sheet_y + 40)
	_box(rc, Rect2(SW * 0.5 - 90, sheet_y + 14, 180, 12), col("line_hi"), Color(0, 0, 0, 0), 0, 6)
	if not tabs.is_empty():
		var tw2: float = minf(300.0, (RX - SX - (560 if primary != "" else 0) - 40) / tabs.size())
		_tabs(rc, Rect2(SX, sheet_y + 40, tw2 * tabs.size(), 104), tabs, tsel, 48 if tw2 >= 240 else 32)
	if primary != "":
		_btn(rc, Rect2(RX - 540, sheet_y + 36, 540, 112), primary, pkind, pic, 48)
	return Rect2(SX, sheet_y + 172, RX - SX, SH - sheet_y - 172 - 20)


## Vitrin: sahnenin üstünde seçilenin kartı.
func _C_vitrin(rc: Control, r: Rect2) -> void:
	_box(rc, r, Color(col("panel"), 0.92), col("line_hi"), 3, 18)


func C_ana_menu(rc: Control) -> void:
	_fade(rc, Rect2(0, 0, 1400, 600), Color(0.02, 0.03, 0.05), 2, 0.75, 8)
	_title_logo(rc, Vector2(SX + 8, 40))
	_money(rc, RX, SY + 16, "soul", SOUL)
	var sy: float = 640.0
	var c: Rect2 = _C_frame(rc, "", [], 0, [], "", null, sy, false, 0.0)
	_t(rc, "NE YAPMAK İSTERSİN?", Rect2(SX, sy + 40, 1000, 56), 32, col("dim"))
	var items: Array = [["TEK OYUNCU", "Hemen başla", G_PLAY], ["ÇOK OYUNCU", "4 oda açık", G_USERS], ["RUH MAĞAZASI", "520 kıymık", "soul"],
			["REKORLAR", "11/17 başarım", G_TROPHY], ["AYARLAR", "Dokunmatik", G_GEAR]]
	var w: float = (RX - SX - 4 * 24) / 5.0
	for i in items.size():
		var r := Rect2(SX + i * (w + 24), sy + 112, w, 300)
		var sel: bool = i == 0
		_box(rc, r, col("accent") if sel else col("panel3"), col("accent_dk") if sel else col("line_hi"), 3, 12)
		var tc: Color = col("accent_text") if sel else col("text")
		_icon(rc, items[i][2], Vector2(r.get_center().x, r.position.y + 96), 88, tc)
		_t(rc, items[i][0], Rect2(r.position.x, r.position.y + 168, r.size.x, 64), 48, tc, 1, not sel)
		_t(rc, items[i][1], Rect2(r.position.x, r.position.y + 228, r.size.x, 48), 32, Color(tc, 0.7), 1, false)
	if c.size.x < 0:
		return


func C_oda(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "ÇOK OYUNCU", ["İNTERNET", "LAN"], 0, [], "KATIL", G_PLAY, 500.0)
	var v := Rect2(SX, 150, 1240, 320)
	_C_vitrin(rc, v)
	var room: Dictionary = ROOMS[0]
	_portrait(rc, int(room["host"]), Rect2(v.position + Vector2(24, 24), Vector2(152, 152)))
	_t(rc, str(room["name"]), Rect2(v.position.x + 200, v.position.y + 24, 700, 72), 64, col("accent"))
	_t(rc, "Kurucu: Mira  ·  38 ms  ·  %s" % str(room["stage"]), Rect2(v.position.x + 200, v.position.y + 100, 1000, 48), 32, col("dim"))
	for j in 4:
		var sr := Rect2(v.position.x + 200 + j * 136, v.position.y + 168, 120, 120)
		if j < (room["players"] as Array).size():
			_portrait(rc, int(room["players"][j]), sr)
		else:
			_box(rc, sr, Color(col("inset"), 0.5), Color(col("line_hi"), 0.5), 2, 10)
			_t(rc, "+", sr, 64, Color(col("dim"), 0.5), 1)
	_btn(rc, Rect2(RX - 1100, c.position.y - 136, 520, 112), "ODA KUR", "secondary", G_PLUS, 48)
	var clip := _ctl(rc, c, true)
	var x: float = 0.0
	for i in ROOMS.size():
		var rm: Dictionary = ROOMS[i]
		var r := Rect2(x, 0, 620, c.size.y)
		var sel: bool = i == 0
		_box(clip, r, col("panel3") if sel else col("panel2"), col("accent") if sel else col("line"), 4 if sel else 3, 12)
		_portrait(clip, int(rm["host"]), Rect2(r.position.x + 24, r.position.y + 24, 120, 120))
		_t(clip, str(rm["name"]), Rect2(r.position.x + 168, r.position.y + 24, 430, 64), 48, col("text"))
		_t(clip, "%d / 4  ·  %d ms" % [(rm["players"] as Array).size(), int(rm["ping"])], Rect2(r.position.x + 168, r.position.y + 92, 430, 48), 32, col("dim"))
		if rm["lock"]:
			_glyph(clip, G_LOCK, Vector2(r.end.x - 48, r.position.y + 120), 5, col("bad"))
		for j in range((rm["players"] as Array).size()):
			_portrait(clip, int(rm["players"][j]), Rect2(r.position.x + 24 + j * 100, r.position.y + 168, 88, 88))
		x += 652
	_scroll_hint(rc, c)


func C_karakter(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "KARAKTER SEÇ", ["KAHRAMAN", "EVCİL", "SİLAH", "RUHANİ"], 0, [], "HAZIR", G_CHECK, 560.0, true, 0.1)
	_sprite(rc, ME, Vector2(2010, 520), 9.0)
	var v := Rect2(SX, 150, 900, 380)
	_C_vitrin(rc, v)
	_t(rc, _cname(ME), Rect2(v.position.x + 32, v.position.y + 16, 700, 80), 64, col("accent"))
	_stat_bars(rc, Rect2(v.position.x + 32, v.position.y + 96, 836, 120), ME, 32)
	_skill_icons(rc, Vector2(v.position.x + 32, v.position.y + 236), ME, 96, 60, false)
	_t(rc, "Seçimde: Mira (Melek)", Rect2(RX - 520, 168, 520, 48), 32, col("dim"), 2)
	var clip := _ctl(rc, c, true)
	var ids: Array = _roster()
	var x: float = 0.0
	for cid: int in ids:
		_char_tile(clip, Rect2(x, 0, 220, c.size.y), cid, cid == ME, true, "Mira" if cid == 10 else "")
		x += 240
	_scroll_hint(rc, c)


func C_hud(rc: Control) -> void:
	for i in range(1, TEAM.size()):
		_party_face(rc, Rect2(SX + (i - 1) * 108, SY, 88, 88), TEAM[i])
	_box(rc, Rect2(SW * 0.5 - 220, SY, 440, 72), Color(0.06, 0.08, 0.12, 0.78), Color("#56657f"), 3, 36)
	_t(rc, "KADEME VII  ·  18:42", Rect2(SW * 0.5 - 220, SY, 440, 72), 48, Color("#d9b46a"), 1)
	_minimap_circle(rc, Vector2(RX - 104, SY + 104), 96)
	_round_btn(rc, Vector2(RX - 290, SY + 60), 56, G_PAUSE)
	_round_btn(rc, Vector2(RX - 290, SY + 188), 56, G_BAG)
	var cr := Rect2(SW * 0.5 - 560, 916, 1120, 140)
	_box(rc, cr, Color(0.06, 0.08, 0.12, 0.82), Color("#56657f"), 3, 20)
	_disk(rc, Vector2(cr.position.x + 72, cr.get_center().y), 52, Color("#121722"), Color("#d9b46a"), 5)
	_t(rc, str(LEVEL), Rect2(cr.position.x + 20, cr.position.y + 36, 104, 64), 64, Color("#ece6d7"), 1)
	_hp(rc, Rect2(cr.position.x + 148, cr.position.y + 20, 680, 76), TEAM[0], 32, 18)
	_bar(rc, Rect2(cr.position.x + 148, cr.position.y + 104, 680, 14), 0.62, XP_COL, Color("#0e1a08"), Color("#0a0604"), 2)
	_hearts(rc, Vector2(cr.position.x + 856, cr.position.y + 24), 2, 4)
	_money_icon(rc, "coin", Rect2(cr.position.x + 856, cr.position.y + 76, 40, 40))
	_t(rc, _num(GOLD), Rect2(cr.position.x + 904, cr.position.y + 70, 200, 52), 48, Color("#eccb7e"))
	_weapon_icons(rc, Vector2(SW * 0.5 - 150, 808), 84, 24)
	var jc := Vector2(360, 850)
	_disk(rc, jc, 160, Color(0.06, 0.08, 0.12, 0.35), Color("#96a0b2"), 5)
	_disk(rc, jc + Vector2(40, -30), 66, Color("#2f3a4f"), Color("#ece6d7"), 4)
	var sk: Array = _skills(ME)
	_skill_btn(rc, Vector2(2196, 940), 96, sk[3][2], Color("#d9b46a"))
	_skill_btn(rc, Vector2(1990, 940), 84, sk[1][2], Color("#56657f"))
	_skill_btn(rc, Vector2(2196, 736), 84, sk[2][2], Color("#56657f"), 0.55, "4")
	_skill_btn(rc, Vector2(1990, 736), 72, str(_spirit(SPIRIT).get("icon", "")), SPIRIT_COL)
	_chat_lines(rc, Vector2(SX, 168 + 72), 600)
	var ir := Rect2(SW * 0.5 - 200, 640, 400, 104)
	_box(rc, ir, Color(0.06, 0.08, 0.12, 0.85), Color("#d9b46a"), 3, 52)
	_glyph(rc, G_HAND, Vector2(ir.position.x + 64, ir.get_center().y), 6, Color("#d9b46a"))
	_t(rc, "SATICI", Rect2(ir.position.x + 120, ir.position.y, 260, 104), 64, Color("#ece6d7"))


func C_level(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "", [], 0, [], "", null, 372.0, false, 0.28)
	_t(rc, "SEVİYE %d!" % LEVEL, Rect2(0, 60, SW, 128), 128, col("accent"), 1)
	_t(rc, "Bir karta dokun", Rect2(0, 196, SW, 56), 48, col("text"), 1)
	_btn(rc, Rect2(SX, 372 + 40, 440, 112), "KARIŞTIR  2", "secondary", G_REROLL, 48)
	_btn(rc, Rect2(SX + 464, 372 + 40, 420, 112), "YASAKLA  1", "secondary", G_BAN, 48)
	var d := _disk(rc, Vector2(RX - 56, 372 + 96), 56, Color(col("inset"), 0.9), col("line"), 8)
	d.arc_frac = 0.68
	d.arc_col = col("accent")
	_t(rc, "17", Rect2(RX - 112, 372 + 64, 112, 64), 64, col("text"), 1)
	_t(rc, "Mira ve Deniz seçiyor", Rect2(RX - 760, 372 + 64, 620, 64), 32, col("dim"), 2)
	var w: float = (c.size.x - 2 * 32) / 3.0
	for i in 3:
		_lv_card(rc, Rect2(c.position.x + i * (w + 32), c.position.y, w, c.size.y), LV_OPTS[i], "wide", false)


func C_sandik(rc: Control) -> void:
	var key: String = (_items(3) as Array)[1]
	var c: Rect2 = _C_frame(rc, "ELİT SANDIK", [], 0, [["coin", GOLD]], "", null, 600.0, false, 0.3)
	var cc := Vector2(SW * 0.5, 470)
	_img(rc, beam_tex, Rect2(cc.x - 192, cc.y - 520, 384, 576), true, Color(1, 1, 1, 0.85))
	_img(rc, chest_tex, Rect2(cc.x - 144, cc.y - 220, 288, 288))
	var card := Rect2(SX, 640, 1500, 412)
	_box(rc, card, col("panel2"), IT_COL[2], 4, 12)
	_item_detail(rc, Rect2(card.position.x + 32, card.position.y + 28, card.size.x - 64, 360), key, true)
	_btn(rc, Rect2(RX - 640, 640, 640, 200), "AL", "primary", G_CHECK, 96)
	_btn(rc, Rect2(RX - 640, 864, 640, 140), "SAT  +%s" % _num(int(_icost(key) * 0.5)), "secondary", "coin", 48)
	_t(rc, "Sıradaki: Mira", Rect2(RX - 640, 1008, 640, 44), 32, col("dim"), 1)
	if c.size.x < 0:
		return


func C_envanter(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "ÇANTA", ["ÇANTA", "ÖZELLİKLER", "SİLAHLAR"], 0, [["coin", GOLD]], "SAT  +%s" % _num(int(_icost(BAG_SEL) * 0.5)), "coin", 520.0, true, 0.3, "danger")
	var v := Rect2(SX, 150, 1300, 340)
	_C_vitrin(rc, v)
	_item_detail(rc, Rect2(v.position.x + 28, v.position.y + 24, v.size.x - 56, 300), BAG_SEL, false)
	var clip := _ctl(rc, c, true)
	var x: float = 0.0
	var ts: float = c.size.y
	_t(clip, "SİLAHLAR", Rect2(x, -4, 400, 40), 32, col("dim"))
	for w: Array in WEAPONS:
		_weapon_tile(clip, Rect2(x, 40, 220, ts - 40), str(w[0]), int(w[1]), false, true, false)
		x += 236
	x += 24
	for k: int in [3, 2, 1]:
		_t(clip, IT_NAMES[k - 1], Rect2(x, -4, 400, 40), 32, IT_COL[k - 1])
		for b: String in _bag():
			if _ik(b) == k:
				_item_slot(clip, Rect2(x, 40, 220, ts - 40), b, k, b == BAG_SEL)
				x += 236
		_item_slot(clip, Rect2(x, 40, 220, ts - 40), "", k)
		x += 260
	_scroll_hint(rc, c)


func C_seyyar(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "SEYYAR SATICI  ·  01:42", ["EFSANEVİ", "EPİK", "PARÇA"], 1, [["coin", GOLD]], "SATIN AL  %s" % _num(_icost(SHOP_SEL)), "coin", 520.0)
	var v := Rect2(SX, 150, 1560, 350)
	_C_vitrin(rc, v)
	_item_detail(rc, Rect2(v.position.x + 28, v.position.y + 24, 760, 300), SHOP_SEL, false)
	_recipe(rc, Vector2(v.position.x + 820, v.position.y + 24), SHOP_SEL, 112, 700)
	_tw(rc, "Parçalar çantadan kullanılır.", Rect2(v.position.x + 820, v.position.y + 220, 700, 80), 32, col("dim"))
	var clip := _ctl(rc, c, true)
	var keys: Array = _items(2)
	var x: float = 0.0
	for k: String in keys:
		_item_tile(clip, Rect2(x, 0, 236, c.size.y), k, k == SHOP_SEL, false, true, true)
		x += 256
	_scroll_hint(rc, c)


func C_demirci(rc: Control) -> void:
	var cst: Array = _w_cost(3)
	var c: Rect2 = _C_frame(rc, "DEMİRCİ", ["SİLAHLARIM", "YENİ SİLAH", "KALKAN"], 0, [["wshard", WSHARD], ["coin", GOLD]], "GELİŞTİR  %d" % int(cst[0]), G_HAMMER, 560.0)
	var v := Rect2(SX, 150, 1500, 390)
	_C_vitrin(rc, v)
	_img(rc, _wtex("tufek", 3), Rect2(v.position.x + 24, v.position.y + 24, 192, 192))
	_t(rc, _wname("tufek"), Rect2(v.position.x + 240, v.position.y + 20, 600, 72), 64, col("accent"))
	_chip(rc, Vector2(v.position.x + 240, v.position.y + 100), "SEVİYE III", ENCH_COL[3], 32, 52)
	_t(rc, "Bu oyunda 48.210 hasar", Rect2(v.position.x + 240, v.position.y + 164, 700, 48), 32, col("dim"))
	_tier_path(rc, Rect2(v.position.x + 24, v.position.y + 240, 700, 64), 3)
	var a: Array = _w_stats(3)
	var b: Array = _w_stats(4)
	_t(rc, "Hasar  %s -> %s" % [a[0], b[0]], Rect2(v.position.x + 780, v.position.y + 236, 700, 56), 48, col("good"))
	_t(rc, "Atış aralığı  %s -> %s" % [a[1], b[1]], Rect2(v.position.x + 780, v.position.y + 296, 700, 56), 48, col("good"))
	_cost_row(rc, Vector2(v.position.x + 780, v.position.y + 40), int(cst[0]), int(cst[1]))
	var clip := _ctl(rc, c, true)
	var x: float = 0.0
	for i in WEAPONS.size():
		_weapon_tile(clip, Rect2(x, 0, 420, c.size.y), str(WEAPONS[i][0]), int(WEAPONS[i][1]), i == 0, true, true)
		x += 444
	_box(clip, Rect2(x, 0, 420, c.size.y), Color(col("inset"), 0.5), Color(col("line_hi"), 0.5), 2, 12)
	_glyph(clip, G_LOCK, Vector2(x + 210, c.size.y * 0.4), 7, Color(col("dim"), 0.6))
	_t(clip, "Yuvalar dolu 3/3", Rect2(x, c.size.y * 0.6, 420, 48), 32, col("dim"), 1)


func C_ruh(rc: Control) -> void:
	var cost: int = int(MetaCosts.CHAR.get(SOUL_SEL, 400))
	var c: Rect2 = _C_frame(rc, "RUH MAĞAZASI", ["KAHRAMAN", "SİLAH", "EVCİL", "RUHANİ", "GELİŞTİR"], 0, [["soul", SOUL]], "AÇ  %d" % cost, "soul", 600.0, true, 0.1)
	_sprite(rc, SOUL_SEL, Vector2(2010, 560), 9.0)
	var v := Rect2(SX, 150, 1040, 420)
	_C_vitrin(rc, v)
	_t(rc, _cname(SOUL_SEL), Rect2(v.position.x + 32, v.position.y + 16, 700, 80), 64, col("accent"))
	_gem(rc, Rect2(v.position.x + 32, v.position.y + 104, 48, 48))
	_t(rc, "%d  ·  kalan %d" % [cost, SOUL - cost], Rect2(v.position.x + 96, v.position.y + 96, 600, 64), 48, SOUL_COL)
	_skill_icons(rc, Vector2(v.position.x + 32, v.position.y + 184), SOUL_SEL, 96, 120, true, 112)
	var clip := _ctl(rc, c, true)
	var x: float = 0.0
	for cid: int in _roster():
		_char_tile(clip, Rect2(x, 0, 220, c.size.y), cid, cid == SOUL_SEL, true)
		x += 240
	_scroll_hint(rc, c)


func C_duraklat(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "", [], 0, [], "", null, 620.0, false, 0.5)
	_t(rc, "DURAKLATILDI", Rect2(0, 120, SW, 112), 96, col("accent"), 1)
	var chips: Array = [RUN_TIME, "Kademe VII", "Seviye %d" % LEVEL, "%s öldürme" % _num(KILLS)]
	var total: float = 0.0
	for s: String in chips:
		total += _tw_of(s, 32) + 36 + 16
	var x: float = SW * 0.5 - total * 0.5
	for s: String in chips:
		x += _chip(rc, Vector2(x, 260), s, col("text"), 32, 56) + 16
	_chip(rc, Vector2(SW * 0.5 - 300, 340), "Çok oyunculu: oyun arkada sürüyor", col("bad"), 32, 56)
	for i in TEAM.size():
		_party_face(rc, Rect2(SW * 0.5 - 250 + i * 128, 430, 96, 96), TEAM[i])
	var items: Array = [["DEVAM ET", G_PLAY, "primary"], ["AYARLAR", G_GEAR, "secondary"], ["SOHBET", G_CHAT, "secondary"], ["ANA MENÜ", G_HOME, "danger"]]
	var ws: Array = [700.0, 480.0, 480.0, 480.0]
	var bx: float = SX
	var gap: float = (RX - SX - 2140.0) / 3.0
	for i in 4:
		var r := Rect2(bx, 680, float(ws[i]), 300)
		_btn(rc, r, "", items[i][2], null)
		var tc: Color = col("accent_text") if i == 0 else (Color("#ffd8c8") if i == 3 else col("text"))
		_icon(rc, items[i][1], Vector2(r.get_center().x, r.position.y + 110), 96, tc)
		_t(rc, items[i][0], Rect2(r.position.x, r.position.y + 180, r.size.x, 80), 64, tc, 1, i != 0)
		bx += float(ws[i]) + gap
	if c.size.x < 0:
		return


func C_ayarlar(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "AYARLAR", SET_CATS, 2, [], "VARSAYILAN", null, 168.0, true, 0.3, "ghost")
	var cw: float = (c.size.x - 48) / 2.0
	for i in SET_ROWS.size():
		@warning_ignore("integer_division")
		var r := Rect2(c.position.x + (i % 2) * (cw + 48), c.position.y + (i / 2) * 168, cw, 148)
		_box(rc, r, col("panel2"), col("line"), 3, 12)
		_set_row(rc, r, SET_ROWS[i], i == 1, 48)


func C_oyun_bitti(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "", ["ÖZET", "HASAR", "ÖDÜLLER"], 0, [], "ANA MENÜ", G_HOME, 400.0, false, 0.55)
	_t(rc, "OYUN BİTTİ", Rect2(0, 60, SW, 128), 128, col("bad"), 1)
	_t(rc, "Kademe IX'da düştün  ·  %s  ·  +%d Ruh Kıymığı" % [str(GO["time"]), int(GO["soul"])], Rect2(0, 210, SW, 56), 48, col("dim"), 1)
	_btn(rc, Rect2(RX - 960, 436, 400, 112), "TEKRAR", "secondary", G_REROLL, 48)
	var stats: Array = [[str(GO["time"]), "SÜRE", G_CLOCK], ["IX", "KADEME", G_SKULL], [_num(int(GO["kills"])), "ÖLDÜRME", G_SWORD],
			[str(GO["level"]), "SEVİYE", G_STAR], ["+%d" % int(GO["soul"]), "KIYMIK", "soul"]]
	var w: float = (c.size.x - 4 * 24) / 5.0
	for i in 5:
		_stat_tile(rc, Rect2(c.position.x + i * (w + 24), c.position.y, w, 180), stats[i][0], stats[i][1], SOUL_COL if i == 4 else col("text"), stats[i][2])
	var tw: float = (c.size.x - 3 * 24) / 4.0
	for i in TEAM.size():
		var t: Dictionary = TEAM[i]
		var r := Rect2(c.position.x + i * (tw + 24), c.position.y + 204, tw, c.size.y - 204)
		_box(rc, r, col("panel2"), col("accent") if i == 2 else col("line"), 4 if i == 2 else 3, 12)
		_portrait(rc, int(t["char"]), Rect2(r.position + Vector2(20, 20), Vector2(112, 112)))
		_t(rc, str(t["name"]), Rect2(r.position.x + 152, r.position.y + 20, tw - 170, 56), 48, col("text"))
		_t(rc, _num(int(t["dmg"])), Rect2(r.position.x + 152, r.position.y + 76, tw - 170, 64), 64, col("price"))
		_bar(rc, Rect2(r.position.x + 20, r.end.y - 52, tw - 40, 28), float(t["dmg"]) / 52740.0, col("accent"))


func C_rekor(rc: Control) -> void:
	var c: Rect2 = _C_frame(rc, "REKORLAR", ["EN İYİLER", "BAŞARIMLAR 11/17"], 0, [], "", null, 520.0, true, 0.15)
	var v := Rect2(SX, 150, 1240, 340)
	_C_vitrin(rc, v)
	_img(rc, load("res://assets/items/kralin_kadehi.png") as Texture2D, Rect2(v.position.x + 32, v.position.y + 42, 256, 256))
	_t(rc, "EN İYİ KOŞU", Rect2(v.position.x + 320, v.position.y + 28, 800, 56), 48, col("dim"))
	_t(rc, "52:30  ·  FİNAL", Rect2(v.position.x + 320, v.position.y + 88, 900, 112), 96, col("accent"))
	_t(rc, "31 koşu  ·  1 zafer  ·  9 sa 41 dk", Rect2(v.position.x + 320, v.position.y + 220, 900, 56), 48, col("text"))
	var clip := _ctl(rc, c, true)
	var x: float = 0.0
	for rec: Array in RECORDS:
		var r := Rect2(x, 0, 460, c.size.y)
		_box(clip, r, col("panel2"), col("accent") if rec[3] else col("line"), 4 if rec[3] else 3, 12)
		_medal(clip, Vector2(r.position.x + 80, r.position.y + 84), 56, GLYPH_BY_NAME[rec[2]], Color("#f0c070"), false)
		if rec[3]:
			_chip(clip, Vector2(r.end.x - 140, r.position.y + 24), "YENİ", col("bad"), 32, 52, true)
		_t(clip, rec[1], Rect2(r.position.x + 28, r.position.y + 160, r.size.x - 56, 96), 96, col("text"))
		_t(clip, rec[0], Rect2(r.position.x + 28, r.position.y + 260, r.size.x - 56, 48), 32, col("dim"))
		x += 484
	_scroll_hint(rc, c)


## ====================================================================================== D - KISIK AHŞAP / TEK ODAK
## Üstte ortalı sekme hapları, ortada tek büyük kart + soluk komşular, kenarlarda dev oklar, altta dev birincil, köşelerde haplar.
func _D_frame(rc: Control, chips: Array, csel: int, money: Array, primary: String, pic: Variant, lc: Array = [], rcn: Array = [],
		arrows: bool = true, back: bool = true, dim: float = 0.6, pkind: String = "primary") -> void:
	_dim(rc, dim)
	_fade(rc, Rect2(0, 0, SW, 180), col("dimbg"), 0, 0.6, 6)
	_fade(rc, Rect2(0, SH - 200, SW, 200), col("dimbg"), 1, 0.7, 6)
	if back:
		_round_btn(rc, Vector2(SX + 60, SY + 60), 60, G_BACK)
	if not chips.is_empty():
		var ws: Array = []
		var total: float = 0.0
		for ch: String in chips:
			var w: float = _tw_of(ch, 48) + 72
			ws.append(w)
			total += w + 16
		var x: float = SW * 0.5 - (total - 16) * 0.5
		for i in chips.size():
			_btn(rc, Rect2(x, SY + 8, float(ws[i]), 104), str(chips[i]), "primary" if i == csel else "secondary", null, 48)
			x += float(ws[i]) + 16
	var mx: float = RX
	for m: Array in money:
		mx = _money(rc, mx, SY + 16, str(m[0]), int(m[1])) - 16
	if arrows:
		_round_btn(rc, Vector2(SX + 72, 500), 72, G_CHEV_L)
		_round_btn(rc, Vector2(RX - 72, 500), 72, G_CHEV_R)
	if primary != "":
		_btn(rc, Rect2(SW * 0.5 - 400, 912, 800, 140), primary, pkind, pic, 64)
	var lx: float = SX
	for it: Array in lc:
		var w2: float = float(it[2]) if it.size() > 2 else 400.0
		_btn(rc, Rect2(lx, 932, w2, 120), str(it[0]), "secondary", it[1], 48)
		lx += w2 + 16
	var rx: float = RX
	for it: Array in rcn:
		var w3: float = float(it[2]) if it.size() > 2 else 400.0
		_btn(rc, Rect2(rx - w3, 932, w3, 120), str(it[0]), "secondary", it[1], 48)
		rx -= w3 + 16


const D_CARD := Rect2(800, 150, 800, 720)
const D_CARD_S := Rect2(800, 150, 800, 560)


func _D_card(rc: Control, r: Rect2) -> void:
	_frame(rc, r, col("panel"), col("accent"), true)


func _D_neighbors(rc: Control, r: Rect2, draw_fn: Callable) -> void:
	var w: float = 480.0
	var h: float = r.size.y - 80
	var lr := Rect2(r.position.x - 56 - w, r.position.y + 40, w, h)
	var rr := Rect2(r.end.x + 56, r.position.y + 40, w, h)
	draw_fn.call(lr, 0)
	draw_fn.call(rr, 1)
	_rect(rc, lr, Color(col("dimbg"), 0.55))
	_rect(rc, rr, Color(col("dimbg"), 0.55))


func _D_strip(rc: Control, y: float, n: int, sel: int, draw_fn: Callable, sz: float = 136.0) -> void:
	var gap: float = 16.0
	var total: float = n * sz + (n - 1) * gap
	var x0: float = SW * 0.5 - total * 0.5
	for i in n:
		var r := Rect2(x0 + i * (sz + gap), y, sz, sz)
		draw_fn.call(r, i)
		if i == sel:
			_box(rc, r.grow(6), Color(0, 0, 0, 0), col("accent"), 4, 0)


func _Dn_char(r: Rect2, i: int, rc: Control, ids: Array, si: int) -> void:
	var cid: int = int(ids[si - 1 if i == 0 else si + 1])
	_frame(rc, r, col("panel"), col("rim"))
	_sprite(rc, cid, Vector2(r.get_center().x, r.end.y - 90), 7.0)
	_t(rc, _cname(cid), Rect2(r.position.x, r.end.y - 76, r.size.x, 64), 48, col("dim"), 1)


func _Ds_inv(rr: Rect2, i: int, rc: Control, all: Array) -> void:
	var e: Array = all[i]
	if e[0] == "w":
		_weapon_tile(rc, rr, str(e[1]), int(e[2]), false, true, false)
	else:
		_item_slot(rc, rr, str(e[1]), _ik(str(e[1])))


func _Ds_weapon(rr: Rect2, i: int, rc: Control) -> void:
	if i < WEAPONS.size():
		_weapon_tile(rc, rr, str(WEAPONS[i][0]), int(WEAPONS[i][1]), false, true, false)
	else:
		_box(rc, rr, Color(col("inset"), 0.5), Color(col("rim"), 0.5), 3)
		_glyph(rc, G_LOCK, rr.get_center(), 5, Color(col("dim"), 0.6))


func _Dn_record(r: Rect2, i: int, rc: Control) -> void:
	var rec: Array = RECORDS[1 if i == 0 else 3]
	_frame(rc, r, col("panel"), col("rim"))
	_medal(rc, Vector2(r.get_center().x, r.position.y + 160), 96, GLYPH_BY_NAME[rec[2]], Color("#f0c070"), false)
	_t(rc, rec[1], Rect2(r.position.x, r.position.y + 300, r.size.x, 96), 96, col("text"), 1)
	_t(rc, rec[0], Rect2(r.position.x, r.position.y + 410, r.size.x, 48), 32, col("dim"), 1)


func D_ana_menu(rc: Control) -> void:
	_fade(rc, Rect2(0, 0, SW, 420), Color(0.03, 0.02, 0.01), 0, 0.7, 8)
	_fade(rc, Rect2(0, SH - 420, SW, 420), Color(0.03, 0.02, 0.01), 1, 0.8, 8)
	_title_logo(rc, Vector2(SW * 0.5, 36), 112, true)
	_money(rc, RX, SY + 16, "soul", SOUL)
	_t(rc, "Oakley  ·  Peri  ·  Tüfek", Rect2(SW * 0.5 - 400, 640, 800, 56), 48, col("text"), 1)
	_tabs(rc, Rect2(SW * 0.5 - 400, 712, 800, 104), ["TEK OYUNCU", "ÇOK OYUNCU"], 0, 48)
	_btn(rc, Rect2(SW * 0.5 - 400, 840, 800, 180), "OYNA", "primary", G_PLAY, 96)
	_btn(rc, Rect2(SX, 900, 320, 120), "MAĞAZA", "secondary", "soul", 48)
	_btn(rc, Rect2(SX + 336, 900, 340, 120), "REKOR", "secondary", G_TROPHY, 48)
	_btn(rc, Rect2(RX - 360, 900, 360, 120), "AYARLAR", "secondary", G_GEAR, 48)


func D_oda(rc: Control) -> void:
	_D_frame(rc, ["İNTERNET", "LAN"], 0, [], "KATIL", G_PLAY, [["YENİLE", G_REROLL, 340], ["KOD", G_KEY, 260]], [["ODA KUR", G_PLUS, 420]])
	_D_neighbors(rc, D_CARD, func(r: Rect2, i: int) -> void: _room_card(rc, r, ROOMS[3] if i == 0 else ROOMS[1], false))
	_D_card(rc, D_CARD)
	var room: Dictionary = ROOMS[0]
	var r: Rect2 = D_CARD.grow(-40)
	_portrait(rc, int(room["host"]), Rect2(r.get_center().x - 120, r.position.y, 240, 240))
	_t(rc, str(room["name"]), Rect2(r.position.x, r.position.y + 260, r.size.x, 80), 64, col("accent"), 1)
	_t(rc, "Kurucu: Mira  ·  38 ms  ·  şifresiz", Rect2(r.position.x, r.position.y + 336, r.size.x, 48), 32, col("dim"), 1)
	for j in 4:
		var sr := Rect2(r.position.x + 20 + j * 172, r.position.y + 410, 144, 144)
		if j < (room["players"] as Array).size():
			_portrait(rc, int(room["players"][j]), sr)
		else:
			_box(rc, sr, Color(col("inset"), 0.6), Color(col("rim"), 0.6), 3)
			_t(rc, "+", sr, 64, Color(col("dim"), 0.5), 1)
	_t(rc, "2 / 4  ·  " + str(room["stage"]), Rect2(r.position.x, r.position.y + 576, r.size.x, 56), 48, col("text"), 1)
	_dots(rc, Vector2(SW * 0.5, 888), 4, 0)


func D_karakter(rc: Control) -> void:
	_D_frame(rc, ["KAHRAMAN", "EVCİL", "SİLAH", "RUHANİ"], 0, [], "HAZIR", G_CHECK, [["Peri", PC.call("icon", PET), 300]], [["Tüfek", _wtex("tufek", 1), 320]], true, true, 0.35)
	var ids: Array = _roster()
	var si: int = ids.find(ME)
	_D_neighbors(rc, D_CARD_S, _Dn_char.bind(rc, ids, si))
	_D_card(rc, D_CARD_S)
	var r: Rect2 = D_CARD_S.grow(-36)
	_ellipse(rc, Vector2(r.get_center().x, r.position.y + 300), 340, 70, Color(0, 0, 0, 0.25))
	_sprite(rc, ME, Vector2(r.get_center().x, r.position.y + 300), 9.0)
	_t(rc, _cname(ME), Rect2(r.position.x, r.position.y + 316, r.size.x, 80), 64, col("accent"), 1)
	_skill_icons(rc, Vector2(r.position.x + 58, r.position.y + 400), ME, 96, 80, false)
	_D_strip(rc, 736, ids.size(), si, func(rr: Rect2, i: int) -> void: _char_tile(rc, rr, int(ids[i]), false, false), 120)


func D_hud(rc: Control) -> void:
	var cx: float = SW * 0.5
	_box(rc, Rect2(cx - 420, SY - 8, 840, 112), Color(0.1, 0.07, 0.04, 0.55), Color(0, 0, 0, 0), 0, 0)
	_disk(rc, Vector2(cx - 360, SY + 44), 40, Color("#271a11"), Color("#f0c070"), 4)
	_t(rc, str(LEVEL), Rect2(cx - 400, SY + 14, 80, 56), 48, Color("#f3e6cc"), 1)
	_hp(rc, Rect2(cx - 300, SY + 8, 700, 52), TEAM[0], 32, 14)
	_bar(rc, Rect2(cx - 300, SY + 64, 700, 8), 0.62, XP_COL, Color("#0e1a08"), Color("#0a0604"), 1)
	_t(rc, "VII  ·  18:42  ·  %s altın" % _num(GOLD), Rect2(cx - 300, SY + 72, 700, 44), 32, Color("#f3e6cc"), 1)
	for i in range(1, TEAM.size()):
		var c := Vector2(SX + 44 + (i - 1) * 104, SY + 44)
		var t: Dictionary = TEAM[i]
		_ctex(rc, _ptex(int(t["char"])), c, 36, Rect2(12, 4, 24, 24), Color.WHITE, true)
		var d := _disk(rc, c, 44, Color(0, 0, 0, 0), Color(0.1, 0.05, 0.05, 0.8), 6)
		d.arc_frac = float(t["hp"]) / float(t["mhp"])
		d.arc_col = HP_COL
	_round_btn(rc, Vector2(RX - 56, SY + 56), 56, G_MENU)
	_round_btn(rc, Vector2(RX - 192, SY + 56), 56, G_MAP)
	_round_btn(rc, Vector2(RX - 328, SY + 56), 56, G_BAG)
	_disk(rc, Vector2(380, 860), 150, Color(0, 0, 0, 0), Color(1, 1, 1, 0.18), 4).dashed = true
	_t(rc, "joystick: ekranın sol yarısında herhangi bir yer", Rect2(SX, 1000, 900, 44), 32, Color(1, 1, 1, 0.45))
	var sk: Array = _skills(ME)
	_skill_btn(rc, Vector2(2200, 948), 92, sk[3][2], Color("#f0c070"))
	_skill_btn(rc, Vector2(2010, 1000), 64, sk[1][2], Color("#6a4a30"))
	_skill_btn(rc, Vector2(2040, 808), 64, sk[2][2], Color("#6a4a30"), 0.55, "4")
	_skill_btn(rc, Vector2(2200, 760), 54, str(_spirit(SPIRIT).get("icon", "")), SPIRIT_COL)
	var ir := Rect2(SW * 0.5 - 150, 690, 300, 88)
	_box(rc, ir, Color(0.1, 0.07, 0.04, 0.75), Color("#f0c070"), 3)
	_glyph(rc, G_HAND, Vector2(ir.position.x + 50, ir.get_center().y), 5, Color("#f0c070"))
	_t(rc, "SATICI", Rect2(ir.position.x + 92, ir.position.y, 200, 88), 48, Color("#f3e6cc"))


func D_level(rc: Control) -> void:
	_D_frame(rc, [], 0, [], "SEÇ", G_CHECK, [["KARIŞTIR 2", G_REROLL, 420]], [["YASAKLA 1", G_BAN, 400]], true, false, 0.68)
	_t(rc, "SEVİYE %d" % LEVEL, Rect2(0, SY, SW, 112), 96, col("accent"), 1)
	_chip(rc, Vector2(RX - 260, SY + 24), "17 sn", col("text"), 48, 72)
	_D_neighbors(rc, D_CARD, func(r: Rect2, i: int) -> void: _lv_card(rc, r, LV_OPTS[0 if i == 0 else 2], "big"))
	_lv_card(rc, D_CARD, LV_OPTS[1], "big", true)
	_dots(rc, Vector2(SW * 0.5, 890), 3, 1)


func D_sandik(rc: Control) -> void:
	var key: String = (_items(3) as Array)[1]
	_D_frame(rc, [], 0, [["coin", GOLD]], "AL", G_CHECK, [["SAT  +%s" % _num(int(_icost(key) * 0.5)), "coin", 520]], [["Sıradaki: Mira", G_USER, 520]], false, false, 0.62)
	_t(rc, "ELİT SANDIK", Rect2(0, SY, SW, 112), 96, col("accent"), 1)
	_img(rc, beam_tex, Rect2(SW * 0.5 - 320, 100, 640, 960), true, Color(1, 1, 1, 0.6))
	var r := Rect2(SW * 0.5 - 420, 160, 840, 720)
	_D_card(rc, r)
	_img(rc, _itex(key), Rect2(r.get_center().x - 96, r.position.y + 48, 192, 192))
	_t(rc, _iname(key), Rect2(r.position.x, r.position.y + 256, r.size.x, 80), 64, col("text"), 1)
	_chip(rc, Vector2(r.get_center().x - 110, r.position.y + 340), "EFSANEVİ", IT_COL[2], 48, 64)
	var y: float = r.position.y + 432
	for ln: String in _desc(key).split("\n"):
		if ln == "":
			continue
		if ln.begins_with("Pasif:"):
			_tw(rc, ln, Rect2(r.position.x + 48, y + 8, r.size.x - 96, 128), 32, col("dim"), 1)
			break
		_t(rc, ln, Rect2(r.position.x, y, r.size.x, 56), 48, col("good"), 1)
		y += 56


func D_envanter(rc: Control) -> void:
	_D_frame(rc, ["ÇANTA", "ÖZELLİKLER", "SİLAHLAR"], 0, [["coin", GOLD]], "SAT  +%s" % _num(int(_icost(BAG_SEL) * 0.5)), "coin", [], [], true, true, 0.62, "danger")
	var bag: Array = _bag()
	var si: int = bag.find(BAG_SEL)
	_D_neighbors(rc, D_CARD_S, func(r: Rect2, i: int) -> void: _item_tile(rc, r, bag[si - 1 if i == 0 else si + 1], false, false, false, true))
	_D_card(rc, D_CARD_S)
	var r: Rect2 = D_CARD_S.grow(-40)
	_img(rc, _itex(BAG_SEL), Rect2(r.get_center().x - 80, r.position.y, 160, 160))
	_t(rc, _iname(BAG_SEL), Rect2(r.position.x, r.position.y + 168, r.size.x, 72), 64, col("text"), 1)
	_chip(rc, Vector2(r.get_center().x - 70, r.position.y + 244), IT_NAMES[_ik(BAG_SEL) - 1], IT_COL[_ik(BAG_SEL) - 1], 32, 52)
	var y: float = r.position.y + 316
	for ln: String in _desc(BAG_SEL).split("\n"):
		if ln == "":
			continue
		if ln.begins_with("Pasif:"):
			_tw(rc, ln, Rect2(r.position.x, y, r.size.x, 96), 32, col("dim"), 1)
			break
		_t(rc, ln, Rect2(r.position.x, y, r.size.x, 48), 48, col("good"), 1)
		y += 52
	var all: Array = []
	for w: Array in WEAPONS:
		all.append(["w", w[0], w[1]])
	for b: String in bag:
		all.append(["i", b, 0])
	var sel: int = 3 + si
	_D_strip(rc, 740, all.size(), sel, _Ds_inv.bind(rc, all), 136)


func D_seyyar(rc: Control) -> void:
	_D_frame(rc, ["EFSANEVİ", "EPİK", "PARÇA"], 1, [["coin", GOLD]], "SATIN AL  %s" % _num(_icost(SHOP_SEL)), "coin", [["ÇANTA 7/15", G_BAG, 420]], [["01:42", G_CLOCK, 300]])
	var keys: Array = _items(2)
	var si: int = keys.find(SHOP_SEL)
	_D_neighbors(rc, D_CARD_S, func(r: Rect2, i: int) -> void: _item_tile(rc, r, keys[maxi(0, si - 1) if i == 0 else si + 1], false, false, true, true))
	_D_card(rc, D_CARD_S)
	var r: Rect2 = D_CARD_S.grow(-36)
	_item_detail(rc, Rect2(r.position.x, r.position.y, r.size.x, 300), SHOP_SEL, true)
	_recipe(rc, Vector2(r.position.x, r.position.y + 340), SHOP_SEL, 112, r.size.x)
	_D_strip(rc, 740, mini(keys.size(), 11), si, func(rr: Rect2, i: int) -> void: _item_slot(rc, rr, keys[i], 2), 136)


func D_demirci(rc: Control) -> void:
	var cst: Array = _w_cost(3)
	_D_frame(rc, ["SİLAHLARIM", "YENİ SİLAH", "KALKAN"], 0, [["wshard", WSHARD], ["coin", GOLD]], "GELİŞTİR  %d + %d" % [int(cst[0]), int(cst[1])], G_HAMMER)
	_D_neighbors(rc, D_CARD_S, func(r: Rect2, i: int) -> void: _weapon_tile(rc, r, str(WEAPONS[2 if i == 0 else 1][0]), int(WEAPONS[2 if i == 0 else 1][1]), false, true, true))
	_D_card(rc, D_CARD_S)
	var r: Rect2 = D_CARD_S.grow(-36)
	_img(rc, _wtex("tufek", 3), Rect2(r.get_center().x - 96, r.position.y, 192, 192))
	_t(rc, _wname("tufek") + "  ·  III", Rect2(r.position.x, r.position.y + 200, r.size.x, 72), 64, col("text"), 1)
	_tier_path(rc, Rect2(r.position.x + 20, r.position.y + 290, r.size.x - 40, 64), 3)
	var a: Array = _w_stats(3)
	var b: Array = _w_stats(4)
	_t(rc, "Hasar  %s -> %s" % [a[0], b[0]], Rect2(r.position.x, r.position.y + 380, r.size.x, 56), 48, col("good"), 1)
	_t(rc, "Atış aralığı  %s -> %s" % [a[1], b[1]], Rect2(r.position.x, r.position.y + 436, r.size.x, 56), 48, col("good"), 1)
	_D_strip(rc, 740, 4, 0, _Ds_weapon.bind(rc), 136)


func D_ruh(rc: Control) -> void:
	var cost: int = int(MetaCosts.CHAR.get(SOUL_SEL, 400))
	_D_frame(rc, ["KAHRAMAN", "SİLAH", "EVCİL", "RUHANİ", "GELİŞTİR"], 0, [["soul", SOUL]], "KİLİDİ AÇ  %d" % cost, "soul", [], [], true, true, 0.4)
	var ids: Array = _roster()
	var si: int = ids.find(SOUL_SEL)
	_D_neighbors(rc, D_CARD_S, func(r: Rect2, i: int) -> void: _char_tile(rc, r, int(ids[si - 1 if i == 0 else si + 1]), false, true))
	_D_card(rc, D_CARD_S)
	var r: Rect2 = D_CARD_S.grow(-36)
	_sprite(rc, SOUL_SEL, Vector2(r.get_center().x, r.position.y + 290), 9.0)
	_t(rc, _cname(SOUL_SEL), Rect2(r.position.x, r.position.y + 300, r.size.x, 80), 64, col("accent"), 1)
	_skill_icons(rc, Vector2(r.position.x + 58, r.position.y + 390), SOUL_SEL, 96, 80, false)
	_D_strip(rc, 740, ids.size(), si, func(rr: Rect2, i: int) -> void: _char_tile(rc, rr, int(ids[i]), false, false), 120)


func D_duraklat(rc: Control) -> void:
	_dim(rc, 0.6)
	for i in TEAM.size():
		_party_face(rc, Rect2(SX + i * 112, SY, 88, 88), TEAM[i])
	var r := Rect2(SW * 0.5 - 440, 60, 880, 980)
	_D_card(rc, r)
	_t(rc, "DURAKLATILDI", Rect2(r.position.x, r.position.y + 40, r.size.x, 96), 96, col("accent"), 1)
	_t(rc, "%s  ·  Kademe VII  ·  Seviye %d" % [RUN_TIME, LEVEL], Rect2(r.position.x, r.position.y + 140, r.size.x, 56), 48, col("text"), 1)
	_t(rc, "Çok oyunculu: oyun arkada sürüyor", Rect2(r.position.x, r.position.y + 196, r.size.x, 48), 32, col("bad"), 1)
	var items: Array = [["DEVAM ET", G_PLAY, "primary"], ["AYARLAR", G_GEAR, "secondary"], ["SOHBET", G_CHAT, "secondary"], ["ANA MENÜ", G_HOME, "danger"]]
	for i in items.size():
		_btn(rc, Rect2(r.position.x + 60, r.position.y + 280 + i * 168, r.size.x - 120, 148), items[i][0], items[i][2], items[i][1], 64)


func D_ayarlar(rc: Control) -> void:
	_D_frame(rc, SET_CATS, 2, [], "DÜĞMELERİ YERLEŞTİR", G_HAND, [], [], true, true, 0.66, "secondary")
	var r := Rect2(SW * 0.5 - 860, 150, 1720, 740)
	_D_card(rc, r)
	var rows: Array = SET_ROWS.slice(0, 6)
	for i in rows.size():
		var rr := Rect2(r.position.x + 32, r.position.y + 32 + i * 114, r.size.x - 64, 106)
		_set_row(rc, rr, rows[i], i == 1, 48)
		if i < rows.size() - 1:
			_rect(rc, Rect2(rr.position.x + 24, rr.end.y + 3, rr.size.x - 48, 3), col("line"))


func D_oyun_bitti(rc: Control) -> void:
	_D_frame(rc, [], 0, [], "ANA MENÜ", G_HOME, [["TEKRAR", G_REROLL, 380]], [["İSTATİSTİK", G_GRID, 460]], false, false, 0.7)
	var r := Rect2(SW * 0.5 - 600, 40, 1200, 840)
	_D_card(rc, r)
	_t(rc, "OYUN BİTTİ", Rect2(r.position.x, r.position.y + 32, r.size.x, 128), 128, col("bad"), 1)
	_t(rc, "Kademe IX'da düştün", Rect2(r.position.x, r.position.y + 160, r.size.x, 56), 48, col("dim"), 1)
	var stats: Array = [[str(GO["time"]), "SÜRE", G_CLOCK], [_num(int(GO["kills"])), "ÖLDÜRME", G_SWORD], [str(GO["level"]), "SEVİYE", G_STAR],
			[_num(int(GO["gold"])), "ALTIN", "coin"], ["IX", "KADEME", G_SKULL], ["+%d" % int(GO["soul"]), "RUH KIYMIĞI", "soul"]]
	var tw: float = (r.size.x - 120 - 2 * 24) / 3.0
	for i in stats.size():
		@warning_ignore("integer_division")
		var tr := Rect2(r.position.x + 60 + (i % 3) * (tw + 24), r.position.y + 248 + (i / 3) * 200, tw, 180)
		_stat_tile(rc, tr, stats[i][0], stats[i][1], SOUL_COL if i == 5 else col("text"), stats[i][2])
	_t(rc, "EN ÇOK HASAR", Rect2(r.position.x + 60, r.position.y + 664, 500, 48), 32, col("dim"))
	_portrait(rc, 5, Rect2(r.position.x + 60, r.position.y + 712, 96, 96))
	_t(rc, "Kerem  ·  52.740", Rect2(r.position.x + 176, r.position.y + 728, 700, 64), 64, col("price"))
	_dots(rc, Vector2(SW * 0.5, 898), 3, 0)


func D_rekor(rc: Control) -> void:
	_D_frame(rc, ["EN İYİLER", "BAŞARIMLAR"], 0, [], "", null, [], [], true, true, 0.5)
	_D_neighbors(rc, D_CARD, _Dn_record.bind(rc))
	_D_card(rc, D_CARD)
	var rec: Array = RECORDS[2]
	var r: Rect2 = D_CARD
	_medal(rc, Vector2(r.get_center().x, r.position.y + 190), 128, GLYPH_BY_NAME[rec[2]], Color("#f0c070"), false)
	_chip(rc, Vector2(r.end.x - 180, r.position.y + 40), "YENİ", col("bad"), 48, 72, true)
	_t(rc, rec[1], Rect2(r.position.x, r.position.y + 360, r.size.x, 128), 128, col("text"), 1)
	_t(rc, rec[0], Rect2(r.position.x, r.position.y + 496, r.size.x, 64), 48, col("dim"), 1)
	_t(rc, "17.10.2026  ·  Şovalye Adam", Rect2(r.position.x, r.position.y + 576, r.size.x, 56), 48, col("text"), 1)
	_dots(rc, Vector2(SW * 0.5, 896), 5, 2)
	_t(rc, "31 koşu  ·  1 zafer  ·  9 sa 41 dk  ·  11/17 başarım", Rect2(0, 960, SW, 56), 48, col("dim"), 1)


## ====================================================================================== S - SEÇİLEN SET: dostane sandık / level / oda
## Kullanıcı (2026-10-18): "sandık ödülü, level atlama ekranı ve multiplayer ekranı daha kullanıcı dostu olabilir". B'deki sorunlar:
## level iki adımlı (satır seç + SEÇ) ve karıştır/yasakla sol üst rayda (başparmaktan uzak); sandıkta AL/SAT sağ altta üst üste, eşyanın
## sana ne kattığı yok, sıra rayı anlaşılmıyor; odada katılmak = satır seç + sağ panel + KATIL (3 adım), hızlı katıl yok.
## Ortak ilke: tek dokunuş, eylem dokunulan şeyin YANINDA, başparmak bölgeleri (sol alt / sağ alt), süre ve sıra hep görünür.

## Sağ üst: seçmeyi bekleyenlerin yüzleri + süre halkası.
func _S_wait(rc: Control) -> void:
	var tc := Vector2(RX - 64, SY + 64)
	var d := _disk(rc, tc, 64, Color(col("inset"), 0.92), col("line"), 8)
	d.arc_frac = 0.68
	d.arc_col = col("accent")
	_t(rc, "17", Rect2(tc - Vector2(64, 34), Vector2(128, 64)), 64, col("text"), 1)
	var x: float = RX - 152
	for i: int in [3, 1]:
		x -= 92
		_face(rc, int(TEAM[i]["char"]), Rect2(x, SY + 24, 80, 80))
	_t(rc, "Bekleniyor:", Rect2(x - 300, SY + 24, 284, 80), 32, col("dim"), 2)


func _S_lv_card(rc: Control, r: Rect2, o: Dictionary, with_btn: bool) -> void:
	var t: int = int(o["tier"])
	var tc: Color = LV_COL[t]
	_box(rc, r, Color(col("panel2"), 0.97), tc, 4, 18)
	_box(rc, Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8, 72)), Color(tc, 0.3), Color(0, 0, 0, 0), 0, 14)
	_t(rc, LV_NAMES[t], Rect2(r.position.x, r.position.y + 4, r.size.x, 72), 48, tc.lightened(0.25), 1)
	if int(o["count"]) > 0:
		_t(rc, "x%d" % int(o["count"]), Rect2(r.end.x - 120, r.position.y + 4, 96, 72), 32, col("dim"), 2)
	var cx: float = r.get_center().x
	_img(rc, _stat_tex(str(o["stat"])), Rect2(cx - 96, r.position.y + 96, 192, 192), false)
	_t(rc, str(o["val"]), Rect2(r.position.x, r.position.y + 296, r.size.x, 112), 112, col("text"), 1)
	_t(rc, str(o["name"]), Rect2(r.position.x, r.position.y + 416, r.size.x, 64), 64, tc.lightened(0.25), 1)
	## Kullanıcı (2026-10-18): "dokun seç yazısı ve gereksiz ayrıntılı açıklama kalksın" -> açıklama cümlesi + DOKUN = SEÇ yok.
	var nr := Rect2(r.position.x + 40, r.position.y + 500, r.size.x - 80, 64)
	_box(rc, nr, Color(col("inset"), 0.85), col("line"), 2, 12)
	_t(rc, "Şu an  " + str(o["now"]), nr, 48, col("good"), 1)
	if with_btn:
		_btn(rc, Rect2(r.position.x + 32, r.end.y - 152, r.size.x - 64, 124), "SEÇ", "primary", G_CHECK, 64)
		_round_btn(rc, Vector2(r.end.x - 60, r.position.y + 140), 44, G_X)


## Level 1: kartın KENDİSİ düğme (tek dokunuş), karıştır/yasakla iki başparmakta.
func S_level(rc: Control) -> void:
	_dim(rc, 0.66)
	_fade(rc, Rect2(0, 0, SW, 190), col("dimbg"), 0, 0.7)
	_t(rc, "SEVİYE %d!" % LEVEL, Rect2(SX, SY - 4, 900, 96), 96, col("accent"))
	_S_wait(rc)
	var w: float = 640.0
	var gap: float = 64.0
	var x0: float = (SW - (w * 3 + gap * 2)) * 0.5
	for i in 3:
		_S_lv_card(rc, Rect2(x0 + i * (w + gap), 226, w, 600), LV_OPTS[i], false)
	_btn(rc, Rect2(SX, 916, 500, 136), "KARIŞTIR", "secondary", G_REROLL, 48, "2 hak")
	_btn(rc, Rect2(RX - 500, 916, 500, 136), "YASAKLA", "secondary", G_BAN, 48, "1 hak")


## Level 2: her kartın altında kendi SEÇ'i (yanlış dokunuşa karşı), sağ üstünde X = yasakla; karıştır başlığın yanında.
func S_level_2(rc: Control) -> void:
	_dim(rc, 0.66)
	_fade(rc, Rect2(0, 0, SW, 190), col("dimbg"), 0, 0.7)
	_t(rc, "SEVİYE %d!" % LEVEL, Rect2(SX, SY - 4, 640, 96), 96, col("accent"))
	_t(rc, "SEÇ'e dokun  ·  X = yasakla (1 hak)", Rect2(SX, SY + 96, 1000, 48), 32, col("dim"))
	_btn(rc, Rect2(SX + 620, SY + 4, 460, 120), "KARIŞTIR", "secondary", G_REROLL, 48, "2 hak kaldı")
	_S_wait(rc)
	var w: float = 680.0
	var gap: float = 44.0
	var x0: float = (SW - (w * 3 + gap * 2)) * 0.5
	for i in 3:
		_S_lv_card(rc, Rect2(x0 + i * (w + gap), 172, w, 880), LV_OPTS[i], true)


## Sıra: Sen -> Mira -> Kerem -> Deniz (sağ üst).
func _S_turn(rc: Control) -> void:
	var x: float = RX
	for i in range(TEAM.size() - 1, -1, -1):
		var me: bool = i == 0
		var fs: float = 96.0 if me else 72.0
		x -= fs
		_face(rc, int(TEAM[i]["char"]), Rect2(x, SY + (0.0 if me else 12.0), fs, fs), col("accent") if me else col("line_hi"))
		if me:
			_t(rc, "SEN", Rect2(x, SY + 100, fs, 40), 32, col("accent"), 1)
		if i > 0:
			_glyph(rc, G_CHEV_R, Vector2(x - 24, SY + 48), 3, Color(col("dim"), 0.7))
			x -= 48
	_t(rc, "SIRA", Rect2(x - 160, SY + 12, 140, 72), 32, col("dim"), 2)


## Eşyanın sana katkısı: describe satırlarından "+N Etiket" -> [etiket, şu an, sonra, yüzde mi].
func _cmp_rows(key: String) -> Array:
	var now: Dictionary = {"Saldırı Gücü": 48.0, "Saldırı Hızı": 34.0, "Mana Kalkanı": 240.0, "Can": 520.0, "Kritik Şansı": 12.0,
			"Kritik Hasarı": 50.0, "Hareket Hızı": 8.0, "Can Çalma": 4.0, "Kalkan Delme": 6.0, "Can Yenilenmesi": 4.0}
	var out: Array = []
	for ln: String in _desc(key).split("\n"):
		if not ln.begins_with("+"):
			continue
		var pct: bool = ln.begins_with("+%")
		var rest: String = ln.substr(2 if pct else 1)
		var sp: int = rest.find(" ")
		if sp < 0:
			continue
		var v: float = float(rest.substr(0, sp).replace(",", "."))
		var label: String = rest.substr(sp + 1)
		var c: float = float(now.get(label, 0.0))
		out.append([label, c, c + v, pct])
	return out


func _fmt(v: float, pct: bool) -> String:
	return ("%%%d" % int(v)) if pct else _num(int(v))


## Sandık 1: AL/SAT kartın HEMEN yanında (kullanıcı 2026-10-03: kenar düğmeleri "çok kenarda"), çantadaki yeri + sıra görünür.
func S_sandik(rc: Control) -> void:
	var key: String = _items(3)[1]
	var refund: int = int(_icost(key) * 0.5)
	_dim(rc, 0.62)
	_fade(rc, Rect2(0, 0, SW, 190), col("dimbg"), 0, 0.7)
	_t(rc, "ELİT SANDIK", Rect2(SX, SY - 4, 900, 80), 64, col("accent"))
	_t(rc, "Sıra sende: al ya da sat", Rect2(SX, SY + 72, 900, 48), 32, col("dim"))
	_S_turn(rc)
	## Kullanıcı (2026-10-18): "arttırılmış gibi göstermek yerine direk verdiği statlar ve pasif gözüksün pasif solgun gözükmesin
	## önemli bir açıklama o çünkü" -> "48 -> 63" karşılaştırması yok; eşyanın kendi statları + PASİF kutusu parlak yazıyla.
	var stat_lines: Array = []
	var passive: String = ""
	for ln: String in _desc(key).split("\n"):
		if ln == "":
			continue
		if ln.begins_with("Pasif:"):
			passive = ln.substr(6).strip_edges()
		else:
			stat_lines.append(ln)
	var card_h: float = 392.0 + stat_lines.size() * 58.0 + (190.0 if passive != "" else 0.0) + 24.0
	var card := Rect2(760, 560 - card_h * 0.5, 880, card_h)
	_img(rc, beam_tex, Rect2(card.get_center().x - 320, 40, 640, 960), true, Color(1, 1, 1, 0.7))
	_box(rc, card, Color(col("panel2"), 0.97), IT_COL[2], 4, 18)
	_box(rc, Rect2(card.position + Vector2(4, 4), Vector2(card.size.x - 8, 72)), Color(IT_COL[2], 0.3), Color(0, 0, 0, 0), 0, 14)
	_t(rc, "EFSANEVİ", Rect2(card.position.x, card.position.y + 4, card.size.x, 72), 48, IT_COL[2].lightened(0.25), 1)
	_img(rc, _itex(key), Rect2(card.get_center().x - 96, card.position.y + 96, 192, 192))
	_t(rc, _iname(key), Rect2(card.position.x, card.position.y + 300, card.size.x, 72), 64, col("text"), 1)
	var y: float = card.position.y + 392
	for ln: String in stat_lines:
		_t(rc, ln, Rect2(card.position.x, y, card.size.x, 56), 48, col("good"), 1)
		y += 58
	if passive != "":
		var pr := Rect2(card.position.x + 36, y + 14, card.size.x - 72, 166)
		_box(rc, pr, Color(col("inset"), 0.92), Color(col("accent"), 0.7), 2, 12)
		_t(rc, "PASİF", Rect2(pr.position.x + 24, pr.position.y + 10, 300, 44), 32, col("accent"))
		_tw(rc, passive, Rect2(pr.position.x + 24, pr.position.y + 58, pr.size.x - 48, 96), 48, col("text"))
	_btn(rc, Rect2(card.position.x - 40 - 460, 520, 460, 280), "SAT", "secondary", "coin", 64, "+%s altın" % _num(refund))
	_btn(rc, Rect2(card.end.x + 40, 520, 460, 280), "AL", "primary", G_CHECK, 96, "çantaya ekle")
	_t(rc, "Çantandaki efsaneviler", Rect2(card.position.x - 500, 300, 460, 44), 32, col("dim"))
	var leg: Array = []
	for b: String in _bag():
		if _ik(b) == 3:
			leg.append(b)
	for j in 5:
		var sr := Rect2(card.position.x - 500 + j * 92, 352, 80, 80)
		if j < leg.size():
			_item_slot(rc, sr, leg[j], 3)
		elif j == leg.size():
			_box(rc, sr, Color(col("accent"), 0.15), col("accent"), 3, 10)
			_t(rc, "+", sr, 64, col("accent"), 1)
		else:
			_item_slot(rc, sr, "", 3)
	_t(rc, "Senden sonra", Rect2(card.end.x + 40, 300, 460, 44), 32, col("dim"))
	_face(rc, int(TEAM[1]["char"]), Rect2(card.end.x + 40, 352, 80, 80))
	_t(rc, "Mira", Rect2(card.end.x + 136, 352, 300, 80), 48, col("text"))


## Sandık 2: solda eşya, sağda "SANA KATKISI" karşılaştırması, SAT sol alt / AL sağ alt (iki başparmak).
func S_sandik_2(rc: Control) -> void:
	var key: String = _items(3)[1]
	var refund: int = int(_icost(key) * 0.5)
	_dim(rc, 0.62)
	_fade(rc, Rect2(0, 0, SW, 190), col("dimbg"), 0, 0.7)
	_t(rc, "ELİT SANDIK", Rect2(SX, SY - 4, 900, 80), 64, col("accent"))
	_t(rc, "Sıra sende: al ya da sat", Rect2(SX, SY + 72, 900, 48), 32, col("dim"))
	_S_turn(rc)
	var lp := Rect2(SX, 176, 1060, 712)
	_box(rc, lp, Color(col("panel2"), 0.97), IT_COL[2], 4, 18)
	_img(rc, beam_tex, Rect2(lp.position.x + 40, lp.position.y + 8, 256, 384), true, Color(1, 1, 1, 0.8))
	_img(rc, chest_tex, Rect2(lp.position.x + 72, lp.position.y + 200, 192, 192))
	_img(rc, _itex(key), Rect2(lp.position.x + 104, lp.position.y + 40, 128, 128))
	var x: float = lp.position.x + 340
	_t(rc, _iname(key), Rect2(x, lp.position.y + 40, lp.end.x - x - 32, 80), 64, col("text"))
	_chip(rc, Vector2(x, lp.position.y + 128), "EFSANEVİ", IT_COL[2], 32, 52)
	_money_icon(rc, "coin", Rect2(x + 220, lp.position.y + 130, 48, 48))
	_t(rc, _num(_icost(key)), Rect2(x + 276, lp.position.y + 124, 300, 60), 48, col("price"))
	var y: float = lp.position.y + 440
	for ln: String in _desc(key).split("\n"):
		if ln == "":
			continue
		if ln.begins_with("Pasif:"):
			_tw(rc, ln, Rect2(lp.position.x + 40, y + 8, lp.size.x - 80, 140), 32, col("dim"))
			break
		_t(rc, ln, Rect2(lp.position.x + 40, y, lp.size.x - 80, 56), 48, col("good"))
		y += 60
	var rp := Rect2(lp.end.x + 40, 176, RX - lp.end.x - 40, 712)
	_box(rc, rp, Color(col("panel"), 0.95), col("line"), 3, 18)
	_t(rc, "SANA KATKISI", Rect2(rp.position.x + 40, rp.position.y + 24, rp.size.x - 80, 72), 64, col("accent"))
	var ry: float = rp.position.y + 120
	for row: Array in _cmp_rows(key):
		_t(rc, str(row[0]), Rect2(rp.position.x + 40, ry, 500, 72), 48, col("text"))
		_t(rc, _fmt(row[1], row[3]), Rect2(rp.position.x + 520, ry, 160, 72), 48, col("dim"), 2)
		_t(rc, "->", Rect2(rp.position.x + 690, ry, 80, 72), 48, col("dim"), 1)
		_t(rc, _fmt(row[2], row[3]), Rect2(rp.position.x + 770, ry, 200, 72), 48, col("good"))
		ry += 84
	_t(rc, "Efsanevi yuva", Rect2(rp.position.x + 40, ry, 500, 72), 48, col("text"))
	_t(rc, "2/5 -> 3/5", Rect2(rp.position.x + 520, ry, 450, 72), 48, col("dim"))
	ry += 84
	_rect(rc, Rect2(rp.position.x + 40, ry + 8, rp.size.x - 80, 3), col("line"))
	_t(rc, "Satarsan", Rect2(rp.position.x + 40, ry + 24, 500, 72), 48, col("text"))
	_money_icon(rc, "coin", Rect2(rp.position.x + 520, ry + 36, 48, 48))
	_t(rc, "+%s" % _num(refund), Rect2(rp.position.x + 580, ry + 24, 300, 72), 48, col("price"))
	_t(rc, "Senden sonra: Mira", Rect2(rp.position.x + 40, rp.end.y - 72, rp.size.x - 80, 56), 32, col("dim"))
	_btn(rc, Rect2(SX, 916, 640, 136), "SAT  +%s" % _num(refund), "secondary", "coin", 48)
	_btn(rc, Rect2(RX - 900, 916, 900, 136), "AL", "primary", G_CHECK, 64, "çantaya ekle")


func _ping(p: Control, pos: Vector2, ms: int) -> void:
	var n: int = 3 if ms < 60 else (2 if ms < 100 else 1)
	var c: Color = col("good") if n == 3 else (col("price") if n == 2 else col("bad"))
	for i in 3:
		var h: float = 14.0 + i * 12.0
		_rect(p, Rect2(pos.x + i * 16, pos.y + 42 - h, 10, h), c if i < n else Color(col("dim"), 0.3))
	_t(p, "%d ms" % ms, Rect2(pos.x + 56, pos.y, 150, 44), 32, c)


func _S_room_join(rc: Control, r: Rect2, room: Dictionary) -> void:
	var full: bool = (room["players"] as Array).size() >= 4
	if full:
		_btn(rc, r, "DOLU", "disabled", null, 48)
	elif room["lock"]:
		_btn(rc, r, "KATIL", "secondary", G_LOCK, 48, "şifreli")
	else:
		_btn(rc, r, "KATIL", "primary", G_PLAY, 64)


## Oda 1: solda büyük eylemler (HIZLI KATIL / ODA KUR / KODLA), sağda her satırın sonunda kendi KATIL'ı (tek dokunuş).
func S_oda(rc: Control) -> void:
	_dim(rc, 0.6)
	_fade(rc, Rect2(0, 0, SW, 190), col("dimbg"), 0, 0.7)
	_sq_btn(rc, Rect2(SX, SY, 120, 120), G_BACK)
	_t(rc, "ÇOK OYUNCU", Rect2(SX + 152, SY - 4, 900, 80), 64, col("accent"))
	_t(rc, "Satırdaki KATIL'a dokun ya da hızlı katıl", Rect2(SX + 152, SY + 70, 1000, 48), 32, col("dim"))
	_tabs(rc, Rect2(RX - 640, SY + 8, 640, 104), ["İNTERNET", "LAN"], 0)
	_btn(rc, Rect2(SX, 176, 560, 236), "HIZLI KATIL", "primary", G_PLAY, 64, "En uygun odaya gir")
	_btn(rc, Rect2(SX, 436, 560, 180), "ODA KUR", "secondary", G_PLUS, 64, "Arkadaşlarını çağır")
	_btn(rc, Rect2(SX, 640, 560, 150), "KODLA KATIL", "secondary", G_KEY, 48, "Oda kodunu yaz")
	var nr := Rect2(SX, 814, 560, 238)
	_box(rc, nr, Color(col("panel"), 0.92), col("line"), 3, 18)
	_face(rc, ME, Rect2(nr.position.x + 24, nr.position.y + 24, 96, 96), col("accent"))
	_t(rc, "Oyuncu adın", Rect2(nr.position.x + 140, nr.position.y + 20, 400, 44), 32, col("dim"))
	_t(rc, "Sen", Rect2(nr.position.x + 140, nr.position.y + 60, 400, 64), 64, col("text"))
	_btn(rc, Rect2(nr.position.x + 24, nr.end.y - 96, nr.size.x - 48, 76), "DEĞİŞTİR", "ghost", null, 32)
	var lx: float = SX + 600
	var lw: float = RX - lx
	_t(rc, "4 ODA", Rect2(lx, 176, 400, 72), 48, col("dim"))
	_btn(rc, Rect2(RX - 300, 168, 300, 88), "YENİLE", "ghost", G_REROLL, 48)
	for i in ROOMS.size():
		var room: Dictionary = ROOMS[i]
		var full: bool = (room["players"] as Array).size() >= 4
		var r := Rect2(lx, 276 + i * 194, lw, 178)
		_box(rc, r, Color(col("panel2"), 0.6 if full else 0.95), col("line"), 3, 18)
		_portrait(rc, int(room["host"]), Rect2(r.position.x + 18, r.position.y + 17, 144, 144), Color(0, 0, 0, 0), full)
		_t(rc, str(room["name"]), Rect2(r.position.x + 186, r.position.y + 20, 540, 64), 48, col("dim") if full else col("text"))
		if room["lock"]:
			_glyph(rc, G_LOCK, Vector2(r.position.x + 186 + _tw_of(str(room["name"]), 48) + 36, r.position.y + 52), 5, col("bad"))
		_t(rc, str(room["stage"]), Rect2(r.position.x + 186, r.position.y + 92, 560, 48), 32, col("dim"))
		for j in 4:
			var sr := Rect2(r.position.x + 760 + j * 84, r.position.y + 51, 76, 76)
			if j < (room["players"] as Array).size():
				_face(rc, int(room["players"][j]), sr)
			else:
				_box(rc, sr, Color(col("inset"), 0.5), Color(col("line_hi"), 0.5), 2, 10)
		_ping(rc, Vector2(r.position.x + 1110, r.position.y + 66), int(room["ping"]))
		_S_room_join(rc, Rect2(r.end.x - 330, r.position.y + 25, 310, 128), room)


## Oda 2: 2x2 büyük oda kartı (her kartta KATIL), altta ODA KUR / KODLA KATIL / HIZLI KATIL başparmak çubuğu.
func S_oda_2(rc: Control) -> void:
	_dim(rc, 0.6)
	_fade(rc, Rect2(0, 0, SW, 190), col("dimbg"), 0, 0.7)
	_fade(rc, Rect2(0, SH - 220, SW, 220), col("dimbg"), 1, 0.8)
	_sq_btn(rc, Rect2(SX, SY, 120, 120), G_BACK)
	_t(rc, "ÇOK OYUNCU", Rect2(SX + 152, SY - 4, 900, 80), 64, col("accent"))
	_t(rc, "4 oda açık", Rect2(SX + 152, SY + 70, 1000, 48), 32, col("dim"))
	_tabs(rc, Rect2(RX - 640, SY + 8, 640, 104), ["İNTERNET", "LAN"], 0)
	_sq_btn(rc, Rect2(RX - 640 - 136, SY + 4, 112, 112), G_REROLL)
	var w: float = (RX - SX - 32) / 2.0
	var h: float = 346.0
	for i in ROOMS.size():
		var room: Dictionary = ROOMS[i]
		var full: bool = (room["players"] as Array).size() >= 4
		@warning_ignore("integer_division")
		var r := Rect2(SX + (i % 2) * (w + 32), 172 + (i / 2) * (h + 24), w, h)
		_box(rc, r, Color(col("panel2"), 0.6 if full else 0.95), col("line"), 3, 18)
		_portrait(rc, int(room["host"]), Rect2(r.position.x + 24, r.position.y + 24, 192, 192), Color(0, 0, 0, 0), full)
		var x: float = r.position.x + 244
		_t(rc, str(room["name"]), Rect2(x, r.position.y + 20, r.size.x - 260, 72), 64, col("dim") if full else col("text"))
		if room["lock"]:
			_glyph(rc, G_LOCK, Vector2(x + _tw_of(str(room["name"]), 64) + 40, r.position.y + 56), 6, col("bad"))
		_t(rc, "Kurucu: " + _cname(int(room["host"])), Rect2(x, r.position.y + 96, 500, 48), 32, col("dim"))
		_ping(rc, Vector2(x + 520, r.position.y + 98), int(room["ping"]))
		for j in 4:
			var sr := Rect2(x + j * 100, r.position.y + 160, 88, 88)
			if j < (room["players"] as Array).size():
				_face(rc, int(room["players"][j]), sr)
			else:
				_box(rc, sr, Color(col("inset"), 0.5), Color(col("line_hi"), 0.5), 2, 10)
				_t(rc, "+", sr, 64, Color(col("dim"), 0.5), 1)
		_t(rc, "%d/4 oyuncu, %s" % [(room["players"] as Array).size(), str(room["stage"]).to_lower()], Rect2(r.position.x + 24, r.end.y - 72, 640, 56), 32, col("dim"))
		_S_room_join(rc, Rect2(r.end.x - 344, r.end.y - 160, 320, 136), room)
	_btn(rc, Rect2(SX, 916, 520, 136), "ODA KUR", "secondary", G_PLUS, 48)
	_btn(rc, Rect2(SX + 540, 916, 520, 136), "KODLA KATIL", "secondary", G_KEY, 48)
	_btn(rc, Rect2(RX - 700, 916, 700, 136), "HIZLI KATIL", "primary", G_PLAY, 64)


## Seçilen setin özeti + üç ekranın "eski B / yeni 1 / yeni 2" karşılaştırması.
func _sheets_s() -> void:
	cur = "B"
	S = SKINS["B"]
	var l := CanvasLayer.new()
	l.layer = 97
	root.add_child(l)
	var rc := _ctl_root(l)
	_rect(rc, Rect2(0, 0, SW, SH), Color("#141210"))
	_t(rc, DIR_NAMES["S"], Rect2(40, 12, 2300, 72), 48, col("accent"))
	for i in SCREENS.size():
		var key: String = "S_" + SCREENS[i]
		if not shots.has(key):
			continue
		@warning_ignore("integer_division")
		var cx: float = 40 + (i % 5) * 470
		@warning_ignore("integer_division")
		var cy: float = 100 + (i / 5) * 320
		_img(rc, _thumb(shots[key], 448, 202), Rect2(cx, cy, 448, 202), true)
		_box(rc, Rect2(cx, cy, 448, 202), Color(0, 0, 0, 0), Color("#3a3028"), 2)
		_t(rc, "%d. %s" % [i + 1, SCREEN_NAMES[SCREENS[i]]], Rect2(cx, cy + 206, 448, 44), 32, Color("#efe2c6"))
	await _wait(0.3)
	await _shot("ozet_S")
	l.queue_free()
	for sc: String in ["level", "sandik", "oda"]:
		var l2 := CanvasLayer.new()
		l2.layer = 97
		root.add_child(l2)
		var rc2 := _ctl_root(l2)
		_rect(rc2, Rect2(0, 0, SW, SH), Color("#141210"))
		var old := Image.load_from_file(ProjectSettings.globalize_path(OUT + "B_" + sc + ".png"))
		var items: Array = [["ESKİ (B)", old], ["YENİ 1", shots.get("S_" + sc)], ["YENİ 2", shots.get("S_" + sc + "_2")]]
		for i in items.size():
			if items[i][1] == null:
				continue
			@warning_ignore("integer_division")
			var r := Rect2(50 + (i % 2) * 1200, 44 + (i / 2) * 538, 1100, 495)
			_img(rc2, _thumb(items[i][1], 1100, 495), r, true)
			_t(rc2, "%s  ·  %s" % [items[i][0], SCREEN_NAMES[sc]], Rect2(r.position.x, r.position.y - 42, 1100, 40), 32, col("accent"))
		_tw(rc2, VARIANT_NOTES[sc], Rect2(1290, 600, 1020, 440), 32, Color("#efe2c6"))
		await _wait(0.3)
		await _shot("varyant_" + sc)
		l2.queue_free()


const VARIANT_NOTES := {
	"level": "YENİ 1: kartın kendisi düğme, tek dokunuş = seçim. Karıştır sol alt, yasakla sağ alt (iki başparmak). Bekleyen arkadaşlar + süre sağ üstte. Her kartta 'Şu an 520 -> 570'.\n\nYENİ 2: her kartın altında kendi SEÇ düğmesi (yanlışlıkla seçmeye karşı), sağ üstünde X = yasakla. Karıştır başlığın yanında.",
	"sandik": "YENİ 1: AL ve SAT kartın hemen yanında, büyük (kenara yapışık değil). Eşyanın sana katkısı kartın içinde (ör. Saldırı Gücü 48 -> 63), çantadaki boş efsanevi yuva işaretli, sıra sağ üstte.\n\nYENİ 2: solda eşya, sağda 'SANA KATKISI' karşılaştırması + satış bedeli; SAT sol alt, AL sağ alt.",
	"oda": "YENİ 1: solda HIZLI KATIL / ODA KUR / KODLA KATIL + oyuncu adı; sağda her oda satırının sonunda kendi KATIL düğmesi (tek dokunuş, şifreli = kilitli KATIL, dolu = gri).\n\nYENİ 2: 2x2 büyük oda kartı, her kartta KATIL; altta ODA KUR / KODLA KATIL / HIZLI KATIL başparmak çubuğu.",
}


## ====================================================================================== HUD v2 (MOBIL_ONLY=HUD)
## Kullanıcı (2026-10-18): "oyun içi arayüzünü beğenmedim grup paneli açılıp kapatılabilmeli chat butonu olmalı minimap daha iyi
## görünmeli arayüz biraz ruhsuz". "Ruhsuz" kök nedeni: düz renk kutular. Burada her çerçeve 3 px'lik SANAT PİKSELİ ızgarasında
## elle çizilir (dış kontur + ışık alan üst/sol kenar + gölgeli alt/sağ kenar + iç kontur + perçin/köşe kapağı/damar), daireler
## (minimap, yetenek, portre madalyonu) piksel piksel üretilen halka dokusu. Üç yön, her biri 2 hâl (grup + sohbet AÇIK / KAPALI).
const HUD_VARIANTS := ["H1", "H2", "H3"]
const HUD_NAMES := {"H1": "H1 - Pirinç ve Sıva", "H2": "H2 - Kısık Ahşap", "H3": "H3 - Rün Taşı"}
const HUD_SKINS := {
	"H1": {"outline": Color("#0d0c16"), "rim": Color("#b48a3e"), "hi": Color("#f2d07a"), "lo": Color("#6e4f20"), "fill": Color("#20203a"),
		"fill_hi": Color("#2e2e50"), "stud": Color("#e2b85c"), "cap": Color("#d8ad55"), "text": Color("#efe6d6"), "dim": Color("#a7a2c0"),
		"accent": Color("#f4c56e"), "glow": Color("#f4c56e"), "well": Color("#0f0f1c"), "alpha": 0.9},
	"H2": {"outline": Color("#20150d"), "rim": Color("#6a4a30"), "hi": Color("#9a7048"), "lo": Color("#3e2a1a"), "fill": Color("#4e3c2b"),
		"fill_hi": Color("#64503a"), "stud": Color("#c49a58"), "cap": Color("#8a6238"), "text": Color("#f3e6cc"), "dim": Color("#c9b493"),
		"accent": Color("#f0c070"), "glow": Color("#f0c070"), "well": Color("#271a11"), "alpha": 0.94},
	"H3": {"outline": Color("#101215"), "rim": Color("#5c636b"), "hi": Color("#959da6"), "lo": Color("#363b41"), "fill": Color("#262a30"),
		"fill_hi": Color("#323840"), "stud": Color("#6fe3cf"), "cap": Color("#7c858e"), "text": Color("#e8eef0"), "dim": Color("#9fb0b4"),
		"accent": Color("#8af0dc"), "glow": Color("#6fe3cf"), "well": Color("#121519"), "alpha": 0.9},
}
const PLAYER_COL := [Color("#f4c56e"), Color("#7ab8f0"), Color("#e38c7c"), Color("#a8d69a")]
const QUICK_CHAT := ["Buraya gel!", "Can lazım", "Sandık burada", "Bekleyin", "Gidelim", "Sağ ol"]
const CHAT_LOG := [[1, "sandık bende, gelin"], [2, "can az, Melek iyileştir"], [3, "boss saati 1 dk"], [0, "geliyorum"]]

var H: Dictionary = {}
var hv: String = "H1"
var _ring_cache: Dictionary = {}


## Sanat pikseli ızgarasında çerçeve levha (px = 3 ekran px).
class Plate extends Control:
	var pal: Dictionary = {}
	var px: float = 3.0
	var caps: bool = false
	var grain: bool = false
	var studs: String = "rivet"
	var strip := Color(0, 0, 0, 0)
	var alpha: float = 1.0
	var cracks: bool = false

	func _c(n: String) -> Color:
		return Color(pal[n], alpha if n != "stud" else 1.0)

	func _cham(r: Rect2, c: Color) -> void:
		draw_rect(Rect2(r.position.x + px, r.position.y, r.size.x - 2 * px, r.size.y), c)
		draw_rect(Rect2(r.position.x, r.position.y + px, r.size.x, r.size.y - 2 * px), c)

	func _stud(pos: Vector2) -> void:
		if studs == "rivet":
			draw_rect(Rect2(pos, Vector2(2 * px, 2 * px)), pal["stud"])
			draw_rect(Rect2(pos, Vector2(px, px)), Color(pal["stud"]).lightened(0.45))
			draw_rect(Rect2(pos + Vector2(px, px), Vector2(px, px)), Color(pal["stud"]).darkened(0.45))
		elif studs == "rune":
			var g: Color = pal["stud"]
			draw_rect(Rect2(pos + Vector2(px, 0), Vector2(px, 3 * px)), g)
			draw_rect(Rect2(pos + Vector2(0, px), Vector2(3 * px, px)), g)
			draw_rect(Rect2(pos - Vector2(px, px), Vector2(5 * px, 5 * px)), Color(g, 0.18))

	func _draw() -> void:
		var R := Rect2(Vector2.ZERO, size)
		_cham(R, _c("outline"))
		var rim: Rect2 = R.grow(-px)
		_cham(rim, _c("rim"))
		draw_rect(Rect2(rim.position.x + px, rim.position.y, rim.size.x - 2 * px, px), _c("hi"))
		draw_rect(Rect2(rim.position.x, rim.position.y + px, px, rim.size.y - 2 * px), _c("hi"))
		draw_rect(Rect2(rim.position.x + px, rim.end.y - px, rim.size.x - 2 * px, px), _c("lo"))
		draw_rect(Rect2(rim.end.x - px, rim.position.y + px, px, rim.size.y - 2 * px), _c("lo"))
		var inner: Rect2 = rim.grow(-2 * px)
		_cham(inner, _c("outline"))
		var fill: Rect2 = inner.grow(-px)
		draw_rect(fill, _c("fill"))
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, px)), _c("fill_hi"))
		if grain:
			var rows: int = int(fill.size.y / (5 * px))
			for i in rows:
				var y: float = fill.position.y + (i * 5 + 3) * px
				var sd: int = (i * 7919 + int(size.x)) % 97
				var x: float = fill.position.x + float((sd * 3) % 11) * px * 2
				while x < fill.end.x - 6 * px:
					var ln: float = float(6 + (sd % 9)) * px
					draw_rect(Rect2(x, y, minf(ln, fill.end.x - x - px), px), Color(Color(pal["fill"]).darkened(0.38), alpha))
					draw_rect(Rect2(x + px * 2, y + px, minf(ln * 0.5, fill.end.x - x - 3 * px), px), Color(Color(pal["fill"]).lightened(0.12), alpha))
					x += ln + float(4 + (sd % 7)) * px * 2
					sd = (sd * 31 + 7) % 97
		if cracks:
			var cx: float = fill.position.x + fill.size.x * 0.72
			var cy: float = fill.position.y + 2 * px
			for k in 5:
				draw_rect(Rect2(cx + k * px * (1 if k % 2 == 0 else 0), cy + k * px, px, px), Color(Color(pal["fill"]).darkened(0.35), alpha))
		if strip.a > 0.0:
			draw_rect(Rect2(fill.position, Vector2(2 * px, fill.size.y)), strip)
		if studs != "" and fill.size.y >= 8 * px:
			_stud(fill.position + Vector2(px, 2 * px))
			_stud(Vector2(fill.end.x - 3 * px, fill.position.y + 2 * px))
			_stud(Vector2(fill.position.x + px, fill.end.y - 3 * px))
			_stud(Vector2(fill.end.x - 3 * px, fill.end.y - 3 * px))
		if caps:
			var cp: Color = pal["cap"]
			for corner in 4:
				var ox: float = 0.0 if corner % 2 == 0 else size.x - 6 * px
				var oy: float = 0.0 if corner < 2 else size.y - 6 * px
				var hx: float = 0.0 if corner % 2 == 0 else 4 * px
				var vy: float = 0.0 if corner < 2 else 4 * px
				draw_rect(Rect2(ox, oy + vy, 6 * px, 2 * px), Color("#0c0a08"))
				draw_rect(Rect2(ox + hx, oy, 2 * px, 6 * px), Color("#0c0a08"))
				draw_rect(Rect2(ox + px, oy + vy + px * 0.0, 5 * px - px, px * 1.0), cp.lightened(0.35))
				draw_rect(Rect2(ox + hx + (px if corner % 2 == 0 else 0.0), oy + px, px, 4 * px), cp)


func _hp_plate(p: Control, r: Rect2, opts: Dictionary = {}) -> Plate:
	var pl := Plate.new()
	pl.pal = H
	pl.px = float(opts.get("px", 3.0))
	pl.caps = bool(opts.get("caps", hv == "H1"))
	pl.grain = hv == "H2"
	pl.cracks = hv == "H3"
	pl.studs = str(opts.get("studs", "rune" if hv == "H3" else "rivet"))
	pl.strip = opts.get("strip", Color(0, 0, 0, 0))
	pl.alpha = float(opts.get("alpha", H["alpha"]))
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pl)
	pl.position = r.position.round()
	pl.size = r.size.round()
	return pl


## Piksel halka dokusu: yarıçap ra (sanat pikseli), bant b; ışık sol üstten. Ekranda x3.
func _ring_tex(ra: int, b: int, fill: Color = Color(0, 0, 0, 0)) -> Texture2D:
	var key: String = "%s_%d_%d_%s" % [hv, ra, b, fill.to_html()]
	if _ring_cache.has(key):
		return _ring_cache[key]
	var n: int = ra * 2 + 2
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n * 0.5, n * 0.5)
	var light := Vector2(-0.707, -0.707)
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5, y + 0.5) - c
			var d: float = v.length()
			if d > ra + 0.5:
				continue
			var inner: float = float(ra - b)
			if d < inner - 0.5:
				if fill.a > 0.0:
					img.set_pixel(x, y, fill)
				continue
			var colr: Color
			if d > ra - 0.5 or d < inner + 0.5:
				colr = H["outline"]
			else:
				var lit: float = v.normalized().dot(light)
				colr = H["hi"] if lit > 0.5 else (H["lo"] if lit < -0.5 else H["rim"])
			img.set_pixel(x, y, colr)
	var t := ImageTexture.create_from_image(img)
	_ring_cache[key] = t
	return t


func _ring(p: Control, center: Vector2, ra: int, b: int, fill: Color = Color(0, 0, 0, 0), mod: Color = Color.WHITE) -> void:
	var n: float = (ra * 2 + 2) * 3.0
	_img(p, _ring_tex(ra, b, fill), Rect2((center - Vector2(n, n) * 0.5).round(), Vector2(n, n)), true, mod)


## Halka içindeki içerik yarıçapı (ekran px).
func _ring_in(ra: int, b: int) -> float:
	return (ra - b) * 3.0 + 1.0


func _h_text(p: Control, s: String, r: Rect2, fs: int, c: Color, al: int = 0) -> Label:
	return _t(p, s, r, fs, c, al, true)


## Yüz madalyonu: piksel halka + portrenin baş kısmı.
func _h_face(p: Control, cid: int, center: Vector2, ra: int, ring_col: Color = Color(0, 0, 0, 0)) -> void:
	_disk(p, center, _ring_in(ra, 3), H["well"])
	_ctex(p, _ptex(cid), center, _ring_in(ra, 3), Rect2(12, 4, 24, 24), Color.WHITE, true)
	_ring(p, center, ra, 3)
	if ring_col.a > 0.0:
		_disk(p, center, ra * 3.0 + 4, Color(0, 0, 0, 0), ring_col, 4)


func _h_bar(p: Control, r: Rect2, frac: float, fill: Color, num: String = "") -> void:
	_box(p, r, H["well"], H["outline"], 3)
	var f: float = clampf(frac, 0.0, 1.0)
	if f > 0.0:
		var inner := Rect2(r.position + Vector2(3, 3), Vector2((r.size.x - 6) * f, r.size.y - 6))
		_rect(p, inner, fill)
		_rect(p, Rect2(inner.position, Vector2(inner.size.x, 3)), fill.lightened(0.35))
		if inner.size.y > 12:
			_rect(p, Rect2(inner.position.x, inner.end.y - 3, inner.size.x, 3), fill.darkened(0.3))
	for i in range(1, 10):
		_rect(p, Rect2(r.position.x + r.size.x * i / 10.0, r.position.y + 3, 2, r.size.y * 0.35), Color(0, 0, 0, 0.25))
	if num != "":
		_t(p, num, Rect2(r.position.x, r.position.y - 2, r.size.x, r.size.y), 32, Color.WHITE, 1)


func _h_round_btn(p: Control, center: Vector2, ra: int, ic: Variant, active: bool = false, badge: String = "") -> void:
	_ring(p, center, ra, 3, H["fill"])
	if active:
		_disk(p, center, ra * 3.0 + 5, Color(0, 0, 0, 0), H["accent"], 4)
	_icon(p, ic, center, ra * 1.5, H["accent"] if active else H["text"])
	if badge != "":
		var bc := center + Vector2(ra * 2.2, -ra * 2.2)
		_disk(p, bc, 26, Color("#c8382c"), Color("#2a0a08"), 3)
		_t(p, badge, Rect2(bc - Vector2(26, 26), Vector2(52, 52)), 32, Color.WHITE, 1)


func _h_skill(p: Control, center: Vector2, ra: int, icon_path: String, ring_mod: Color = Color.WHITE, cd: float = 0.0, cd_txt: String = "",
		glow: bool = false) -> void:
	if glow:
		_disk(p, center, ra * 3.0 + 14, Color(H["glow"], 0.16))
		_disk(p, center, ra * 3.0 + 8, Color(H["glow"], 0.22))
	_ctex(p, _stex(icon_path), center, _ring_in(ra, 4))
	_ring(p, center, ra, 4, Color(0, 0, 0, 0), ring_mod)
	if cd > 0.0:
		var d := _disk(p, center, _ring_in(ra, 4), Color(0, 0, 0, 0))
		d.sweep = cd
		d.queue_redraw()
		_t(p, cd_txt, Rect2(center - Vector2(ra * 3, 40), Vector2(ra * 6, 80)), 64, Color.WHITE, 1)


## Minimap: harita bölgesi + kenar karartma + işaretler + yöne göre süs.
func _h_minimap(p: Control, center: Vector2, ra: int) -> void:
	var b: int = 4
	var rin: float = _ring_in(ra, b)
	_disk(p, center, rin, Color("#1b2a18"))
	_ctex(p, minimap_tex, center, rin, Rect2(60, 74, 64, 64), Color(1.05, 1.05, 1.0), true)
	for i in 4:
		_disk(p, center, rin - i * 6, Color(0, 0, 0, 0), Color(0, 0, 0, 0.16), 6)
	## işaretler: satıcı (altın), sandık (mor), arkadaşlar, görüş dışı boss oku
	_disk(p, center + Vector2(64, -38), 13, Color("#f4c56e"), Color("#3a2408"), 4)
	_money_icon(p, "coin", Rect2(center + Vector2(64, -38) - Vector2(8, 8), Vector2(16, 16)))
	_box(p, Rect2(center + Vector2(-82, 40), Vector2(24, 18)), Color("#b98af2"), Color("#1c0f2a"), 3)
	for k in range(1, 4):
		var off: Vector2 = [Vector2(-44, -30), Vector2(26, 58), Vector2(-20, 74)][k - 1]
		_disk(p, center + off, 10, PLAYER_COL[k], Color("#0c0c10"), 3)
	var arrow := PackedVector2Array([Vector2(0, -16), Vector2(12, 12), Vector2(0, 5), Vector2(-12, 12)])
	var pc := Polygon2D.new()
	pc.polygon = arrow
	pc.color = Color.WHITE
	pc.position = center
	pc.rotation = 0.6
	p.add_child(pc)
	var pc2 := Polygon2D.new()
	pc2.polygon = arrow
	pc2.color = Color("#0c0c10")
	pc2.position = center + Vector2(2, 3)
	pc2.rotation = 0.6
	p.add_child(pc2)
	p.move_child(pc2, pc.get_index())
	_ring(p, center, ra, b)
	## görüş dışı boss: halkanın üstünde kuru kafa pimi
	var bang: float = deg_to_rad(-112.0)
	var bp: Vector2 = center + Vector2.from_angle(bang) * (ra * 3.0 + 2)
	_disk(p, bp, 22, Color("#5a1410"), Color("#e06a52"), 4)
	_glyph(p, G_SKULL, bp, 3, Color("#f3d2c8"))
	match hv:
		"H1":
			for i in 16:
				var a: float = TAU * i / 16.0 - PI * 0.5
				var tp: Vector2 = center + Vector2.from_angle(a) * (ra - b * 0.5) * 3.0
				var big: bool = i % 4 == 0
				_rect(p, Rect2((tp - Vector2(3, 3)).round(), Vector2(6, 6) if big else Vector2(3, 3)), Color("#2a1c08") if big else Color("#6e4f20"))
			var letters: Array = [["K", -PI * 0.5], ["D", 0.0], ["G", PI * 0.5], ["B", PI]]
			for l: Array in letters:
				var lp: Vector2 = center + Vector2.from_angle(float(l[1])) * (ra * 3.0 + 4)
				_disk(p, lp, 24, Color("#20203a"), Color("#e2b85c"), 4)
				_t(p, l[0], Rect2(lp - Vector2(24, 26), Vector2(48, 48)), 32, Color("#f4c56e"), 1)
		"H2":
			for a2: float in [-PI * 0.75, -PI * 0.25, PI * 0.25, PI * 0.75]:
				var lp2: Vector2 = center + Vector2.from_angle(a2) * (ra * 3.0 + 2)
				_disk(p, lp2, 20, Color("#20150d"))
				for q: Array in [[Vector2(-15, -9), Color("#4f8a3a")], [Vector2(3, -15), Color("#6aa84a")], [Vector2(-6, 3), Color("#3c6e2c")], [Vector2(-6, -6), Color("#8cc860")], [Vector2(6, 0), Color("#4f8a3a")]]:
					_rect(p, Rect2((lp2 + (q[0] as Vector2)).round(), Vector2(12, 12)), q[1])
				_rect(p, Rect2((lp2 + Vector2(-3, -3)).round(), Vector2(6, 6)), Color("#e0c050"))
			_t(p, "K", Rect2(center + Vector2(-24, -ra * 3.0 - 50), Vector2(48, 44)), 32, Color("#f0c070"), 1)
		"H3":
			for i in 8:
				var a3: float = TAU * i / 8.0 - PI * 0.5
				var rp: Vector2 = center + Vector2.from_angle(a3) * (ra - b * 0.5) * 3.0
				_rect(p, Rect2((rp - Vector2(7, 7)).round(), Vector2(15, 15)), Color(0.43, 0.89, 0.81, 0.22))
				_rect(p, Rect2((rp - Vector2(1.5, 6)).round(), Vector2(3, 12)), Color("#8af0dc"))
				_rect(p, Rect2((rp - Vector2(6, 1.5)).round(), Vector2(12, 3)), Color("#8af0dc") if i % 2 == 0 else Color(0, 0, 0, 0))
			_t(p, "K", Rect2(center + Vector2(-24, -ra * 3.0 - 50), Vector2(48, 44)), 32, Color("#8af0dc"), 1)


## Kademe + saat levhası (minimapin altında): H1 kurdele, H2 zincirli tabela, H3 taş tablet.
func _h_tier_plate(p: Control, center_x: float, y: float) -> void:
	var r := Rect2(center_x - 170, y, 340, 84)
	match hv:
		"H2":
			for cx: float in [r.position.x + 60, r.end.x - 60]:
				for k in 3:
					_box(p, Rect2(cx - 6, y - 30 + k * 10, 12, 12), Color(0, 0, 0, 0), Color("#8f8a80"), 3)
	_hp_plate(p, r, {"caps": hv == "H1"})
	_t(p, "VII  ·  18:42", Rect2(r.position.x, r.position.y + 6, r.size.x, 56), 48, H["accent"], 1)
	_t(p, "1.204 öldürme", Rect2(r.position.x, r.end.y + 4, r.size.x, 40), 32, H["dim"], 1)


func _render_hud(v: String, st: String) -> void:
	hv = v
	H = HUD_SKINS[v]
	cur = "B"
	S = SKINS["B"]
	var l := CanvasLayer.new()
	l.layer = 96
	root.add_child(l)
	var rc := _ctl_root(l)
	if game_tex:
		_img(rc, game_tex, Rect2(0, 0, SW, SH), true)
	_hud_v2(rc, st == "acik")
	await _wait(0.5)
	shots["hud_%s_%s" % [v, st]] = await _shot("hud_%s_%s" % [v, st])
	l.queue_free()
	await process_frame


func _hud_v2(rc: Control, open: bool) -> void:
	_fade(rc, Rect2(0, 0, SW, 150), Color(0, 0, 0), 0, 0.3, 5)
	## --- oyuncu levhası (sol üst)
	var pr := Rect2(SX - 12, SY - 8, 660, 186)
	_hp_plate(rc, pr)
	var fc := Vector2(pr.position.x + 92, pr.position.y + 93)
	_h_face(rc, ME, fc, 24)
	_disk(rc, fc + Vector2(-52, 52), 32, H["well"], H["accent"], 4)
	_t(rc, str(LEVEL), Rect2(fc + Vector2(-84, 22), Vector2(64, 60)), 48, H["accent"], 1)
	var x0: float = pr.position.x + 184
	_t(rc, "Sen", Rect2(x0, pr.position.y + 18, 200, 52), 48, H["text"])
	_hearts(rc, Vector2(x0 + 112, pr.position.y + 30), 2, 4)
	_money_icon(rc, "coin", Rect2(pr.end.x - 200, pr.position.y + 26, 32, 32))
	_t(rc, _num(GOLD), Rect2(pr.end.x - 160, pr.position.y + 18, 140, 48), 48, Color("#f6d27e"))
	var t0: Dictionary = TEAM[0]
	_h_bar(rc, Rect2(x0, pr.position.y + 74, pr.end.x - x0 - 26, 20), float(t0["sh"]) / float(t0["msh"]), SH_COL)
	_h_bar(rc, Rect2(x0, pr.position.y + 98, pr.end.x - x0 - 26, 46), float(t0["hp"]) / float(t0["mhp"]), HP_COL, "%d / %d" % [int(t0["hp"]), int(t0["mhp"])])
	_h_bar(rc, Rect2(x0, pr.position.y + 148, pr.end.x - x0 - 26, 14), 0.62, XP_COL)
	## --- sohbet düğmesi (levhanın sağında)
	var chat_c := Vector2(pr.end.x + 88, SY + 66)
	_h_round_btn(rc, chat_c, 20, G_CHAT, open, "" if open else "2")
	_t(rc, "SOHBET", Rect2(chat_c.x - 80, chat_c.y + 64, 160, 40), 32, H["dim"], 1)
	## --- grup paneli (açılır/kapanır, levhanın altında)
	var gy: float = pr.end.y + 18
	if open:
		var cw: float = 560.0
		for i in range(1, TEAM.size()):
			var t: Dictionary = TEAM[i]
			var low: bool = float(t["hp"]) / float(t["mhp"]) < 0.3
			var cr := Rect2(SX - 12, gy + (i - 1) * 124, cw, 112)
			_hp_plate(rc, cr, {"strip": PLAYER_COL[i], "caps": false, "studs": ""})
			if low:
				_box(rc, cr.grow(4), Color(0, 0, 0, 0), Color("#e0503c"), 4)
			_h_face(rc, int(t["char"]), Vector2(cr.position.x + 70, cr.get_center().y), 16)
			_t(rc, str(t["name"]), Rect2(cr.position.x + 136, cr.position.y + 12, 240, 44), 32, H["text"])
			_t(rc, "Sv %d" % int(t["lv"]), Rect2(cr.end.x - 150, cr.position.y + 12, 120, 44), 32, H["dim"], 2)
			if low:
				_t(rc, "CAN AZ!", Rect2(cr.position.x + 300, cr.position.y + 12, 160, 44), 32, Color("#ff8a70"))
			_h_bar(rc, Rect2(cr.position.x + 136, cr.position.y + 58, cw - 166, 14), float(t["sh"]) / float(t["msh"]), SH_COL)
			_h_bar(rc, Rect2(cr.position.x + 136, cr.position.y + 74, cw - 166, 24), float(t["hp"]) / float(t["mhp"]), HP_COL)
		var tab := Rect2(SX - 12 + cw + 8, gy, 84, 3 * 124 - 12)
		_hp_plate(rc, tab, {"studs": "", "caps": false})
		_glyph(rc, G_CHEV_L, tab.get_center() + Vector2(0, -40), 5, H["accent"])
		_t(rc, "GRUP", Rect2(tab.position.x, tab.get_center().y, 84, 40), 32, H["dim"], 1)
	else:
		var tab2 := Rect2(SX - 12, gy, 132, 3 * 108 + 60)
		_hp_plate(rc, tab2, {"studs": "", "caps": false})
		for i in range(1, TEAM.size()):
			var t2: Dictionary = TEAM[i]
			var c2 := Vector2(tab2.get_center().x, gy + 60 + (i - 1) * 108)
			_h_face(rc, int(t2["char"]), c2, 14)
			var d := _disk(rc, c2, 14 * 3.0 + 10, Color(0, 0, 0, 0), Color(0.1, 0.05, 0.05, 0.7), 6)
			d.arc_frac = float(t2["hp"]) / float(t2["mhp"])
			d.arc_col = HP_COL
			d.queue_redraw()
		_glyph(rc, G_CHEV_R, Vector2(tab2.get_center().x, tab2.end.y - 34), 4, H["accent"])
	## --- sohbet paneli (açıkken)
	if open:
		var cp := Rect2(pr.end.x + 24, SY + 180, 860, 500)
		_hp_plate(rc, cp, {"caps": hv == "H1"})
		_t(rc, "SOHBET", Rect2(cp.position.x + 32, cp.position.y + 20, 400, 56), 48, H["accent"])
		_h_round_btn(rc, Vector2(cp.end.x - 60, cp.position.y + 52), 13, G_X)
		var ly: float = cp.position.y + 84
		_box(rc, Rect2(cp.position.x + 24, ly, cp.size.x - 48, 196), H["well"], H["outline"], 3)
		for m: Array in CHAT_LOG:
			var who: Dictionary = TEAM[int(m[0])]
			var nm: String = str(who["name"]) + ":"
			_t(rc, nm, Rect2(cp.position.x + 44, ly + 8, 200, 44), 32, PLAYER_COL[int(m[0])])
			_t(rc, str(m[1]), Rect2(cp.position.x + 44 + _tw_of(nm, 32) + 14, ly + 8, 600, 44), 32, H["text"])
			ly += 46
		var qy: float = cp.position.y + 296
		var qw: float = (cp.size.x - 48 - 2 * 12) / 3.0
		for i in QUICK_CHAT.size():
			@warning_ignore("integer_division")
			var qr := Rect2(cp.position.x + 24 + (i % 3) * (qw + 12), qy + (i / 3) * 76, qw, 66)
			_hp_plate(rc, qr, {"px": 2.0, "studs": "", "caps": false})
			_t(rc, QUICK_CHAT[i], Rect2(qr.position.x, qr.position.y - 2, qr.size.x, qr.size.y), 32, H["text"], 1)
		var ir := Rect2(cp.position.x + 24, cp.end.y - 50, cp.size.x - 48 - 150, 0)
		ir = Rect2(cp.position.x + 24, qy + 160, cp.size.x - 48 - 150, 60)
		_box(rc, ir, H["well"], H["outline"], 3)
		_glyph(rc, G_KEY, Vector2(ir.position.x + 40, ir.get_center().y), 4, H["dim"])
		_t(rc, "Mesaj yaz...", Rect2(ir.position.x + 80, ir.position.y, 400, ir.size.y), 32, Color(H["dim"], 0.7))
		_hp_plate(rc, Rect2(ir.end.x + 12, ir.position.y, 138, ir.size.y), {"px": 2.0, "studs": "", "caps": false})
		_t(rc, "GÖNDER", Rect2(ir.end.x + 12, ir.position.y - 2, 138, ir.size.y), 32, H["accent"], 1)
	## --- minimap + kademe levhası + duraklat/çanta (sağ üst)
	var mc := Vector2(RX - 156, SY + 152)
	_h_minimap(rc, mc, 46)
	_h_tier_plate(rc, mc.x, mc.y + 46 * 3 + 40)
	_h_round_btn(rc, Vector2(mc.x - 46 * 3 - 120, SY + 64), 18, G_PAUSE)
	_h_round_btn(rc, Vector2(mc.x - 46 * 3 - 120, SY + 196), 18, G_BAG)
	## --- joystick
	var jc := Vector2(380, 860)
	_ring(rc, jc, 52, 3, Color(0, 0, 0, 0), Color(1, 1, 1, 0.55))
	_disk(rc, jc, 52 * 3.0 - 9, Color(H["fill"], 0.22))
	_ring(rc, jc + Vector2(40, -28), 22, 3, Color(H["fill"], 0.8), Color(1, 1, 1, 0.85))
	## --- yetenekler (yay)
	var sk: Array = _skills(ME)
	_h_skill(rc, Vector2(2146, 876), 36, sk[3][2], Color.WHITE, 0.0, "", true)
	_h_skill(rc, Vector2(1904, 968), 26, sk[1][2])
	_h_skill(rc, Vector2(1936, 752), 26, sk[2][2], Color.WHITE, 0.55, "4")
	_h_skill(rc, Vector2(2120, 634), 22, str(_spirit(SPIRIT).get("icon", "")), Color(0.82, 0.68, 1.0))
	## --- silahlar + etkileşim
	var wr := Rect2(SW * 0.5 - 192, 948, 384, 108)
	_hp_plate(rc, wr, {"studs": "", "caps": false})
	for i in WEAPONS.size():
		var sr := Rect2(wr.position.x + 24 + i * 116, wr.position.y + 15, 104, 78)
		var ec: Color = ENCH_COL[int(WEAPONS[i][1])]
		_box(rc, sr, H["well"], ec if ec.a > 0 else H["outline"], 3)
		_img(rc, _wtex(str(WEAPONS[i][0]), int(WEAPONS[i][1])), Rect2(sr.get_center() - Vector2(36, 36), Vector2(72, 72)))
	var ip := Rect2(SW * 0.5 - 190, 820, 380, 100)
	_hp_plate(rc, ip, {"studs": "", "caps": hv == "H1"})
	_glyph(rc, G_HAND, Vector2(ip.position.x + 70, ip.get_center().y), 6, H["accent"])
	_t(rc, "SATICI", Rect2(ip.position.x + 124, ip.position.y, 240, ip.size.y), 64, H["text"])


func _sheets_hud() -> void:
	var l := CanvasLayer.new()
	l.layer = 97
	root.add_child(l)
	var rc := _ctl_root(l)
	_rect(rc, Rect2(0, 0, SW, SH), Color("#141210"))
	_t(rc, "OYUN İÇİ ARAYÜZ v2  ·  üst: grup + sohbet AÇIK  ·  alt: KAPALI", Rect2(40, 10, 2300, 64), 48, Color("#f4c56e"))
	for i in HUD_VARIANTS.size():
		for j in 2:
			var key: String = "hud_%s_%s" % [HUD_VARIANTS[i], ["acik", "kapali"][j]]
			if not shots.has(key):
				continue
			var r := Rect2(30 + i * 790, 120 + j * 470, 760, 342)
			_img(rc, _thumb(shots[key], 760, 342), r, true)
			if j == 0:
				_t(rc, HUD_NAMES[HUD_VARIANTS[i]], Rect2(r.position.x, r.position.y - 46, 760, 44), 32, Color("#efe2c6"))
	await _wait(0.3)
	await _shot("hud_karsi")
	l.queue_free()


## ====================================================================================== ML HUD (MOBIL_ONLY=ML)
## Kullanıcı (2026-10-18): "hepsi rezalet. mobile legends arayüzünden ilham alarak oyun içi arayüzünü baştan tasarla."
## MLBB düzeni oyunumuza eşlendi: sol üst KARE minimap (kahraman yüzleri haritada, kamera çerçevesi, satıcı/sandık/boss işaretleri)
## + yanında işaret sütunu (Saldır / Geri çekil / Toplan) + sohbet; altında açılıp kapanan TAKIM listesi (MLBB rengi: müttefik mavi,
## yerdeki arkadaş gri yüz + diriltme sayacı); üst orta skor tablosu (kademe arması, süre, öldürme; mavi kanat = ayaktaki takım,
## kırmızı kanat = boss saati) + kademe ilerleme çizgisi; sağ üst kişisel/ping/ayar + silahlar; can (yeşil) + MANA KALKANI (mavi,
## MLBB'nin manası = yeteneklerin bedeli) kahramanın BAŞININ ÜSTÜNDE; sağ altta MLBB yayı: köşede büyük Q (en sık), solunda E,
## sol üstte ULTİ R (altın parıltı), en solda ruhani F (MLBB büyü yeri), üstte bağlamsal ETKİLEŞİM; sol ortada çanta + altın
## (MLBB dükkan düğmesi); MLBB "First Blood" şeridi gibi duyuru kurdelesi. Pürüzsüz çizim + Nunito; ikon/portre = oyunun sanatı.
const ML := {
	"panel": Color(0.03, 0.06, 0.12, 0.62), "deep": Color(0.02, 0.04, 0.09, 0.84), "border": Color(0.5, 0.66, 0.9, 0.55),
	"gold": Color("#f2c35b"), "gold_hi": Color("#ffe39a"), "gold_lo": Color("#9a6a1c"), "ally": Color("#3aa6ff"),
	"self": Color("#46e070"), "red": Color("#ff5148"), "mana": Color("#3d8bff"), "mana_ally": Color("#8fe8ff"),
	"text": Color("#ffffff"), "dim": Color("#b9c7dc"), "purple": Color("#b07cff"), "orange": Color("#ff9a3c"),
}
## Hızlı sohbet hazır mesajları (oyuna özgü; MOBA kopyası saldır/geri çekil yok).
const ML_QUICK := ["Buraya gelin!", "Can lazım!", "Sandık burada!", "Elit burada!", "Bekleyin!", "Sağ olun!"]
var mlfont: Font


## Komut listesiyle pürüzsüz (kenar yumuşatmalı) çizim tuvali.
class MLDraw extends Control:
	var cmds: Array = []

	func _draw() -> void:
		for c: Array in cmds:
			var kind: String = str(c[0])
			if kind == "circle":
				draw_circle(c[1], c[2], c[3], true, -1.0, true)
			elif kind == "ring":
				draw_arc(c[1], c[2], 0.0, TAU, 128, c[3], c[4], true)
			elif kind == "arc":
				draw_arc(c[1], c[2], c[3], c[4], 64, c[5], c[6], true)
			elif kind == "poly":
				draw_colored_polygon(c[1], c[2])
			elif kind == "line":
				draw_line(c[1], c[2], c[3], c[4], true)
			elif kind == "pline":
				draw_polyline(c[1], c[2], c[3], true)
			elif kind == "rect":
				draw_rect(c[1], c[2])
			elif kind == "texcircle":
				var tex: Texture2D = c[3]
				if tex != null:
					var center: Vector2 = c[1]
					var r: float = c[2]
					var reg: Rect2 = c[4]
					var ts: Vector2 = tex.get_size()
					if reg.size.x <= 0.0:
						reg = Rect2(Vector2.ZERO, ts)
					var pts := PackedVector2Array()
					var uvs := PackedVector2Array()
					for i in 96:
						var d: Vector2 = Vector2.from_angle(TAU * float(i) / 96.0)
						pts.append(center + d * r)
						uvs.append((reg.position + reg.size * (Vector2(0.5, 0.5) + d * 0.5)) / ts)
					draw_colored_polygon(pts, c[5], uvs, tex)
			elif kind == "tex":
				draw_texture_rect(c[2], c[1], false, c[3])
			elif kind == "ncircle":
				draw_circle(c[1], c[2], c[3], true, -1.0, false)
			elif kind == "nring":
				draw_arc(c[1], c[2], 0.0, TAU, 96, c[3], c[4], false)
			elif kind == "pix":
				c[1].call("draw_shape", self, c[2], c[3], c[4], c[5])
			elif kind == "ohbar":
				c[1].call("draw_pixel_bar", self, c[2], c[3], c[4], c[5])
			elif kind == "ohseg":
				var rr: Rect2 = Rect2((c[2] as Rect2).position.round(), (c[2] as Rect2).size.round())
				var lines: int = int(c[1].call("_segment_line_count", float(c[3])))
				for off: float in c[1].call("_segment_line_offsets", rr.size.x, lines):
					draw_rect(Rect2(rr.position.x + off, rr.position.y, 1.0, rr.size.y), Color(0, 0, 0, 0.7))


func _cv(p: Control, nearest: bool = false) -> MLDraw:
	var d := MLDraw.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if nearest else CanvasItem.TEXTURE_FILTER_LINEAR
	p.add_child(d)
	d.position = Vector2.ZERO
	d.size = Vector2(SW, SH)
	return d


func _mlt(p: Control, s: String, r: Rect2, fs: int, c: Color, al: int = 0, ol: int = 6) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", mlfont)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.82))
	l.add_theme_constant_override("outline_size", ol)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = al
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	l.position = r.position
	l.size = r.size
	return l


func _mlbox(p: Control, r: Rect2, fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, rad: int = 14, skew: float = 0.0,
		shadow: int = 0, top_flat: bool = false, left_flat: bool = false) -> Panel:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(rad)
	if top_flat:
		sb.corner_radius_top_left = 0
		sb.corner_radius_top_right = 0
		sb.border_width_top = 0
	if left_flat:
		sb.corner_radius_top_left = 0
		sb.corner_radius_bottom_left = 0
		sb.border_width_left = 0
	sb.anti_aliasing = true
	sb.corner_detail = 12
	sb.skew = Vector2(skew, 0)
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_offset = Vector2(0, 3)
	var pn := Panel.new()
	pn.add_theme_stylebox_override("panel", sb)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(pn)
	pn.position = r.position
	pn.size = r.size
	return pn


func _P(pts: Array, c: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(c + v * s)
	return out


func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 32) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## Vektör ikonlar (MLBB işaret/arayüz simgeleri gibi düz, dolgun).
func _ml_icon(cv: MLDraw, kind: String, c: Vector2, s: float, col: Color) -> void:
	var dark := Color(0.03, 0.05, 0.1, 0.95)
	match kind:
		"sword":
			cv.cmds.append(["line", c + Vector2(-0.14, 0.14) * s, c + Vector2(0.38, -0.38) * s, col, 0.13 * s])
			cv.cmds.append(["poly", _P([Vector2(0.30, -0.42), Vector2(0.44, -0.44), Vector2(0.42, -0.30)], c, s), col])
			cv.cmds.append(["line", c + Vector2(-0.32, 0.0) * s, c + Vector2(0.0, 0.32) * s, col.lightened(0.15), 0.1 * s])
			cv.cmds.append(["line", c + Vector2(-0.18, 0.18) * s, c + Vector2(-0.36, 0.36) * s, col.darkened(0.25), 0.11 * s])
			cv.cmds.append(["circle", c + Vector2(-0.40, 0.40) * s, 0.07 * s, col])
		"shield":
			cv.cmds.append(["poly", _P([Vector2(-0.36, -0.42), Vector2(0.36, -0.42), Vector2(0.36, 0.02), Vector2(0.0, 0.46), Vector2(-0.36, 0.02)], c, s), col])
			cv.cmds.append(["poly", _P([Vector2(0.0, -0.34), Vector2(0.27, -0.34), Vector2(0.27, 0.0), Vector2(0.0, 0.34)], c, s), col.darkened(0.25)])
		"flag":
			cv.cmds.append(["line", c + Vector2(-0.30, 0.46) * s, c + Vector2(-0.30, -0.44) * s, col.lightened(0.3), 0.08 * s])
			cv.cmds.append(["poly", _P([Vector2(-0.27, -0.44), Vector2(0.05, -0.36), Vector2(0.40, -0.44), Vector2(0.40, -0.04), Vector2(0.05, 0.04), Vector2(-0.27, -0.04)], c, s), col])
		"chat":
			cv.cmds.append(["poly", _ellipse_pts(c + Vector2(0, -0.06) * s, 0.44 * s, 0.33 * s), col])
			cv.cmds.append(["poly", _P([Vector2(-0.20, 0.16), Vector2(-0.32, 0.44), Vector2(0.04, 0.22)], c, s), col])
			for dx: float in [-0.19, 0.0, 0.19]:
				cv.cmds.append(["circle", c + Vector2(dx, -0.06) * s, 0.06 * s, dark])
		"bag":
			cv.cmds.append(["arc", c + Vector2(0, -0.16) * s, 0.2 * s, PI, TAU, col, 0.08 * s])
			cv.cmds.append(["poly", _P([Vector2(-0.36, -0.12), Vector2(0.36, -0.12), Vector2(0.44, 0.42), Vector2(-0.44, 0.42)], c, s), col])
			cv.cmds.append(["poly", _P([Vector2(-0.38, -0.12), Vector2(0.38, -0.12), Vector2(0.40, 0.02), Vector2(-0.40, 0.02)], c, s), col.darkened(0.28)])
			cv.cmds.append(["circle", c + Vector2(0, 0.06) * s, 0.07 * s, col.lightened(0.4)])
		"gear":
			for i in 8:
				var a: float = TAU * i / 8.0
				var d := Vector2.from_angle(a)
				var n := Vector2(-d.y, d.x)
				cv.cmds.append(["poly", PackedVector2Array([c + (d * 0.26 - n * 0.08) * s, c + (d * 0.46 - n * 0.07) * s, c + (d * 0.46 + n * 0.07) * s, c + (d * 0.26 + n * 0.08) * s]), col])
			cv.cmds.append(["circle", c, 0.33 * s, col])
			cv.cmds.append(["circle", c, 0.13 * s, dark])
		"skull":
			cv.cmds.append(["circle", c + Vector2(0, -0.08) * s, 0.34 * s, col])
			cv.cmds.append(["poly", _P([Vector2(-0.20, 0.12), Vector2(0.20, 0.12), Vector2(0.16, 0.40), Vector2(-0.16, 0.40)], c, s), col])
			cv.cmds.append(["circle", c + Vector2(-0.13, -0.06) * s, 0.09 * s, dark])
			cv.cmds.append(["circle", c + Vector2(0.13, -0.06) * s, 0.09 * s, dark])
			cv.cmds.append(["poly", _P([Vector2(0, 0.06), Vector2(-0.05, 0.16), Vector2(0.05, 0.16)], c, s), dark])
		"heart":
			cv.cmds.append(["circle", c + Vector2(-0.18, -0.10) * s, 0.22 * s, col])
			cv.cmds.append(["circle", c + Vector2(0.18, -0.10) * s, 0.22 * s, col])
			cv.cmds.append(["poly", _P([Vector2(-0.39, -0.02), Vector2(0.39, -0.02), Vector2(0, 0.42)], c, s), col])
		"hand":
			cv.cmds.append(["line", c + Vector2(0.02, -0.40) * s, c + Vector2(0.02, 0.02) * s, col, 0.17 * s])
			cv.cmds.append(["circle", c + Vector2(0.02, -0.40) * s, 0.085 * s, col])
			cv.cmds.append(["poly", _P([Vector2(-0.30, -0.02), Vector2(0.33, -0.02), Vector2(0.33, 0.28), Vector2(0.15, 0.45), Vector2(-0.16, 0.45), Vector2(-0.32, 0.18)], c, s), col])
			for dx2: float in [0.12, 0.24]:
				cv.cmds.append(["line", c + Vector2(dx2, -0.02) * s, c + Vector2(dx2, 0.12) * s, col.darkened(0.3), 0.03 * s])
		"keyboard":
			cv.cmds.append(["pline", _P([Vector2(-0.44, -0.24), Vector2(0.44, -0.24), Vector2(0.44, 0.26), Vector2(-0.44, 0.26), Vector2(-0.44, -0.24)], c, s), col, 0.07 * s])
			for ky in 2:
				for kx in 4:
					cv.cmds.append(["rect", Rect2(c + Vector2(-0.32 + kx * 0.18, -0.13 + ky * 0.16) * s, Vector2(0.1, 0.09) * s), col])
		"smile":
			cv.cmds.append(["ring", c, 0.38 * s, col, 0.07 * s])
			cv.cmds.append(["circle", c + Vector2(-0.13, -0.1) * s, 0.06 * s, col])
			cv.cmds.append(["circle", c + Vector2(0.13, -0.1) * s, 0.06 * s, col])
			cv.cmds.append(["arc", c + Vector2(0, 0.02) * s, 0.2 * s, 0.35, PI - 0.35, col, 0.07 * s])
		"wifi":
			for i in 3:
				cv.cmds.append(["arc", c + Vector2(0, 0.30) * s, (0.2 + i * 0.18) * s, deg_to_rad(-135), deg_to_rad(-45), col, 0.08 * s])
			cv.cmds.append(["circle", c + Vector2(0, 0.30) * s, 0.07 * s, col])
		"chev_l":
			cv.cmds.append(["pline", _P([Vector2(0.15, -0.3), Vector2(-0.15, 0), Vector2(0.15, 0.3)], c, s), col, 0.12 * s])
		"chev_r":
			cv.cmds.append(["pline", _P([Vector2(-0.15, -0.3), Vector2(0.15, 0), Vector2(-0.15, 0.3)], c, s), col, 0.12 * s])
		"x":
			cv.cmds.append(["line", c + Vector2(-0.25, -0.25) * s, c + Vector2(0.25, 0.25) * s, col, 0.1 * s])
			cv.cmds.append(["line", c + Vector2(0.25, -0.25) * s, c + Vector2(-0.25, 0.25) * s, col, 0.1 * s])
		"coin":
			cv.cmds.append(["circle", c, 0.42 * s, Color("#c98a1e")])
			cv.cmds.append(["circle", c + Vector2(-0.02, -0.02) * s, 0.38 * s, Color("#f5c542")])
			cv.cmds.append(["ring", c, 0.27 * s, Color("#d9a12c"), 0.06 * s])
			cv.cmds.append(["arc", c, 0.33 * s, deg_to_rad(200), deg_to_rad(290), Color("#fff1b8"), 0.05 * s])
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var rr: float = 0.45 if i % 2 == 0 else 0.19
				pts.append(c + Vector2.from_angle(-PI * 0.5 + PI * i / 5.0) * rr * s)
			cv.cmds.append(["poly", pts, col])
		"team":
			cv.cmds.append(["circle", c + Vector2(-0.17, -0.16) * s, 0.15 * s, col])
			cv.cmds.append(["circle", c + Vector2(0.17, -0.16) * s, 0.15 * s, col])
			cv.cmds.append(["poly", _ellipse_pts(c + Vector2(-0.17, 0.28) * s, 0.24 * s, 0.18 * s), col])
			cv.cmds.append(["poly", _ellipse_pts(c + Vector2(0.17, 0.28) * s, 0.24 * s, 0.18 * s), col])
		"chart":
			for b: Array in [[-0.30, 0.22], [-0.02, 0.48], [0.26, 0.72]]:
				var bx: float = float(b[0])
				var bh: float = float(b[1])
				cv.cmds.append(["rect", Rect2(c + Vector2(bx - 0.09, 0.40 - bh) * s, Vector2(0.18, bh) * s), col])
			cv.cmds.append(["rect", Rect2(c + Vector2(-0.44, 0.40) * s, Vector2(0.88, 0.07) * s), col])
		"expand":
			cv.cmds.append(["line", c + Vector2(-0.3, 0.3) * s, c + Vector2(0.3, -0.3) * s, col, 0.07 * s])
			cv.cmds.append(["pline", _P([Vector2(0.05, -0.32), Vector2(0.32, -0.32), Vector2(0.32, -0.05)], c, s), col, 0.07 * s])
			cv.cmds.append(["pline", _P([Vector2(-0.32, 0.05), Vector2(-0.32, 0.32), Vector2(-0.05, 0.32)], c, s), col, 0.07 * s])


## Radyal degrade daire (dıştan içe katman katman).
func _ml_rgrad(cv: MLDraw, c: Vector2, r: float, inner: Color, outer: Color, steps: int = 14) -> void:
	for i in steps:
		var t: float = float(i) / float(steps - 1)
		cv.cmds.append(["circle", c, r * (1.0 - t * 0.85), outer.lerp(inner, t)])


## MLBB yetenek düğmesi: gölge + koyu dış halka + metalik çerçeve (sol üst parlak) + ikon + iç gölge + cam parıltısı.
func _ml_skill(p: Control, c: Vector2, r: float, tex: Texture2D, rim: Color, cd: float = 0.0, cd_txt: String = "", ult: bool = false) -> void:
	var cv := _cv(p)
	if ult:
		for k in 7:
			cv.cmds.append(["circle", c, r + 36 - k * 4, Color(ML["gold"], 0.06 + k * 0.03)])
	cv.cmds.append(["circle", c + Vector2(0, 6), r + 10, Color(0, 0, 0, 0.42)])
	cv.cmds.append(["circle", c, r + 9, Color("#0a1120")])
	cv.cmds.append(["ring", c, r + 4.5, rim.darkened(0.2), 8.0])
	cv.cmds.append(["arc", c, r + 4.5, deg_to_rad(195), deg_to_rad(325), rim.lightened(0.5), 8.0])
	cv.cmds.append(["arc", c, r + 4.5, deg_to_rad(15), deg_to_rad(150), rim.darkened(0.55), 8.0])
	cv.cmds.append(["texcircle", c, r, tex, Rect2(), Color.WHITE])
	cv.cmds.append(["ring", c, r - 3.0, Color(0, 0, 0, 0.38), 7.0])
	cv.cmds.append(["arc", c, r - 13.0, deg_to_rad(205), deg_to_rad(335), Color(1, 1, 1, 0.17), 9.0])
	if cd > 0.0:
		cv.cmds.append(["circle", c, r, Color(0.02, 0.04, 0.08, 0.38)])
		var pts := PackedVector2Array([c])
		for i in 49:
			pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * cd * float(i) / 48.0) * r)
		cv.cmds.append(["poly", pts, Color(0, 0, 0, 0.42)])
		cv.cmds.append(["arc", c, r + 4.5, -PI * 0.5 + TAU * cd, -PI * 0.5 + TAU, Color("#8fd8ff"), 5.0])
		_mlt(p, cd_txt, Rect2(c - Vector2(r, r), Vector2(r * 2, r * 2)), int(r * 0.85), Color.WHITE, 1, 8)
	if ult:
		var cv2 := _cv(p)
		for a: float in [-0.9, 0.35, 2.4]:
			var sp: Vector2 = c + Vector2.from_angle(a) * (r + 18)
			cv2.cmds.append(["poly", _P([Vector2(0, -1), Vector2(0.25, 0), Vector2(0, 1), Vector2(-0.25, 0)], sp, 14.0), ML["gold_hi"]])


## Yuvarlak küçük düğme (işaret/ayar/çanta): koyu cam + ince çerçeve + ikon (+ rozet / etkin halkası).
func _ml_round(p: Control, c: Vector2, r: float, icon: String, icol: Color, badge: String = "", active: bool = false) -> void:
	var cv := _cv(p)
	cv.cmds.append(["circle", c + Vector2(0, 4), r + 3, Color(0, 0, 0, 0.35)])
	_ml_rgrad(cv, c, r, Color(0.09, 0.15, 0.27, 0.92), Color(0.02, 0.04, 0.09, 0.9), 8)
	cv.cmds.append(["ring", c, r - 1.5, Color(ML["gold"]) if active else Color(ML["border"]), 4.0 if active else 3.0])
	cv.cmds.append(["arc", c, r - 6.0, deg_to_rad(205), deg_to_rad(335), Color(1, 1, 1, 0.12), 4.0])
	_ml_icon(cv, icon, c, r * 1.15, icol)
	if badge != "":
		var bc: Vector2 = c + Vector2(r * 0.72, -r * 0.72)
		cv.cmds.append(["circle", bc, 17.0, Color("#0a0a12")])
		cv.cmds.append(["circle", bc, 14.0, ML["red"]])
		_mlt(p, badge, Rect2(bc - Vector2(17, 18), Vector2(34, 34)), 22, Color.WHITE, 1, 4)


## Yüz dairesi (portrenin baş bölgesi, en yakın komşu) + renkli halka.
func _ml_face(p: Control, cid: int, c: Vector2, r: float, ring: Color, dead: bool = false) -> void:
	var cvn := _cv(p, true)
	cvn.cmds.append(["circle", c, r, Color("#121a2a")])
	cvn.cmds.append(["texcircle", c, r - 2, _ptex(cid), Rect2(12, 3, 24, 24), Color(0.42, 0.42, 0.48) if dead else Color.WHITE])
	var cv := _cv(p)
	if dead:
		cv.cmds.append(["circle", c, r - 2, Color(0, 0, 0, 0.45)])
	cv.cmds.append(["ring", c, r + 1, ring, 4.0])


func _ml_bar(cv: MLDraw, r: Rect2, frac: float, col: Color, ticks: int = 0, extra: float = 0.0) -> void:
	cv.cmds.append(["rect", r.grow(2), Color(0, 0, 0, 0.85)])
	cv.cmds.append(["rect", r, Color(0.05, 0.07, 0.11, 0.95)])
	var f: float = clampf(frac, 0.0, 1.0)
	if f > 0.0:
		var fr := Rect2(r.position, Vector2(r.size.x * f, r.size.y))
		cv.cmds.append(["rect", fr, col.darkened(0.12)])
		cv.cmds.append(["rect", Rect2(fr.position, Vector2(fr.size.x, r.size.y * 0.45)), col.lightened(0.18)])
	if extra > 0.0:
		var ex := Rect2(r.position.x + r.size.x * f, r.position.y, minf(r.size.x * extra, r.size.x * (1.0 - f)), r.size.y)
		cv.cmds.append(["rect", ex, Color(1, 1, 1, 0.92)])
	for i in range(1, ticks):
		var x: float = r.position.x + r.size.x * float(i) / float(ticks)
		cv.cmds.append(["rect", Rect2(x - 1, r.position.y, 2, r.size.y * (0.65 if i % 5 != 0 else 1.0)), Color(0, 0, 0, 0.7)])


## ------------------------------------------------------------------ AHŞAP HUD KİTİ (kullanıcı 2026-10-18: "arayüzdeki bazı ayrıntılar
## ben direk yapay zekayım diye bağırıyor. örneğin sohbet penceresi grup paneli istatistikler ayarlar vb. tasarımlarını bozmadan
## görünüşlerini değiştir"). Düzen AYNI; lacivert cam kutular, Nunito, vektör emoji simgeler, parlama/ışıltı, "·" ara yazıları ve
## açıklama satırları yerine PC HUD'unun GERÇEK malzemesi (madde 207 Kısık Ahşap; party_panel.gd ile aynı): hud_plaque_clean levha,
## hud_inset kuyu, btn_hud / btn_mini_hud ahşap düğme, m5x7 yazı (24 = 3x, 32 = 4x), piksel simgeler, HudTheme renkleri.
const WD := {
	"text": Color("#f3e6cc"), "dim": Color("#c4b090"), "price": Color("#f6d27e"), "accent": Color("#f0c070"),
	"good": Color("#b5d98a"), "bad": Color("#f09a80"), "outline": Color("#20150d"), "inset": Color("#271a11"),
	"plate": Color("#5a4734"), "rim_hi": Color("#86623f"), "bar": Color("#e0aa3e"), "bar_hi": Color("#f2cd7c"),
	"badge": Color("#a8403a"), "badge_hi": Color("#cf6a58"), "ally": Color("#7cc4ff"),
}
## [doku, 9 dilim payı (sanat pikseli; game/ dokuları 3x çizili), karo mu] - UIKit.panel_style / button_style payları.
const WKIT := {
	"plaque": ["res://assets/ui/game/hud_plaque_clean.png", [6, 5, 6, 5], false],
	"inset": ["res://assets/ui/game/hud_inset.png", [4, 4, 4, 4], true],
	"btn": ["res://assets/ui/game/btn_hud_normal.png", [8, 5, 8, 5], true],
	"btn_on": ["res://assets/ui/game/btn_hud_pressed.png", [8, 5, 8, 5], true],
	"mini": ["res://assets/ui/game/btn_mini_hud_normal.png", [4, 4, 4, 4], true],
	"mini_on": ["res://assets/ui/game/btn_mini_hud_pressed.png", [4, 4, 4, 4], true],
}
const COIN_PATH := "res://assets/ui/newui/icon_gold_coin.png"
const RING_PATH := "res://assets/ui/kit/hud_skill_frame_round.png"
const RING_SPIRIT_PATH := "res://assets/ui/kit/hud_skill_frame_spirit_round.png"
const G_EXPAND := ["###..###", "#......#", "#......#", "........", "........", "#......#", "#......#", "###..###"]
var _ktex_cache: Dictionary = {}
var HPI = null


func _ktex(path: String) -> Texture2D:
	if not _ktex_cache.has(path):
		_ktex_cache[path] = load(path) as Texture2D
	return _ktex_cache[path]


## Kit levhası / kuyu / ahşap düğme (9 dilim, en yakın komşu; PC ile aynı ölçek: 1 sanat pikseli = 3 px).
func _wk(p: Control, r: Rect2, kind: String) -> Panel:
	var d: Array = WKIT[kind]
	var m: Array = d[1]
	var sb := StyleBoxTexture.new()
	sb.texture = _ktex(str(d[0]))
	sb.texture_margin_left = float(m[0]) * 3.0
	sb.texture_margin_top = float(m[1]) * 3.0
	sb.texture_margin_right = float(m[2]) * 3.0
	sb.texture_margin_bottom = float(m[3]) * 3.0
	if bool(d[2]):
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	var pn := Panel.new()
	pn.add_theme_stylebox_override("panel", sb)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.add_child(pn)
	pn.position = r.position.round()
	pn.size = r.size.round()
	return pn


## m5x7 yazı. ol: harita üstündeki yazıya oyunun koyu kahve dış hattı (1 yazı pikseli); levha içinde hat yok (PC gibi).
func _wt(p: Control, s: String, r: Rect2, fs: int, c: Color, al: int = 0, ol: bool = false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.add_theme_constant_override("line_spacing", 0)
	if ol:
		l.add_theme_color_override("font_outline_color", WD["outline"])
		l.add_theme_constant_override("outline_size", int(fs / 4.0))
	l.horizontal_alignment = al
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	l.position = r.position.round()
	l.size = r.size.round()
	return l


## Ahşap HUD düğmesi (PC party_panel._wood_button: btn_hud dokusu + krem yazı); on = basılı doku + kehribar yazı.
func _wbtn(p: Control, r: Rect2, txt: String, on: bool = false, fs: int = 24, mini: bool = false) -> void:
	_wk(p, r, ("mini" if mini else "btn") + ("_on" if on else ""))
	if txt != "":
		_wt(p, txt, Rect2(r.position + Vector2(0, 1.0 if on else -2.0), r.size), fs, WD["accent"] if on else WD["text"], 1)


## Küçük kare ahşap düğme + piksel simge (ayar / çanta / sohbet / sekme okları).
func _wglyph_btn(p: Control, r: Rect2, pat: Array, on: bool = false, cell: float = 4.0) -> void:
	_wk(p, r, "mini_on" if on else "mini")
	_glyph(p, pat, r.get_center() + Vector2(0, 1.0 if on else -2.0), cell, WD["accent"] if on else WD["text"])


## PC'deki gibi "x" yazılı küçük ahşap kapat düğmesi.
func _wclose(p: Control, c: Vector2) -> void:
	_wbtn(p, Rect2(c - Vector2(24, 24), Vector2(48, 48)), "x", false, 32, true)


## Oyunun altın simgesi (icon_gold_coin.png 16 px, k katı).
func _wcoin(p: Control, c: Vector2, k: float = 2.0) -> void:
	var s: float = 16.0 * k
	_img(p, _ktex(COIN_PATH), Rect2((c - Vector2(s, s) * 0.5).round(), Vector2(s, s)), true)


## Kare portre kutusu (PC grup satırı: 3 px koyu çerçeve + kuyu zemini + portrenin baş bölgesi). s 54 -> iç 48 (24 x 2, keskin).
func _wface(p: Control, cid: int, c: Vector2, s: float = 54.0, border: Color = Color("#20150d"), dead: bool = false) -> void:
	var r := Rect2((c - Vector2(s, s) * 0.5).round(), Vector2(s, s))
	_rect(p, r, border)
	var inner: Rect2 = r.grow(-3.0)
	_rect(p, inner, WD["inset"])
	var at := AtlasTexture.new()
	at.atlas = _ptex(cid)
	at.region = Rect2(12, 3, 24, 24)
	_img(p, at, inner, true, Color(0.42, 0.42, 0.46) if dead else Color.WHITE)


## Okunmamış mesaj rozeti: koyu kontur + oyunun kırmızı kurdele rengi (game_notice.gd RIB_RED) + krem sayı.
func _wbadge(p: Control, c: Vector2, txt: String) -> void:
	var r := Rect2((c - Vector2(15, 15)).round(), Vector2(30, 30))
	_rect(p, r, WD["outline"])
	_rect(p, r.grow(-3.0), WD["badge"])
	_rect(p, Rect2(r.position + Vector2(3, 3), Vector2(24, 3)), WD["badge_hi"])
	_wt(p, txt, Rect2(r.position + Vector2(0, -2), r.size), 24, WD["text"], 1)


## Minimap işareti (PC minimap.gd dili): koyu kontur + düz renk kare + 3 px açık üst kenar.
func _wmark(cv: MLDraw, pos: Vector2, half: float, colr: Color) -> void:
	cv.cmds.append(["rect", Rect2(pos - Vector2(half + 3.0, half + 3.0), Vector2(half + 3.0, half + 3.0) * 2.0), WD["outline"]])
	cv.cmds.append(["rect", Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0), colr])
	cv.cmds.append(["rect", Rect2(pos - Vector2(half, half), Vector2(half * 2.0, 3.0)), colr.lightened(0.3)])


## Minimapte takım arkadaşı (PC minimap.gd: koyu taban + yuvarlak portre + renkli halka, kenar yumuşatmasız).
func _wmapface(p: Control, cid: int, c: Vector2, r: float, ring: Color, dead: bool = false) -> void:
	var cv := _cv(p, true)
	cv.cmds.append(["ncircle", c, r + 3.0, WD["outline"]])
	cv.cmds.append(["texcircle", c, r, _ptex(cid), Rect2(12, 3, 24, 24), Color(0.42, 0.42, 0.46) if dead else Color.WHITE])
	cv.cmds.append(["nring", c, r + 1.0, ring, 3.0])


func _mp(inner: Rect2, u: float, v: float) -> Vector2:
	return (inner.position + Vector2(u, v) * inner.size).round()


## Yetenek düğmesi: onaylı telefon çerçevesi (ince ahşap halka hud_skill_frame_round.png; ruhani F mor hud_skill_frame_spirit_round)
## x3 = 162 px, ikon 144 px daire (1:1 keskin). Bekleme: koyu dilim + m5x7 sayı. Altın metal çerçeve, parlama, ışıltı, cam yansıması yok.
func _w_skill(p: Control, c: Vector2, tex: Texture2D, cd: float = 0.0, cd_txt: String = "", spirit: bool = false) -> void:
	var cv := _cv(p, true)
	cv.cmds.append(["ncircle", c, 75.0, WD["outline"]])
	cv.cmds.append(["texcircle", c, 72.0, tex, Rect2(), Color.WHITE])
	if cd > 0.0:
		var pts := PackedVector2Array([c])
		for i in 49:
			pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * cd * float(i) / 48.0) * 72.0)
		cv.cmds.append(["poly", pts, Color(0.08, 0.05, 0.03, 0.62)])
	cv.cmds.append(["tex", Rect2(c - Vector2(81, 81), Vector2(162, 162)), _ktex(RING_SPIRIT_PATH if spirit else RING_PATH), Color.WHITE])
	if cd > 0.0:
		_wt(p, cd_txt, Rect2(c - Vector2(72, 76), Vector2(144, 144)), 64, WD["text"], 1, true)


func _render_ml(st: String) -> void:
	cur = "B"
	S = SKINS["B"]
	var l := CanvasLayer.new()
	l.layer = 96
	root.add_child(l)
	var rc := _ctl_root(l)
	if game_tex:
		_img(rc, game_tex, Rect2(0, 0, SW, SH), true)
	_ml_hud(rc, st)
	await _wait(0.5)
	shots["ml_" + st] = await _shot("ml_hud_" + st)
	l.queue_free()
	await process_frame


func _ml_hud(rc: Control, st: String) -> void:
	var chat_open: bool = st == "sohbet"
	var team_open: bool = st != "sohbet"
	if chat_open:
		_ml_merchant(rc)
	_ml_overhead(rc)
	_ml_minimap(rc)
	## Harita işaretleri (Saldır / Geri çekil / Toplan) GEÇİCİ olarak kaldırıldı (kullanıcı 2026-10-18); sohbet düğmesi minimapin
	## sağında tek başına, en üstte: kare ahşap düğme + piksel konuşma balonu + okunmamış rozeti.
	var chat_r := Rect2(ML_EDGE + 316, ML_EDGE, 72, 72)
	_wglyph_btn(rc, chat_r, G_CHAT, chat_open)
	if not chat_open:
		_wbadge(rc, chat_r.position + Vector2(68, 4), "2")
	_ml_team(rc, team_open, 2 if st == "altin" else -1, st == "istatistik")
	if st == "takim":
		_ml_banner(rc)
	_ml_topright(rc)
	_ml_joystick(rc)
	_ml_skills2(rc, chat_open)
	if chat_open:
		_ml_quickchat(rc)
	elif st == "takim":
		_ml_feed(rc, Vector2(ML_TEAM_X + ML_TEAM_W + 64, 344))
	if st == "altin":
		_ml_gift_popup(rc)
	elif st == "istatistik":
		_ml_stats_popup(rc)
	_ml_xpbar(rc)


## Kullanıcı (2026-10-18): "exp ilerlemesi ekranın en altında olsun tıpkı pc versiyonundaki gibi" -> PC'nin kendi çubuğu
## (bottom_exp_bar.gd: tam genişlik, 10 px, ahşap üst çizgi, mor dolgu + parlama, %10 bölme) aynen ekranın en altında.
func _ml_xpbar(rc: Control) -> void:
	var xb := Control.new()
	xb.set_script(load("res://scripts/bottom_exp_bar.gd"))
	rc.add_child(xb)
	xb.call("set_xp", 62.0, 100.0)


## Kahramanın başının üstü: ad + seviye kutusu + yeşil can (100'lük çentik, beyaz = ek kalkan yok) + mavi mana kalkanı + ince XP.
## Kullanıcı (2026-10-18): "can ve kalkan barı pc versiyonuna benzesin daha minimalist olsun" -> PC'nin karakter üstü çubuğu
## (overhead_bar.gd draw_pixel_bar: siyah kontur, hafif oval köşe, sert gölge, üst parlama + 40 canda bir eşit bölme çizgisi;
## yeşil can + altında ince mavi kalkan). Ad / seviye kutusu / XP çizgisi YOK. Telefonda okunsun diye x2 ölçek.
const PC_HP_COL := Color(0.30, 0.82, 0.24)
const PC_HP_BG := Color(0.12, 0.04, 0.04)
const PC_SH_COL := Color(0.35, 0.72, 1.0)
const PC_SH_BG := Color(0.04, 0.08, 0.14)
var OHB = null


func _pc_bars(p: Control, origin: Vector2, lw: float, lh: float, k: float, t: Dictionary, centered: bool = true, dead: bool = false) -> void:
	if OHB == null:
		OHB = load("res://scripts/overhead_bar.gd")
	var cv := _cv(p)
	cv.position = origin
	cv.scale = Vector2(k, k)
	var x0: float = -lw * 0.5 if centered else 0.0
	var hr := Rect2(x0, 0.0, lw, lh)
	var hpf: float = 0.0 if dead else float(t["hp"]) / float(t["mhp"])
	cv.cmds.append(["ohbar", OHB, hr, hpf, PC_HP_COL, PC_HP_BG])
	cv.cmds.append(["ohseg", OHB, hr, float(t["mhp"])])
	if float(t["msh"]) > 0.0:
		var sr := Rect2(x0, lh + 2.0, lw, roundf(lh * 0.72))
		cv.cmds.append(["ohbar", OHB, sr, 0.0 if dead else float(t["sh"]) / float(t["msh"]), PC_SH_COL, PC_SH_BG])


func _ml_overhead(rc: Control) -> void:
	_pc_bars(rc, Vector2(1200, 426), 58.0, 8.0, 2.0, TEAM[0])


func _ml_overhead_mlbb(rc: Control) -> void:
	var cv := _cv(rc)
	var x0: float = 1092.0
	var y0: float = 424.0
	var t0: Dictionary = TEAM[0]
	cv.cmds.append(["rect", Rect2(x0 - 3, y0 - 3, 216, 46), Color(0, 0, 0, 0.55)])
	cv.cmds.append(["rect", Rect2(x0, y0, 36, 40), Color("#10213d")])
	cv.cmds.append(["rect", Rect2(x0, y0, 36, 3), ML["ally"]])
	_ml_bar(cv, Rect2(x0 + 40, y0, 170, 22), float(t0["hp"]) / float(t0["mhp"]), ML["self"], int(float(t0["mhp"]) / 100.0) + 1)
	_ml_bar(cv, Rect2(x0 + 40, y0 + 26, 170, 10), float(t0["sh"]) / float(t0["msh"]), ML["mana"])
	cv.cmds.append(["rect", Rect2(x0, y0 + 42, 210, 4), Color(0, 0, 0, 0.6)])
	cv.cmds.append(["rect", Rect2(x0, y0 + 42, 210 * 0.62, 4), ML["gold"]])
	_mlt(rc, str(LEVEL), Rect2(x0, y0, 36, 40), 26, Color.WHITE, 1, 4)
	_mlt(rc, "Sen", Rect2(x0, y0 - 38, 210, 34), 26, ML["self"].lightened(0.3), 1, 5)


func _ml_minimap(rc: Control) -> void:
	## Kullanıcı (2026-10-18): "minimap sol tarafla yapışık olsun" + "direk yapışık değil ufak da olsa bi aralık olsun estetik durması
	## için" -> sol ve üst kenardan ML_EDGE (18 px). Görünüş (2026-10-18 "yapay zekâ gibi" turu): ahşap levha çerçeve + koyu iç
	## kontur; işaretler PC minimap.gd dilinde (koyu konturlu düz renk kare/nokta, yuvarlak portre). Vektör simgeler, mavi kenar ve
	## üst gölge şeritleri kalktı.
	var M := Rect2(ML_EDGE, ML_EDGE, 300, 300)
	_wk(rc, M, "plaque")
	var inner := Rect2(M.position + Vector2(15, 15), M.size - Vector2(30, 30))
	_rect(rc, inner.grow(3.0), WD["outline"])
	var clip := _ctl(rc, inner, true)
	var mt := AtlasTexture.new()
	mt.atlas = minimap_tex
	mt.region = Rect2(32, 32, 128, 128)
	_img(clip, mt, Rect2(Vector2.ZERO, inner.size), false)
	var cv := _cv(rc, true)
	var me: Vector2 = _mp(inner, 0.47, 0.58)
	var cam := Rect2(me - Vector2(45, 21), Vector2(90, 42))
	for e: Rect2 in [Rect2(cam.position, Vector2(cam.size.x, 3)), Rect2(cam.position + Vector2(0, cam.size.y - 3), Vector2(cam.size.x, 3)),
			Rect2(cam.position, Vector2(3, cam.size.y)), Rect2(cam.position + Vector2(cam.size.x - 3, 0), Vector2(3, cam.size.y))]:
		cv.cmds.append(["rect", e, Color(WD["text"], 0.75)])
	## satıcı (yeşil nokta), sandık (altın kare), elit (turuncu kare), boss (kırmızı büyük kare)
	var mer: Vector2 = _mp(inner, 0.63, 0.38)
	cv.cmds.append(["ncircle", mer, 12.0, WD["outline"]])
	cv.cmds.append(["ncircle", mer, 9.0, Color("#9fd4b4")])
	_wmark(cv, _mp(inner, 0.28, 0.40), 6.0, WD["price"])
	_wmark(cv, _mp(inner, 0.72, 0.80), 7.0, Color("#f0a060"))
	_wmark(cv, _mp(inner, 0.84, 0.18), 9.0, Color("#e0604c"))
	_wmapface(rc, int(TEAM[1]["char"]), _mp(inner, 0.40, 0.49), 14.0, WD["ally"])
	_wmapface(rc, int(TEAM[2]["char"]), _mp(inner, 0.57, 0.67), 14.0, WD["ally"])
	_wmapface(rc, int(TEAM[3]["char"]), _mp(inner, 0.33, 0.73), 14.0, WD["bad"], true)
	_wmapface(rc, ME, me, 17.0, WD["good"])
	var ex: Vector2 = inner.end - Vector2(21, 21)
	_rect(rc, Rect2(ex - Vector2(18, 18), Vector2(36, 36)), Color(WD["outline"], 0.7))
	_glyph(rc, G_EXPAND, ex, 3.0, WD["text"])


## Grup paneli: minimapin ALTINDA, minimapla AYNI genişlikte (300 px) kompakt satırlar (kullanıcı 2026-10-18: üste taşınması kötü,
## "önceki gibi olsun ama daha ufak, minimaple aynı genişlikte"). Alt kenarı joystick'in ~110 px üstünde biter. PC party_panel.gd
## işlevleri: satır başına ALTIN GÖNDER, altta İSTATİSTİKLER. Canı azalan = kırmızı portre çerçevesi (yazı yok). Kapalı: kare portre sütunu + ince can/kalkan çubuğu.
const ML_EDGE := 18.0
const ML_TEAM_X := ML_EDGE
const ML_TEAM_Y := 334.0
const ML_TEAM_W := 300.0
const ML_ROW_H := 70.0


func _ml_team(rc: Control, open: bool, gift_row: int = -1, stats_on: bool = false) -> void:
	## Görünüş (2026-10-18 "yapay zekâ gibi" turu): PC grup paneli gibi her satır ayrı ahşap levha, kare portre, m5x7 ad, ahşap altın
	## düğmesi (oyunun altın simgesi), ahşap "İstatistik" düğmesi ve sekme; yuvarlak cam kutu + vektör simgeler kalktı.
	var x0: float = ML_TEAM_X
	var y0: float = ML_TEAM_Y
	if open:
		for i in range(1, TEAM.size()):
			var t: Dictionary = TEAM[i]
			var ry: float = y0 + (i - 1) * ML_ROW_H
			var dead: bool = i == 3
			var low: bool = not dead and float(t["hp"]) / float(t["mhp"]) < 0.3
			_wk(rc, Rect2(x0, ry, ML_TEAM_W, ML_ROW_H - 4), "plaque")
			## Kullanıcı (2026-10-18): grup satırında oyuncu seviyesi yazmasın; genel seviye sağ üst pencerede.
			var fc := Vector2(x0 + 39, ry + 32)
			_wface(rc, int(t["char"]), fc, 54.0, WD["bad"] if low else WD["outline"], dead)
			if dead:
				_wt(rc, "14", Rect2(fc - Vector2(27, 29), Vector2(54, 54)), 32, WD["text"], 1, true)
			_wt(rc, str(t["name"]), Rect2(x0 + 76, ry + 4, 160, 30), 24, WD["dim"] if dead else WD["text"])
			if dead:
				## PC grup satırındaki durum yazısı (YERDE); çubuklar boş olduğu için onların yerinde.
				_wt(rc, "YERDE", Rect2(x0 + 76, ry + 31, 160, 26), 24, WD["bad"])
			else:
				_pc_bars(rc, Vector2(x0 + 76, ry + 35), 82.0, 5.0, 2.0, t, false)
			var gb := Rect2(x0 + ML_TEAM_W - 54, ry + 10, 44, 44)
			_wk(rc, gb, "mini_on" if i == gift_row else "mini")
			_wcoin(rc, gb.get_center() + Vector2(0, 1.0 if i == gift_row else -2.0), 2.0)
		_wbtn(rc, Rect2(x0, y0 + 3 * ML_ROW_H, ML_TEAM_W, 52), "İstatistik", stats_on, 32)
		_wglyph_btn(rc, Rect2(x0 + ML_TEAM_W + 6, y0, 40, 66), G_CHEV_L, false, 3.0)
	else:
		for i in range(1, TEAM.size()):
			var t2: Dictionary = TEAM[i]
			var dead2: bool = i == 3
			var low2: bool = not dead2 and float(t2["hp"]) / float(t2["mhp"]) < 0.3
			var c2 := Vector2(x0 + 36, y0 + 30 + (i - 1) * 80)
			_wface(rc, int(t2["char"]), c2, 54.0, WD["bad"] if low2 else WD["outline"], dead2)
			if dead2:
				_wt(rc, "14", Rect2(c2 - Vector2(27, 29), Vector2(54, 54)), 32, WD["text"], 1, true)
			else:
				_pc_bars(rc, Vector2(c2.x, c2.y + 33), 27.0, 4.0, 2.0, t2)
		_wglyph_btn(rc, Rect2(x0 + 76, y0 + 6, 40, 60), G_CHEV_R, false, 3.0)


func _ml_scoreboard(rc: Control, banner: bool) -> void:
	var cx: float = SW * 0.5
	_mlbox(rc, Rect2(cx - 352, 0, 160, 62), Color("#173f78", 0.9), Color("#5fa8ff"), 2, 10, 0.35, 0, true)
	_mlbox(rc, Rect2(cx + 192, 0, 196, 62), Color("#7a1818", 0.9), Color("#ff6a5c"), 2, 10, -0.35, 0, true)
	_mlbox(rc, Rect2(cx - 210, 0, 420, 90), ML["deep"], Color(ML["gold"], 0.8), 3, 22, 0.0, 8, true)
	var cv := _cv(rc)
	_ml_icon(cv, "team", Vector2(cx - 300, 30), 40.0, Color("#cfe6ff"))
	_ml_icon(cv, "skull", Vector2(cx + 236, 30), 30.0, Color("#ffd7cf"))
	var em := Vector2(cx - 150, 44)
	cv.cmds.append(["poly", _P([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 0.15), Vector2(0, 1.05), Vector2(-1, 0.15)], em + Vector2(0, 3), 33.0), Color(0, 0, 0, 0.5)])
	cv.cmds.append(["poly", _P([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 0.15), Vector2(0, 1.05), Vector2(-1, 0.15)], em, 32.0), ML["gold_lo"]])
	cv.cmds.append(["poly", _P([Vector2(-0.86, -0.86), Vector2(0.86, -0.86), Vector2(0.86, 0.1), Vector2(0, 0.88), Vector2(-0.86, 0.1)], em, 32.0), ML["gold"]])
	cv.cmds.append(["poly", _P([Vector2(-0.86, -0.86), Vector2(0, -0.86), Vector2(0, 0.88), Vector2(-0.86, 0.1)], em, 32.0), ML["gold_hi"]])
	_mlt(rc, "VII", Rect2(em - Vector2(32, 26), Vector2(64, 46)), 26, Color("#3a2306"), 1, 0)
	_mlt(rc, RUN_TIME, Rect2(cx - 110, 6, 180, 60), 46, Color.WHITE, 1, 7)
	_mlt(rc, "3/4", Rect2(cx - 290, 6, 90, 50), 30, Color.WHITE, 1, 5)
	_mlt(rc, "BOSS 2:30", Rect2(cx + 250, 6, 130, 50), 24, Color.WHITE, 1, 5)
	_mlt(rc, _num(KILLS), Rect2(cx + 112, 8, 92, 56), 28, ML["gold_hi"], 0, 5)
	var cvk := _cv(rc)
	_ml_icon(cvk, "sword", Vector2(cx + 94, 36), 26.0, ML["gold"])
	var pb := Rect2(cx - 140, 98, 280, 10)
	cvk.cmds.append(["rect", pb.grow(2), Color(0, 0, 0, 0.6)])
	cvk.cmds.append(["rect", Rect2(pb.position, Vector2(pb.size.x * 0.58, pb.size.y)), ML["gold"]])
	_mlt(rc, "VIII. kademeye 1:12", Rect2(cx - 200, 110, 400, 34), 22, ML["dim"], 1, 4)
	if banner:
		var by: float = 166.0
		var bcv := _cv(rc)
		for k in 6:
			var a: float = 0.12 + k * 0.12
			bcv.cmds.append(["rect", Rect2(cx - 380 + k * 22, by, 760 - k * 44, 80), Color(0.03, 0.05, 0.12, a * 0.55)])
		bcv.cmds.append(["rect", Rect2(cx - 300, by, 600, 2), Color(ML["gold"], 0.9)])
		bcv.cmds.append(["rect", Rect2(cx - 300, by + 78, 600, 2), Color(ML["gold"], 0.9)])
		_ml_face(rc, int(TEAM[1]["char"]), Vector2(cx - 300, by + 40), 44.0, ML["ally"])
		var ecv := _cv(rc)
		ecv.cmds.append(["circle", Vector2(cx + 300, by + 40), 44.0, Color("#2a0606")])
		ecv.cmds.append(["ring", Vector2(cx + 300, by + 40), 45.0, ML["orange"], 4.0])
		_ml_icon(ecv, "skull", Vector2(cx + 300, by + 40), 52.0, Color("#ffd7cf"))
		_mlt(rc, "ELİT AVI!", Rect2(cx - 240, by + 2, 480, 48), 38, ML["gold_hi"], 1, 7)
		_mlt(rc, "Mira elit yaratığı devirdi", Rect2(cx - 240, by + 44, 480, 32), 22, Color.WHITE, 1, 4)


func _ml_topright(rc: Control) -> void:
	_wglyph_btn(rc, Rect2(RX - 76, 20, 72, 72), G_GEAR)
	## Genel seviye (kullanıcı 2026-10-18: "genel seviye sağ üstteki canların olduğu pencerede görünebilir"): ahşap şeridin başında
	## oyunun seviye rozeti (hud_level_badge.png) + sayı; sonra piksel kalp (hud_pixel_icons.gd) / oyunun altın simgesi / ping yazısı.
	var pill := Rect2(RX - 680, 26, 590, 60)
	_wk(rc, pill, "plaque")
	var cy: float = pill.position.y + 30.0
	var bc := Vector2(pill.position.x + 34, cy)
	_img(rc, _ktex("res://assets/ui/kit/hud_level_badge.png"), Rect2(bc - Vector2(26, 26), Vector2(52, 52)), true)
	_wt(rc, str(LEVEL), Rect2(bc - Vector2(26, 28), Vector2(52, 52)), 32, WD["text"], 1, true)
	var x0: float = pill.position.x + 84
	_rect(rc, Rect2(x0, pill.position.y + 12, 3, 36), WD["outline"])
	_rect(rc, Rect2(x0 + 3, pill.position.y + 12, 3, 36), WD["rim_hi"])
	if HPI == null:
		HPI = load("res://scripts/hud_pixel_icons.gd")
	var cv := _cv(rc, true)
	cv.cmds.append(["pix", HPI, HPI.HEART, Vector2(x0 + 26, cy - 15), 3.0, HPI.HEART_COLOR])
	_wt(rc, "x2", Rect2(x0 + 66, pill.position.y + 2, 70, 56), 32, WD["text"])
	_wcoin(rc, Vector2(x0 + 168, cy), 2.0)
	_wt(rc, _num(GOLD), Rect2(x0 + 192, pill.position.y + 2, 120, 56), 32, WD["price"])
	_wt(rc, "38 ms", Rect2(x0 + 330, pill.position.y + 2, 140, 56), 24, WD["dim"])
	_wglyph_btn(rc, Rect2(RX - 74, 108, 68, 68), G_BAG)


func _ml_bag(rc: Control) -> void:
	var c := Vector2(SX + 62, 700)
	var cv := _cv(rc)
	cv.cmds.append(["circle", c + Vector2(0, 5), 58.0, Color(0, 0, 0, 0.4)])
	_ml_rgrad(cv, c, 55.0, Color("#2a3f66"), Color("#0b1426"), 10)
	cv.cmds.append(["ring", c, 53.0, ML["gold"], 4.0])
	cv.cmds.append(["arc", c, 47.0, deg_to_rad(205), deg_to_rad(335), Color(1, 1, 1, 0.15), 5.0])
	_ml_icon(cv, "bag", c + Vector2(0, -2), 62.0, Color("#f3e3c0"))
	var pill := Rect2(SX - 4, 762, 132, 40)
	_mlbox(rc, pill, ML["deep"], Color(ML["gold"], 0.8), 2, 20)
	var cv2 := _cv(rc)
	_ml_icon(cv2, "coin", Vector2(pill.position.x + 22, pill.get_center().y), 30.0, Color.WHITE)
	_mlt(rc, _num(GOLD), Rect2(pill.position.x + 40, pill.position.y, 90, 40), 24, ML["gold_hi"], 1, 4)


func _ml_joystick(rc: Control) -> void:
	## Telefonun GERÇEK joystick'i (touch_controls.gd çizimi: krem saydam taban, koyu + krem halka, kademeli krem düğme; kenar
	## yumuşatmasız). Mavi parlak top + yön okları kalktı (2026-10-18 "yapay zekâ gibi" turu).
	var c := Vector2(420, 872)
	var jr := 154.0
	var k: Vector2 = c + Vector2(46, -34)
	var kr := 62.0
	var cv := _cv(rc)
	cv.cmds.append(["ncircle", c, jr, Color(1.0, 0.96, 0.86, 0.12)])
	cv.cmds.append(["nring", c, jr + 2.0, Color(0.24, 0.15, 0.08, 0.55), 3.0])
	cv.cmds.append(["nring", c, jr - 1.5, Color(1.0, 0.94, 0.82, 0.6), 4.0])
	cv.cmds.append(["ncircle", k, kr + 3.0, Color(0.24, 0.15, 0.08, 0.77)])
	cv.cmds.append(["ncircle", k, kr, Color(0.78, 0.6, 0.4, 0.95)])
	cv.cmds.append(["ncircle", k + Vector2(-6, -6), kr - 9.0, Color(0.95, 0.86, 0.7, 0.95)])


func _ml_skills(rc: Control) -> void:
	var sk: Array = _skills(ME)
	_ml_skill(rc, Vector2(1984, 762), 88, _stex(sk[3][2]), ML["gold"], 0.0, "", true)
	_ml_skill(rc, Vector2(2190, 910), 110, _stex(sk[1][2]), Color("#c9d6ea"))
	_ml_skill(rc, Vector2(1952, 986), 78, _stex(sk[2][2]), Color("#c9d6ea"), 0.55, "4")
	_ml_skill(rc, Vector2(1748, 1006), 58, _stex(str(_spirit(SPIRIT).get("icon", ""))), ML["purple"])
	## bağlamsal etkileşim (yakında satıcı)
	var ic := Vector2(2196, 650)
	var cv := _cv(rc)
	for k in 5:
		cv.cmds.append(["ring", ic, 66.0 + k * 5.0, Color(ML["gold"], 0.32 - k * 0.06), 4.0])
	cv.cmds.append(["circle", ic + Vector2(0, 5), 62.0, Color(0, 0, 0, 0.4)])
	_ml_rgrad(cv, ic, 60.0, Color("#3a2c12"), Color("#120c05"), 10)
	cv.cmds.append(["ring", ic, 58.0, ML["gold"], 4.0])
	_ml_icon(cv, "hand", ic + Vector2(0, -4), 62.0, ML["gold_hi"])
	var pill := Rect2(ic.x - 70, ic.y + 46, 140, 36)
	_mlbox(rc, pill, Color("#2a1d08", 0.95), ML["gold"], 2, 18)
	_mlt(rc, "SATICI", pill, 22, ML["gold_hi"], 1, 4)


## Üst orta duyuru: oyunun GERÇEK bildirim levhası (game_notice.gd banner: kurdele + levha + kuru kafa sırası; madde 264), örnek
## olay kademe başlangıcı. Uydurma "ELİT AVI!" şeridi (degrade + parlak çizgiler + yuvarlak yüzler) kalktı.
func _ml_banner(rc: Control) -> void:
	var gn: GDScript = load("res://scripts/game_notice.gd")
	var n: Control = gn.call("banner", "tier", "KADEME VII", "", 999.0, 7)
	rc.add_child(n)
	n.position = Vector2(roundf((SW - n.size.x) * 0.5), 34.0)


## Kullanıcı düzeni (2026-10-18): Q/E/R sağ kenarda ÜST ÜSTE, EŞİT boy, ULTİ en üstte; ruhani F ultinin solunda ve biraz
## aşağıda (R ile E arasının hizası); dükkan düğmesi SADECE dükkana yakınken F'nin altında belirir.
const ML_SKILL_R := 84.0
const ML_STACK_X := 2206.0
const ML_STACK_Y := [539.0, 751.0, 963.0]


func _ml_skills2(rc: Control, near_shop: bool) -> void:
	var sk: Array = _skills(ME)
	var x: float = ML_STACK_X
	_w_skill(rc, Vector2(x, ML_STACK_Y[0]), _stex(sk[3][2]))
	_w_skill(rc, Vector2(x, ML_STACK_Y[1]), _stex(sk[2][2]), 0.55, "4")
	_w_skill(rc, Vector2(x, ML_STACK_Y[2]), _stex(sk[1][2]))
	## Kullanıcı (2026-10-18): "ruhani yetenek Q yeteneğinin solunda olsun" -> F, Q ile aynı satırda; dükkan düğmesi F'nin eski
	## yerine (R ile E arasının solu) geçti.
	_w_skill(rc, Vector2(x - 216, ML_STACK_Y[2]), _stex(str(_spirit(SPIRIT).get("icon", ""))), 0.0, "", true)
	if near_shop:
		## Dükkan (sadece dükkana yakınken): aynı ince ahşap halka x2 + koyu iç + piksel çanta; altında ahşap levhada "Dükkan".
		var ic := Vector2(x - 216, 690)
		var cv := _cv(rc, true)
		cv.cmds.append(["ncircle", ic, 50.0, WD["outline"]])
		cv.cmds.append(["ncircle", ic, 47.0, WD["plate"]])
		cv.cmds.append(["tex", Rect2(ic - Vector2(54, 54), Vector2(108, 108)), _ktex(RING_PATH), Color.WHITE])
		_glyph(rc, G_BAG, ic + Vector2(0, -2), 5.0, WD["price"])
		var pl := Rect2(ic.x - 72, ic.y + 52, 144, 44)
		_wk(rc, pl, "plaque")
		_wt(rc, "Dükkan", Rect2(pl.position + Vector2(0, -1), pl.size), 24, WD["text"], 1)


## Dükkana yakın hâli için seyyar satıcı NPC'si (oyunun sprite'ı) oyuncunun sağında.
func _ml_merchant(rc: Control) -> void:
	var path := "res://assets/npc/seyyar_satici/seyyar_satici_frames.tres"
	if not ResourceLoader.exists(path):
		return
	var sf: SpriteFrames = load(path) as SpriteFrames
	var a: StringName = &"idle_left"
	var tex: Texture2D = sf.get_frame_texture(a, 0)
	var fh: float = tex.get_size().y if tex else 64.0
	print("MERCHANT frame ", tex.get_size() if tex else Vector2.ZERO)
	var k: float = 3.6
	var foot := Vector2(1470, 600)
	var cv := _cv(rc)
	cv.cmds.append(["poly", _ellipse_pts(foot, 16.0 * k, 5.0 * k), Color(0, 0, 0, 0.3)])
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.animation = a
	s.play()
	s.scale = Vector2(k, k)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = true
	s.offset = Vector2(0, -fh * 0.5)
	rc.add_child(s)
	s.position = foot
	_wt(rc, "Seyyar Satıcı", Rect2(foot.x - 120, foot.y - fh * k - 44, 240, 40), 24, WD["accent"], 1, true)


## Altın gönder (PC party_panel.gd _build_gift_popup: "Altın gönder" + 10 / 50 / 100 / Hepsi): Kerem'in satırındaki (basılı) altın
## düğmesinin sağında ahşap levha; ahşap düğmeler + oyunun altın simgesi. Konuşma balonu ucu ve parlak altın çerçeve kalktı.
func _ml_gift_popup(rc: Control) -> void:
	var t: Dictionary = TEAM[2]
	var row_cy: float = ML_TEAM_Y + ML_ROW_H + 32.0
	var P := Rect2(ML_TEAM_X + ML_TEAM_W + 64, row_cy - 62, 560, 250)
	var x0: float = P.position.x
	var y0: float = P.position.y
	_wk(rc, P, "plaque")
	_wface(rc, int(t["char"]), Vector2(x0 + 46, y0 + 46), 54.0)
	_wt(rc, str(t["name"]) + "'e altın gönder", Rect2(x0 + 86, y0 + 14, 400, 40), 32, WD["accent"])
	_wclose(rc, Vector2(P.end.x - 40, y0 + 38))
	_wt(rc, "Altının:", Rect2(x0 + 86, y0 + 54, 160, 36), 32, WD["dim"])
	var ax: float = x0 + 86 + _tw_of("Altının:", 32) + 10.0
	_wcoin(rc, Vector2(ax + 16, y0 + 72), 2.0)
	_wt(rc, _num(GOLD), Rect2(ax + 40, y0 + 52, 160, 38), 32, WD["price"])
	var labels: Array = ["10", "50", "100", "Hepsi"]
	var bw: float = floorf((P.size.x - 40.0 - 36.0) / 4.0)
	for i in 4:
		var br := Rect2(x0 + 20 + i * (bw + 12), y0 + 112, bw, 116)
		_wk(rc, br, "btn")
		_wcoin(rc, Vector2(br.get_center().x, br.position.y + 38), 2.0)
		_wt(rc, str(labels[i]), Rect2(br.position.x, br.position.y + 60, br.size.x, 40), 32, WD["text"], 1)


## İstatistikler (PC party_panel.gd "Hasar Sıralaması" levhası): başlık + "x", sağa yaslı sütunlar (Verilen / Alınan hasar, Öldürme,
## İyileştirme), sıra "1." kehribar, kendi satırın hafif koyu şerit, verilen hasar çubuğu PC'deki gibi gömme kuyuda altın dolgu.
## Grafik simgesi, "bu oyun · 18:42" ara yazısı, BÜYÜK HARF mini başlıklar ve yeşil yuvarlak vurgu kutusu kalktı.
func _ml_stats_popup(rc: Control) -> void:
	## [oyuncu, verilen, öldürme, iyileştirme, ALINAN] - alınan hasar sütunu kullanıcı isteği (2026-10-18, PC'de de var).
	var rows: Array = [[2, 52740, 401, 0, 7950], [0, 48210, 312, 0, 4320], [1, 31800, 140, 12400, 2180], [3, 27110, 186, 2300, 9640]]
	var P := Rect2(ML_TEAM_X + ML_TEAM_W + 64, 300, 1180, 470)
	var x0: float = P.position.x
	_wk(rc, P, "plaque")
	_wt(rc, "İstatistikler", Rect2(x0 + 30, P.position.y + 16, 500, 44), 32, WD["accent"])
	_wclose(rc, Vector2(P.end.x - 42, P.position.y + 40))
	var hy: float = P.position.y + 72
	_wt(rc, "Oyuncu", Rect2(x0 + 150, hy, 170, 32), 24, WD["dim"])
	_wt(rc, "Verilen hasar", Rect2(x0 + 330, hy, 260, 32), 24, WD["dim"])
	_wt(rc, "Alınan hasar", Rect2(x0 + 600, hy, 250, 32), 24, WD["dim"], 2)
	_wt(rc, "Öldürme", Rect2(x0 + 860, hy, 120, 32), 24, WD["dim"], 2)
	_wt(rc, "İyileştirme", Rect2(x0 + 990, hy, 160, 32), 24, WD["dim"], 2)
	_rect(rc, Rect2(x0 + 24, hy + 38, P.size.x - 48, 3), WD["outline"])
	_rect(rc, Rect2(x0 + 24, hy + 41, P.size.x - 48, 3), Color(WD["rim_hi"], 0.45))
	var maxd: float = 52740.0
	for i in rows.size():
		var r: Array = rows[i]
		var t: Dictionary = TEAM[int(r[0])]
		var y: float = hy + 54 + i * 84
		if int(r[0]) == 0:
			_rect(rc, Rect2(x0 + 15, y - 3, P.size.x - 30, 78), Color(WD["outline"], 0.3))
		_wt(rc, "%d." % (i + 1), Rect2(x0 + 28, y, 56, 72), 32, WD["accent"] if i == 0 else WD["dim"])
		_wface(rc, int(t["char"]), Vector2(x0 + 112, y + 36), 54.0)
		_wt(rc, str(t["name"]), Rect2(x0 + 150, y, 170, 72), 32, WD["text"])
		var well := Rect2(x0 + 330, y + 24, 210, 24)
		_wk(rc, well, "inset")
		var fw: float = roundf((well.size.x - 12.0) * float(r[1]) / maxd)
		_rect(rc, Rect2(well.position + Vector2(6, 6), Vector2(fw, 12)), WD["bar"])
		_rect(rc, Rect2(well.position + Vector2(6, 6), Vector2(fw, 3)), WD["bar_hi"])
		_wt(rc, _num(int(r[1])), Rect2(x0 + 548, y, 132, 72), 32, WD["price"], 2)
		_wt(rc, _num(int(r[4])), Rect2(x0 + 700, y, 150, 72), 32, WD["bad"], 2)
		_wt(rc, _num(int(r[2])), Rect2(x0 + 860, y, 120, 72), 32, WD["text"], 2)
		_wt(rc, _num(int(r[3])) if int(r[3]) > 0 else "-", Rect2(x0 + 990, y, 160, 72), 32, WD["good"] if int(r[3]) > 0 else WD["dim"], 2)


## Son sohbet satırları (harita üstünde, grup panelinin sağında): düz m5x7 + koyu kahve dış hat, ad altın, mesaj krem. Degrade
## şerit ve yuvarlak yüzler kalktı.
func _ml_feed(rc: Control, pos: Vector2) -> void:
	var msgs: Array = [[1, "sandık bende, gelin"], [2, "can az, Melek iyileştir"]]
	for i in msgs.size():
		var m: Array = msgs[i]
		var y: float = pos.y + i * 44
		var nm: String = str(TEAM[int(m[0])]["name"]) + ":"
		_wt(rc, nm, Rect2(pos.x, y, 200, 42), 32, WD["price"], 0, true)
		_wt(rc, str(m[1]), Rect2(pos.x + _tw_of(nm, 32) + 12, y, 640, 42), 32, WD["text"], 0, true)


## Hızlı sohbet: sohbet düğmesinin altında, ekranın üst yarısında (joystick bölgesine inmez). Ahşap levha + son mesajlar kuyusu + 6
## hazır mesaj (ahşap düğme, simgesiz, oyuna özgü) + yazma alanı ve Gönder. MOBA kopyası "Saldırın / Geri çekilin", renkli emoji
## simgeler ve oyunda olmayan "İFADE" kalktı.
func _ml_quickchat(rc: Control) -> void:
	var P := Rect2(ML_EDGE + 316, 110, 700, 452)
	var x0: float = P.position.x
	_wk(rc, P, "plaque")
	_wt(rc, "Sohbet", Rect2(x0 + 26, P.position.y + 14, 300, 44), 32, WD["accent"])
	_wclose(rc, Vector2(P.end.x - 40, P.position.y + 38))
	var lg := Rect2(x0 + 18, P.position.y + 66, P.size.x - 36, 84)
	_wk(rc, lg, "inset")
	var y: float = lg.position.y + 6
	for m: Array in [[1, "sandık bende, gelin"], [2, "can az, Melek iyileştir"]]:
		var nm: String = str(TEAM[int(m[0])]["name"]) + ":"
		_wt(rc, nm, Rect2(lg.position.x + 16, y, 160, 36), 32, WD["price"])
		_wt(rc, str(m[1]), Rect2(lg.position.x + 28 + _tw_of(nm, 32), y, 520, 36), 32, WD["text"])
		y += 36
	var cw: float = floorf((P.size.x - 36.0 - 12.0) / 2.0)
	for i in ML_QUICK.size():
		@warning_ignore("integer_division")
		var r := Rect2(x0 + 18 + (i % 2) * (cw + 12), P.position.y + 162 + (i / 2) * 66, cw, 58)
		_wbtn(rc, r, str(ML_QUICK[i]), false, 32)
	var inp := Rect2(x0 + 18, P.end.y - 76, P.size.x - 36 - 196, 58)
	_wk(rc, inp, "inset")
	_wt(rc, "Mesaj yaz", Rect2(inp.position.x + 18, inp.position.y, 300, inp.size.y), 32, WD["dim"])
	_wbtn(rc, Rect2(inp.end.x + 12, inp.position.y, 184, 58), "Gönder", false, 32)


func _sheet_ml() -> void:
	var l := CanvasLayer.new()
	l.layer = 97
	root.add_child(l)
	var rc := _ctl_root(l)
	_rect(rc, Rect2(0, 0, SW, SH), Color("#0d1018"))
	var items: Array = [["ml_takim", "Normal: grup paneli AÇIK (minimapin altında, minimap genişliğinde)"], ["ml_sohbet", "Dükkana yakın: DÜKKAN düğmesi + sohbet AÇIK, grup KAPALI"],
			["ml_altin", "Altın gönder penceresi (Kerem)"], ["ml_istatistik", "İstatistikler penceresi"]]
	for i in items.size():
		if not shots.has(items[i][0]):
			continue
		@warning_ignore("integer_division")
		var r := Rect2(50 + (i % 2) * 1200, 44 + (i / 2) * 538, 1100, 495)
		_img(rc, _thumb(shots[items[i][0]], 1100, 495), r, false)
		_mlt(rc, str(items[i][1]), Rect2(r.position.x, r.position.y - 42, 1100, 40), 26, ML["gold_hi"], 0, 4)
	await _wait(0.3)
	await _shot("ml_hud_karsi")
	l.queue_free()


## Ruh Mağazası bedelleri meta_progress.gd COSTS ile aynı (sadece okunur kopya; -s betiğinde sınıf sabiti olarak).
class MetaCosts:
	const CHAR := {3: 250, 5: 250, 8: 300, 9: 300, 10: 350, 11: 350, 12: 350, 13: 400, 14: 400, 15: 450}
