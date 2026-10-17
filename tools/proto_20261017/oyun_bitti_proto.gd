extends SceneTree

## OYUN BİTTİ ekranı PROTOTİPLERİ (2026-10-17). Kullanıcı: "oyun bitti ekranını yeniden tasarla 4 prototip üret uyumlu olacak şekilde".
## Şu anki: main.gd _show_death_overlay(true) (layer 95, %55 kahve karartma + üstte bej UIKit penceresi: OYUN BİTTİ / Öldün,
## SÜRE-KADEME-ÖLDÜRME satırı, kıymık/rekor/başarım satırları, 4 sütunlu yazı tablosu, Yeniden Başla + Ana Menüye Dön).
## Oyuna BAĞLI DEĞİL: gerçek SP main.tscn açılır, yerel oyuncu ölüm klibinde yatar, her prototip ayrı CanvasLayer (arka plan 94,
## çizim 95) olarak üstüne çizilir. "Uyumlu": HUD teması "Kısık Ahşap" (hud_theme.gd renkleri + UIKit hud_plaque/hud_inset_tight
## dokuları + gerçek "green"/"hud" kit düğmeleri), m5x7 8'in katları, 48 px portreler 1:1 / 2:1, stat_mini ikonları, boss barının
## 9x9 kuru kafası + kademe kafa satırı (tier_display.gd skull_fills).
## Veri: oyunda ZATEN olan (süre, en yüksek kademe, takım seviyesi, kişi başı hasar/tank/öldürme, kıymık/rekor/başarım) + YENİ iki
## alan: kişi başı kalıcı ölüm zamanı (B/C/D) ve kademe başlangıç zamanları (yalnız C).
##  A Ahşap Pano / B Kahraman Kartları / C Koşu Çizelgesi / D Sinematik Perde (+ "simdi" = mevcut ekran).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261017/oyun_bitti_proto.gd
##   OYUN_BITTI_ONLY = "simdi,A" gibi seçili çekimler (boşsa hepsi + ozet.png).

const OUT := "res://tools/proto_20261017/out/oyun_bitti/"
const HT := preload("res://scripts/hud_theme.gd")
const CHAR_ID := 2 ## yerel oyuncu (Oakley)
## Takım: yerel oyuncu + 3 sahte arkadaş. death = kalıcı ölüm anı (koşu saniyesi), son ölen koşuyu bitirir.
const TEAM := [
	{"name": "Sen", "char": 2, "me": true, "dealt": 48210.0, "taken": 9870.0, "kills": 561, "death": 1060.0},
	{"name": "Mira", "char": 10, "dealt": 21540.0, "taken": 6120.0, "kills": 158, "death": 640.0},
	{"name": "Kerem", "char": 5, "dealt": 61930.0, "taken": 12380.0, "kills": 537, "death": 905.0},
	{"name": "Deniz", "char": 15, "dealt": 35080.0, "taken": 15920.0, "kills": 296, "death": 1131.0},
]
const RUN_TIME := 1131.0
const RUN_TIER := 6
const RUN_LEVEL := 23
const SHARDS := 47
const RECORDS := ["tier", "kills"]
const ACHIEVEMENTS := ["tier_5"]
const TIER_STARTS := [0.0, 150.0, 330.0, 560.0, 790.0, 985.0] ## C: Kademe I..VI başlangıcı (sn)
const BOSS_AT := {3: "Minotaur", 5: "Yeraltı Canavarı"} ## C: o kademenin bossu
## OYUN_BITTI_TEAM=8 için ek sahte arkadaşlar (sığma denetimi)
const TEAM_EXTRA := [
	{"name": "Ece", "char": 6, "dealt": 30400.0, "taken": 18800.0, "kills": 240, "death": 980.0},
	{"name": "Arda", "char": 8, "dealt": 27100.0, "taken": 7400.0, "kills": 205, "death": 700.0},
	{"name": "Bora", "char": 12, "dealt": 19800.0, "taken": 8100.0, "kills": 173, "death": 1110.0},
	{"name": "Selin", "char": 3, "dealt": 41900.0, "taken": 10200.0, "kills": 388, "death": 1020.0},
]
const CAPTIONS := {
	"simdi": "ŞU AN - bej pencere + yazı tablosu",
	"oyunda": "OYUNDA - A, satıcı renkleri (gerçek _show_death_overlay)",
	"A": "A - Ahşap Pano",
	"B": "B - Kahraman Kartları",
	"C": "C - Koşu Çizelgesi",
	"D": "D - Sinematik Perde",
}
## Gerçek kit düğmeleri: [x, y, w, h] Yeniden Başla (green), Ana Menüye Dön (hud)
const BUTTONS := {
	"A": [[568, 906, 380, 64], [972, 906, 380, 64]],
	"B": [[568, 890, 380, 64], [972, 890, 380, 64]],
	"C": [[124, 820, 572, 64], [124, 900, 572, 64]],
	"D": [[1500, 876, 380, 60], [1500, 948, 380, 60]],
}

const BONE := Color("#e9dcc0")
const DMG := Color("#e8885a") ## verilen hasar (oyunda hasar = kırmızı-turuncu)
const TANK := Color("#8cc0e6") ## tanklanan hasar (kalkan mavisi)
const SOUL_L := Color("#e6dcff")
const SOUL_M := Color("#b49cf0")
const SOUL_D := Color("#6f52bc")
const DEAD_MOD := Color(0.58, 0.56, 0.54)
const AWARD_SHORT := {"EN ÇOK HASAR": "en çok hasar", "EN ÇOK TANK": "en çok tank", "EN ÇOK ÖLDÜRME": "en çok öldürme",
		"SON AYAKTA KALAN": "son ayakta", "İLK DÜŞEN": "ilk düşen"}

