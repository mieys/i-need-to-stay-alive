extends SceneTree

## BİLDİRİM PANELLERİ PROTOTİPLERİ (2026-10-18). Kullanıcı: "görev tamamlandı ve diğer bildirim panelleri için yeni 4 prototip
## hazırla" + "ayrıca diğer oyuncular bekleniyor paneli de dahil buna".
## Şu anki: mission_complete_window.gd (üst orta bej pencere, altın/parçacık), main.gd _show_network_toast (sağda bej levha:
## görev başlayacak/başladı/başarısız, seyyar satıcı, başarım, oyuncu ayrıldı, sonsuz mod; kademe = _tier_banner üst orta),
## bekleme = _show_level_up_wait_overlay / _show_chest_wait_overlay / _show_mini_shop_wait_overlay (%55 karartma + 720x220 bej).
## Oyuna BAĞLI DEĞİL: gerçek SP main.tscn açılır, 3 sahte arkadaş, her prototip ayrı CanvasLayer olarak üstüne çizilir.
##  A Ahşap Levha / B Ateş Işığı Şeridi / C Madalyon ve Sancak / D Kayrak Kuyruk (+ "simdi" = gerçek mevcut ekran).
## Her yön için 3 çekim: <k>.png (görev bitti + 2 bildirim aynı anda), katalog_<k>.png (bütün türler), bekleme_<k>.png.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261018/bildirim_proto.gd
##   BILDIRIM_ONLY = "simdi,A" gibi seçili yönler (boşsa hepsi + ozet.png / ozet_bekleme.png).

const OUT := "res://tools/proto_20261018/out/bildirim/"
const HT := preload("res://scripts/hud_theme.gd")
const TierDisplayScript := preload("res://scripts/tier_display.gd")
const CHAR_ID := 2 ## yerel oyuncu (Oakley)
const LEFT := 17.0 ## bekleme: kalan saniye
const TOTAL := 25.0 ## NetworkManager.level_up_countdown başlangıcı
const TIER := 4
const TEAM := [
	{"name": "Sen", "char": 2, "ready": true, "me": true},
	{"name": "Mira", "char": 10, "ready": false, "hp": [412.0, 520.0, 180.0, 240.0]},
	{"name": "Kerem", "char": 5, "ready": true, "hp": [160.0, 610.0, 0.0, 0.0]},
	{"name": "Deniz", "char": 15, "ready": false, "hp": [300.0, 380.0, 90.0, 120.0]},
]
const CAPTIONS := {
	"simdi": "ŞU AN",
	"A": "A - Ahşap Levha",
	"B": "B - Ateş Işığı Şeridi",
	"C": "C - Madalyon ve Sancak",
	"D": "D - Kayrak Kuyruk",
}
const SCENE_CAP := {
	"oyun": "görev bitti + 2 bildirim",
	"katalog": "bütün bildirim türleri",
	"bekleme": "oyuncular bekleniyor (kart / sandık / alışveriş: aynı panel, başlık değişir)",
}

## Tür renkleri: görev uyarısı/başlangıcı minimap işaretleriyle aynı aile (uyarı açık mavi "?", aktif kırmızı-turuncu "!").
const CAT := {
	"ok": Color("#f0c070"),
	"warn": Color("#a8d0f0"),
	"start": Color("#f0a060"),
	"fail": Color("#e8735e"),
	"merchant": Color("#9fd4b4"),
	"ach": Color("#c9a2f0"),
	"left": Color("#b8ac96"),
	"tier": Color("#e0604c"),
}
## [başlık, gövde] - gerçek metinler (main.gd MISSION_DESCRIPTIONS, achievements.gd, world_event_manager MISSION_LABELS).
const NOTE := {
	"warn": ["Konvoyu Koru", "Yakında başlıyor. Konumu haritada."],
	"start": ["Konvoyu Koru BAŞLADI", "Konvoyun çevresindeki dairede kalarak onu hedefe kadar it. Uzaklaşırsan geri kayar."],
	"fail": ["Ağacı Koru BAŞARISIZ", "Ağaç yok edildi."],
	"merchant": ["Seyyar Satıcı geldi", "Konumu haritada işaretlendi."],
	"ach": ["Başarım: Ayakta Kal", "V. Kademe'ye ulaş."],
	"left": ["Kerem oyundan ayrıldı", ""],
}
const WARN_SECONDS := 30
const FUSE := {"warn": 0.8, "start": 0.55, "fail": 0.35, "merchant": 0.7, "ach": 0.45, "left": 0.25, "ok": 0.75}
const MISSION_DONE := "Bayrağı Ele Geçir"
const GOLD_REWARD := 120
const SHARD_REWARD := 5

## B: fire_menu_kit.gd (ESC/Ayarlar "Ateş Işığı") renkleri
const F_GOLD := Color("#f4c56e")
const F_GOLD_DIM := Color("#e2c08a")
const F_CREAM := Color("#efe2c6")
const F_SUB := Color("#b09878")
const F_RED := Color("#dc7f60")
const F_DARK := Color("#140e09")
## C: sancak kumaşı (HUD ahşabının koyu ucu)
const CLOTH := Color("#2b1d13")
const CLOTH_HI := Color("#4a3322")
## D: shop_dark_kit.gd PAL_SLATE (Seyyar Satıcı + Oyun Bitti)
const SL := {
	"panel": Color("#1b212e"), "panel2": Color("#242c3b"), "inset": Color("#121722"),
	"line": Color("#353f55"), "line_hi": Color("#56657f"), "text": Color("#ece6d7"), "dim": Color("#96a0b2"),
	"accent": Color("#d9b46a"), "accent_text": Color("#21180a"), "good": Color("#94c97e"), "price": Color("#eccb7e"),
}
const RIB_GOLD := {"fill": Color("#d9a54a"), "hi": Color("#f2cd7c"), "dk": Color("#8a5a20"), "text": Color("#2a1a0c")}
const RIB_RED := {"fill": Color("#a8403a"), "hi": Color("#cf6a58"), "dk": Color("#5e1c16"), "text": Color("#f6e6cc")}

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
const XMARK := [
	"OOO   OOO",
	"ORRO ORRO",
	"OORRORROO",
	" OORRROO ",
	"  ORRRO  ",
	" OORRROO ",
	"OORRORROO",
	"ORRO ORRO",
	"OOO   OOO",
]
const FLAG := [
	"OO         ",
	"OWOOOOOOOO ",
	"OWORRRRRRRO",
	"OWORRRRRRO ",
	"OWORRRRRO  ",
	"OWORRRRRRO ",
	"OWORRRRRRRO",
	"OWOOOOOOOO ",
	"OWO        ",
	"OWO        ",
	"OWO        ",
	"OOO        ",
]
const HG_SMALL := [
	"OOOOOOOOO",
	"OWWWWWWWO",
	"OOOOOOOOO",
	" OSSSSSO ",
	"  OSSSO  ",
	"   OSO   ",
	"   OgO   ",
	"  OgSgO  ",
	" OgSSSgO ",
	"OOOOOOOOO",
	"OWWWWWWWO",
	"OOOOOOOOO",
]
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
const BUBBLE := [
	" OOOOOOOOO ",
	"OWWWWWWWWWO",
	"OWDWWDWWDWO",
	"OWWWWWWWWWO",
	" OOWOOOOOO ",
	"  OWO      ",
	"  OO       ",
]

