extends "res://tools/proto_20261108/hud_yeni/hud_proto.gd"

## SOL ÜST (ENVANTER / altın / parçacık) + GRUP PANELİ (çubuklar hariç) + HASAR düğmesi + BİLDİRİMLER (görev satırı, küçük levhalar)
## prototipleri (madde 480, 2026-11-08, oyuna bağlı DEĞİL). Kullanıcı: "oyundaki envanter, altın, eşya parçacığı, grup paneli (barlar hariç)
## görünüşleri için yeni prototipler üretir misin ... görünüşleri skill barına benzeyebilir" + "hasar butonu ve bildirimler de dahil".
## hud_capture.gd SOLG=<A..D> gerçek oyunu açar, bu parçaların gerçek düğümlerini gizler, ekran dikdörtgenlerini + verilerini (ad, yüz,
## karakter arka planı, can/kalkan, altın, parçacık, görev, bildirim) buraya verir. Oyuncu paneli, minimap, çubuklar GERÇEK hâliyle kalır;
## müttefik çubukları oyundaki çubuğun kendisi (hud_pixel_bar.gd), yerleri aynı.
## Malzeme oyuncu panelinin (Gömme Tepsi, madde 454) kendisi: yan kutu dokusu (9 dilim), yuva çerçevesi (hud_tray_frame.gd), kuyu rengi
## DOCK_INSET, pirinç = çubuk kapakları. 1 sanat pikseli = 3 ekran pikseli (P), yazı m5x7 32, sayı PixeloidSans 18.
##   A Ayrı Tepsiler   - her parça paneldeki yan kutu gibi kendi tepsisi (sol üst üç kutu, her müttefik ayrı tepsi)
##   B Tek Konsol      - sol üst TEK tepsi (ENVANTER düğmesi + altın/parçacık kuyuları), grup TEK uzun tepsi (satırlar ayraçlı, Hasar altta sekme)
##   C Gömme Kuyular   - ahşap kutu yok: ENVANTER kare yuva (Q/E/R gibi, köşede "I"), altın/parçacık + müttefik satırları koyu gömme kuyu
##   D Pirinç Perçin   - A'nın tepsileri + çubuk kapağı pirinci: köşe perçinleri, pirinç kapaklı sayı kuyuları, ad levhası sekmesi, pirinç halkalı altın düğmesi

const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")
const PixelBarScript: GDScript = preload("res://scripts/hud_pixel_bar.gd")
const TRAY_TEX: Texture2D = preload("res://assets/ui/kit/hud_dock_tray_side.png")
## Kullanıcı: "altın simgelerinde oyundaki altın olmalı (animasyonsuz) parçacık simgesinde de item parçacığı simgesi olmalı" -> oyunun kendi dokuları:
## altın = grup panelinin altın düğmesindeki ilk kare (16 px, 2 kat = 32), parçacık = HUD sayacının simgesi (22 px, oyundaki gibi 33 px).
const GOLD_TEX: Texture2D = preload("res://assets/ui/newui/icon_gold_coin.png")
const SHARD_TEX: Texture2D = preload("res://assets/pickups/weapon_shard/shard_icon.png")
const GOLD_H := 32.0
const SHARD_H := 33.0

const DIAMOND := ["..o..", ".o1o.", "o121o", ".o1o.", "..o.."]
const HOURGLASS := ["ooooo", "o111o", ".o1o.", "..o..", ".o1o.", "o111o", "ooooo"]
const KEY_I := ["ooo", ".o.", ".o.", ".o.", "ooo"]

var sg: Dictionary = {}
var _tray_sb: StyleBoxTexture
var _bars: Control


func setup_sg(st: String, data: Dictionary) -> void:
	style = st
	sg = data
	d = {}
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tray_sb = StyleBoxTexture.new()
	_tray_sb.texture = TRAY_TEX
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_tray_sb.set_texture_margin(side, 18.0)
	_icons = Control.new()
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.size = size
	add_child(_icons)
	_bars = Control.new()
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.size = size
	add_child(_bars)
	_layout()
	_front = Layer.new()
	_front.size = size
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.fn = Callable(self, "_front_sg")
	add_child(_front)
	queue_redraw()