const SKULL := [ ## boss_bar_art.gd SKULL_ROWS
	"..XXXXX..",
	".XWWWWWX.",
	"XWWWWWWWX",
	"XWKKWKKWX",
	"XWKKWKKWX",
	".XWWXWWX.",
	"..XWWWX..",
	"..XWXWX..",
	"...XXX...",
]
const HOURGLASS := [ ## bekleme_proto.gd ile aynı
	"OOOOOOOOOOOOO",
	"OWWWWWWWWWWWO",
	"OOOOOOOOOOOOO",
	" OHgggggggGO ",
	" OHgSSSSSgGO ",
	"  OHSSSSSGO  ",
	"   OHSSSGO   ",
	"    OHSGO    ",
	"     OSO     ",
	"    OgSgO    ",
	"   OggSggO   ",
	"  OHggSggGO  ",
	" OHgggSgggGO ",
	" OHggSSSggGO ",
	" OHSSSSSSSGO ",
	"OOOOOOOOOOOOO",
	"OWWWWWWWWWWWO",
	"OOOOOOOOOOOOO",
]
const CROWN := [
	".O...O...O.",
	"OYO.OYO.OYO",
	"OYYOYYYOYYO",
	"OYYYYYYYYYO",
	"OYYRYYYRYYO",
	"OYYYYYYYYYO",
	"OHHHHHHHHHO",
	"OOOOOOOOOOO",
]
const SOUL := [ ## Ruh Kıymığı (yeni küçük simge)
	"...O...",
	"..OLO..",
	".OLLMO.",
	".OLMMO.",
	"OLLMMDO",
	"OLMMMDO",
	"OLMMDDO",
	".OMMDO.",
	".OMDDO.",
	"..ODO..",
	"...O...",
]
const STAR := [
	"....O....",
	"...OYO...",
	"OOOOYOOOO",
	"OYYYYYYYO",
	".OYYYYYO.",
	"..OYYYO..",
	".OYYOYYO.",
	".OYO.OYO.",
	".OO...OO.",
]
const CHECK := [ ## bekleme_proto.gd ile aynı
	"  OOOOO  ",
	" OGGGGGO ",
	"OGGGGGWGO",
	"OGGGGWWGO",
	"OGWGWWGGO",
	"OGWWWGGGO",
	"OGGWGGGGO",
	" OGGGGGO ",
	"  OOOOO  ",
]
const DIAMOND := [
	"...O...",
	"..OAO..",
	".OAAAO.",
	"OAAAAAO",
	".OAAAO.",
	"..OAO..",
	"...O...",
]

const VIGNETTE := """shader_type canvas_item;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.6, 1.0));
	COLOR = vec4(0.07, 0.04, 0.02, mix(0.5, 0.86, smoothstep(0.1, 0.8, d)));
}
"""
const DESAT := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(vec3(g), c, 0.28) * 0.6;
	float e = smoothstep(0.55, 1.0, abs(UV.y - 0.45) * 2.0);
	col *= 1.0 - 0.45 * e;
	COLOR = vec4(col * vec3(1.0, 0.94, 0.88), 1.0);
}
"""
## D: dünya solar, ceset üstünde bantlı (piksel stili) ışık lekesi.
const SPOT := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 spot = vec2(960.0, 540.0);
uniform vec2 res = vec2(1920.0, 1080.0);
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 px = floor(SCREEN_UV * res / 4.0) * 4.0;
	float d = length((px - spot) / res.y * vec2(0.75, 1.0));
	float light = 1.0 - smoothstep(0.05, 0.42, d);
	light = floor(light * 12.0 + 0.5) / 12.0;
	vec3 col = mix(vec3(g), c, 0.18 + 0.55 * light) * mix(0.2, 1.0, light);
	COLOR = vec4(col, 1.0);
}
"""


class FakeAlly extends Node2D:
	var peer_id: int = 0
	var player_name: String = ""
	var char_id: int = 0
	var health: float = 0.0
	var max_health: float = 400.0
	var item_shield_max: float = 0.0
	var item_shield_hp: float = 0.0
	var is_dead: bool = true
	var is_downed: bool = false
	var match_damage_dealt: float = 0.0


