extends SceneTree

## KART SEÇİMİ BEKLEME mini arayüzü PROTOTİPLERİ (2026-10-17). Kullanıcı: "diğer oyuncuların kart seçmesini beklerkenki mini
## arayüz için 4 yeni prototip hazırla". Şu anki: main.gd _show_level_up_wait_overlay (tam ekran %55 karartma + ortada
## 720x220 ahşap pencere + "Seçim yapılıyor: X / Lütfen bekleyin" + "25s").
## Oyuna BAĞLI DEĞİL: gerçek oyun (SP main.tscn) açılır, 3 sahte takım arkadaşı eklenir, her prototip ayrı CanvasLayer olarak
## üstüne çizilir. Yalnız oyunda ZATEN olan veri kullanılır: kimin kuyruğu sürüyor (NetworkManager.level_up_busy_peers),
## isimler, karakter portresi, ortak geri sayım (level_up_countdown, 25 sn). Renkler HUD teması (hud_theme.gd, "Kısık Ahşap").
##  A Üst Şerit / B Kum Saati Madalyonu / C Grup Paneli Etiketleri / D Kart Masası (+ "simdi" = mevcut ekran).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261017/bekleme_proto.gd
##   BEKLEME_ONLY = "simdi,A" gibi seçili çekimler (boşsa hepsi + ozet.png).

