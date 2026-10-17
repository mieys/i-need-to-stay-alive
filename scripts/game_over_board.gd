extends Control

## OYUN BİTTİ ekranının gövdesi - tasarım "A - Ahşap Pano" (madde 224, 2026-10-17; kullanıcı 4 prototipten A'yı seçti, renkleri
## sonra "seyyar satıcıya benzesin" -> shop_dark_kit.gd PAL_SLATE; prototip tools/proto_20261017/oyun_bitti_proto.gd).
## main.gd _show_death_overlay(true) penceresinde başlık/alt yazı ile düğmelerin ARASINDA durur: ayraç + stat kutuları (SÜRE / KADEME kafa ızgarası / [SONSUZ KAT] /
## SEVİYE / ÖLDÜRME) + portreli takım tablosu (hasar/tank çubukları, en çok hasar verene taç) + kazanımlar kuyusu
## (Ruh Kıymığı / yeni rekor / başarım). Hepsi tek _draw'da, piksel ızgaraya oturan dikdörtgenlerle; yazı m5x7.
## Veri: set_summary(özet, sonuçlar) + set_team(stats_by_peer, char_by_peer, my_peer) - ikisi de tekrar tekrar çağrılabilir
## (takımın istatistikleri RPC ile art arda gelir, bkz. main.gd _refresh_match_stats_ui). Zafer penceresi (victory_overlay.gd)
## hâlâ bej kitte ve run_summary_ui.gd'yi kullanır.
## Medallion (iç sınıf): pencerenin üst kenarına binen kuru kafa madalyonu.

const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const BossArt := preload("res://scripts/boss_bar_art.gd")
const TierDisplay := preload("res://scripts/tier_display.gd")
const RunSummaryUI := preload("res://scripts/run_summary_ui.gd")
const RunRecords := preload("res://scripts/run_records.gd")
const Achievements := preload("res://scripts/achievements.gd")
const MetaProgress := preload("res://scripts/meta_progress.gd")
const FONT := preload("res://assets/fonts/m5x7.ttf")
const ICON_DMG := preload("res://assets/ui/stat_mini/damage.png")
const ICON_SHIELD := preload("res://assets/ui/stat_mini/shield_amount.png")

const W := 1120.0 ## gövde genişliği (pencere 1200 = W + 2 x 40 pay)
const TILE_H := 112.0
const ROW_GAP := 6.0
const COMPACT_FROM := 5 ## bu kadar ve fazla oyuncuda satırlar alçalır (8 oyuncu ekrana sığsın)

## Renkler Seyyar Satıcı "Klasik Pazar" kitiyle aynı (kullanıcı 2026-10-17: "renk olarak seyyar satıcıya benzesin", ilk sürümün
## HUD kahvesini sevmedi): shop_dark_kit.gd PAL_SLATE değerleri + piksel simgelerin dış hattı. Pencere/düğmeler main.gd'de aynı kitle.
class HT:
	const OUTLINE := Color("#0b0e15") ## piksel simge/çubuk dış hattı (kayrağın en koyusu)
	const PANEL := Color("#1b212e") ## PAL_SLATE panel
	const STRIPE := Color("#242c3b") ## panel2: satır şeridi
	const RIM_LO := Color("#2f3a4f") ## panel3
	const INSET := Color("#121722") ## inset: kuyu/çubuk içi
	const RIM := Color("#353f55") ## line
	const RIM_HI := Color("#56657f") ## line_hi
	const TEXT := Color("#ece6d7")
	const DIM := Color("#96a0b2")
	const ACCENT := Color("#d9b46a") ## altın
	const PRICE := Color("#eccb7e")
	const GOOD := Color("#94c97e")
	const BAD := Color("#dc8676")