const VIGNETTE := """shader_type canvas_item;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.6, 1.0));
	COLOR = vec4(0.05, 0.03, 0.02, mix(0.18, 0.66, smoothstep(0.15, 0.85, d)));
}
"""
const DESAT := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(g), c, 0.3) * 0.78, 1.0);
}
"""


class FakeAlly extends Node2D:
	var peer_id: int = 0
	var player_name: String = ""
	var char_id: int = 0
	var health: float = 100.0
	var max_health: float = 100.0
	var item_shield_max: float = 0.0
	var item_shield_hp: float = 0.0
	var is_dead: bool = false
	var is_downed: bool = false
	var match_damage_dealt: float = 0.0


## Bir prototipin bir çekimi (tam ekran, fareyi geçirir). Piksel ızgaraya oturan dikdörtgenlerle çizilir.
class Proto extends Control:
	var kind: String = ""
	var scene: String = ""
	var team: Array = [] ## [{name, tex, ready, me}]
	var font: Font = null
	var plaque: StyleBox = null
	var rows: Array = [] ## grup paneli satır dikdörtgenleri (TEAM[1..])
	var rows_bottom: float = 500.0 ## görev satırlarının (world_event_banner) alt kenarı
	var tex: Dictionary = {} ## coin, shard, medal, merchant, kerem
	var _skulls: Dictionary = {}

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

	func sprite(rows_: Array, pos: Vector2, s: float, cols: Dictionary) -> void:
		for j in rows_.size():
			var row: String = rows_[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					r(pos.x + i * s, pos.y + j * s, s, s, cols[ch])

	## Izgarayı c merkezli çizer.
	func grid_c(rows_: Array, c: Vector2, s: float, cols: Dictionary) -> void:
		var w: float = String(rows_[0]).length() * s
		var h: float = rows_.size() * s
		sprite(rows_, Vector2(roundf(c.x - w * 0.5), roundf(c.y - h * 0.5)), s, cols)

	func check(pos: Vector2, s: float) -> void:
		sprite(CHECK, pos, s, {"O": HT.OUTLINE, "G": Color("#5f9a3c"), "W": Color("#f3f0d8")})

	func bubble(pos: Vector2, s: float) -> void:
		sprite(BUBBLE, pos, s, {"O": HT.OUTLINE, "W": HT.TEXT, "D": Color("#4b3320")})

	func hourglass(pos: Vector2, s: float) -> void:
		sprite(HOURGLASS, pos, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "H": Color(1, 1, 1, 0.5),
				"G": Color(0.75, 0.85, 0.9, 0.3), "g": Color(0.55, 0.7, 0.8, 0.14), "S": Color("#e8b860")})

	func tex_c(t: Texture2D, c: Vector2, sz: float, mod: Color = Color.WHITE) -> void:
		if t == null:
			return
		draw_texture_rect(t, Rect2(roundf(c.x - sz * 0.5), roundf(c.y - sz * 0.5), sz, sz), false, mod)

	## Tür simgesi, c merkezli. big = 2 kat (madalyon/büyük pencere).
	func icon(k: String, c: Vector2, big: bool = false) -> void:
		var s := 6.0 if big else 3.0
		match k:
			"ok":
				grid_c(CHECK, c, s, {"O": HT.OUTLINE, "G": Color("#5f9a3c"), "W": Color("#f3f0d8")})
			"warn":
				grid_c(HG_SMALL, c, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "S": Color("#e8b860"), "g": Color(0.55, 0.7, 0.8, 0.3)})
			"start":
				grid_c(FLAG, c, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "R": CAT["start"]})
			"fail":
				grid_c(XMARK, c, s, {"O": HT.OUTLINE, "R": CAT["fail"]})
			"merchant":
				tex_c(tex.get("merchant"), c, 96.0 if big else 48.0)
			"ach":
				tex_c(tex.get("medal"), c, 64.0 if big else 32.0)
			"left":
				tex_c(tex.get("kerem"), c, 96.0 if big else 48.0, Color(0.62, 0.6, 0.58, 0.85))

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

	func diamond(c: Vector2, cell: float, col: Color) -> void:
		r(c.x - cell * 0.5, c.y - cell * 1.5, cell, cell, col)
		r(c.x - cell * 1.5, c.y - cell * 0.5, cell * 3.0, cell, col)
		r(c.x - cell * 0.5, c.y + cell * 0.5, cell, cell, col)

	func tw(s: String, size: int) -> float:
		return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

	## pos = yazı kutusunun sol üstü; en fazla 3 px aşağı-sağ gölge.
	func txt(s: String, pos: Vector2, size: int, c: Color, shadow: bool = true) -> void:
		var u: float = minf(size / 8.0, 3.0)
		var base := Vector2(roundf(pos.x), roundf(pos.y + font.get_ascent(size)))
		if shadow:
			draw_string(font, base + Vector2(u, u), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(HT.OUTLINE, 0.9))
		draw_string(font, base, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

	func txt_c(s: String, cx: float, y: float, size: int, c: Color, shadow: bool = true) -> void:
		txt(s, Vector2(roundf(cx - tw(s, size) * 0.5), y), size, c, shadow)

	func txt_r(s: String, right: float, y: float, size: int, c: Color, shadow: bool = true) -> void:
		txt(s, Vector2(roundf(right - tw(s, size)), y), size, c, shadow)

	## Renkli parçalardan tek satır, cx merkezli.
	func txt_segs(segs: Array, cx: float, y: float, size: int) -> void:
		var total := 0.0
		for sg in segs:
			total += tw(sg[0], size)
		var x := roundf(cx - total * 0.5)
		for sg in segs:
			txt(sg[0], Vector2(x, y), size, sg[1])
			x += tw(sg[0], size)

	func wrap_text(s: String, size: int, width: float) -> PackedStringArray:
		var out := PackedStringArray()
		if s == "":
			return out
		var line := ""
		for w in s.split(" "):
			var cand: String = w if line == "" else line + " " + w
			if line == "" or tw(cand, size) <= width:
				line = cand
			else:
				out.append(line)
				line = w
		if line != "":
			out.append(line)
		return out

	func bar(rc: Rect2, frac: float, fill: Color, inset: Color = HT.INSET) -> void:
		frame(rc, inset, HT.OUTLINE, 3.0)
		var inner := rc.grow(-3.0)
		var w := roundf(inner.size.x * frac)
		r(inner.position.x, inner.position.y, w, inner.size.y, fill)
		r(inner.position.x, inner.position.y, w, 3.0, fill.lightened(0.35))
		r(inner.position.x + w - 3.0, inner.position.y, 3.0, inner.size.y, Color(1, 1, 1, 0.55))

	## 64x64 oyuncu yuvası: portre 1:1 + durum (hazır = yeşil tik, seçiyor = altın kenar + üç nokta balonu).
	func chip(pos: Vector2, p: Dictionary, inset: Color = HT.INSET) -> void:
		var rc := Rect2(pos, Vector2(64, 64))
		var ready: bool = p["ready"]
		if not ready:
			frame(rc.grow(3.0), Color(0, 0, 0, 0), Color(HT.ACCENT, 0.35), 3.0)
		frame(rc, inset, HT.GOOD.darkened(0.25) if ready else HT.ACCENT, 3.0)
		draw_texture_rect(p["tex"], Rect2(pos + Vector2(8, 8), Vector2(48, 48)), false)
		if ready:
			check(pos + Vector2(44, 44), 3.0)
		else:
			bubble(pos + Vector2(36, -12), 3.0)

	## Kırlangıç kuyruklu sancak / kurdele ucu (3 px satırlarla). notch = çentik derinliği.
	func pennant(rc: Rect2, fill: Color, edge: Color, notch: float, notch_left: bool = false) -> void:
		var n := int(rc.size.y / 3.0)
		for pass_ in 2:
			var g := 0.0 if pass_ == 0 else 3.0
			var c := edge if pass_ == 0 else fill
			var skip := int(g / 3.0)
			for j in range(skip, n - skip):
				var v := (j + 0.5) / float(n)
				var ins := roundf(notch * (1.0 - absf(v - 0.5) * 2.0) / 3.0) * 3.0 + g
				var y := rc.position.y + j * 3.0
				if notch_left:
					r(rc.position.x + ins, y, rc.size.x - ins - g, 3.0, c)
				else:
					r(rc.position.x + g, y, rc.size.x - ins - g, 3.0, c)

	## Kumaş kurdele: arkada çentikli iki kuyruk, önde düz şerit.
	func ribbon(cx: float, y: float, w: float, h: float, pal: Dictionary) -> void:
		var x := roundf(cx - w * 0.5)
		var th := h - 12.0
		pennant(Rect2(x - 48, y + 18, 66, th), pal["dk"], HT.OUTLINE, 15.0, true)
		pennant(Rect2(x + w - 18, y + 18, 66, th), pal["dk"], HT.OUTLINE, 15.0, false)
		frame(Rect2(x, y, w, h), pal["fill"], HT.OUTLINE, 3.0)
		r(x + 3, y + 3, w - 6, 3, pal["hi"])
		r(x + 3, y + h - 6, w - 6, 3, (pal["fill"] as Color).darkened(0.18))

	## Yumuşak koyu şerit (kutu yok): dikeyde ortası koyu, kenarlara söner; yatayda fx oranında söner.
	## right_solid = sağ uç ekran kenarına yapışık (sönmez). 3 px'lik piksellerle doku (şerit şerit çokgen çizgi bırakıyordu).
	var _band_cache: Dictionary = {}

	func band(rc: Rect2, col: Color, amax: float, fx: float, fy: float, right_solid: bool = false) -> void:
		var w := int(rc.size.x / 3.0)
		var h := int(rc.size.y / 3.0)
		var key := "%d_%d_%s_%.2f_%.2f_%.2f_%s" % [w, h, col.to_html(), amax, fx, fy, right_solid]
		var t: ImageTexture = _band_cache.get(key)
		if t == null:
			var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
			for j in h:
				var dv := absf((j + 0.5) / h - 0.5) * 2.0
				var av := amax * (1.0 - smoothstep(1.0 - fy, 1.0, dv))
				for i in w:
					var u := (i + 0.5) / w
					var ah := smoothstep(0.0, fx, u)
					if not right_solid:
						ah = minf(ah, smoothstep(0.0, fx, 1.0 - u))
					img.set_pixel(i, j, Color(col, av * ah))
			t = ImageTexture.create_from_image(img)
			_band_cache[key] = t
		draw_texture_rect(t, Rect2(rc.position.round(), Vector2(w * 3, h * 3)), false)

	## Süs çizgisi: başlığa yakın uçta elmas, dışa doğru solan çizgi.
	func orn(x_from: float, x_to: float, y: float, col: Color) -> void:
		var dir := signf(x_to - x_from)
		diamond(Vector2(x_from, y + 1.5), 3.0, col)
		var n := 12
		var ln := absf(x_to - x_from) - 12.0
		for i in n:
			var a := 1.0 - float(i) / n
			var xa := x_from + dir * (12.0 + ln * i / n)
			var xb := x_from + dir * (12.0 + ln * (i + 1) / n)
			r(minf(xa, xb), y, absf(xb - xa), 3.0, Color(col, a * 0.9))

	func medal(c: Vector2, rad: float, col: Color, frac: float) -> void:
		disk(c, rad, 3.0, HT.OUTLINE)
		ring(c, rad - 9.0, rad - 3.0, 3.0, frac, col, HT.RIM_LO)
		disk(c, rad - 9.0, 3.0, HT.OUTLINE)
		disk(c, rad - 12.0, 3.0, HT.INSET)

	## Kuru kafa satırı (gerçek tier_display.gd), center merkezli; çizimden sonra eklenir.
	func skulls(center: Vector2, px: int) -> float:
		var key := "%d_%d" % [int(center.x), int(center.y)]
		if not _skulls.has(key):
			_skulls[key] = true
			_add_skulls.call_deferred(center, px)
		return float(TierDisplayScript.SKULL_H * px)

	func _add_skulls(center: Vector2, px: int) -> void:
		var row := Control.new()
		row.set_script(TierDisplayScript)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)
		row.call("set_tier", TIER, px)
		row.position = (center - row.size * 0.5).round()

	func caption() -> void:
		var s: String = CAPTIONS.get(kind, kind)
		if SCENE_CAP.has(scene):
			s += "  ·  " + String(SCENE_CAP[scene])
		var w := tw(s, 24) + 28.0
		frame(Rect2(16, 1000, w, 44), Color(0.08, 0.05, 0.03, 0.88), HT.RIM, 3.0)
		txt(s, Vector2(30, 1009), 24, HT.ACCENT)

	func ready_count() -> int:
		var n := 0
		for p in team:
			if p["ready"]:
				n += 1
		return n

	func picking_names() -> Array:
		var out: Array = []
		for p in team:
			if not p["ready"]:
				out.append(p["name"])
		return out

	func reward_parts() -> Array:
		## [doku, boyut, sayı, sayı rengi, etiket]
		return [[tex.get("coin"), 32.0, "+%d" % GOLD_REWARD, HT.PRICE, "altın"],
				[tex.get("shard"), 44.0, "+%d" % SHARD_REWARD, HT.SHARD, "Silah Parçacığı"]]

	# ------------------------------------------------------------ çizim
	func _draw() -> void:
		if kind != "simdi":
			call("_%s_%s" % [scene, kind])
		caption()

	# ============================================================ A - AHŞAP LEVHA
	## HUD'un Kısık Ahşap levhası (grup paneliyle aynı doku). Küçük bildirimler sağ sütunda (görev satırlarının altında),
	## solda tür renkli simge kuyusu, altta tükenen fitil. Büyükler üst ortada levha + kumaş kurdele.
	func toast_a(k: String, pos: Vector2, w: float) -> float:
		var col: Color = CAT[k]
		var tx := pos.x + 12.0 + 54.0 + 14.0
		var lines: PackedStringArray = wrap_text(NOTE[k][1], 24, pos.x + w - 16.0 - tx)
		var h := maxf(12.0 + 54.0 + 18.0, 14.0 + 26.0 + lines.size() * 24.0 + 20.0)
		plaque.draw(get_canvas_item(), Rect2(pos, Vector2(w, h)))
		var well := Rect2(pos + Vector2(12, roundf((h - 6.0 - 54.0) * 0.5)), Vector2(54, 54))
		frame(well, HT.INSET, col.darkened(0.3), 3.0)
		icon(k, well.get_center())
		var ty := pos.y + 13.0 if lines.size() > 0 else well.get_center().y - 15.0
		txt(NOTE[k][0], Vector2(tx, ty), 24, col)
		if k == "warn":
			txt_r("%d sn" % WARN_SECONDS, pos.x + w - 16.0, ty, 24, HT.PRICE)
		for i in lines.size():
			txt(lines[i], Vector2(tx, ty + 27.0 + i * 24.0), 24, HT.DIM)
		var fy := pos.y + h - 12.0
		r(pos.x + 12, fy, w - 24, 3, Color(HT.INSET, 0.9))
		r(pos.x + 12, fy, roundf((w - 24) * float(FUSE[k])), 3, col)
		return h

	func complete_a(cx: float, top: float) -> void:
		var w := 600.0
		var ph := 182.0
		var prc := Rect2(roundf(cx - w * 0.5), top + 30, w, ph)
		plaque.draw(get_canvas_item(), prc)
		ribbon(cx, top, 470, 54, RIB_GOLD)
		txt_c("GÖREV TAMAMLANDI", cx, top + 12, 32, RIB_GOLD["text"], false)
		var y0 := top + 30 + 38.0
		var name_w := 27.0 + 12.0 + tw(MISSION_DONE, 32)
		var nx := roundf(cx - name_w * 0.5)
		icon("ok", Vector2(nx + 13, y0 + 16))
		txt(MISSION_DONE, Vector2(nx + 39, y0), 32, HT.TEXT)
		var dy := y0 + 46.0
		r(prc.position.x + 24, dy, w - 48, 3, HT.RIM_LO)
		r(prc.position.x + 24, dy + 3, w - 48, 3, Color(HT.RIM_HI, 0.35))
		## ödüller: kuyu + sayı + etiket, ortalı
		var parts := reward_parts()
		var widths: Array = []
		var total := 0.0
		for p in parts:
			var pw: float = 54.0 + 12.0 + tw(p[2], 32) + 8.0 + tw(p[4], 24)
			widths.append(pw)
			total += pw
		total += 44.0
		var x := roundf(cx - total * 0.5)
		var ry := dy + 18.0
		for i in parts.size():
			var p: Array = parts[i]
			frame(Rect2(x, ry, 54, 54), HT.INSET, HT.RIM_LO, 3.0)
			tex_c(p[0], Vector2(x + 27, ry + 27), p[1])
			txt(p[2], Vector2(x + 66, ry + 10), 32, p[3])
			txt(p[4], Vector2(x + 66 + tw(p[2], 32) + 8, ry + 17), 24, HT.DIM)
			x += float(widths[i]) + 44.0
		var fy := prc.end.y - 14.0
		r(prc.position.x + 16, fy, w - 32, 3, Color(HT.INSET, 0.9))
		r(prc.position.x + 16, fy, roundf((w - 32) * float(FUSE["ok"])), 3, CAT["ok"])

	func tier_a(cx: float, top: float) -> void:
		var w := 420.0
		var prc := Rect2(roundf(cx - w * 0.5), top + 30, w, 96)
		plaque.draw(get_canvas_item(), prc)
		ribbon(cx, top, 330, 54, RIB_RED)
		txt_c("KADEME %s" % TierDisplayScript.to_roman(TIER), cx, top + 12, 32, RIB_RED["text"])
		skulls(Vector2(cx, top + 30 + 58), 4)

	func _oyun_A() -> void:
		complete_a(960, 36)
		var x := 1884.0 - 400.0
		var y := rows_bottom + 10.0
		for k in ["warn", "merchant"]:
			y += toast_a(k, Vector2(x, y), 400) + 8.0

	func _katalog_A() -> void:
		complete_a(520, 36)
		tier_a(1400, 36)
		var cols := [[90.0, ["start", "warn", "fail"]], [1010.0, ["merchant", "ach", "left"]]]
		for cdef in cols:
			var y := 316.0
			for k in cdef[1]:
				y += toast_a(k, Vector2(cdef[0], y), 420) + 12.0

	## Bekleme: yeni pencere YOK - dünya solar, grup panelinin satırlarına HAZIR/SEÇİYOR etiketi, yetenek panelinin üstünde levha.
	func _bekleme_A() -> void:
		for i in rows.size():
			var p: Dictionary = team[i + 1]
			var R: Rect2 = rows[i]
			var ready: bool = p["ready"]
			var col: Color = HT.GOOD if ready else HT.ACCENT
			if not ready:
				frame(R.grow(4.0), Color(0, 0, 0, 0), col, 3.0)
			var label := "HAZIR" if ready else "SEÇİYOR"
			var w := tw(label, 24) + 64.0
			var tg := Rect2(R.position.x - w - 6, R.get_center().y - 22, w, 44)
			frame(tg, Color(HT.INSET, 0.96), col if not ready else HT.GOOD.darkened(0.25), 3.0)
			r(tg.end.x, tg.get_center().y - 3, 6, 6, col if not ready else HT.GOOD.darkened(0.25))
			if ready:
				check(tg.position + Vector2(10, 9), 3.0)
			else:
				bubble(tg.position + Vector2(8, 10), 3.0)
			txt(label, Vector2(tg.position.x + 50, tg.position.y + 8), 24, col)
		var pr := Rect2(960 - 330, 800, 660, 84)
		plaque.draw(get_canvas_item(), pr)
		txt("KART SEÇİMİ", Vector2(pr.position.x + 22, pr.position.y + 12), 24, HT.ACCENT)
		var waiting := team.size() - ready_count()
		check(Vector2(pr.position.x + 22, pr.position.y + 44), 3.0)
		txt("Seçimin tamam", Vector2(pr.position.x + 58, pr.position.y + 45), 24, HT.GOOD)
		txt("·  %d oyuncu bekleniyor" % waiting, Vector2(pr.position.x + 58 + tw("Seçimin tamam", 24) + 12, pr.position.y + 45), 24, HT.TEXT)
		var rc := Vector2(pr.end.x - 50, pr.get_center().y)
		disk(rc, 33, 3, HT.OUTLINE)
		ring(rc, 21, 30, 3, LEFT / TOTAL, HT.ACCENT, HT.RIM_LO)
		disk(rc, 21, 3, HT.INSET)
		txt_c("%d" % int(LEFT), rc.x, rc.y - 13, 24, HT.PRICE)

	# ============================================================ B - ATEŞ IŞIĞI ŞERİDİ
	## Kutu yok (ESC/Ayarlar "Ateş Işığı" dili): büyükler ekranı yatay kesen yumuşak koyu şerit + büyük altın yazı + süs
	## çizgileri; küçükler sağ kenara yapışık, sola doğru sönen gölgede sağa yaslı yazı, altında tükenen ince çizgi.
	func toast_b(k: String, right: float, y: float, w: float) -> float:
		var col: Color = CAT[k]
		var text_r := right - 84.0
		var lines: PackedStringArray = wrap_text(NOTE[k][1], 24, minf(w - 150.0, 370.0))
		var h := maxf(76.0, 14.0 + 27.0 + lines.size() * 24.0 + 20.0)
		band(Rect2(right - w, y, w, h), F_DARK, 0.84, 0.24, 0.3, true)
		icon(k, Vector2(right - 42, y + h * 0.5 - 2))
		var ty := y + 12.0 if lines.size() > 0 else y + h * 0.5 - 16.0
		var title: String = NOTE[k][0]
		txt_r(title, text_r, ty, 24, col)
		if k == "warn":
			txt_r("%d sn  ·  " % WARN_SECONDS, text_r - tw(title, 24), ty, 24, F_GOLD)
		for i in lines.size():
			txt_r(lines[i], text_r, ty + 27.0 + i * 24.0, 24, F_SUB)
		var ln := roundf((w - 170.0) * float(FUSE[k]))
		var fy := y + h - 9.0
		for i in 8:
			var a := 0.85 * (1.0 - i / 8.0)
			r(text_r - ln * (i + 1) / 8.0, fy, ln / 8.0, 3, Color(col, a))
		return h

	func complete_b(cx: float, cy: float, w: float) -> void:
		band(Rect2(cx - w * 0.5, cy - 126, w, 252), F_DARK, 0.86, 0.3, 0.42)
		diamond(Vector2(cx, cy - 100), 3.0, F_GOLD)
		var title := "GÖREV TAMAMLANDI"
		var tl := tw(title, 64)
		txt(title, Vector2(roundf(cx - tl * 0.5), cy - 88), 64, F_GOLD)
		orn(cx - tl * 0.5 - 28, cx - tl * 0.5 - 330, cy - 52, F_GOLD_DIM)
		orn(cx + tl * 0.5 + 28, cx + tl * 0.5 + 330, cy - 52, F_GOLD_DIM)
		txt_c(MISSION_DONE, cx, cy - 6, 32, F_CREAM)
		var parts := reward_parts()
		var segw: Array = []
		var total := 0.0
		for p in parts:
			var pw: float = 48.0 + tw(p[2], 32) + 8.0 + tw(p[4], 24)
			segw.append(pw)
			total += pw
		total += 60.0
		var x := roundf(cx - total * 0.5)
		var ry := cy + 44.0
		for i in parts.size():
			var p: Array = parts[i]
			tex_c(p[0], Vector2(x + 20, ry + 16), p[1])
			txt(p[2], Vector2(x + 48, ry), 32, p[3])
			txt(p[4], Vector2(x + 48 + tw(p[2], 32) + 8, ry + 7), 24, F_SUB)
			x += float(segw[i])
			if i < parts.size() - 1:
				diamond(Vector2(x + 30, ry + 16), 3.0, F_GOLD_DIM)
			x += 60.0

	func tier_b(cx: float, cy: float, w: float) -> void:
		band(Rect2(cx - w * 0.5, cy - 96, w, 192), Color("#1c0907"), 0.86, 0.3, 0.42)
		var title := "KADEME %s" % TierDisplayScript.to_roman(TIER)
		var tl := tw(title, 64)
		txt(title, Vector2(roundf(cx - tl * 0.5), cy - 64), 64, F_RED)
		orn(cx - tl * 0.5 - 28, cx - tl * 0.5 - 260, cy - 28, Color(F_RED, 0.8))
		orn(cx + tl * 0.5 + 28, cx + tl * 0.5 + 260, cy - 28, Color(F_RED, 0.8))
		skulls(Vector2(cx, cy + 40), 4)

	func _oyun_B() -> void:
		complete_b(960, 290, 1500)
		var y := rows_bottom + 10.0
		for k in ["warn", "merchant"]:
			y += toast_b(k, 1910, y, 560) + 6.0

	func _katalog_B() -> void:
		complete_b(960, 150, 1500)
		tier_b(960, 410, 1100)
		var cols := [[1910.0, ["start", "warn", "fail"]], [1000.0, ["merchant", "ach", "left"]]]
		for cdef in cols:
			var y := 560.0
			for k in cdef[1]:
				y += toast_b(k, cdef[0], y, 600) + 8.0

	## Bekleme: vinyet + ortada şerit; portreler kutusuz, büyük sayaç + ortada tükenen çizgi.
	func _bekleme_B() -> void:
		var cy := 330.0
		band(Rect2(960 - 720, cy - 174, 1440, 348), F_DARK, 0.86, 0.28, 0.35)
		var title := "KART SEÇİMİ BEKLENİYOR"
		var tl := tw(title, 48)
		txt(title, Vector2(roundf(960 - tl * 0.5), cy - 150), 48, F_GOLD)
		orn(960 - tl * 0.5 - 28, 960 - tl * 0.5 - 250, cy - 125, F_GOLD_DIM)
		orn(960 + tl * 0.5 + 28, 960 + tl * 0.5 + 250, cy - 125, F_GOLD_DIM)
		## portreler 2x (96 px), kutusuz; altında isim + durum
		var step := 190.0
		var x0 := 960.0 - step * (team.size() - 1) * 0.5
		for i in team.size():
			var p: Dictionary = team[i]
			var px := x0 + i * step
			var ready: bool = p["ready"]
			var py := cy - 96.0
			draw_texture_rect(p["tex"], Rect2(px - 48, py, 96, 96), false, Color(1, 1, 1, 1) if not ready else Color(1, 1, 1, 0.8))
			if ready:
				check(Vector2(px + 22, py + 66), 3.0)
			else:
				bubble(Vector2(px + 18, py - 12), 3.0)
			r(px - 45, py + 98, 90, 3, Color(HT.GOOD if ready else F_GOLD, 0.7))
			txt_c(p["name"], px, py + 106, 24, F_CREAM if ready else F_GOLD)
			txt_c("hazır" if ready else "seçiyor", px, py + 130, 24, HT.GOOD if ready else F_SUB)
		txt_segs([["%d" % int(LEFT), HT.PRICE], [" sn", F_SUB]], 960, cy + 70, 48)
		var lw := roundf(700.0 * LEFT / TOTAL)
		r(960 - lw * 0.5, cy + 132, lw, 3, F_GOLD_DIM)
		diamond(Vector2(960 - lw * 0.5 - 6, cy + 133.5), 3.0, F_GOLD_DIM)
		diamond(Vector2(960 + lw * 0.5 + 6, cy + 133.5), 3.0, F_GOLD_DIM)

	# ============================================================ C - MADALYON VE SANCAK
	## Simge önde: her bildirim bir madalyon (kenarı = zamanlayıcı halka) + arkasından açılan kırlangıç kuyruklu sancak.
	## Küçükler ekranın SOLUNDA (altın/parçacık panelinin altı, boş alan), büyükler üst ortada büyük madalyon.
	func toast_c(k: String, x: float, y: float, w: float) -> float:
		var col: Color = CAT[k]
		var R := 36.0
		var tx := x + 2.0 * R + 20.0
		var lines: PackedStringArray = wrap_text(NOTE[k][1], 24, x + w - 34.0 - tx)
		var bh := maxf(60.0, 12.0 + 27.0 + lines.size() * 24.0 + 12.0)
		var c := Vector2(x + R + 3.0, y + maxf(R + 3.0, bh * 0.5))
		var by := roundf(c.y - bh * 0.5)
		var bx := c.x + 12.0
		pennant(Rect2(bx, by, x + w - bx, bh), CLOTH, HT.OUTLINE, 15.0)
		r(bx + 3, by + 3, x + w - bx - 24, 3, CLOTH_HI)
		medal(c, R, col, float(FUSE[k]))
		icon(k, c)
		var ty := by + 11.0 if lines.size() > 0 else c.y - 15.0
		txt(NOTE[k][0], Vector2(tx, ty), 24, col)
		if k == "warn":
			txt("%d sn" % WARN_SECONDS, Vector2(tx + tw(NOTE[k][0], 24) + 14, ty), 24, HT.PRICE)
		for i in lines.size():
			txt(lines[i], Vector2(tx, ty + 27.0 + i * 24.0), 24, HT.DIM)
		return maxf(2.0 * R + 6.0, bh)

	func complete_c(cx: float, top: float) -> void:
		var R := 66.0
		var bw := 520.0
		var total := 2.0 * R + bw - 40.0
		var x0 := roundf(cx - total * 0.5)
		var c := Vector2(x0 + R, top + R + 18.0)
		var bh := 102.0
		var bx := c.x + 20.0
		var by := c.y - bh * 0.5
		pennant(Rect2(bx, by, x0 + total - bx, bh), CLOTH, HT.OUTLINE, 24.0)
		r(bx + 3, by + 3, x0 + total - bx - 33, 3, CLOTH_HI)
		var tx := c.x + R + 22.0
		txt("GÖREV TAMAMLANDI", Vector2(tx, by + 14), 40, CAT["ok"])
		txt(MISSION_DONE, Vector2(tx, by + 62), 24, HT.TEXT)
		## asılı ödül etiketleri
		var parts := reward_parts()
		var tagx := tx + 6.0
		for p in parts:
			var tc := Vector2(tagx + 36.0, by + bh + 50.0)
			var lw: float = maxf(tw(p[2], 32), tw(p[4], 24))
			r(tc.x - 1.5, by + bh - 3.0, 3, 16, HT.RIM_LO)
			pennant(Rect2(tc.x + 12, tc.y - 33, lw + 60, 66), CLOTH, HT.OUTLINE, 12.0)
			medal(tc, 36.0, CAT["ok"], 1.0)
			tex_c(p[0], tc, p[1])
			txt(p[2], Vector2(tc.x + 46, tc.y - 28), 32, p[3])
			txt(p[4], Vector2(tc.x + 46, tc.y + 2), 24, HT.DIM)
			tagx += 36.0 + lw + 60.0 + 30.0
		## parıltı: madalyonun çevresinde 8 küçük elmas
		for i in 8:
			var a := i * TAU / 8.0 + TAU / 16.0
			diamond(c + Vector2(cos(a), sin(a)) * (R + 13.0), 3.0, CAT["ok"])
		medal(c, R, CAT["ok"], float(FUSE["ok"]))
		icon("ok", c, true)

	func tier_c(cx: float, top: float) -> void:
		var R := 56.0
		var bw := 380.0
		var total := 2.0 * R + bw - 40.0
		var x0 := roundf(cx - total * 0.5)
		var c := Vector2(x0 + R, top + R + 18.0)
		var bh := 96.0
		var bx := c.x + 20.0
		var by := c.y - bh * 0.5
		pennant(Rect2(bx, by, x0 + total - bx, bh), Color("#2a1210"), HT.OUTLINE, 24.0)
		r(bx + 3, by + 3, x0 + total - bx - 33, 3, Color("#4a2420"))
		medal(c, R, CAT["tier"], 1.0)
		txt_c(TierDisplayScript.to_roman(TIER), c.x, c.y - 26, 48, HT.TEXT)
		var tx := c.x + R + 22.0
		txt("KADEME", Vector2(tx, by + 12), 40, CAT["tier"])
		skulls(Vector2(tx + 69.0 * 1.5, by + 74), 3)

	func _oyun_C() -> void:
		complete_c(960, 30)
		var y := 226.0
		for k in ["warn", "merchant"]:
			y += toast_c(k, 16, y, 470) + 10.0

	func _katalog_C() -> void:
		complete_c(560, 30)
		tier_c(1420, 30)
		var cols := [[60.0, ["start", "warn", "fail"]], [980.0, ["merchant", "ach", "left"]]]
		for cdef in cols:
			var y := 330.0
			for k in cdef[1]:
				y += toast_c(k, cdef[0], y, 560) + 14.0

	## Bekleme: kum saati madalyonu (kenarı = geri sayım) + sancakta oyuncu yuvaları.
	func _bekleme_C() -> void:
		var R := 78.0
		var bw := 560.0
		var total := 2.0 * R + bw - 40.0
		var x0 := roundf(960.0 - total * 0.5)
		var c := Vector2(x0 + R, 150.0)
		var bh := 156.0
		var bx := c.x + 20.0
		var by := c.y - bh * 0.5
		pennant(Rect2(bx, by, x0 + total - bx, bh), CLOTH, HT.OUTLINE, 27.0)
		r(bx + 3, by + 3, x0 + total - bx - 36, 3, CLOTH_HI)
		disk(c, R, 3.0, HT.OUTLINE)
		ring(c, R - 15.0, R - 3.0, 3.0, LEFT / TOTAL, HT.ACCENT, HT.RIM_LO)
		disk(c, R - 15.0, 3.0, HT.OUTLINE)
		disk(c, R - 18.0, 3.0, HT.INSET)
		hourglass(c - Vector2(26, 36), 4.0)
		var pr := Rect2(c.x - 54, c.y + R - 12, 108, 44)
		plaque.draw(get_canvas_item(), pr)
		txt_segs([["%d" % int(LEFT), HT.PRICE], [" sn", HT.DIM]], c.x, pr.position.y + 9, 24)
		var tx := c.x + R + 26.0
		txt("KART SEÇİMİ", Vector2(tx, by + 12), 32, HT.ACCENT)
		txt_r("%d/%d HAZIR" % [ready_count(), team.size()], x0 + total - 60.0, by + 18, 24, HT.GOOD)
		for i in team.size():
			var p: Dictionary = team[i]
			var px := tx + i * 100.0
			chip(Vector2(px, by + 56), p)
			txt_c(p["name"], px + 32, by + 124, 24, HT.TEXT if p["ready"] else HT.ACCENT)

	# ============================================================ D - KAYRAK KUYRUK
	## Seyyar Satıcı / Oyun Bitti kayrağı. TEK yer: hepsi üst ortada bir kuyrukta - büyük olan genişleyip başlık şeridi alır,
	## küçükler altında ince haplar (en yeni üstte, en fazla 3), solda tür renkli şerit, altta tükenen çizgi.
	func pill_d(k: String, cx: float, y: float, w: float) -> float:
		var col: Color = CAT[k]
		var x := roundf(cx - w * 0.5)
		var tx := x + 18.0 + 48.0 + 12.0
		var lines: PackedStringArray = wrap_text(NOTE[k][1], 24, x + w - 20.0 - tx)
		var h := maxf(66.0, 12.0 + 27.0 + lines.size() * 24.0 + 15.0)
		frame(Rect2(x, y, w, h), Color(SL["panel"], 0.95), SL["line"], 3.0)
		r(x + 3, y + 3, 6, h - 6, col)
		icon(k, Vector2(x + 18 + 24, y + h * 0.5 - 2))
		var ty := y + 11.0 if lines.size() > 0 else y + h * 0.5 - 15.0
		txt(NOTE[k][0], Vector2(tx, ty), 24, col)
		if k == "warn":
			txt_r("%d sn" % WARN_SECONDS, x + w - 18.0, ty, 24, SL["price"])
		for i in lines.size():
			txt(lines[i], Vector2(tx, ty + 27.0 + i * 24.0), 24, SL["dim"])
		r(x + 9, y + h - 6, roundf((w - 12) * float(FUSE[k])), 3, Color(col, 0.75))
		return h

	func card_d(cx: float, y: float, w: float, h: float, head: Color, hi: Color) -> Rect2:
		var x := roundf(cx - w * 0.5)
		frame(Rect2(x, y, w, h), Color(SL["panel"], 0.96), SL["line"], 3.0)
		r(x + 3, y + 3, w - 6, 48, head)
		r(x + 3, y + 3, w - 6, 3, hi)
		r(x + 3, y + 51, w - 6, 3, Color(SL["inset"], 0.9))
		return Rect2(x, y, w, h)

	func complete_d(cx: float, y: float) -> float:
		var w := 640.0
		var h := 186.0
		var rc := card_d(cx, y, w, h, SL["accent"], (SL["accent"] as Color).lightened(0.3))
		var x := rc.position.x
		icon("ok", Vector2(x + 34, y + 27))
		txt("GÖREV TAMAMLANDI", Vector2(x + 62, y + 11), 32, SL["accent_text"], false)
		txt_r("ödül alındı", x + w - 20, y + 17, 24, Color(SL["accent_text"], 0.75), false)
		txt(MISSION_DONE, Vector2(x + 24, y + 66), 32, SL["text"])
		var parts := reward_parts()
		var px := x + 24.0
		for p in parts:
			var cw: float = 54.0 + 10.0 + tw(p[2], 32) + 8.0 + tw(p[4], 24) + 18.0
			frame(Rect2(px, y + 110, cw, 58), SL["inset"], SL["line_hi"], 3.0)
			tex_c(p[0], Vector2(px + 30, y + 139), p[1])
			txt(p[2], Vector2(px + 62, y + 121), 32, p[3])
			txt(p[4], Vector2(px + 62 + tw(p[2], 32) + 8, y + 128), 24, SL["dim"])
			px += cw + 16.0
		r(x + 3, y + h - 6, roundf((w - 6) * float(FUSE["ok"])), 3, Color(SL["accent"], 0.8))
		return h

	func tier_d(cx: float, y: float) -> float:
		var w := 460.0
		var h := 118.0
		var rc := card_d(cx, y, w, h, Color("#a8443a"), Color("#cf6a58"))
		txt_c("KADEME %s" % TierDisplayScript.to_roman(TIER), cx, y + 11, 32, Color("#f6e6cc"))
		skulls(Vector2(cx, rc.position.y + 86), 4)
		return h

	func _oyun_D() -> void:
		var y := 24.0
		y += complete_d(960, y) + 8.0
		for k in ["merchant", "warn"]:
			y += pill_d(k, 960, y, 560) + 6.0

	func _katalog_D() -> void:
		complete_d(520, 24)
		tier_d(1400, 24)
		var cols := [[520.0, ["start", "warn", "fail"]], [1400.0, ["merchant", "ach", "left"]]]
		for cdef in cols:
			var y := 240.0
			for k in cdef[1]:
				y += pill_d(k, cdef[0], y, 620) + 8.0

	## Bekleme: aynı kuyruğun en üstünde genişlemiş kart (başlık şeridi + yuvalar + sayaç + fitil); hafif düz karartma.
	func _bekleme_D() -> void:
		var w := 760.0
		var h := 206.0
		var y := 24.0
		var rc := card_d(960, y, w, h, SL["accent"], (SL["accent"] as Color).lightened(0.3))
		var x := rc.position.x
		grid_c(HG_SMALL, Vector2(x + 30, y + 27), 3.0, {"O": HT.OUTLINE, "W": HT.RIM_HI, "S": Color("#e8b860"), "g": Color(0.55, 0.7, 0.8, 0.3)})
		txt("KART SEÇİMİ BEKLENİYOR", Vector2(x + 58, y + 11), 32, SL["accent_text"], false)
		txt_r("%d/%d HAZIR" % [ready_count(), team.size()], x + w - 20, y + 17, 24, SL["accent_text"], false)
		for i in team.size():
			var p: Dictionary = team[i]
			var px := x + 30.0 + i * 104.0
			chip(Vector2(px, y + 74), p, SL["inset"])
			txt_c(p["name"], px + 32, y + 144, 24, SL["text"] if p["ready"] else SL["accent"])
		txt_segs([["%d" % int(LEFT), SL["price"]], [" sn", SL["dim"]]], x + w - 110, y + 86, 48)
		r(x + 3, y + h - 6, roundf((w - 6) * LEFT / TOTAL), 3, Color(SL["accent"], 0.85))


func _initialize() -> void:
	_run.call_deferred()


## hold = dünya donuk kalsın (prototip çekimlerinde yaratıklar dövüşmesin); gerçek bildirimler (simdi) tween ister.
func _wait(sec: float, hold: bool = false) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = hold
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


## Gerçek bildirimleri (bej levhalar + Görev Tamamlandı penceresi) kaldırır.
func _clear_real(main: Node) -> void:
	for p in main.get("_active_toast_panels"):
		if is_instance_valid(p) and (p as Node).get_parent():
			(p as Node).get_parent().queue_free()
	for ch in main.get_children():
		var sc: Script = ch.get_script()
		if sc and sc.resource_path.ends_with("mission_complete_window.gd"):
			ch.queue_free()


func _sheet(shots: Dictionary, name: String) -> void:
	var order := ["A", "B", "C", "D"]
	for k in order:
		if not shots.has(k):
			return
	var sheet := Image.create(1920, 1080, false, Image.FORMAT_RGBA8)
	for i in 4:
		var im: Image = (shots[order[i]] as Image).duplicate()
		im.convert(Image.FORMAT_RGBA8)
		im.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(im, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
	sheet.save_png(ProjectSettings.globalize_path(OUT + name))
	print("SHOT ", name)


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var only: String = OS.get_environment("BILDIRIM_ONLY")
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
	await _wait(2.5)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var main: Node = current_scene
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	if player:
		player.global_position += Vector2(40, 170)
		player.set("health", float(player.get("max_health")) * 0.72)
	for i in range(1, TEAM.size()):
		var t: Dictionary = TEAM[i]
		var a := FakeAlly.new()
		a.peer_id = 1000 + i
		a.player_name = t["name"]
		a.char_id = t["char"]
		a.health = t["hp"][0]
		a.max_health = t["hp"][1]
		a.item_shield_hp = t["hp"][2]
		a.item_shield_max = t["hp"][3]
		main.add_child(a)
		a.add_to_group("remote_players")
		if player:
			a.global_position = player.global_position + Vector2(-300 + 300 * (i - 1), -140)
	var hud: Node = main.get_node_or_null("HUD")
	if hud:
		hud.call("update_level", 12)
	Input.warp_mouse(Vector2(1480, 640))
	await _wait(1.5)

	## Görev satırı (Konvoyu Koru uyarısı) + satıcı oku/işareti: HUD'un kalıcı parçaları, her çekimde aynı.
	var ppos: Vector2 = player.global_position if player else Vector2.ZERO
	main.call("_on_world_event_announced", 7, "escort_van", ppos + Vector2(900, -420), 120.0, float(WARN_SECONDS), "Konvoyu Koru")
	main.call("_on_merchant_spawned", ppos + Vector2(-1100, 600), [])
	## autoload kullanan betikler -s derlemesinde preload edilemez (madde notu) -> çalışırken yüklenir
	(load("res://scripts/gold_reward_fx.gd") as GDScript).call("hold", self, GOLD_REWARD, &"mission", ppos)
	(load("res://scripts/mission_complete_window.gd") as GDScript).call("open", main, MISSION_DONE)
	await _wait(0.75)

	var team: Array = []
	for t: Dictionary in TEAM:
		team.append({"name": t["name"], "ready": t["ready"], "me": t.get("me", false),
				"tex": load(str(chars.get_def(int(t["char"])).get("portrait", "")))})
	var font: Font = load("res://assets/fonts/m5x7.ttf")
	var plaque: StyleBox = load("res://scripts/party_panel.gd")._plaque_style(14.0, 8.0)
	## satıcı simgesi: idle karesinin baş-gövde kısmı (figür 48 px karenin ortasında 14x33) - 2x çizilir
	var merchant_tex := AtlasTexture.new()
	merchant_tex.atlas = load("res://assets/npc/seyyar_satici/sheets/idle.png")
	merchant_tex.region = Rect2(12, 6, 24, 24)
	var texs := {
		"coin": load("res://assets/ui/newui/icon_gold_coin.png"),
		"shard": load("res://assets/pickups/weapon_shard/shard_icon.png"),
		"medal": load("res://assets/items/lutuf_madalyonu.png"),
		"merchant": merchant_tex,
		"kerem": load(str(chars.get_def(5).get("portrait", ""))),
	}
	var party_layer: CanvasLayer = hud.get_node_or_null("PartyPanelLayer") as CanvasLayer if hud else null
	var party_layer_orig: int = party_layer.layer if party_layer else 1
	var rows: Array = []
	var pp: Node = hud.get_node_or_null("PartyPanelLayer/PartyPanel") if hud else null
	if pp:
		var rd: Dictionary = pp.get("_rows")
		for i in range(1, TEAM.size()):
			var row = rd.get(1000 + i)
			if row:
				rows.append((row.container as Control).get_global_rect())
	var banner: Node = main.get("_world_event_banner")
	var rows_bottom: float = float(banner.call("get_rows_bottom_y")) if banner else 500.0
	## katalog çekiminde gizlenecek HUD katmanları
	var hud_layers: Array = []
	if hud:
		hud_layers.append(hud)
		for n in hud.find_children("*", "CanvasLayer", true, false):
			hud_layers.append(n)
	for nname in ["WorldEventBannerLayer"]:
		var n2: Node = main.get_node_or_null(nname)
		if n2:
			hud_layers.append(n2)
	var arrow: Node = main.get("_merchant_arrow")
	if arrow and arrow.get_parent() is CanvasLayer:
		hud_layers.append(arrow.get_parent())
	print("ROWS ", rows, " rows_bottom=", rows_bottom)

	var shots: Dictionary = {}
	var shots_wait: Dictionary = {}
	for k: String in kinds:
		for sc: String in ["oyun", "katalog", "bekleme"]:
			var layers: Array = []
			var fname: String = ("%s.png" % k) if sc == "oyun" else ("%s_%s.png" % [sc, k])
			if k == "simdi":
				if sc == "katalog":
					_clear_real(main)
					await _wait(0.2)
					main.call("_show_network_toast", "%s görevi BAŞLADI!\n%s" % ["Konvoyu Koru", String(NOTE["start"][1])], 9.0)
					main.call("_show_network_toast", "Ağacı Koru görevi BAŞARISIZ! Ağaç yok edildi.", 9.0)
					main.call("_show_network_toast", "BAŞARIM: Ayakta Kal", 4.0)
					main.call("_show_network_toast", "Kerem oyundan ayrıldı.")
					var title: String = TierDisplayScript.title(TIER)
					main.call("_show_network_toast", title, 4.0, true, main.call("_tier_banner", title, TIER))
				elif sc == "bekleme":
					_clear_real(main)
					main.call("_show_level_up_wait_overlay")
					await process_frame
					var lbl: Label = main.get("_level_up_wait_label")
					var cd: Label = main.get("_level_up_wait_countdown_label")
					if lbl:
						lbl.text = "Seçim yapılıyor: Mira, Deniz\nLütfen bekleyin"
					if cd:
						cd.text = "%ds" % int(LEFT)
				var capl := CanvasLayer.new()
				capl.layer = 99
				var cp := Proto.new()
				cp.kind = k
				cp.scene = sc
				cp.font = font
				capl.add_child(cp)
				root.add_child(capl)
				layers.append(capl)
			else:
				_clear_real(main)
				var bg := CanvasLayer.new()
				bg.layer = 90
				if sc == "bekleme":
					match k:
						"A":
							bg.add_child(_shader_rect(DESAT))
							if party_layer:
								party_layer.layer = 95
						"B":
							bg.add_child(_shader_rect(VIGNETTE))
						"C", "D":
							var dim := ColorRect.new()
							dim.color = Color(0.06, 0.04, 0.02, 0.28)
							dim.set_anchors_preset(Control.PRESET_FULL_RECT)
							bg.add_child(dim)
				root.add_child(bg)
				layers.append(bg)
				var fl := CanvasLayer.new()
				fl.layer = 96
				var pr := Proto.new()
				pr.kind = k
				pr.scene = sc
				pr.team = team
				pr.font = font
				pr.plaque = plaque
				pr.rows = rows
				pr.rows_bottom = rows_bottom
				pr.tex = texs
				fl.add_child(pr)
				root.add_child(fl)
				layers.append(fl)
			if sc == "katalog":
				for l: CanvasLayer in hud_layers:
					l.visible = false
			await _wait(0.6, k != "simdi")
			var img: Image = await _shot(fname)
			if sc == "oyun":
				shots[k] = img
			elif sc == "bekleme":
				shots_wait[k] = img
			if sc == "katalog":
				for l: CanvasLayer in hud_layers:
					l.visible = true
			if k == "simdi" and sc == "bekleme":
				main.call("_hide_level_up_wait_overlay")
			if party_layer:
				party_layer.layer = party_layer_orig
			for l: Node in layers:
				l.queue_free()
			await _wait(0.25)
	_clear_real(main)
	_sheet(shots, "ozet.png")
	_sheet(shots_wait, "ozet_bekleme.png")
	quit()