const OUT := "res://tools/proto_20261017/out/bekleme/"
const HT := preload("res://scripts/hud_theme.gd")
const CHAR_ID := 2 ## yerel oyuncu (Oakley)
const LEFT := 17.0 ## kalan saniye
const TOTAL := 25.0 ## NetworkManager.level_up_countdown başlangıcı
## Takım: yerel oyuncu + 3 sahte arkadaş. ready = kuyruğu bitti (level_up_busy_peers'ta değil).
const TEAM := [
	{"name": "Sen", "char": 2, "ready": true, "me": true},
	{"name": "Mira", "char": 10, "ready": false, "hp": [412.0, 520.0, 180.0, 240.0]},
	{"name": "Kerem", "char": 5, "ready": true, "hp": [160.0, 610.0, 0.0, 0.0]},
	{"name": "Deniz", "char": 15, "ready": false, "hp": [300.0, 380.0, 90.0, 120.0]},
]
const CAPTIONS := {
	"simdi": "ŞU AN - tam ekran karartma + orta pencere",
	"A": "A - Üst Şerit",
	"B": "B - Kum Saati Madalyonu",
	"C": "C - Grup Paneli Etiketleri",
	"D": "D - Kart Masası",
}

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
## "seçiyor" balonu: üç nokta (oyunda sırayla yanıp söner)
const BUBBLE := [
	" OOOOOOOOO ",
	"OWWWWWWWWWO",
	"OWDWWDWWDWO",
	"OWWWWWWWWWO",
	" OOWOOOOOO ",
	"  OWO      ",
	"  OO       ",
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

const VIGNETTE := """shader_type canvas_item;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.6, 1.0));
	COLOR = vec4(0.05, 0.03, 0.02, mix(0.22, 0.7, smoothstep(0.15, 0.85, d)));
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
const BOTTOM_FADE := """shader_type canvas_item;
void fragment() {
	COLOR = vec4(0.05, 0.03, 0.02, mix(0.12, 0.68, smoothstep(0.35, 0.95, UV.y)));
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


## Bir prototipin bütün çizimi (tam ekran, fareyi geçirir). Piksel ızgaraya oturan dikdörtgenlerle çizilir.
class Proto extends Control:
	var kind: String = ""
	var team: Array = [] ## [{name, tex, ready, me}]
	var font: Font = null
	var plaque: StyleBox = null
	var rows: Array = [] ## C: takım arkadaşı satırlarının ekran dikdörtgenleri (TEAM[1..] sırasıyla)
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

	func sprite(rows_: Array, pos: Vector2, s: float, cols: Dictionary) -> void:
		for j in rows_.size():
			var row: String = rows_[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					r(pos.x + i * s, pos.y + j * s, s, s, cols[ch])

	func check(pos: Vector2, s: float) -> void:
		sprite(CHECK, pos, s, {"O": HT.OUTLINE, "G": Color("#5f9a3c"), "W": Color("#f3f0d8")})

	func bubble(pos: Vector2, s: float) -> void:
		sprite(BUBBLE, pos, s, {"O": HT.OUTLINE, "W": HT.TEXT, "D": Color("#4b3320")})

	func hourglass(pos: Vector2, s: float) -> void:
		sprite(HOURGLASS, pos, s, {"O": HT.OUTLINE, "W": HT.RIM_HI, "H": Color(1, 1, 1, 0.5),
				"G": Color(0.75, 0.85, 0.9, 0.3), "g": Color(0.55, 0.7, 0.8, 0.14), "S": Color("#e8b860")})

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

	## pos = yazı kutusunun sol üstü; en fazla 3 px aşağı-sağ gölge (büyük yazıda 1 font pikseli çift görüntü veriyordu).
	func txt(s: String, pos: Vector2, size: int, c: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
		var u: float = minf(size / 8.0, 3.0)
		var base := Vector2(roundf(pos.x), roundf(pos.y + font.get_ascent(size)))
		draw_string(font, base + Vector2(u, u), s, align, width, size, Color(HT.OUTLINE, 0.9))
		draw_string(font, base, s, align, width, size, c)

	## Renkli parçalardan tek satır, cx merkezli.
	func txt_segs(segs: Array, cx: float, y: float, size: int) -> void:
		var total := 0.0
		for sg in segs:
			total += tw(sg[0], size)
		var x := roundf(cx - total * 0.5)
		for sg in segs:
			txt(sg[0], Vector2(x, y), size, sg[1])
			x += tw(sg[0], size)

	func bar(rc: Rect2, frac: float, fill: Color) -> void:
		frame(rc, HT.INSET, HT.OUTLINE, 3.0)
		var inner := rc.grow(-3.0)
		var w := roundf(inner.size.x * frac)
		r(inner.position.x, inner.position.y, w, inner.size.y, fill)
		r(inner.position.x, inner.position.y, w, 3.0, fill.lightened(0.35))
		r(inner.position.x + w - 3.0, inner.position.y, 3.0, inner.size.y, Color(1, 1, 1, 0.55))

	## 64x64 oyuncu yuvası: portre 1:1 + durum rozeti (hazır = yeşil tik, seçiyor = altın kenar + üç nokta balonu).
	func chip(pos: Vector2, p: Dictionary, dim_ready: bool = false) -> void:
		var rc := Rect2(pos, Vector2(64, 64))
		var ready: bool = p["ready"]
		if not ready:
			frame(rc.grow(3.0), Color(0, 0, 0, 0), Color(HT.ACCENT, 0.35), 3.0)
		frame(rc, HT.INSET, HT.GOOD.darkened(0.25) if ready else HT.ACCENT, 3.0)
		var mod := Color(1, 1, 1, 0.75) if (ready and dim_ready) else Color.WHITE
		draw_texture_rect(p["tex"], Rect2(pos + Vector2(8, 8), Vector2(48, 48)), false, mod)
		if ready:
			check(pos + Vector2(44, 44), 3.0)
		else:
			bubble(pos + Vector2(36, -12), 3.0)

	func caption() -> void:
		var s: String = CAPTIONS.get(kind, kind)
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

	# ------------------------------------------------------------ çizim
	func _draw() -> void:
		focus.clear()
		match kind:
			"A":
				_draw_a()
			"B":
				_draw_b()
			"C":
				_draw_c()
			"D":
				_draw_d()
		caption()

	## A - Üst Şerit: ekranın tepesinde ince levha; herkesin yuvası + tek bakışta kalan süre. Hafif karartma, oyun görünür.
	func _draw_a() -> void:
		var step := 96.0
		var w := 24.0 + team.size() * step + 196.0
		var h := 168.0
		var x0 := roundf(960.0 - w * 0.5)
		var y0 := 30.0
		var rc := Rect2(x0, y0, w, h)
		plaque.draw(get_canvas_item(), rc)
		txt("KART SEÇİMİ", Vector2(x0 + 24, y0 + 14), 24, HT.ACCENT)
		for i in team.size():
			var p: Dictionary = team[i]
			var cx := x0 + 24 + i * step
			chip(Vector2(cx + 8, y0 + 48), p)
			txt(p["name"], Vector2(cx - 4, y0 + 116), 24, HT.TEXT if p["ready"] else HT.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, 88)
		var dx := x0 + 24 + team.size() * step + 4
		r(dx, y0 + 18, 3, 118, Color(HT.OUTLINE, 0.7))
		r(dx + 3, y0 + 18, 3, 118, Color(HT.RIM_HI, 0.25))
		txt("%d/%d HAZIR" % [ready_count(), team.size()], Vector2(dx + 20, y0 + 14), 24, HT.GOOD)
		hourglass(Vector2(dx + 22, y0 + 52), 3.0)
		txt("%d" % int(LEFT), Vector2(dx + 76, y0 + 50), 48, HT.PRICE)
		txt("sn", Vector2(dx + 76 + tw("%d" % int(LEFT), 48) + 6, y0 + 74), 24, HT.DIM)
		bar(Rect2(x0 + 24, y0 + h - 30, w - 48, 15), LEFT / TOTAL, HT.ACCENT)
		focus.append(rc.grow(16))

	## B - Kum Saati Madalyonu: ortada yuvarlak madalyon, kenarında boşalan süre halkası, içinde akan kum saati;
	## oyuncular madalyonun iki yanında "masa başında" oturur. Kenarları kararan vinyet.
	func _draw_b() -> void:
		var c := Vector2(960, 392)
		disk(c, 96, 4, HT.OUTLINE)
		disk(c, 92, 4, HT.RIM)
		ring(c, 84, 92, 4, 1.0, HT.RIM_HI, HT.RIM_HI)
		disk(c, 84, 4, HT.OUTLINE)
		disk(c, 80, 4, HT.INSET)
		ring(c, 64, 76, 4, LEFT / TOTAL, HT.ACCENT, Color(HT.RIM_LO, 0.8))
		hourglass(c - Vector2(26, 40), 4.0)
		## alt sayaç levhası madalyonun kenarına biner
		var pr := Rect2(c.x - 64, c.y + 72, 128, 52)
		plaque.draw(get_canvas_item(), pr)
		txt_segs([["%d" % int(LEFT), HT.PRICE], [" sn", HT.DIM]], c.x, pr.position.y + 6, 32)
		## koltuklar: sol iki, sağ iki
		var seats := [Vector2(-196, -78), Vector2(132, -78), Vector2(-196, 14), Vector2(132, 14)]
		for i in team.size():
			var p: Dictionary = team[i]
			var pos: Vector2 = c + seats[i]
			chip(pos, p, true)
			var left_side: bool = seats[i].x < 0
			var nx: float = pos.x - 112 if left_side else pos.x + 76
			var al := HORIZONTAL_ALIGNMENT_RIGHT if left_side else HORIZONTAL_ALIGNMENT_LEFT
			txt(p["name"], Vector2(nx, pos.y + 8), 24, HT.TEXT if p["ready"] else HT.ACCENT, al, 104)
			txt("hazır" if p["ready"] else "seçiyor", Vector2(nx, pos.y + 34), 24, HT.GOOD if p["ready"] else HT.DIM, al, 104)
		## alt yazı levhası
		var names := picking_names()
		var tr := Rect2(c.x - 230, c.y + 140, 460, 48)
		plaque.draw(get_canvas_item(), tr)
		var segs: Array = []
		for i in names.size():
			if i > 0:
				segs.append([" ve " if i == names.size() - 1 else ", ", HT.TEXT])
			segs.append([names[i], HT.ACCENT])
		segs.append([" kart seçiyor", HT.TEXT])
		txt_segs(segs, c.x, tr.position.y + 10, 24)
		focus.append(Rect2(c.x - 330, c.y - 120, 660, 330))

	## C - Grup Paneli Etiketleri: yeni pencere YOK. Dünya solar (oyun durdu), grup paneli parlak kalır, her satırın soluna
	## durum etiketi; yerel oyuncunun durumu yetenek panelinin üstünde küçük bir hapta.
	func _draw_c() -> void:
		var rmin := Rect2()
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
			rmin = tg.merge(R) if i == 0 else rmin.merge(tg).merge(R)
		focus.append(rmin.grow(20))
		## alt hap
		var pr := Rect2(960 - 300, 808, 600, 72)
		plaque.draw(get_canvas_item(), pr)
		var ty := pr.position.y + 20
		check(Vector2(pr.position.x + 20, ty - 1), 3.0)
		txt("Seçimin tamam", Vector2(pr.position.x + 56, ty), 24, HT.GOOD)
		var waiting := team.size() - ready_count()
		txt("·  %d oyuncu bekleniyor" % waiting, Vector2(pr.position.x + 56 + tw("Seçimin tamam", 24) + 12, ty), 24, HT.TEXT)
		var rc := Vector2(pr.end.x - 46, pr.get_center().y)
		disk(rc, 30, 2, HT.OUTLINE)
		ring(rc, 20, 28, 2, LEFT / TOTAL, HT.ACCENT, HT.RIM_LO)
		disk(rc, 20, 2, HT.INSET)
		txt("%d" % int(LEFT), Vector2(rc.x - 20, rc.y - 13), 24, HT.PRICE, HORIZONTAL_ALIGNMENT_CENTER, 40)
		focus.append(pr.grow(20))

	## D - Kart Masası: yetenek panelinin üstünde herkesin bir kartı; seçen kart kapalı (arkasında portre, üç nokta),
	## bitiren kart açık (portre + tik). Alttan kararan geçiş, altında boşalan fitil çubuğu.
	func _draw_d() -> void:
		var cw := 84.0
		var ch := 116.0
		var gap := 32.0
		var total := team.size() * cw + (team.size() - 1) * gap
		var x0 := roundf(960.0 - total * 0.5)
		var base_y := 684.0
		txt_segs([["KARTLAR BEKLENİYOR  ", HT.TEXT], ["%d/%d" % [ready_count(), team.size()], HT.GOOD]], 960, base_y - 52, 24)
		for i in team.size():
			var p: Dictionary = team[i]
			var x := x0 + i * (cw + gap)
			var ready: bool = p["ready"]
			var y := base_y if ready else base_y - 12.0
			if not ready:
				r(x + 12, base_y + ch - 6, cw - 24, 6, Color(0, 0, 0, 0.32)) ## havada süzülen kartın gölgesi
			var rc := Rect2(x, y, cw, ch)
			if ready:
				frame(rc, Color("#e6d3a8"), HT.OUTLINE, 4.0)
				frame(rc.grow(-4.0), Color(0, 0, 0, 0), HT.ACCENT, 4.0)
				frame(rc.grow(-12.0), Color(0, 0, 0, 0), Color("#c4a46c"), 2.0)
				frame(Rect2(x + 14, y + 18, 56, 56), HT.INSET, HT.OUTLINE, 4.0)
				draw_texture_rect(p["tex"], Rect2(x + 18, y + 22, 48, 48), false)
				check(Vector2(x + cw * 0.5 - 13.5, y + 80), 3.0)
			else:
				frame(rc, HT.RIM_LO, HT.OUTLINE, 4.0)
				frame(rc.grow(-4.0), Color(0, 0, 0, 0), HT.RIM_HI, 4.0)
				## çapraz kafes deseni
				var inner := rc.grow(-8.0)
				var cell := 4.0
				var ny := int(inner.size.y / cell)
				var nx := int(inner.size.x / cell)
				for jj in ny:
					for ii in nx:
						var k := (ii + jj) % 6
						var k2 := (ii - jj + 600) % 6
						if k == 0 or k2 == 0:
							r(inner.position.x + ii * cell, inner.position.y + jj * cell, cell, cell, Color(HT.RIM, 0.9))
				var mrc := Rect2(x + 14, y + 30, 56, 56)
				frame(mrc.grow(4.0), HT.OUTLINE, HT.OUTLINE, 4.0)
				frame(mrc, HT.INSET, HT.ACCENT, 4.0)
				draw_texture_rect(p["tex"], Rect2(x + 18, y + 34, 48, 48), false, Color(1, 1, 1, 0.9))
				bubble(Vector2(x + cw - 22, y - 16), 3.0)
			txt(p["name"], Vector2(x - 14, base_y + ch + 10), 24, HT.TEXT if ready else HT.ACCENT, HORIZONTAL_ALIGNMENT_CENTER, cw + 28)
		var by := base_y + ch + 46
		var bw := total - 64.0
		bar(Rect2(x0, by, bw, 15), LEFT / TOTAL, HT.ACCENT)
		r(x0 + 3 + roundf((bw - 6) * LEFT / TOTAL) - 3, by - 6, 6, 6, Color("#ffe6a0")) ## fitil kıvılcımı
		txt("%d sn" % int(LEFT), Vector2(x0 + bw + 12, by - 6), 24, HT.PRICE)
		focus.append(Rect2(x0 - 40, base_y - 72, total + 80, ch + 150))


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


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var only: String = OS.get_environment("BEKLEME_ONLY")
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
		player.set("health", float(player.get("max_health")) * 0.72)
	gm.set("owned_items", [{"key": "ruzgar_eldiveni"}, {"key": "anka_kusunun_kalbi"}, {"key": "zaman_kiran"}])
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
		a.match_damage_dealt = 900.0 * i
		current_scene.add_child(a)
		a.add_to_group("remote_players")
		if player:
			a.global_position = player.global_position + Vector2(-300 + 300 * (i - 1), -140)
	var hud: Node = current_scene.get_node_or_null("HUD")
	if hud:
		hud.call("update_level", 12)
	Input.warp_mouse(Vector2(1480, 640))
	await _wait(1.5)

	var team: Array = []
	for t: Dictionary in TEAM:
		team.append({"name": t["name"], "ready": t["ready"], "me": t.get("me", false),
				"tex": load(str(chars.get_def(int(t["char"])).get("portrait", "")))})
	var font: Font = load("res://assets/fonts/m5x7.ttf")
	var plaque: StyleBox = load("res://scripts/party_panel.gd")._plaque_style(14.0, 8.0)
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
	print("ROWS ", rows, " party_layer=", party_layer.layer if party_layer else -1)

	var shots: Dictionary = {}
	for k: String in kinds:
		var layers: Array = []
		if k == "simdi":
			current_scene.call("_show_level_up_wait_overlay")
			await process_frame
			var lbl: Label = current_scene.get("_level_up_wait_label")
			var cd: Label = current_scene.get("_level_up_wait_countdown_label")
			if lbl:
				lbl.text = "Seçim yapılıyor: Mira, Deniz\nLütfen bekleyin"
			if cd:
				cd.text = "%ds" % int(LEFT)
			var capl := CanvasLayer.new()
			capl.layer = 99
			var cp := Proto.new()
			cp.kind = k
			cp.font = font
			capl.add_child(cp)
			root.add_child(capl)
			layers.append(capl)
		else:
			var bg := CanvasLayer.new()
			bg.layer = 90
			match k:
				"A":
					var dim := ColorRect.new()
					dim.color = Color(0.06, 0.04, 0.02, 0.3)
					dim.set_anchors_preset(Control.PRESET_FULL_RECT)
					bg.add_child(dim)
				"B":
					bg.add_child(_shader_rect(VIGNETTE))
				"C":
					bg.add_child(_shader_rect(DESAT))
					if party_layer:
						party_layer.layer = 95
				"D":
					bg.add_child(_shader_rect(BOTTOM_FADE))
			root.add_child(bg)
			layers.append(bg)
			var fl := CanvasLayer.new()
			fl.layer = 96
			var pr := Proto.new()
			pr.kind = k
			pr.team = team
			pr.font = font
			pr.plaque = plaque
			pr.rows = rows
			fl.add_child(pr)
			root.add_child(fl)
			layers.append(fl)
		await _wait(0.5)
		var img: Image = await _shot("%s.png" % k)
		shots[k] = img
		for l: Node in layers:
			for ch in l.get_children():
				if ch is Proto:
					var n := 0
					for fr: Rect2 in (ch as Proto).focus:
						var cr := Rect2i(fr).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
						var sub := img.get_region(cr)
						var nm_: String = "yakin_%s%s.png" % [k, "" if n == 0 else str(n + 1)]
						sub.save_png(ProjectSettings.globalize_path(OUT + nm_))
						n += 1
		if k == "simdi":
			current_scene.call("_hide_level_up_wait_overlay")
		if k == "C" and party_layer:
			party_layer.layer = party_layer_orig
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
			sheet.blit_rect(im, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
		sheet.save_png(ProjectSettings.globalize_path(OUT + "ozet.png"))
		print("SHOT ozet.png")
	quit()