const BONE := Color("#e9dcc0")
const DMG := Color("#e8885a") ## verilen hasar
const TANK := Color("#8cc0e6") ## tanklanan hasar (kalkan mavisi)
const SOUL_L := Color("#e6dcff")
const SOUL_M := Color("#b49cf0")
const SOUL_D := Color("#6f52bc")
const DEAD_MOD := Color(0.58, 0.56, 0.54) ## portreler solgun (herkes öldü)

const HOURGLASS := [
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
const SOUL := [ ## Ruh Kıymığı
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
const CHECK := [
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

var _summary: Dictionary = {}
var _results: Dictionary = {}
## [{name, cname, tex (Texture2D | null), dealt, taken, kills, me}] - en çok hasar veren üstte
var _team: Array = []
var _tex_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_min_size()


## summary: main.gd _run_summary sözlüğü {time, tier, kills, layer, level, ...}; results: _run_results {records, achievements, shards}.
func set_summary(summary: Dictionary, results: Dictionary) -> void:
	_summary = summary.duplicate()
	_results = results.duplicate(true)
	_update_min_size()
	queue_redraw()


## stats_by_peer: {peer: {name, dealt, taken, kills}} (main.gd _match_stats_by_peer); char_by_peer: {peer: karakter id}.
func set_team(stats_by_peer: Dictionary, char_by_peer: Dictionary, my_peer: int) -> void:
	_team.clear()
	for peer in stats_by_peer.keys():
		var e: Dictionary = stats_by_peer[peer]
		var cid: int = int(char_by_peer.get(peer, -1))
		var d: Dictionary = Characters.get_def(cid) if cid >= 0 else {}
		_team.append({"name": str(e.get("name", "?")), "cname": str(d.get("name", "")), "tex": _portrait(str(d.get("portrait", ""))),
				"dealt": float(e.get("dealt", 0.0)), "taken": float(e.get("taken", 0.0)), "kills": int(e.get("kills", 0)),
				"me": int(peer) == my_peer})
	_team.sort_custom(func(a, b): return float(a["dealt"]) > float(b["dealt"]))
	_update_min_size()
	queue_redraw()


func _portrait(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex_cache[path]


# ------------------------------------------------------------ yerleşim
func _compact() -> bool:
	return _team.size() >= COMPACT_FROM


func _row_h() -> float:
	return 58.0 if _compact() else 70.0


func _reward_lines() -> Array:
	## [simge, yazı, renk]
	var out: Array = []
	for key in _results.get("records", []):
		var label: String = str(RunRecords.RECORD_LABELS.get(key, key))
		var value: String = RunSummaryUI.record_value_text(str(key), _summary)
		out.append(["star", "Yeni rekor · %s" % label + (": " + value if value != "" else ""), HT.PRICE])
	for id in _results.get("achievements", []):
		var d: Dictionary = Achievements.def_of(str(id))
		var desc: String = str(d.get("desc", "")).trim_suffix(".")
		out.append(["check", "Başarım · %s" % d.get("name", id) + (" (%s)" % desc if desc != "" else ""), HT.GOOD])
	return out


func _shards() -> int:
	return int(_results.get("shards", 0))


func _rewards_h() -> float:
	var lines: int = _reward_lines().size()
	if lines == 0 and _shards() <= 0:
		return 0.0
	return maxf(124.0 if _shards() > 0 else 0.0, 32.0 + lines * 32.0)


## Gövde: ayraç (0-24) + kutular (32-144) + tablo başlığı (168) + satırlar (204-) + kazanımlar.
func _table_top() -> float:
	return 168.0


func _rows_end() -> float:
	var n: int = maxi(_team.size(), 1)
	return _table_top() + 36.0 + n * (_row_h() + ROW_GAP)


func _update_min_size() -> void:
	var h := _rows_end()
	var rh := _rewards_h()
	if rh > 0.0:
		h += 8.0 + rh
	custom_minimum_size = Vector2(W, h + 4.0)


# ------------------------------------------------------------ piksel yardımcıları
func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), roundf(w), roundf(h)), c)


## Köşeleri bir birim kesik çerçeve (piksel yuvarlak köşe).
func _frame(rc: Rect2, fill: Color, border: Color, bw: float = 3.0) -> void:
	var x := rc.position.x
	var y := rc.position.y
	var w := rc.size.x
	var h := rc.size.y
	if fill.a > 0.0:
		_r(x + bw, y + bw, w - 2.0 * bw, h - 2.0 * bw, fill)
	_r(x + bw, y, w - 2.0 * bw, bw, border)
	_r(x + bw, y + h - bw, w - 2.0 * bw, bw, border)
	_r(x, y + bw, bw, h - 2.0 * bw, border)
	_r(x + w - bw, y + bw, bw, h - 2.0 * bw, border)


static var _well_sb: StyleBox = null


## Satıcının iç kutusu: kuyu dolgusu + çizgi kenar, 45° pahlı piksel köşe (shop_dark_kit.gd sb).
func _well(rc: Rect2) -> void:
	if _well_sb == null:
		_well_sb = DarkKit.new(DarkKit.PAL_SLATE).sb(HT.INSET, HT.RIM, 3, 6)
	draw_style_box(_well_sb, rc)


func _sprite(rows: Array, pos: Vector2, s: float, cols: Dictionary) -> void:
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			var ch: String = row[i]
			if cols.has(ch):
				_r(pos.x + i * s, pos.y + j * s, s, s, cols[ch])


## fill: 2 dolu, 1 yarım (sol yarı), 0 boş - kademe göstergesinin kafa dili (tier_display.gd).
static func draw_skull(ci: CanvasItem, pos: Vector2, s: float, fill: int = 2) -> void:
	var dim_w := Color(HT.RIM_HI, 0.55)
	var rows: Array = BossArt.SKULL_ROWS
	for j in rows.size():
		var row: String = rows[j]
		for i in row.length():
			var c: Color
			var on: bool = fill == 2 or (fill == 1 and i <= TierDisplay.HALF_COL)
			match row[i]:
				"X":
					c = HT.OUTLINE
				"W":
					c = BONE if on else dim_w
				"K":
					c = Color("#2a1a10") if on else Color(HT.OUTLINE, 0.7)
				_:
					continue
			ci.draw_rect(Rect2(roundf(pos.x + i * s), roundf(pos.y + j * s), s, s), c)


func _skull(pos: Vector2, s: float, fill: int = 2) -> void:
	draw_skull(self, pos, s, fill)


## 3x2 kafa ızgarası (KADEME kutusunun simgesi).
func _tier_grid(c: Vector2, s: float) -> void:
	var fills: Array = Array(TierDisplay.skull_fills(int(_summary.get("tier", 1))))
	var cw := 9.0 * s
	var g := 3.0
	var x0 := c.x - (3.0 * cw + 2.0 * g) * 0.5
	var y0 := c.y - (2.0 * cw + g) * 0.5
	for k in fills.size():
		@warning_ignore("integer_division")
		_skull(Vector2(x0 + (k % 3) * (cw + g), y0 + (k / 3) * (cw + g)), s, int(fills[k]))


func _glyph_size(key: String, s: float) -> Vector2:
	match key:
		"hg":
			return Vector2(13, 18) * s
		"skull", "star", "check":
			return Vector2(9, 9) * s
		"crown":
			return Vector2(11, 8) * s
		"soul":
			return Vector2(7, 11) * s
		"dmg", "shield":
			return Vector2(24, 24) * s
	return Vector2.ZERO


## Simgeyi c merkezine çizer.
func _glyph(key: String, c: Vector2, s: float) -> void:
	var sz := _glyph_size(key, s)
	var p := Vector2(roundf(c.x - sz.x * 0.5), roundf(c.y - sz.y * 0.5))
	match key:
		"hg":
			_sprite(HOURGLASS, p, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "H": Color(1, 1, 1, 0.5),
					"G": Color(0.75, 0.85, 0.9, 0.3), "g": Color(0.55, 0.7, 0.8, 0.14), "S": Color("#e8b860")})
		"skull":
			_skull(p, s)
		"star":
			_sprite(STAR, p, s, {"O": HT.OUTLINE, "Y": HT.PRICE})
		"check":
			_sprite(CHECK, p, s, {"O": HT.OUTLINE, "G": Color("#5f9a3c"), "W": Color("#f3f0d8")})
		"crown":
			_sprite(CROWN, p, s, {"O": HT.OUTLINE, "Y": HT.PRICE, "H": Color("#c48a3a"), "R": Color("#d9574a")})
		"soul":
			_sprite(SOUL, p, s, {"O": HT.OUTLINE, "L": SOUL_L, "M": SOUL_M, "D": SOUL_D})
		"dmg":
			draw_texture_rect(ICON_DMG, Rect2(p, sz), false)
		"shield":
			draw_texture_rect(ICON_SHIELD, Rect2(p, sz), false)