## Bir prototipin bütün çizimi (tam ekran, fareyi geçirir). Piksel ızgaraya oturan dikdörtgenlerle çizilir.
class Proto extends Control:
	var kind: String = ""
	var team: Array = [] ## [{name, cname, tex, dealt, taken, kills, death, me, award, last}]
	var font: Font = null
	var plate_sb: StyleBox = null ## UIKit hud_plaque
	var well_sb: StyleBox = null ## UIKit hud_inset_tight
	var icons: Dictionary = {} ## "dmg", "shield" (stat_mini 24 px)
	var tier_fills: Array = [] ## tier_display.gd skull_fills(RUN_TIER)
	var record_labels: Dictionary = {}
	var ach_name: String = ""
	var ach_desc: String = ""
	var subtitle: String = ""
	var focus: Array = [] ## yakın çekim dikdörtgenleri (çizimden sonra dolar)

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# ------------------------------------------------------------ piksel yardımcıları
	func r(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)

	## Köşeleri bir birim kesik çerçeve (piksel yuvarlak köşe).
	func frame(rc: Rect2, fill: Color, border: Color, bw: float = 3.0) -> void:
		var x := rc.position.x
		var y := rc.position.y
		var w := rc.size.x
		var h := rc.size.y
		if fill.a > 0.0:
			r(x + bw, y + bw, w - 2.0 * bw, h - 2.0 * bw, fill)
		r(x + bw, y, w - 2.0 * bw, bw, border)
		r(x + bw, y + h - bw, w - 2.0 * bw, bw, border)
		r(x, y + bw, bw, h - 2.0 * bw, border)
		r(x + w - bw, y + bw, bw, h - 2.0 * bw, border)

	func plate(rc: Rect2) -> void:
		plate_sb.draw(get_canvas_item(), rc)

	func well(rc: Rect2) -> void:
		well_sb.draw(get_canvas_item(), rc)

	func sprite(rows_: Array, pos: Vector2, s: float, cols: Dictionary) -> void:
		for j in rows_.size():
			var row: String = rows_[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					r(pos.x + i * s, pos.y + j * s, s, s, cols[ch])

	## fill: 2 dolu, 1 yarım (sol yarı), 0 boş (kademe kafa satırının dili).
	func skull(pos: Vector2, s: float, fill: int = 2) -> void:
		var dim_w := Color(HT.RIM_HI, 0.55)
		for j in SKULL.size():
			var row: String = SKULL[j]
			for i in row.length():
				var ch: String = row[i]
				var on: bool = fill == 2 or (fill == 1 and i <= 4)
				var c: Color
				match ch:
					"X":
						c = HT.OUTLINE
					"W":
						c = BONE if on else dim_w
					"K":
						c = Color("#2a1a10") if on else Color(HT.OUTLINE, 0.7)
					_:
						continue
				r(pos.x + i * s, pos.y + j * s, s, s, c)

	func tier_row(pos: Vector2, s: float) -> void:
		for k in tier_fills.size():
			skull(pos + Vector2(k * (9.0 * s + 3.0), 0), s, int(tier_fills[k]))

	## 3x2 kafa ızgarası (kademe kutusunun simgesi)
	func tier_grid(c: Vector2, s: float) -> void:
		var cw := 9.0 * s
		var g := 3.0
		var x0 := c.x - (3.0 * cw + 2.0 * g) * 0.5
		var y0 := c.y - (2.0 * cw + g) * 0.5
		for k in tier_fills.size():
			skull(Vector2(x0 + (k % 3) * (cw + g), y0 + (k / 3) * (cw + g)), s, int(tier_fills[k]))

	func glyph_size(key: String, s: float) -> Vector2:
		match key:
			"hg":
				return Vector2(13, 18) * s
			"skull", "star", "check":
				return Vector2(9, 9) * s
			"crown":
				return Vector2(11, 8) * s
			"soul":
				return Vector2(7, 11) * s
			"tierrow":
				return Vector2(6 * 9.0 * s + 15.0, 9.0 * s)
			"dmg", "shield":
				return Vector2(24, 24) * s
		return Vector2.ZERO

	## Simgeyi c merkezine çizer.
	func glyph(key: String, c: Vector2, s: float) -> void:
		var sz := glyph_size(key, s)
		var p := Vector2(roundf(c.x - sz.x * 0.5), roundf(c.y - sz.y * 0.5))
		match key:
			"hg":
				sprite(HOURGLASS, p, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "H": Color(1, 1, 1, 0.5),
						"G": Color(0.75, 0.85, 0.9, 0.3), "g": Color(0.55, 0.7, 0.8, 0.14), "S": Color("#e8b860")})
			"skull":
				skull(p, s)
			"star":
				sprite(STAR, p, s, {"O": HT.OUTLINE, "Y": HT.PRICE})
			"check":
				sprite(CHECK, p, s, {"O": HT.OUTLINE, "G": Color("#5f9a3c"), "W": Color("#f3f0d8")})
			"crown":
				sprite(CROWN, p, s, {"O": HT.OUTLINE, "Y": HT.PRICE, "H": Color("#c48a3a"), "R": Color("#d9574a")})
			"soul":
				sprite(SOUL, p, s, {"O": HT.OUTLINE, "L": SOUL_L, "M": SOUL_M, "D": SOUL_D})
			"tierrow":
				tier_row(p, s)
			"dmg", "shield":
				draw_texture_rect(icons[key], Rect2(p, sz), false)

	## Izgaraya oturan halka; frac = saat yönünde tepeden dolu kısım.
	func ring(c: Vector2, r0: float, r1: float, cell: float, frac: float, on: Color, off: Color) -> void:
		var n := int(ceil(r1 / cell)) + 1
		for j in range(-n, n):
			for i in range(-n, n):
				var cx := (i + 0.5) * cell
				var cy := (j + 0.5) * cell
				var d := sqrt(cx * cx + cy * cy)
				if d < r0 or d > r1:
					continue
				var a := fposmod(atan2(cx, -cy), TAU) / TAU
				var col: Color = on if a <= frac else off
				if col.a > 0.0:
					r(c.x + i * cell, c.y + j * cell, cell, cell, col)

	func disk(c: Vector2, rad: float, cell: float, col: Color) -> void:
		ring(c, -1.0, rad, cell, 1.0, col, col)

	func tw(s: String, size: int) -> float:
		return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

	## pos = yazı kutusunun sol üstü; en fazla 3 px aşağı-sağ gölge.
	func txt(s: String, pos: Vector2, size: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
		var u: float = minf(size / 8.0, 3.0)
		var base := Vector2(roundf(pos.x), roundf(pos.y + font.get_ascent(size)))
		draw_string(font, base + Vector2(u, u), s, align, width, size, Color(HT.OUTLINE, 0.9))
		draw_string(font, base, s, align, width, size, c)

	## Dünya üstündeki büyük başlık: koyu dış hat (yarım font pikseli) + 1 font pikseli aşağı gölge.
	func title_on_world(s: String, y: float, size: int, c: Color) -> void:
		var base := Vector2(0, roundf(y + font.get_ascent(size)))
		var px := size / 8.0
		draw_string(font, base + Vector2(0, px), s, HORIZONTAL_ALIGNMENT_CENTER, 1920, size, Color(HT.OUTLINE, 0.85))
		for o in [Vector2(-px * 0.5, 0), Vector2(px * 0.5, 0), Vector2(0, -px * 0.5), Vector2(0, px * 0.5)]:
			draw_string(font, base + o, s, HORIZONTAL_ALIGNMENT_CENTER, 1920, size, HT.OUTLINE)
		draw_string(font, base, s, HORIZONTAL_ALIGNMENT_CENTER, 1920, size, c)

	## Yazı orta çizgisi (m5x7: görünür harf ~ boyutun 7/8'i, tabanın üstünde).
	func mid_y(y: float, size: int) -> float:
		return y + font.get_ascent(size) - size * 0.42

	## Satır parçaları: ["t", yazı, renk] / ["i", simge, ölçek] / ["sep"]. cx merkezli, y = yazı kutusunun üstü.
	func parts_w(pp: Array, size: int) -> float:
		var w := 0.0
		for pt: Array in pp:
			match pt[0]:
				"t":
					w += tw(pt[1], size)
				"i":
					w += glyph_size(pt[1], pt[2]).x + 10.0
				"sep":
					w += 44.0
		return w

	func parts(pp: Array, cx: float, y: float, size: int) -> void:
		var x := roundf(cx - parts_w(pp, size) * 0.5)
		var my := mid_y(y, size)
		for pt: Array in pp:
			match pt[0]:
				"t":
					txt(pt[1], Vector2(x, y), size, pt[2])
					x += tw(pt[1], size)
				"i":
					var sz := glyph_size(pt[1], pt[2])
					glyph(pt[1], Vector2(x + sz.x * 0.5, my), pt[2])
					x += sz.x + 10.0
				"sep":
					r(x + 19, my - 3, 6, 6, Color(HT.RIM_HI, 0.8))
					x += 44.0

	func bar(rc: Rect2, frac: float, fill: Color) -> void:
		frame(rc, HT.INSET, HT.OUTLINE, 3.0)
		var inner := rc.grow(-3.0)
		var w := roundf(inner.size.x * clampf(frac, 0.0, 1.0))
		r(inner.position.x, inner.position.y, w, inner.size.y, fill)
		r(inner.position.x, inner.position.y, w, 3.0, fill.lightened(0.35))

	func divider(xa: float, xb: float, y: float) -> void:
		r(xa, y, xb - xa, 3, Color(HT.OUTLINE, 0.8))
		r(xa, y + 3, xb - xa, 3, Color(HT.RIM_HI, 0.3))
		sprite(DIAMOND, Vector2(roundf((xa + xb) * 0.5) - 10, y - 8), 3.0, {"O": HT.OUTLINE, "A": HT.ACCENT})

	## Ölü oyuncu yuvası: 48 px portre x s, solgun + sağ altta kuru kafa rozeti.
	func portrait(pos: Vector2, p: Dictionary, s: float) -> Rect2:
		var inner := 48.0 * s
		var pad := 8.0 if s <= 1.0 else 12.0
		var rc := Rect2(pos, Vector2(inner + 2.0 * pad, inner + 2.0 * pad))
		frame(rc, HT.INSET, HT.ACCENT if p["me"] else HT.OUTLINE, 3.0 if s <= 1.0 else 4.0)
		if s > 1.0:
			frame(rc.grow(-4.0), Color(0, 0, 0, 0), HT.RIM_LO, 4.0)
		draw_texture_rect(p["tex"], Rect2(pos + Vector2(pad, pad), Vector2(inner, inner)), false, DEAD_MOD)
		var bs := 2.0 if s <= 1.0 else 3.0
		var bsz := 9.0 * bs + 2.0 * bs
		var bp := rc.end - Vector2(bsz * 0.75, bsz * 0.75)
		r(bp.x, bp.y, bsz, bsz, HT.OUTLINE)
		skull(bp + Vector2(bs, bs), bs)
		return rc

	func caption(y: float = 1000.0) -> void:
		var s: String = CAPTIONS.get(kind, kind)
		var w := tw(s, 24) + 28.0
		frame(Rect2(16, y, w, 44), Color(0.08, 0.05, 0.03, 0.88), HT.RIM, 3.0)
		txt(s, Vector2(30, y + 9), 24, HT.ACCENT)

	# ------------------------------------------------------------ veri yardımcıları
	static func fmt(n: int) -> String:
		var s := str(absi(n))
		var out := ""
		while s.length() > 3:
			out = "." + s.substr(s.length() - 3) + out
			s = s.substr(0, s.length() - 3)
		return s + out

	static func clock(sec: float) -> String:
		var t := int(sec)
		return "%02d:%02d" % [floori(t / 60.0), t % 60]

	func sum_of(key: String) -> float:
		var s := 0.0
		for p in team:
			s += float(p[key])
		return s

	func max_of(key: String) -> float:
		var m := 0.0
		for p in team:
			m = maxf(m, float(p[key]))
		return m

	func by_dealt() -> Array:
		var idx: Array = range(team.size())
		idx.sort_custom(func(a, b): return float(team[a]["dealt"]) > float(team[b]["dealt"]))
		return idx

	func tiles() -> Array:
		return [["hg", "SÜRE", clock(RUN_TIME)], ["tier", "KADEME", "VI"], ["star", "SEVİYE", str(RUN_LEVEL)],
				["skull", "ÖLDÜRME", fmt(int(sum_of("kills")))]]

	func summary_parts() -> Array:
		return [["i", "hg", 2.0], ["t", clock(RUN_TIME), HT.TEXT], ["sep"],
				["t", "KADEME VI  ", HT.ACCENT], ["i", "tierrow", 2.0], ["sep"],
				["t", "SEVİYE %d" % RUN_LEVEL, HT.TEXT], ["sep"],
				["i", "skull", 3.0], ["t", "%s öldürme" % fmt(int(sum_of("kills"))), HT.TEXT]]

	## [simge, kısa yazı, uzun yazı, renk]
	func rewards() -> Array:
		var out: Array = [["soul", "+%d Ruh Kıymığı" % SHARDS, "+%d Ruh Kıymığı" % SHARDS, SOUL_L]]
		for k: String in RECORDS:
			var v := "Kademe VI" if k == "tier" else "%d öldürme" % int(team[0]["kills"])
			var long_label := "En yüksek kademe: VI" if k == "tier" else "En çok öldürme: %d" % int(team[0]["kills"])
			out.append(["star", "Rekor · " + v, "Yeni rekor · " + long_label, HT.PRICE])
		out.append(["check", "Başarım · " + ach_name, "Başarım · %s (%s)" % [ach_name, ach_desc.trim_suffix(".")], HT.GOOD])
		return out

	## Kutu: solda simge, sağda küçük başlık + büyük değer.
	func tile(rc: Rect2, t: Array) -> void:
		well(rc)
		var ic := Vector2(rc.position.x + 46, rc.get_center().y)
		match t[0]:
			"hg":
				glyph("hg", ic, 2.0)
			"tier":
				tier_grid(ic, 2.0)
			_:
				glyph(t[0], ic, 4.0)
		txt(t[1], Vector2(rc.position.x + 88, rc.position.y + 16), 24, HT.DIM)
		txt(t[2], Vector2(rc.position.x + 88, rc.position.y + 46), 48, HT.ACCENT if t[0] == "tier" else HT.TEXT)

	## Hasar/tank hücresi: simge + sayı, altında en iyiye göre çubuk.
	func stat_cell(pos: Vector2, icon: String, v: float, vmax: float, col: Color, w: float) -> void:
		glyph(icon, pos + Vector2(12, 20), 1.0)
		txt(fmt(int(v)), pos + Vector2(32, 4), 32, HT.TEXT)
		bar(Rect2(pos.x, pos.y + 44, w, 12), v / maxf(vmax, 1.0), col)

	func award_color(a: String) -> Color:
		match a:
			"EN ÇOK HASAR":
				return DMG
			"EN ÇOK TANK":
				return TANK
			"EN ÇOK ÖLDÜRME":
				return HT.PRICE
			"SON AYAKTA KALAN":
				return HT.GOOD
		return HT.DIM

	# ------------------------------------------------------------ çizim
	func _draw() -> void:
		focus.clear()
		match kind:
			"simdi":
				pass
			"A":
				_draw_a()
			"B":
				_draw_b()
			"C":
				_draw_c()
			"D":
				_draw_d()
		caption(134.0 if kind == "D" else 1000.0)

	## Takım tablosu satırları (A ve C ortak). Sıra oyundaki gibi en çok hasar veren üstte.
	func team_rows(x0: float, w: float, y: float, cols: Dictionary) -> float:
		var right: float = x0 + w - 24.0
		txt("OYUNCU", Vector2(x0 + 16, y), 24, HT.DIM)
		txt("VERDİĞİ HASAR", Vector2(cols["dmg"], y), 24, HT.DIM)
		txt("TANKLADIĞI", Vector2(cols["tank"], y), 24, HT.DIM)
		txt("ÖLDÜRME", Vector2(right - 200, y), 24, HT.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 200)
		var md := max_of("dealt")
		var mt := max_of("taken")
		var order := by_dealt()
		var ry := y + 36.0
		for k in order.size():
			var p: Dictionary = team[order[k]]
			var row := Rect2(x0, ry, w, 70)
			if p["me"]:
				r(row.position.x, row.position.y, row.size.x, row.size.y, HT.STRIPE)
				r(row.position.x, row.position.y, 6, row.size.y, HT.ACCENT)
			elif k % 2 == 1:
				r(row.position.x, row.position.y, row.size.x, row.size.y, Color(HT.STRIPE, 0.45))
			portrait(Vector2(x0 + 16, ry + 3), p, 1.0)
			var nx: float = x0 + 98
			txt(p["name"], Vector2(nx, ry + 4), 32, HT.ACCENT if p["me"] else HT.TEXT)
			if p["award"] == "EN ÇOK HASAR":
				glyph("crown", Vector2(nx + tw(p["name"], 32) + 30, ry + 20), 3.0)
			txt(p["cname"], Vector2(nx, ry + 38), 24, HT.DIM)
			stat_cell(Vector2(cols["dmg"], ry + 2), "dmg", p["dealt"], md, DMG, cols["dmg_w"])
			stat_cell(Vector2(cols["tank"], ry + 2), "shield", p["taken"], mt, TANK, cols["tank_w"])
			var ks := str(int(p["kills"]))
			txt(ks, Vector2(right - 160, ry + 18), 32, HT.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 160)
			glyph("skull", Vector2(right - tw(ks, 32) - 26, mid_y(ry + 18, 32)), 3.0)
			ry += 76.0
		return ry

	## A - Ahşap Pano: tek koyu ahşap pencere (HUD levhası), tepede kuru kafa madalyonu, 4 stat kutusu, portreli tablo
	## (hasar/tank çubukları, taç), kazanımlar kuyusu, gerçek kit düğmeleri. Mevcut düzenin "Kısık Ahşap" hâli.
	func _draw_a() -> void:
		var W := 1200.0
		var x0 := 360.0
		var y0 := 72.0
		var win := Rect2(x0, y0, W, 926.0)
		plate(win)
		var mc := Vector2(960, y0 + 4)
		disk(mc, 56, 4, HT.OUTLINE)
		disk(mc, 52, 4, HT.RIM)
		ring(mc, 44, 52, 4, 1.0, HT.RIM_HI, HT.RIM_HI)
		disk(mc, 44, 4, HT.OUTLINE)
		disk(mc, 40, 4, HT.INSET)
		skull(mc - Vector2(27, 27), 6.0)
		txt("OYUN BİTTİ", Vector2(x0, y0 + 66), 64, HT.BAD, HORIZONTAL_ALIGNMENT_CENTER, W)
		txt(subtitle, Vector2(x0, y0 + 140), 24, HT.DIM, HORIZONTAL_ALIGNMENT_CENTER, W)
		divider(x0 + 80, x0 + W - 80, y0 + 182)
		var tl := tiles()
		var tw_ := 270.0
		var gap := 16.0
		var sx := 960.0 - (4.0 * tw_ + 3.0 * gap) * 0.5
		for i in 4:
			tile(Rect2(sx + i * (tw_ + gap), y0 + 206, tw_, 112), tl[i])
		var end_y := team_rows(x0 + 40, W - 80, y0 + 342, {"dmg": x0 + 470, "dmg_w": 250.0, "tank": x0 + 780, "tank_w": 210.0})
		var rw := Rect2(x0 + 40, end_y + 8, W - 80, 124)
		well(rw)
		glyph("soul", Vector2(rw.position.x + 52, rw.get_center().y), 5.0)
		txt("+%d" % SHARDS, Vector2(rw.position.x + 94, rw.position.y + 22), 48, SOUL_L)
		txt("Ruh Kıymığı", Vector2(rw.position.x + 94, rw.position.y + 76), 24, HT.DIM)
		r(rw.position.x + 300, rw.position.y + 18, 3, rw.size.y - 36, Color(HT.OUTLINE, 0.8))
		r(rw.position.x + 303, rw.position.y + 18, 3, rw.size.y - 36, Color(HT.RIM_HI, 0.25))
		var rws := rewards()
		for i in range(1, rws.size()):
			var ly := rw.position.y + 16 + (i - 1) * 32.0
			glyph(rws[i][0], Vector2(rw.position.x + 344, mid_y(ly, 24)), 3.0)
			txt(rws[i][2], Vector2(rw.position.x + 372, ly), 24, rws[i][3])
		focus.append(Rect2(x0 + 20, y0 + 330, W - 40, 600))

	## B - Kahraman Kartları: başlık + tek satır özet levhası, her oyuncuya dikey kart (2x portre, ödül kurdelesi, hasar/tank/
	## öldürme çubukları, ne zaman düştüğü), altta kazanım çipleri. Dünya solar (gri, kenarlar kararır).
	func _draw_b() -> void:
		txt("OYUN BİTTİ", Vector2(0, 40), 64, HT.BAD, HORIZONTAL_ALIGNMENT_CENTER, 1920)
		var sp := summary_parts()
		var sw := parts_w(sp, 32) + 72.0
		var strip := Rect2(roundf(960 - sw * 0.5), 124, roundf(sw), 68)
		plate(strip)
		parts(sp, 960, strip.position.y + 16, 32)
		var cw := 320.0
		var ch := 540.0
		var gap := 28.0
		var total := 4.0 * cw + 3.0 * gap
		var x0 := roundf(960 - total * 0.5)
		var y := 238.0
		var sd := sum_of("dealt")
		var st := sum_of("taken")
		var sk := sum_of("kills")
		for i in team.size():
			var p: Dictionary = team[i]
			var rc := Rect2(x0 + i * (cw + gap), y, cw, ch)
			plate(rc)
			if p["me"]:
				frame(rc.grow(6.0), Color(0, 0, 0, 0), HT.ACCENT, 3.0)
			var cx := rc.get_center().x
			portrait(Vector2(cx - 60, rc.position.y + 44), p, 2.0)
			if p["award"] != "":
				var ac := award_color(p["award"])
				var rb := Rect2(rc.position.x + 18, rc.position.y - 18, cw - 36, 40)
				frame(rb, HT.INSET, HT.OUTLINE, 3.0)
				frame(rb.grow(-3.0), Color(0, 0, 0, 0), ac.darkened(0.45), 3.0)
				r(rb.position.x - 6, rb.position.y + 9, 6, 22, HT.OUTLINE) ## kurdele uçları
				r(rb.end.x, rb.position.y + 9, 6, 22, HT.OUTLINE)
				txt(p["award"], Vector2(rb.position.x, rb.position.y + 8), 24, ac, HORIZONTAL_ALIGNMENT_CENTER, rb.size.x)
			txt(p["name"], Vector2(rc.position.x, rc.position.y + 194), 32, HT.ACCENT if p["me"] else HT.TEXT, HORIZONTAL_ALIGNMENT_CENTER, cw)
			txt(p["cname"], Vector2(rc.position.x, rc.position.y + 230), 24, HT.DIM, HORIZONTAL_ALIGNMENT_CENTER, cw)
			divider(rc.position.x + 28, rc.end.x - 28, rc.position.y + 274)
			var rows_: Array = [["dmg", "Hasar", p["dealt"], sd, max_of("dealt"), DMG],
					["shield", "Tank", p["taken"], st, max_of("taken"), TANK],
					["skull", "Öldürme", float(p["kills"]), sk, max_of("kills"), HT.PRICE]]
			for j in rows_.size():
				var rr: Array = rows_[j]
				var ry := rc.position.y + 300 + j * 66.0
				var lx := rc.position.x + 28
				glyph(rr[0], Vector2(lx + 12, mid_y(ry, 24)), 1.0 if rr[0] != "skull" else 2.0)
				txt(rr[1], Vector2(lx + 32, ry), 24, HT.DIM)
				txt("%%%d" % roundi(100.0 * rr[2] / maxf(rr[3], 1.0)), Vector2(lx + 32 + tw(rr[1], 24) + 12, ry), 24, Color(rr[5], 0.8))
				txt(fmt(int(rr[2])), Vector2(rc.end.x - 228, ry - 6), 32, HT.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 200)
				bar(Rect2(lx, ry + 32, cw - 56, 12), rr[2] / maxf(rr[4], 1.0), rr[5])
			var fy := rc.end.y - 50
			if p["last"]:
				parts([["i", "skull", 2.0], ["t", "Son ayakta · ", HT.GOOD], ["t", clock(p["death"]), HT.TEXT]], cx, fy, 24)
			else:
				parts([["i", "skull", 2.0], ["t", "Düştü · ", HT.DIM], ["t", clock(p["death"]), HT.TEXT]], cx, fy, 24)
		## kazanım çipleri
		var rws := rewards()
		var chips_w := 0.0
		for rw: Array in rws:
			chips_w += glyph_size(rw[0], 3.0).x + tw(rw[1], 24) + 52.0
		chips_w += (rws.size() - 1) * 20.0
		var x := roundf(960 - chips_w * 0.5)
		for rw: Array in rws:
			var w := glyph_size(rw[0], 3.0).x + tw(rw[1], 24) + 52.0
			var rc := Rect2(x, 806, w, 52)
			well(rc)
			glyph(rw[0], Vector2(x + 20 + glyph_size(rw[0], 3.0).x * 0.5, mid_y(rc.position.y + 12, 24)), 3.0)
			txt(rw[1], Vector2(x + 32 + glyph_size(rw[0], 3.0).x, rc.position.y + 12), 24, rw[3])
			x += w + 20.0
		focus.append(Rect2(x0 - 20, y - 30, 2.0 * cw + gap + 40, ch + 50))

	## C - Koşu Çizelgesi: solda başlık + 2x2 stat + kazanımlar + düğmeler; sağda koşunun zaman çizelgesi (kademe dilimleri,
	## boss işaretleri, kim ne zaman düştü) ve altında portreli takım tablosu.
	func _draw_c() -> void:
		var L := Rect2(100, 84, 620, 912)
		plate(L)
		txt("OYUN BİTTİ", Vector2(L.position.x, 116), 64, HT.BAD, HORIZONTAL_ALIGNMENT_CENTER, L.size.x)
		txt(subtitle, Vector2(L.position.x, 190), 24, HT.DIM, HORIZONTAL_ALIGNMENT_CENTER, L.size.x)
		divider(140, 680, 232)
		var tl := tiles()
		for i in 4:
			tile(Rect2(124 + (i % 2) * 294.0, 256 + (i / 2) * 128.0, 278, 112), tl[i])
		txt("KAZANIMLAR", Vector2(124, 528), 24, HT.ACCENT)
		glyph("soul", Vector2(150, 600), 4.0)
		txt("+%d" % SHARDS, Vector2(184, 568), 48, SOUL_L)
		txt("Ruh Kıymığı", Vector2(184 + tw("+%d" % SHARDS, 48) + 14, 586), 24, HT.DIM)
		var rws := rewards()
		for i in range(1, rws.size()):
			var ly := 650 + (i - 1) * 38.0
			glyph(rws[i][0], Vector2(150, mid_y(ly, 24)), 3.0)
			txt(rws[i][1], Vector2(184, ly), 24, rws[i][3])
		var R := Rect2(752, 84, 1068, 912)
		plate(R)
		txt("KOŞUNUN HİKAYESİ", Vector2(784, 110), 32, HT.ACCENT)
		txt("%s · %d kademe" % [clock(RUN_TIME), RUN_TIER], Vector2(R.end.x - 432, 116), 24, HT.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 400)
		## zaman çizelgesi
		var bx := 804.0
		var bw := 970.0
		var by := 236.0
		var bh := 32.0
		var tx := func(t: float) -> float: return roundf(bx + bw * t / RUN_TIME)
		frame(Rect2(bx - 3, by - 3, bw + 6, bh + 6), Color(0, 0, 0, 0), HT.OUTLINE, 3.0)
		for k in TIER_STARTS.size():
			var xa: float = tx.call(TIER_STARTS[k])
			var xb: float = tx.call(TIER_STARTS[k + 1] if k + 1 < TIER_STARTS.size() else RUN_TIME)
			var col := HT.RIM if k % 2 == 0 else HT.RIM_LO
			if k == TIER_STARTS.size() - 1:
				col = HT.BAD.darkened(0.55)
			r(xa, by, xb - xa, bh, col)
			r(xa, by, xb - xa, 3, col.lightened(0.18))
			txt(TierDisplayRoman(k + 1), Vector2(xa, by + 4), 24, HT.TEXT, HORIZONTAL_ALIGNMENT_CENTER, xb - xa)
			if k > 0:
				r(xa - 1, by - 6, 3, bh + 12, HT.OUTLINE)
				txt(clock(TIER_STARTS[k]), Vector2(xa - 60, by + bh + 8), 24, HT.DIM, HORIZONTAL_ALIGNMENT_CENTER, 120)
			if BOSS_AT.has(k + 1):
				skull(Vector2(xa + 6, by - 36), 3.0)
				txt(BOSS_AT[k + 1], Vector2(xa + 40, by - 40), 24, HT.BAD)
		txt("00:00", Vector2(bx - 4, by + bh + 8), 24, HT.DIM)
		## düşüş işaretleri: sıraya göre şerit (yan yana gelenler alt şeride)
		var order: Array = range(team.size())
		order.sort_custom(func(a, b): return float(team[a]["death"]) < float(team[b]["death"]))
		var lane_last: Array = [-1000.0, -1000.0]
		for idx in order:
			var p: Dictionary = team[idx]
			var x: float = tx.call(p["death"])
			var lane := 0 if x - lane_last[0] >= 120.0 else 1
			lane_last[lane] = x
			var py := 330.0 + lane * 142.0
			r(x - 1, by + bh, 3, py - by - bh, Color(HT.RIM_HI, 0.7))
			r(x - 4, by + bh - 2, 9, 9, HT.BAD)
			var pr := portrait(Vector2(x - 32, py), p, 1.0)
			txt(p["name"], Vector2(x - 70, pr.end.y + 4), 24, HT.ACCENT if p["me"] else HT.TEXT, HORIZONTAL_ALIGNMENT_CENTER, 140)
			txt(clock(p["death"]), Vector2(x - 70, pr.end.y + 30), 24, HT.GOOD if p["last"] else HT.DIM, HORIZONTAL_ALIGNMENT_CENTER, 140)
		txt("İLK DÜŞEN", Vector2(bx, 336), 24, HT.DIM)
		txt(team[order[0]]["name"] + " · " + clock(team[order[0]]["death"]), Vector2(bx, 362), 24, HT.TEXT)
		team_rows(R.position.x + 24, R.size.x - 48, 618, {"dmg": R.position.x + 360, "dmg_w": 240.0, "tank": R.position.x + 660, "tank_w": 190.0})
		focus.append(Rect2(R.position.x, R.position.y, R.size.x, 520))

	static func TierDisplayRoman(n: int) -> String:
		return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"][n - 1]

	## D - Sinematik Perde: pencere YOK; üst/alt siyah perde, dünya solar ve ceset ışık lekesinde kalır, dünyanın üstünde büyük
	## başlık; üst perdede tek satır özet, alt perdede oyuncu şeridi + kazanımlar + düğmeler.
	func _draw_d() -> void:
		var bar_c := Color(0.045, 0.03, 0.02, 0.97)
		r(0, 0, 1920, 112, bar_c)
		r(0, 112, 1920, 3, HT.RIM_LO)
		r(0, 852, 1920, 228, bar_c)
		r(0, 849, 1920, 3, HT.RIM_LO)
		parts(summary_parts(), 960, 36, 32)
		title_on_world("OYUN BİTTİ", 172, 96, HT.BAD)
		title_on_world(subtitle, 300, 32, HT.TEXT)
		var bw := 340.0
		for i in team.size():
			var p: Dictionary = team[i]
			var bx := 60.0 + i * bw
			var pr := portrait(Vector2(bx, 880), p, 1.0)
			if p["award"] == "EN ÇOK HASAR":
				glyph("crown", Vector2(pr.get_center().x, pr.position.y - 8), 3.0)
			var nx := bx + 82
			txt(p["name"], Vector2(nx, 872), 32, HT.ACCENT if p["me"] else HT.TEXT)
			if p["award"] != "":
				txt(AWARD_SHORT.get(p["award"], ""), Vector2(nx + tw(p["name"], 32) + 12, 880), 16, award_color(p["award"]))
			var line: Array = [["i", "dmg", 1.0], ["t", fmt(int(p["dealt"])) + "   ", HT.TEXT], ["i", "skull", 2.0], ["t", str(int(p["kills"])), HT.TEXT]]
			parts(line, nx + parts_w(line, 24) * 0.5, 910, 24)
			var dt := ("Son ayakta · " if p["last"] else "Düştü · ") + clock(p["death"])
			txt(dt, Vector2(nx, 940), 24, HT.GOOD if p["last"] else HT.DIM)
		var rp: Array = []
		var rws := rewards()
		for i in rws.size():
			if i > 0:
				rp.append(["sep"])
			rp.append(["i", rws[i][0], 3.0])
			rp.append(["t", rws[i][1], rws[i][3]])
		parts(rp, 960, 1026, 24)
		focus.append(Rect2(0, 840, 1920, 240))


var _keep: Array = []


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
	img.save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])
	return img