func _draw() -> void:
	_back_sg()


# --- malzeme ------------------------------------------------------------------------------------------------------------------

func sn(r: Rect2) -> Rect2:
	var p: Vector2 = (r.position / P).round() * P
	var e: Vector2 = (r.end / P).round() * P
	return Rect2(p, e - p)


## Paneldeki yan kutunun kendisi (9 dilim, kenar 12 px: dış hat + ahşap + koyu iç çizgi, içi tepsi).
func tray(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_style_box(_tray_sb, r)


## Yetenek yuvası gibi: koyu kuyu + Gömme Tepsi yuva çerçevesi (4 x layer_px).
func slot(ci: CanvasItem, r: Rect2, layer_px: float = 1.0, accent: Color = Color(0, 0, 0, 0)) -> void:
	ci.draw_rect(r, HudTheme.DOCK_INSET)
	HudTrayFrame.draw(ci, r, layer_px, accent)


## Gömme kuyu (kalp sayacı / süre kutusu gibi): dış hat + koyu iç + üstte gölge çizgisi, alt dudakta ahşap ışığı.
func well(ci: CanvasItem, r: Rect2, k: int = 2) -> void:
	rr(ci, r, HudTheme.OUTLINE, k)
	rr(ci, r.grow(-P), HudTheme.DOCK_INSET, maxi(k - 1, 0))
	ci.draw_rect(Rect2(r.position.x + 2 * P, r.position.y + P, r.size.x - 4 * P, P), HudTheme.DEEP)
	ci.draw_rect(Rect2(r.position.x + 2 * P, r.end.y, r.size.x - 4 * P, P), Color(HudTheme.RIM_HI, 0.55))


## Kabarık ahşap düğme (tepsinin üstünde): dış hat + ahşap + üst ışık + alt gölge.
func plate(ci: CanvasItem, r: Rect2) -> void:
	rr(ci, r, HudTheme.OUTLINE, 2)
	var i: Rect2 = r.grow(-P)
	rr(ci, i, HudTheme.RIM, 1)
	ci.draw_rect(Rect2(i.position.x + P, i.position.y, i.size.x - 2 * P, P), HudTheme.RIM_HI)
	ci.draw_rect(Rect2(i.position.x, i.position.y + P, P, i.size.y - 3 * P), HudTheme.RIM_HI)
	ci.draw_rect(Rect2(i.position.x + P, i.end.y - P, i.size.x - 2 * P, P), HudTheme.RIM_LO)


## Dock'taki Q-E-R ayracı (yatay): koyu çizgi + ahşap ışığı.
func hdivider(ci: CanvasItem, x0: float, x1: float, y: float) -> void:
	ci.draw_rect(Rect2(x0, y, x1 - x0, P), HudTheme.OUTLINE)
	ci.draw_rect(Rect2(x0, y + P, x1 - x0, P), Color(HudTheme.RIM_HI, 0.6))


## Çubuk kapağı pirinci: 2x2 sanat px perçin.
func rivet(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_rect(Rect2(p, Vector2(2 * P, 2 * P)), HudTheme.ACCENT_DK)
	ci.draw_rect(Rect2(p, Vector2(P, P)), HudTheme.ACCENT)
	ci.draw_rect(Rect2(p + Vector2(P, 0), Vector2(P, P)), HudTheme.SPOT)
	ci.draw_rect(Rect2(p + Vector2(0, P), Vector2(P, P)), HudTheme.SPOT)


## Tepsi çerçevesinin dört köşesine (açık kenar + ahşap katmanı, köşe basamağının içi).
func rivets(ci: CanvasItem, r: Rect2) -> void:
	rivet(ci, r.position + Vector2(P, P))
	rivet(ci, Vector2(r.end.x - 3 * P, r.position.y + P))
	rivet(ci, Vector2(r.position.x + P, r.end.y - 3 * P))
	rivet(ci, r.end - Vector2(3 * P, 3 * P))


## Pirinç kapaklı kuyu: can çubuğunun kendisi gibi (iki uçta perçinli pirinç kapak, arada koyu kanal).
func brass_well(ci: CanvasItem, r: Rect2) -> void:
	var cw: float = 4 * P
	rr(ci, Rect2(r.position.x + cw - P, r.position.y + P, r.size.x - 2 * cw + 2 * P, r.size.y - 2 * P), HudTheme.OUTLINE, 0)
	ci.draw_rect(Rect2(r.position.x + cw, r.position.y + 2 * P, r.size.x - 2 * cw, r.size.y - 4 * P), HudTheme.DOCK_INSET)
	for side in [0, 1]:
		var cx: float = r.position.x if side == 0 else r.end.x - cw
		var cap := Rect2(cx, r.position.y, cw, r.size.y)
		rr(ci, cap, HudTheme.ACCENT_DK, 1)
		var c2: Rect2 = cap.grow(-P)
		ci.draw_rect(c2, HudTheme.SPOT)
		ci.draw_rect(Rect2(c2.position, Vector2(c2.size.x, P)), HudTheme.ACCENT)
		ci.draw_rect(Rect2(c2.position.x, c2.end.y - P, c2.size.x, P), HudTheme.SPOT.darkened(0.3))
		ci.draw_rect(Rect2(c2.position.x + (P if side == 0 else 0.0), c2.position.y + P, P, c2.size.y - 2 * P),
			HudTheme.ACCENT if side == 0 else HudTheme.SPOT.darkened(0.3))
		var rv := Vector2(c2.position.x + floorf((c2.size.x - P) * 0.5 / P) * P, c2.position.y + floorf((c2.size.y - P) * 0.5 / P) * P)
		ci.draw_rect(Rect2(rv, Vector2(P, P)), HudTheme.ACCENT_DK)


## Pirinç halka (altın düğmesi): dış hat + koyu pirinç + pirinç + ışık, içi koyu.
func brass_socket(ci: CanvasItem, r: Rect2) -> void:
	rr(ci, r, HudTheme.OUTLINE, 2)
	rr(ci, r.grow(-P), HudTheme.ACCENT_DK, 2)
	rr(ci, r.grow(-2 * P), HudTheme.SPOT, 1)
	ci.draw_rect(Rect2(r.position.x + 3 * P, r.position.y + 2 * P, r.size.x - 6 * P, P), HudTheme.ACCENT)
	rr(ci, r.grow(-3 * P), HudTheme.DOCK_INSET, 1)


## Pirinç çerçeveli tuş kapağı ("I"): dış hat + pirinç halka (üstü ışıklı) + koyu kuyu + krem harf.
func brass_key(ci: CanvasItem, r: Rect2, glyph: Array) -> void:
	rr(ci, r, HudTheme.OUTLINE, 1)
	var i: Rect2 = r.grow(-P)
	ci.draw_rect(i, HudTheme.SPOT)
	ci.draw_rect(Rect2(i.position, Vector2(i.size.x, P)), HudTheme.ACCENT)
	ci.draw_rect(i.grow(-P), HudTheme.DOCK_INSET)
	pix_c(ci, glyph, i.grow(-P), {"o": HudTheme.TEXT})


## Koyu tuş kapağı ("I"): kuyu + krem harf (paneldeki Q/E/R harfleriyle aynı renk).
func dark_key(ci: CanvasItem, r: Rect2, glyph: Array) -> void:
	rr(ci, r, HudTheme.OUTLINE, 1)
	ci.draw_rect(r.grow(-P), HudTheme.DOCK_INSET)
	pix_c(ci, glyph, r, {"o": HudTheme.TEXT})


func t(ci: CanvasItem, pos: Vector2, s: String, size: int = 32, col: Color = HudTheme.TEXT, font: Font = F) -> void:
	txt(ci, pos, s, size, col, font, HudTheme.OUTLINE)


## Dikeyde ortalı yazı (büyük harf yüksekliğine göre).
func t_mid(ci: CanvasItem, x: float, r: Rect2, s: String, size: int = 32, col: Color = HudTheme.TEXT, font: Font = F) -> void:
	t(ci, Vector2(x, round(r.position.y + (r.size.y - cap_h(size, font)) * 0.5)), s, size, col, font)


## Dikeyde ortalı simge: piksel haritası (rows + palet) ya da oyunun dokusu (rows = Texture2D, pal = hedef yükseklik px).
func icon_mid(ci: CanvasItem, rows: Variant, pal: Variant, x: float, r: Rect2) -> float:
	if rows is Texture2D:
		return icon_tex(ci, rows, x, r, float(pal))
	var s: Vector2 = pix_size(rows)
	pix(ci, rows, Vector2(x, r.position.y + floorf((r.size.y - s.y) * 0.5 / P) * P), pal)
	return s.x


func icon_tex(ci: CanvasItem, tx: Texture2D, x: float, r: Rect2, h: float) -> float:
	var ts: Vector2 = tx.get_size()
	var sz: Vector2 = (ts * (h / ts.y)).round()
	ci.draw_texture_rect(tx, Rect2(Vector2(round(x), round(r.position.y + (r.size.y - sz.y) * 0.5)), sz), false)
	return sz.x


func icon_tex_c(ci: CanvasItem, tx: Texture2D, r: Rect2, h: float) -> void:
	var ts: Vector2 = tx.get_size()
	var sz: Vector2 = (ts * (h / ts.y)).round()
	ci.draw_texture_rect(tx, Rect2((r.position + (r.size - sz) * 0.5).round(), sz), false)


func kind_pal(kind: String) -> Dictionary:
	var c: Color = sg.get("kind_colors", {}).get(kind, HudTheme.TEXT)
	return {"o": HudTheme.OUTLINE, "1": c, "2": c.lightened(0.35)}


# --- yerleşim --------------------------------------------------------------------------------------------------------------------
## Sol üst sütun gerçek ENVANTER'in sol üst köşesinden başlar; grup satırları, Hasar, görev ve bildirimler gerçek yerlerinde (3 px'e oturur),
## yalnız kutu boyları malzemenin kenarına göre birkaç sanat pikseli büyür. Müttefik çubukları gerçek çubuk, gerçek dikdörtgende.

var L: Dictionary = {}


func _layout() -> void:
	var env: Rect2 = sn(sg.get("env", Rect2(20, 20, 166, 43)))
	var o: Vector2 = env.position
	match style:
		"A", "D":
			L["env"] = Rect2(o, Vector2(66 * P, 19 * P))
			L["gold"] = Rect2(o + Vector2(0, 21 * P), Vector2(66 * P, 19 * P))
			L["shard"] = Rect2(o + Vector2(0, 42 * P), Vector2(66 * P, 19 * P))
		"B":
			L["console"] = Rect2(o, Vector2(76 * P, 42 * P))
		"C":
			L["env"] = Rect2(o, Vector2(26 * P, 26 * P))
			L["gold"] = Rect2(o + Vector2(28 * P, 0), Vector2(44 * P, 12 * P))
			L["shard"] = Rect2(o + Vector2(28 * P, 14 * P), Vector2(44 * P, 12 * P))
	## Hasar: gerçek düğmenin sağ üst köşesi; B'de grup tepsisinin altına asılı sekme
	var hb: Rect2 = sn(sg.get("dmg", Rect2()))
	var rows: Array = sg.get("rows", [])
	if hb.size.x > 0.0:
		var w: float = ceilf((tw("Hasar", 32) + 2 * 12.0 + 4 * P) / P) * P
		if style == "B" and not rows.is_empty():
			var last: Rect2 = _row_box(rows[rows.size() - 1])
			L["dmg"] = Rect2(last.end.x - w - 4 * P, last.end.y - 3 * P, w, 12 * P)
		else:
			L["dmg"] = Rect2(hb.end.x - w + P, hb.position.y, w, 13 * P)
	## görev satırı: gerçek yer, boy malzemeye göre (başlık + çubuk sığsın); bildirimler onun altından, sağa yaslı
	var bn: Rect2 = sn(sg.get("banner", {}).get("rect", Rect2()))
	var col_y: float = 0.0
	if bn.size.x > 0.0:
		var top: float = maxf(bn.position.y, L.get("dmg", Rect2()).end.y + P)
		L["banner"] = Rect2(bn.position.x, top, bn.size.x, 22 * P)
		col_y = L["banner"].end.y + 2 * P
	var nl: Array = []
	for n: Dictionary in sg.get("notices", []):
		var r0: Rect2 = sn(n["rect"])
		var cd: float = float(n.get("countdown", -1.0))
		var cw: float = tw(str(n.get("title", "")), 32) + (tw("%d sn" % int(ceil(cd)), 32) + 5 * P if cd >= 0.0 else 0.0)
		var h: float = (13 if style == "C" else 15) * P
		var pad: float = (3 if style == "C" else 4) * P
		var w2: float = ceilf((cw + 2 * pad + 7 * P + 3 * P + 3 * P) / P) * P
		var y: float = maxf(r0.position.y, col_y)
		var rr2 := Rect2(r0.end.x - w2, y, w2, h)
		nl.append({"rect": rr2, "kind": n.get("kind", "info"), "title": n.get("title", ""), "countdown": cd})
		col_y = rr2.end.y + 2 * P
	L["notices"] = nl
	for row: Dictionary in rows:
		var bar_k: Array = [["hp", row.get("hp_ratio", 1.0), row.get("hp_fill", HudTheme.HP_GREEN), row.get("hp_text", ""), HudTheme.TEXT],
			["sh", row.get("sh_ratio", 0.0), HudTheme.SHIELD_BAR, row.get("sh_text", ""), HudTheme.TEXT]]
		for bk in bar_k:
			var br: Rect2 = row.get(bk[0], Rect2())
			if br.size.x <= 0.0:
				continue
			var bar: Control = PixelBarScript.new()
			bar.set("merged", true)
			bar.set("value_color", bk[4])
			bar.position = br.position
			bar.size = br.size
			_bars.add_child(bar)
			bar.call("set_values", float(bk[1]), bk[2], str(bk[3]))
		var av: Rect2 = sn(row.get("avatar", Rect2()))
		if av.size.x > 0.0:
			if row.get("bg") != null:
				tex(row["bg"], av)
			tex(row.get("face"), av)


# --- arka (kutular) ----------------------------------------------------------------------------------------------------------------

func _back_sg() -> void:
	match style:
		"A": _back_a_sg(false)
		"D": _back_a_sg(true)
		"B": _back_b_sg()
		"C": _back_c_sg()


func _row_box(row: Dictionary) -> Rect2:
	var r: Rect2 = sn(row.get("row", Rect2()))
	return Rect2(r.position.x - 2 * P, r.position.y - P, r.size.x + 3 * P, r.size.y + 2 * P)


func _gold_btn(row: Dictionary) -> Rect2:
	var gb: Rect2 = sn(row.get("gold_btn", Rect2()))
	var c: Vector2 = gb.get_center().snapped(Vector2(P, P))
	return Rect2(c - Vector2(7 * P, 7 * P), Vector2(14 * P, 14 * P))


func _dmg_box() -> Rect2:
	return L.get("dmg", Rect2())


func _banner_box() -> Rect2:
	return L.get("banner", Rect2())


func _back_a_sg(brass: bool) -> void:
	for k in ["env", "gold", "shard"]:
		var r: Rect2 = L[k]
		tray(self, r)
		if brass:
			rivets(self, r)
	for row: Dictionary in sg.get("rows", []):
		var rb: Rect2 = _row_box(row)
		tray(self, rb)
		if brass:
			rivets(self, rb)
		var av: Rect2 = sn(row.get("avatar", Rect2()))
		if av.size.x > 0.0:
			draw_rect(av, HudTheme.DOCK_INSET)
		var gb: Rect2 = _gold_btn(row)
		if brass:
			brass_socket(self, gb)
		else:
			draw_rect(gb, HudTheme.DOCK_INSET)
	var db: Rect2 = _dmg_box()
	if db.size.x > 0.0:
		tray(self, db)
	var bn: Rect2 = _banner_box()
	if bn.size.x > 0.0:
		tray(self, bn)
		if brass:
			rivets(self, bn)
	for n: Dictionary in L.get("notices", []):
		tray(self, n["rect"])
		if brass:
			rivets(self, n["rect"])


func _back_b_sg() -> void:
	var c: Rect2 = L["console"]
	tray(self, c)
	var rows: Array = sg.get("rows", [])
	if not rows.is_empty():
		var first: Rect2 = _row_box(rows[0])
		var last: Rect2 = _row_box(rows[rows.size() - 1])
		var panel := Rect2(first.position.x, first.position.y, first.size.x, last.end.y - first.position.y)
		tray(self, panel)
		for i in rows.size():
			var row: Dictionary = rows[i]
			if i > 0:
				hdivider(self, panel.position.x + 6 * P, panel.end.x - 6 * P, _row_box(row).position.y - P)
			var av: Rect2 = sn(row.get("avatar", Rect2()))
			if av.size.x > 0.0:
				draw_rect(av, HudTheme.DOCK_INSET)
			draw_rect(_gold_btn(row), HudTheme.DOCK_INSET)
	var bn: Rect2 = _banner_box()
	if bn.size.x > 0.0:
		tray(self, bn)
	for n: Dictionary in L.get("notices", []):
		tray(self, n["rect"])


func _back_c_sg() -> void:
	slot(self, L["env"], 2.0)
	well(self, L["gold"])
	well(self, L["shard"])
	for row: Dictionary in sg.get("rows", []):
		well(self, _row_box(row), 3)
		var av: Rect2 = sn(row.get("avatar", Rect2()))
		if av.size.x > 0.0:
			draw_rect(av, HudTheme.DOCK_INSET)
		draw_rect(_gold_btn(row), HudTheme.DOCK_INSET)
	var db: Rect2 = _dmg_box()
	if db.size.x > 0.0:
		plate(self, Rect2(db.position.x, db.position.y + 2 * P, db.size.x, db.size.y - 4 * P))
	var bn: Rect2 = _banner_box()
	if bn.size.x > 0.0:
		well(self, bn, 3)
	for n: Dictionary in L.get("notices", []):
		well(self, n["rect"], 3)


# --- ön (simgeler, yazılar, çerçeveler) ----------------------------------------------------------------------------------------------

func _front_sg(ci: CanvasItem) -> void:
	var gold_s: String = _money_str(int(str(sg.get("gold_text", "0")).to_int()))
	var shard_s: String = str(sg.get("shard_text", "0"))
	match style:
		"A", "D":
			var brass: bool = style == "D"
			var e: Rect2 = L["env"].grow(-12.0)
			var x: float = e.position.x + P
			x += icon_mid(ci, BAG, BAG_PAL, x, e) + 2 * P
			t_mid(ci, x, e, "Envanter")
			var kr := Rect2(e.end.x - (9 if brass else 7) * P, e.position.y + (P if brass else 2 * P), (9 if brass else 7) * P,
				e.size.y - (2 if brass else 4) * P)
			if brass:
				brass_key(ci, kr, KEY_I)
			else:
				dark_key(ci, kr, KEY_I)
			for pair in [["gold", GOLD_TEX, GOLD_H, gold_s, HudTheme.PRICE], ["shard", SHARD_TEX, SHARD_H, shard_s, HudTheme.SHARD]]:
				var r: Rect2 = L[pair[0]].grow(-12.0)
				if brass:
					var bw := Rect2(r.position.x + 13 * P, r.position.y + 2 * P, r.size.x - 13 * P, r.size.y - 4 * P)
					brass_well(ci, bw)
					icon_mid(ci, pair[1], pair[2], r.position.x + 2 * P, r)
					txt_c(ci, bw, pair[3], 18, pair[4], N, Color(0, 0, 0, 0), HudTheme.OUTLINE)
				else:
					var ix: float = r.position.x + 2 * P
					ix += icon_mid(ci, pair[1], pair[2], ix, r) + 3 * P
					t_mid(ci, ix, r, pair[3], 18, pair[4], N)
		"B":
			_front_b_console(ci, gold_s, shard_s)
		"C":
			var s: Rect2 = L["env"]
			pix_c(ci, BAG, Rect2(s.position + Vector2(2 * P, 2 * P), s.size - Vector2(6 * P, 6 * P)), BAG_PAL)
			## Q/E/R gibi: köşede krem harf, koyu konturlu
			t(ci, Vector2(s.end.x - 7 * P, s.end.y - 9 * P), "I")
			for pair in [["gold", GOLD_TEX, GOLD_H, gold_s, HudTheme.PRICE], ["shard", SHARD_TEX, SHARD_H, shard_s, HudTheme.SHARD]]:
				var r: Rect2 = L[pair[0]]
				var ix: float = r.position.x + 3 * P
				ix += icon_mid(ci, pair[1], pair[2], ix, r) + 3 * P
				t_mid(ci, ix, r, pair[3], 18, pair[4], N)
	_front_party(ci)
	_front_notices(ci)


func _front_b_console(ci: CanvasItem, gold_s: String, shard_s: String) -> void:
	var c: Rect2 = L["console"].grow(-12.0)
	## ENVANTER: konsolun üstünde kabarık ahşap düğme
	var bt := Rect2(c.position + Vector2(P, P), Vector2(c.size.x - 2 * P, 15 * P))
	plate(ci, bt)
	var x: float = bt.position.x + 3 * P
	x += icon_mid(ci, BAG, BAG_PAL, x, bt) + 2 * P
	t_mid(ci, x, bt, "Envanter")
	dark_key(ci, Rect2(bt.end.x - 9 * P, bt.position.y + 3 * P, 6 * P, bt.size.y - 6 * P), KEY_I)
	hdivider(ci, c.position.x + P, c.end.x - P, bt.end.y + P)
	## altın + parçacık: yan yana iki gömme kuyu
	var wy: float = bt.end.y + 4 * P
	var wh: float = c.end.y - wy - P
	var gw := Rect2(c.position.x + P, wy, floorf((c.size.x - 3 * P) * 0.62 / P) * P, wh)
	var sw := Rect2(gw.end.x + P, wy, c.end.x - P - gw.end.x - P, wh)
	for pair in [[gw, GOLD_TEX, GOLD_H, gold_s, HudTheme.PRICE], [sw, SHARD_TEX, SHARD_H, shard_s, HudTheme.SHARD]]:
		var r: Rect2 = pair[0]
		well(ci, r)
		var ix: float = r.position.x + 2 * P
		ix += icon_mid(ci, pair[1], pair[2], ix, r) + 2 * P
		t_mid(ci, ix, r, pair[3], 18, pair[4], N)


func _front_party(ci: CanvasItem) -> void:
	for row: Dictionary in sg.get("rows", []):
		var av: Rect2 = sn(row.get("avatar", Rect2()))
		var nr: Rect2 = sn(row.get("name", Rect2()))
		var name_s: String = str(row.get("name_text", ""))
		if style == "D" and nr.size.x > 0.0:
			## ad levhası sekmesi: tepsinin üst kenarına binen koyu levha, pirinç uçlu
			var w: float = ceilf((tw(name_s, 32) + 6 * P) / P) * P
			var tab := Rect2(nr.position.x - 2 * P, _row_box(row).position.y - 2 * P, w, 9 * P)
			rr(ci, tab, HudTheme.OUTLINE, 1)
			ci.draw_rect(tab.grow(-P), HudTheme.DOCK_INSET)
			ci.draw_rect(Rect2(tab.position.x + P, tab.position.y + P, P, tab.size.y - 2 * P), HudTheme.SPOT)
			ci.draw_rect(Rect2(tab.end.x - 2 * P, tab.position.y + P, P, tab.size.y - 2 * P), HudTheme.SPOT)
			t_mid(ci, tab.position.x + 3 * P, tab, name_s)
		elif nr.size.x > 0.0:
			t(ci, Vector2(nr.position.x, nr.position.y + P), name_s)
		if row.get("downed", false):
			t(ci, Vector2(nr.end.x - tw("YERDE", 32), nr.position.y + P), "YERDE", 32, HudTheme.BAD)
		if av.size.x > 0.0:
			match style:
				"C":
					HudTrayFrame.draw(ci, av.grow(8.0), 2.0)
				_:
					HudTrayFrame.draw(ci, av.grow(4.0), 1.0)
		var gb: Rect2 = _gold_btn(row)
		match style:
			"D":
				icon_tex_c(ci, GOLD_TEX, gb, GOLD_H)
			"C":
				HudTrayFrame.draw(ci, gb, 1.0)
				icon_tex_c(ci, GOLD_TEX, gb, GOLD_H)
			_:
				HudTrayFrame.draw(ci, gb, 1.0)
				icon_tex_c(ci, GOLD_TEX, gb, GOLD_H)
	var db: Rect2 = _dmg_box()
	if db.size.x > 0.0:
		match style:
			"B":
				plate(ci, db)
				txt_c(ci, db, "Hasar", 32, HudTheme.TEXT, F, HudTheme.OUTLINE)
			"C":
				txt_c(ci, Rect2(db.position.x, db.position.y + 2 * P, db.size.x, db.size.y - 4 * P), "Hasar", 32, HudTheme.TEXT, F, HudTheme.OUTLINE)
			_:
				txt_c(ci, db, "Hasar", 32, HudTheme.TEXT, F, HudTheme.OUTLINE)


func _front_notices(ci: CanvasItem) -> void:
	var bn: Rect2 = _banner_box()
	var binfo: Dictionary = sg.get("banner", {})
	if bn.size.x > 0.0:
		var inner: Rect2 = bn.grow(-12.0) if style != "C" else bn.grow(-3 * P)
		var ic := Rect2(inner.position.x + P, inner.position.y + floorf((inner.size.y - 12 * P) * 0.5 / P) * P, 12 * P, 12 * P)
		if style == "D":
			brass_socket(ci, ic.grow(P))
		else:
			slot(ci, ic, 1.0)
		pix_c(ci, FLAG, ic, FLAG_PAL)
		var tx: float = ic.end.x + 3 * P
		t(ci, Vector2(tx, inner.position.y + P), str(binfo.get("title", "")))
		var cur: int = int(binfo.get("cur", 0))
		var mx: int = maxi(1, int(binfo.get("max", 1)))
		var br := Rect2(tx, inner.end.y - 7 * P, inner.end.x - tx - P, 7 * P)
		var bar: Control = PixelBarScript.new()
		bar.set("merged", true)
		bar.position = br.position
		bar.size = br.size
		_bars.add_child(bar)
		bar.call("set_values", float(cur) / float(mx), HudTheme.ACCENT_SOFT, "%d/%d" % [cur, mx])
	for n: Dictionary in L.get("notices", []):
		var r: Rect2 = n["rect"]
		var inner: Rect2 = r.grow(-12.0) if style != "C" else r.grow(-3 * P)
		var kind: String = str(n.get("kind", "info"))
		var col: Color = sg.get("kind_colors", {}).get(kind, HudTheme.TEXT)
		var x: float = inner.position.x + 2 * P
		x += icon_mid(ci, HOURGLASS if float(n.get("countdown", -1.0)) >= 0.0 else DIAMOND, kind_pal(kind), x, inner) + 3 * P
		t_mid(ci, x, inner, str(n.get("title", "")), 32, col)
		var cd: float = float(n.get("countdown", -1.0))
		if cd >= 0.0:
			var s: String = "%d sn" % int(ceil(cd))
			t_mid(ci, inner.end.x - tw(s, 32) - 2 * P, inner, s, 32, HudTheme.DIM)