func _tw(s: String, size: int) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## pos = yazı kutusunun sol üstü; en fazla 3 px aşağı-sağ gölge.
func _txt(s: String, pos: Vector2, size: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var u: float = minf(size / 8.0, 3.0)
	var base := Vector2(roundf(pos.x), roundf(pos.y + FONT.get_ascent(size)))
	draw_string(FONT, base + Vector2(u, u), s, align, width, size, Color(HT.OUTLINE, 0.9))
	draw_string(FONT, base, s, align, width, size, c)


## Yazının görünür orta çizgisi (simgeleri hizalamak için).
func _mid_y(y: float, size: int) -> float:
	return y + FONT.get_ascent(size) - size * 0.42


func _bar(rc: Rect2, frac: float, fill: Color) -> void:
	_frame(rc, HT.INSET, HT.OUTLINE, 3.0)
	var inner := rc.grow(-3.0)
	var w := roundf(inner.size.x * clampf(frac, 0.0, 1.0))
	_r(inner.position.x, inner.position.y, w, inner.size.y, fill)
	_r(inner.position.x, inner.position.y, w, 3.0, fill.lightened(0.35))


func _divider(xa: float, xb: float, y: float) -> void:
	_r(xa, y, xb - xa, 3, Color(HT.OUTLINE, 0.8))
	_r(xa, y + 3, xb - xa, 3, Color(HT.RIM_HI, 0.3))
	_sprite(DIAMOND, Vector2(roundf((xa + xb) * 0.5) - 10, y - 8), 3.0, {"O": HT.OUTLINE, "A": HT.ACCENT})


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ------------------------------------------------------------ çizim
func _draw() -> void:
	_divider(40, W - 40, 8)
	_draw_tiles(32.0)
	_draw_table(_table_top())
	var rh := _rewards_h()
	if rh > 0.0:
		_draw_rewards(Rect2(0, _rows_end() + 8.0, W, rh))


func _tiles() -> Array:
	var kills: int = int(_summary.get("kills", 0))
	if _team.size() > 1: ## çok oyunculuda takımın toplamı (tabloda kişi başı var)
		kills = 0
		for p in _team:
			kills += int(p["kills"])
	var out: Array = [["hg", "SÜRE", RunSummaryUI.format_time(float(_summary.get("time", 0.0)))],
			["tier", "KADEME", TierDisplay.to_roman(int(_summary.get("tier", 1)))]]
	if int(_summary.get("layer", 0)) > 0:
		out.append(["star", "SONSUZ KAT", str(int(_summary["layer"]))])
	out.append(["star", "SEVİYE", str(int(_summary.get("level", 1)))])
	out.append(["skull", "ÖLDÜRME", fmt(kills)])
	return out


func _draw_tiles(y: float) -> void:
	var tl := _tiles()
	var gap := 16.0
	var tw_ := floorf((W - (tl.size() - 1) * gap) / tl.size())
	var x0 := roundf((W - (tl.size() * tw_ + (tl.size() - 1) * gap)) * 0.5)
	for i in tl.size():
		var t: Array = tl[i]
		var rc := Rect2(x0 + i * (tw_ + gap), y, tw_, TILE_H)
		_well(rc)
		var ic := Vector2(rc.position.x + 46, rc.get_center().y)
		match t[0]:
			"hg":
				_glyph("hg", ic, 2.0)
			"tier":
				_tier_grid(ic, 2.0)
			_:
				_glyph(t[0], ic, 4.0)
		_txt(t[1], Vector2(rc.position.x + 88, rc.position.y + 16), 24, HT.DIM)
		_txt(t[2], Vector2(rc.position.x + 88, rc.position.y + 46), 48, HT.ACCENT if t[0] == "tier" else HT.TEXT)


## Ölü oyuncu yuvası: 48 px portre 1:1, solgun + sağ altta kuru kafa rozeti. pad 8 (64 px yuva) ya da sıkışıkta 4 (56).
func _portrait_slot(pos: Vector2, p: Dictionary, pad: float) -> void:
	var rc := Rect2(pos, Vector2(48.0 + 2.0 * pad, 48.0 + 2.0 * pad))
	_frame(rc, HT.INSET, HT.ACCENT if p["me"] else HT.OUTLINE, 3.0)
	var tex: Texture2D = p["tex"]
	if tex:
		draw_texture_rect(tex, Rect2(pos + Vector2(pad, pad), Vector2(48, 48)), false, DEAD_MOD)
	else:
		_skull(pos + Vector2(pad + 6, pad + 6), 4.0)
	var bsz := 22.0
	var bp := rc.end - Vector2(16, 16)
	_r(bp.x, bp.y, bsz, bsz, HT.OUTLINE)
	_skull(bp + Vector2(2, 2), 2.0)


func _stat_cell(pos: Vector2, icon: String, v: float, vmax: float, col: Color, w: float, bar_y: float) -> void:
	_glyph(icon, pos + Vector2(12, 20), 1.0)
	_txt(fmt(int(round(v))), pos + Vector2(32, 4), 32, HT.TEXT)
	_bar(Rect2(pos.x, pos.y + bar_y, w, 12), v / maxf(vmax, 1.0), col)


func _draw_table(y: float) -> void:
	var x0 := 0.0
	var right := W - 24.0
	var c_dmg := 430.0
	var c_tank := 740.0
	_txt("OYUNCU", Vector2(x0 + 16, y), 24, HT.DIM)
	_txt("VERDİĞİ HASAR", Vector2(c_dmg, y), 24, HT.DIM)
	_txt("TANKLADIĞI", Vector2(c_tank, y), 24, HT.DIM)
	_txt("ÖLDÜRME", Vector2(right - 200, y), 24, HT.DIM, HORIZONTAL_ALIGNMENT_RIGHT, 200)
	var md := 0.0
	var mt := 0.0
	for p in _team:
		md = maxf(md, float(p["dealt"]))
		mt = maxf(mt, float(p["taken"]))
	var rh := _row_h()
	var pad := 4.0 if _compact() else 8.0
	var bar_y := 40.0 if _compact() else 44.0
	var ry := y + 36.0
	if _team.is_empty():
		_txt("Takım istatistikleri bekleniyor...", Vector2(x0, ry + 20), 24, HT.DIM, HORIZONTAL_ALIGNMENT_CENTER, W)
		return
	for k in _team.size():
		var p: Dictionary = _team[k]
		if p["me"]:
			_r(x0, ry, W, rh, HT.STRIPE)
			_r(x0, ry, 6, rh, HT.ACCENT)
		elif k % 2 == 1:
			_r(x0, ry, W, rh, Color(HT.STRIPE, 0.45))
		var slot := 48.0 + 2.0 * pad
		_portrait_slot(Vector2(x0 + 16, ry + roundf((rh - slot) * 0.5)), p, pad)
		var nx := x0 + 34.0 + slot
		_txt(p["name"], Vector2(nx, ry + (2 if _compact() else 4)), 32, HT.ACCENT if p["me"] else HT.TEXT)
		if k == 0 and _team.size() > 1:
			_glyph("crown", Vector2(nx + _tw(p["name"], 32) + 30, ry + 20), 3.0) ## en çok hasar
		_txt(p["cname"], Vector2(nx, ry + (32 if _compact() else 38)), 24, HT.DIM)
		_stat_cell(Vector2(c_dmg, ry + 2), "dmg", p["dealt"], md, DMG, 250.0, bar_y)
		_stat_cell(Vector2(c_tank, ry + 2), "shield", p["taken"], mt, TANK, 210.0, bar_y)
		var ks := fmt(int(p["kills"]))
		var ky := ry + roundf((rh - 32.0) * 0.5) - 2.0
		_txt(ks, Vector2(right - 160, ky), 32, HT.TEXT, HORIZONTAL_ALIGNMENT_RIGHT, 160)
		_glyph("skull", Vector2(right - _tw(ks, 32) - 26, _mid_y(ky, 32)), 3.0)
		ry += rh + ROW_GAP


func _draw_rewards(rw: Rect2) -> void:
	_well(rw)
	var lx := rw.position.x + 40
	if _shards() > 0:
		_glyph("soul", Vector2(rw.position.x + 52, rw.position.y + 62), 5.0)
		_txt("+%d" % _shards(), Vector2(rw.position.x + 94, rw.position.y + 22), 48, SOUL_L)
		_txt(MetaProgress.CURRENCY_NAME, Vector2(rw.position.x + 94, rw.position.y + 76), 24, HT.DIM)
		_r(rw.position.x + 300, rw.position.y + 18, 3, rw.size.y - 36, Color(HT.OUTLINE, 0.8))
		_r(rw.position.x + 303, rw.position.y + 18, 3, rw.size.y - 36, Color(HT.RIM_HI, 0.25))
		lx = rw.position.x + 332
	var lines := _reward_lines()
	var ly := rw.position.y + 16.0
	if lines.size() < 3 and _shards() > 0: ## az satır kuyunun ortasına
		ly = rw.position.y + roundf((rw.size.y - lines.size() * 32.0) * 0.5)
	for ln: Array in lines:
		_glyph(ln[0], Vector2(lx + 12, _mid_y(ly, 24)), 3.0)
		_txt(ln[1], Vector2(lx + 40, ly), 24, ln[2])
		ly += 32.0


## Pencerenin üst kenarına binen kuru kafa madalyonu (yüksekliği 0; çizim kutusunun YUKARISINA taşar).
class Medallion extends Control:
	const RAD := 56.0
	var lift := 52.0 ## madalyon merkezi bu kadar yukarıda

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 0)

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
		_disk(c, RAD, 4, HT.OUTLINE)
		_disk(c, RAD - 4, 4, HT.RIM_HI)
		_disk(c, RAD - 10, 4, HT.RIM)
		_disk(c, RAD - 12, 4, HT.OUTLINE)
		_disk(c, RAD - 16, 4, HT.INSET)
		var board: GDScript = load("res://scripts/game_over_board.gd") ## dış betiğin statik çizicisi (kendini preload edemez)
		board.draw_skull(self, c - Vector2(27, 27), 6.0)


const VIGNETTE := """shader_type canvas_item;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.6, 1.0));
	COLOR = vec4(0.02, 0.025, 0.04, mix(0.5, 0.86, smoothstep(0.1, 0.8, d)));
}
"""


## Oyun bitti karartması: kenarlara doğru koyulaşan kahve vinyet (izleyici modunun düz karartmasının yerine).
static func vignette_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = VIGNETTE
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