func _shader_rect(code: String) -> ColorRect:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	var cr := ColorRect.new()
	cr.material = m
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cr


func _add_buttons(parent: Control, k: String, uk: GDScript) -> void:
	var labels := ["Yeniden Başla", "Ana Menüye Dön"]
	var variants := ["green", "hud"]
	var specs: Array = BUTTONS[k]
	var btns: Array = []
	var same := 0.0
	for i in 2:
		var s: Array = specs[i]
		var b := Button.new()
		b.text = labels[i]
		b.theme = uk.theme()
		uk.style_button(b, variants[i], false, 32)
		b.focus_mode = Control.FOCUS_NONE
		parent.add_child(b)
		btns.append(b)
		same = maxf(same, maxf(float(s[2]), b.get_combined_minimum_size().x)) ## kit dokusunun asgari genişliği
	## İki düğme aynı genişlikte: A/B ortada yan yana, C sola yaslı alt alta, D sağa yaslı alt alta.
	for i in 2:
		var s: Array = specs[i]
		var x: float = s[0]
		if k == "A" or k == "B":
			x = roundf(960.0 - (2.0 * same + 24.0) * 0.5 + i * (same + 24.0))
		elif k == "D":
			x = s[0] + s[2] - same
		var b: Button = btns[i]
		b.custom_minimum_size = Vector2(same, s[3])
		b.position = Vector2(x, s[1])
		b.size = Vector2(same, s[3])


func _hide_hud(hud: Node, on: bool) -> void:
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = not on
	for n in hud.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = not on


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var only: String = OS.get_environment("OYUN_BITTI_ONLY")
	var kinds: Array = ["simdi", "A", "B", "C", "D"]
	if only != "":
		kinds = Array(only.split(","))
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", CHAR_ID)
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_character", chars.get_def(CHAR_ID).get("skill", 1))
	gm.set("selected_pet", "peri")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	## Gerçek kayıtlara (rekor/balans/Ruh Kıymığı) HİÇ yazılmasın: koşu sonu "işlendi" sayılır.
	current_scene.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
	await _wait(2.5)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	if player:
		player.global_position += Vector2(40, 170)
	gm.set("owned_items", [{"key": "ruzgar_eldiveni"}, {"key": "anka_kusunun_kalbi"}, {"key": "zaman_kiran"}])
	for i in range(1, TEAM.size()):
		var t: Dictionary = TEAM[i]
		var a := FakeAlly.new()
		a.peer_id = 1000 + i
		a.player_name = t["name"]
		a.char_id = t["char"]
		a.match_damage_dealt = t["dealt"]
		current_scene.add_child(a)
		a.add_to_group("remote_players")
		if player:
			a.global_position = player.global_position + Vector2(-300 + 300 * (i - 1), -140)
	var hud: Node = current_scene.get_node_or_null("HUD")
	if hud:
		hud.call("update_level", RUN_LEVEL)
	await _wait(1.0)
	## Yerel oyuncu ölüm klibinde yere yığılır ve son karede kalır (oyun mantığı durur, sadece sprite oynar).
	if player:
		player.set("health", 0.0)
		player.process_mode = Node.PROCESS_MODE_DISABLED
		for nn in ["ShieldVisual", "OverheadBar", "NameLabel", "DownedTimerLabel"]: ## ölüde görünmezler
			var vn := player.get_node_or_null(nn) as CanvasItem
			if vn:
				vn.visible = false
		var anim: AnimatedSprite2D = player.get("anim")
		if anim:
			anim.process_mode = Node.PROCESS_MODE_ALWAYS
			var ca: GDScript = load("res://scripts/char_anim.gd")
			var clip: String = ca.pick(anim.sprite_frames, ["death_down", "death"])
			if clip != "":
				anim.sprite_frames.set_animation_loop(clip, false)
				anim.play(clip)
	Input.warp_mouse(Vector2(1700, 560))
	await _wait(1.8)

	## Koşu verisi (mevcut ekran bunları GameManager/_run_results/_match_stats_by_peer'den okur)
	gm.set("run_max_tier", RUN_TIER)
	gm.set("team_level", RUN_LEVEL)
	gm.set("run_kills", int(TEAM[0]["kills"]))
	var stats: Dictionary = {}
	var my_id: int = current_scene.multiplayer.get_unique_id() if current_scene.multiplayer.has_multiplayer_peer() else 0
	var team_env: String = OS.get_environment("OYUN_BITTI_TEAM")
	var full: Array = TEAM.duplicate() + (TEAM_EXTRA if team_env == "8" else [])
	if team_env == "1":
		full = [TEAM[0]]
	for i in full.size():
		var t: Dictionary = full[i]
		stats[my_id if i == 0 else 1000 + i] = {"name": t["name"], "dealt": t["dealt"], "taken": t["taken"], "kills": t["kills"]}
		if i >= TEAM.size(): ## ek arkadaşların kuklası (portre için char_id)
			var a := FakeAlly.new()
			a.peer_id = 1000 + i
			a.player_name = t["name"]
			a.char_id = t["char"]
			current_scene.add_child(a)
			a.add_to_group("remote_players")
	if team_env == "1":
		for rp: Node in current_scene.get_tree().get_nodes_in_group("remote_players"):
			rp.remove_from_group("remote_players")
	current_scene.set("_match_stats_by_peer", stats)
	current_scene.set("_run_results", {"records": RECORDS.duplicate(), "achievements": ACHIEVEMENTS.duplicate(), "shards": SHARDS})

	var ach: GDScript = load("res://scripts/achievements.gd")
	var adef: Dictionary = ach.def_of(ACHIEVEMENTS[0])
	var td: GDScript = load("res://scripts/tier_display.gd")
	var rr: GDScript = load("res://scripts/run_records.gd")
	var uk: GDScript = load("res://scripts/ui_kit.gd")
	## Ödüller: her oyuncuya en fazla bir unvan (hasar > tank > öldürme > son ayakta / ilk düşen).
	var awards: Dictionary = {}
	for key_award: Array in [["dealt", "EN ÇOK HASAR"], ["taken", "EN ÇOK TANK"], ["kills", "EN ÇOK ÖLDÜRME"]]:
		var best := -1
		for i in TEAM.size():
			if awards.has(i):
				continue
			if best < 0 or float(TEAM[i][key_award[0]]) > float(TEAM[best][key_award[0]]):
				best = i
		awards[best] = key_award[1]
	var last_i := 0
	var first_i := 0
	for i in TEAM.size():
		if float(TEAM[i]["death"]) > float(TEAM[last_i]["death"]):
			last_i = i
		if float(TEAM[i]["death"]) < float(TEAM[first_i]["death"]):
			first_i = i
	for i in TEAM.size():
		if not awards.has(i):
			awards[i] = "SON AYAKTA KALAN" if i == last_i else ("İLK DÜŞEN" if i == first_i else "")
	var team: Array = []
	for i in TEAM.size():
		var t: Dictionary = TEAM[i]
		var d: Dictionary = chars.get_def(int(t["char"]))
		team.append({"name": t["name"], "cname": d.get("name", "?"), "tex": load(str(d.get("portrait", ""))),
				"dealt": t["dealt"], "taken": t["taken"], "kills": t["kills"], "death": t["death"],
				"me": t.get("me", false), "award": awards.get(i, ""), "last": i == last_i})
	var font: Font = load("res://assets/fonts/m5x7.ttf")
	var icons := {"dmg": load("res://assets/ui/stat_mini/damage.png"), "shield": load("res://assets/ui/stat_mini/shield_amount.png")}

	var shots: Dictionary = {}
	for k: String in kinds:
		var layers: Array = []
		if k == "simdi" or k == "oyunda":
			gm.set("run_clock_origin", float(gm.get("game_time")) - RUN_TIME)
			current_scene.call("_show_death_overlay", true)
			## mevcut ekran tek oyunculuda "Öldün." der; çok oyunculu metni göster (tablo 4 kişilik)
			var sub: Label = current_scene.get("_death_overlay_layer").get_node_or_null("Window/VBox/Subtitle")
			if sub and team_env != "1":
				sub.text = "Tüm takım elendi."
			var capl := CanvasLayer.new()
			capl.layer = 99
			var cp := Proto.new()
			cp.kind = k
			cp.font = font
			capl.add_child(cp)
			root.add_child(capl)
			layers.append(capl)
		else:
			if hud:
				_hide_hud(hud, true)
			var bg := CanvasLayer.new()
			bg.layer = 94
			match k:
				"A", "C":
					bg.add_child(_shader_rect(VIGNETTE))
				"B":
					bg.add_child(_shader_rect(DESAT))
				"D":
					var sr := _shader_rect(SPOT)
					var spot := Vector2(960, 540)
					if player:
						spot = player.get_global_transform_with_canvas().origin + Vector2(0, -12)
					(sr.material as ShaderMaterial).set_shader_parameter("spot", spot)
					bg.add_child(sr)
			root.add_child(bg)
			layers.append(bg)
			var fl := CanvasLayer.new()
			fl.layer = 95
			var pr := Proto.new()
			pr.kind = k
			pr.team = team
			pr.font = font
			pr.plate_sb = uk.panel_style("hud_plaque")
			pr.well_sb = uk.panel_style("hud_inset_tight")
			pr.icons = icons
			pr.tier_fills = Array(td.skull_fills(RUN_TIER))
			pr.record_labels = rr.RECORD_LABELS
			pr.ach_name = str(adef.get("name", ACHIEVEMENTS[0]))
			pr.ach_desc = str(adef.get("desc", ""))
			pr.subtitle = "Tüm takım elendi."
			fl.add_child(pr)
			root.add_child(fl)
			_add_buttons(pr, k, uk)
			layers.append(fl)
		await _wait(0.6)
		var img: Image = await _shot("%s%s.png" % [k, ("_" + team_env) if team_env != "" else ""])
		shots[k] = img
		for l: Node in layers:
			for ch in l.get_children():
				if ch is Proto:
					var n := 0
					for fr: Rect2 in (ch as Proto).focus:
						var cr := Rect2i(fr).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
						var sub_img := img.get_region(cr)
						sub_img.save_png(ProjectSettings.globalize_path(OUT + "yakin_%s%s.png" % [k, "" if n == 0 else str(n + 1)]))
						n += 1
		if k == "simdi" or k == "oyunda":
			var dl: CanvasLayer = current_scene.get("_death_overlay_layer")
			if dl:
				dl.queue_free()
			current_scene.set("_death_overlay_layer", null)
		for l: Node in layers:
			l.queue_free()
		await _wait(0.3)

	## özet: A-D 2x2, yarım boyut
	if shots.has("A") and shots.has("B") and shots.has("C") and shots.has("D"):
		var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
		var order := ["A", "B", "C", "D"]
		for i in 4:
			var im: Image = (shots[order[i]] as Image).duplicate()
			im.convert(Image.FORMAT_RGBA8)
			im.resize(960, 540, Image.INTERPOLATE_LANCZOS)
			@warning_ignore("integer_division")
			sheet.blit_rect(im, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
		sheet.save_png(ProjectSettings.globalize_path(OUT + "ozet.png"))
		print("SHOT ozet.png")
	quit()
