extends "res://tools/proto_20261108/hud_yeni/hud_proto.gd"

## V2 - BUGÜNKÜ YERLEŞİM + A/B/C/D KAPLAMASI (2026-11-08, oyuna bağlı DEĞİL). Kullanıcı (v1'den sonra): "şuanki tasarımı koruyarak buna
## göre prototip hazırla" -> yerleşim (dock, sol üst levhalar, yuvarlak harita, grup, görev satırı) gerçek HUD düğümlerinin ekran
## dikdörtgenlerinden (hud_capture.gd _geo) gelir ve 3 px ızgaraya oturtulur; değişen yalnız kaplama (kutu, kuyu, çubuk, tuş kapağı,
## seviye rozeti, harita halkası, yazı rengi) ve yeni piksel simgeler. Kaplamalar v1'in A/B/C/D dilleri (hud_proto.gd).

var geo: Dictionary = {}
var skin: String = "A"


func setup_v2(st: String, data: Dictionary, gd: Dictionary) -> void:
	skin = st
	d = data
	geo = gd
	style = "V2"
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icons = Control.new()
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.size = size
	add_child(_icons)
	_build_v2()
	_front = Layer.new()
	_front.size = size
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_front.fn = Callable(self, "_front_v2")
	add_child(_front)
	queue_redraw()


func sn(r: Rect2) -> Rect2:
	var p: Vector2 = (r.position / P).round() * P
	var e: Vector2 = (r.end / P).round() * P
	return Rect2(p, e - p)


func gr(key: String) -> Rect2:
	var r: Rect2 = sn(geo.get(key, Rect2()))
	if key == "dmg_btn" and r.size.x > 0.0:
		## "Hasar" m5x7 32 düğmeye sığmıyor: sağ kenar sabit, sola genişler
		var need: float = ceilf((tw("Hasar", 32) + 18.0) / P) * P
		if need > r.size.x:
			r = Rect2(r.end.x - need, r.position.y, need, r.size.y)
	return r


func _frame_line(ci: CanvasItem, r: Rect2, c: Color) -> void:
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, P)), c)
	ci.draw_rect(Rect2(r.position.x, r.end.y - P, r.size.x, P), c)
	ci.draw_rect(Rect2(r.position, Vector2(P, r.size.y)), c)
	ci.draw_rect(Rect2(r.end.x - P, r.position.y, P, r.size.y), c)


# --- kaplama işlevleri -------------------------------------------------------------------------------------------------------

func k_panel(ci: CanvasItem, r: Rect2, k: int = 2) -> void:
	if r.size.x <= 0.0:
		return
	match skin:
		"A":
			_box_a(ci, r, k)
		"B":
			rr(ci, r, B_RIM, k)
			rr(ci, r.grow(-P), B_FILL, maxi(k - 1, 0))
			ci.draw_rect(Rect2(r.position.x + k * P, r.position.y + P, r.size.x - 2 * k * P, P), Color(B_RIM_HI, 0.55))
		"C":
			_card(ci, r, C_BG, C_BORDER, 3 * k)
		"D":
			_log_d(ci, r, true)


func k_well(ci: CanvasItem, r: Rect2) -> void:
	match skin:
		"A": _well_a(ci, r)
		"B": _slot_b(ci, r)
		"C": _well_c(ci, r)
		"D": _socket_d(ci, r)


## Yazı taşıyan koyu kuyu (kalp sayacı, stat düğmesi, grup altın düğmesi).
func k_dark_well(ci: CanvasItem, r: Rect2) -> void:
	match skin:
		"A":
			rr(ci, r, A_OUT, 1)
			rr(ci, r.grow(-P), A_DK, 0)
			ci.draw_rect(Rect2(r.position + Vector2(P, P), Vector2(r.size.x - 2 * P, P)), A_GROOVE)
		"B":
			rr(ci, r, B_RIM_DK, 1)
			rr(ci, r.grow(-P), B_FILL_SOLID, 0)
		"C":
			rr(ci, r, C_BORDER, 1)
			rr(ci, r.grow(-P), C_DARK, 0)
		"D":
			_socket_d(ci, r)


func k_text_col() -> Color:
	match skin:
		"B": return B_TEXT
		"C": return C_INK
		"D": return D_END
	return CREAM


func k_t(ci: CanvasItem, pos: Vector2, s: String, size: int, font: Font = F, col: Color = Color(0, 0, 0, 0)) -> void:
	var c: Color = k_text_col() if col.a == 0.0 else col
	match skin:
		"A": txt(ci, pos, s, size, c, font, A_OUT)
		"B": txt(ci, pos, s, size, c, font, Color(0, 0, 0, 0), DEEP)
		"C": txt(ci, pos, s, size, c, font)
		"D": txt(ci, pos, s, size, c, font, D_INK)


func k_tc(ci: CanvasItem, r: Rect2, s: String, size: int, font: Font = F, col: Color = Color(0, 0, 0, 0)) -> void:
	var w: float = tw(s, size, font)
	var h: float = cap_h(size, font)
	k_t(ci, Vector2(round(r.position.x + (r.size.x - w) * 0.5), round(r.position.y + (r.size.y - h) * 0.5)), s, size, font, col)


func k_bar(ci: CanvasItem, r: Rect2, ratio: float, cols: Array, k: int = 1) -> void:
	match skin:
		"A": hbar(ci, r, ratio, cols, A_GROOVE, A_OUT, k)
		"B": hbar(ci, r, ratio, cols, B_FILL_SOLID, B_RIM, k)
		"C": hbar(ci, r, ratio, cols, C_DARK, C_BORDER, k)
		"D": hbar(ci, r, ratio, cols, D_SOCKET, D_BARK, k)


func k_key(ci: CanvasItem, r: Rect2, key: String) -> void:
	match skin:
		"A":
			rr(ci, r, A_OUT, 1)
			rr(ci, r.grow(-P), A_DK, 0)
			txt_c(ci, r, key, 32, A_WELL)
		"B":
			txt_c(ci, r, key, 32, B_TEXT, F, Color(0, 0, 0, 0), DEEP)
		"C":
			rr(ci, r, C_BORDER, 1)
			rr(ci, r.grow(-P), C_DARK, 0)
			txt_c(ci, r, key, 32, Color("#efd9ad"))
		"D":
			_brass_d(ci, r)
			## levhanın alt 2 sanat pikseli gölge: harf parlak kısma ortalanır (yoksa E'nin alt çizgisi gölgede kaybolup F okunur)
			txt_c(ci, Rect2(r.position, r.size - Vector2(0, 2 * P)), key, 32, D_INK)


## Halka (harita çerçevesi, rozet kenarı): r0 iç, r1 dış yarıçap.
func k_ring(ci: CanvasItem, c: Vector2, r0: float, r1: float) -> void:
	match skin:
		"A":
			_annulus(ci, c, r0 - P, r1, A_OUT)
			_annulus(ci, c, r0, r1 - P, A_LO)
			_annulus(ci, c, r0 + P, r1 - 2 * P, A_HI)
			_annulus(ci, c, r0 + P, r1 - 3 * P, A_MID)
		"B":
			_annulus(ci, c, r0 - P, r1, B_RIM)
			_annulus(ci, c, r0, r1 - P, Color(0.11, 0.075, 0.045, 0.92))
			_annulus(ci, c, r1 - 2 * P, r1 - P, Color(B_RIM_HI, 0.5))
		"C":
			_annulus(ci, c, r0 - P, r1, C_BORDER)
			_annulus(ci, c, r0, r1 - P, C_BG)
			_annulus(ci, c, r1 - 2 * P, r1 - P, Color("#f5e6c4"))
			_annulus(ci, c, r0, r0 + P, C_WELL_SH)
		"D":
			_annulus(ci, c, r0 - P, r1, D_BARK)
			_annulus(ci, c, r0, r1 - P, D_END_RING)
			_annulus(ci, c, r0 + P, r1 - 2 * P, D_END)
			var mid: float = floorf((r0 + r1) * 0.5 / P) * P
			_annulus(ci, c, mid, mid + P, D_END_RING)


func k_disc(ci: CanvasItem, c: Vector2, rad: float) -> void:
	k_ring(ci, c, 0.0, rad)
	match skin:
		"A": _annulus(ci, c, 0.0, rad - 3 * P, A_MID)
		"B": _annulus(ci, c, 0.0, rad - P, Color(0.11, 0.075, 0.045, 0.95))
		"C": _annulus(ci, c, 0.0, rad - 2 * P, C_BG)
		"D": _annulus(ci, c, 0.0, rad - 2 * P, D_END)


# --- kurulum ---------------------------------------------------------------------------------------------------------------

func _build_v2() -> void:
	var sk: Array = _skills()
	var keys: Array = ["q", "e", "r", "f"]
	for i in 4:
		var r: Rect2 = gr(keys[i])
		if r.size.x > 0.0:
			tex(sk[i + 1].get("tex"), r.grow(-6.0))
	## küçük yuvalar ve efsanevi hücreler: 32 px simge tam katla sığsın diye kuyu kenarı payı bırakılmaz (yoksa yarıya iner)
	var pr: Rect2 = gr("passive")
	if pr.size.x > 0.0:
		tex(sk[0].get("tex"), pr.grow(-3.0))
	var pet: Rect2 = gr("pet")
	if pet.size.x > 0.0:
		tex(d.get("pet"), pet)
	var po: Rect2 = gr("portrait")
	if po.size.x > 0.0:
		tex(d.get("portrait"), po.grow(-9.0))
	var cells: Array = geo.get("legend_cells", [])
	var licons: Array = geo.get("legend_icons", [])
	for i in cells.size():
		if i < licons.size() and licons[i] != null:
			tex(licons[i], sn(cells[i]))
	var shield_cell: Rect2 = sn(geo.get("legend_shield", Rect2()))
	if shield_cell.size.x > 0.0 and geo.get("legend_shield_tex") != null:
		tex(geo["legend_shield_tex"], shield_cell)
	for row in geo.get("party", []):
		var av: Rect2 = sn(row.get("avatar", Rect2()))
		if av.size.x > 0.0 and row.get("portrait") != null:
			tex(row["portrait"], av)
	## harita: gerçek düğüm, yerinde ve yuvarlak; halkayı ön katman çizer
	var mm: Control = d.get("minimap") as Control
	if mm:
		var gp: Vector2 = geo.get("minimap_pos", mm.global_position)
		mm.get_parent().remove_child(mm)
		add_child(mm)
		mm.set("square", false)
		mm.scale = Vector2.ONE
		mm.position = gp
		mm.queue_redraw()


func _back_v2() -> void:
	var xp: Rect2 = gr("xp")
	if xp.size.x > 0.0:
		k_bar(self, Rect2(0.0, 1080.0 - 12.0, 1920.0, 12.0), float(d.get("xp_ratio", 0.6)), XP_COLS, 0)
	for key in ["envanter", "gold", "shard"]:
		k_panel(self, gr(key), 2)
	for row in geo.get("party", []):
		k_panel(self, sn(row.get("row", Rect2())), 2)
		var av: Rect2 = sn(row.get("avatar", Rect2()))
		if av.size.x > 0.0:
			k_well(self, av.grow(3.0))
		var gb: Rect2 = sn(row.get("gold_btn", Rect2()))
		if gb.size.x > 0.0:
			k_dark_well(self, gb)
	var hb: Rect2 = gr("dmg_btn")
	if hb.size.x > 0.0:
		k_panel(self, hb, 1)
	var bn: Rect2 = gr("banner")
	if bn.size.x > 0.0:
		k_panel(self, bn, 2)
		k_well(self, Rect2(bn.position + Vector2(9, 9), Vector2(bn.size.y - 18.0, bn.size.y - 18.0)))
	## efsanevi panel (ana panelin arkasında)
	var lg: Rect2 = gr("legend")
	if lg.size.x > 0.0:
		k_panel(self, lg, 2)
		for c in geo.get("legend_cells", []):
			k_well(self, sn(c))
		var shc: Rect2 = sn(geo.get("legend_shield", Rect2()))
		if shc.size.x > 0.0:
			k_well(self, shc)
			_frame_line(self, shc.grow(-P), Color(0.36, 0.66, 0.95, 0.85)) ## mana kalkanı yuvası: anlamlı mavi (bugünkü gibi)
	## ana panel
	k_panel(self, gr("frame"), 4)
	k_well(self, gr("portrait"))
	for key in ["q", "e", "r", "f", "passive", "pet"]:
		var r: Rect2 = gr(key)
		if r.size.x > 0.0:
			k_well(self, r)
	var fslot: Rect2 = gr("f")
	if fslot.size.x > 0.0:
		_frame_line(self, fslot.grow(-P), Color(0.6, 0.45, 0.85, 0.9)) ## ruhani yuvanın bugünkü mor anlamı
	var dv: Rect2 = gr("divider")
	if dv.size.y > 0.0:
		var x: float = dv.position.x
		var top: float = dv.position.y
		match skin:
			"A":
				draw_rect(Rect2(x, top, P, dv.size.y), A_LO)
				draw_rect(Rect2(x + P, top, P, dv.size.y), A_HI)
			"B":
				draw_rect(Rect2(x, top, P, dv.size.y), Color(B_RIM, 0.7))
			"C":
				draw_rect(Rect2(x, top, P, dv.size.y), C_WELL_SH)
				draw_rect(Rect2(x + P, top, P, dv.size.y), Color("#f5e6c4"))
			"D":
				draw_rect(Rect2(x, top, P, dv.size.y), D_BARK)
				draw_rect(Rect2(x + P, top, P, dv.size.y), D_GRAIN_HI)
	var hr: Rect2 = gr("hearts")
	if hr.size.x > 0.0:
		k_dark_well(self, Rect2(hr.position.x, hr.end.y - 30.0, hr.size.x, 30.0))
	var tg: Rect2 = gr("toggle")
	if tg.size.x > 0.0:
		k_dark_well(self, tg)


func _front_v2(ci: CanvasItem) -> void:
	## harita halkası (minimap'in kendi halka dokusunu örter) + kuzey levhası
	var mc: Vector2 = geo.get("minimap_center", Vector2.ZERO)
	if mc != Vector2.ZERO:
		mc = mc.snapped(Vector2(P, P))
		k_ring(ci, mc, 81.0, 96.0)
		k_key(ci, Rect2(mc.x - 15.0, mc.y - 105.0, 30.0, 27.0), "K")
	## sol üst: ENVANTER / altın / parçacık
	var ev: Rect2 = gr("envanter")
	if ev.size.x > 0.0:
		k_tc(ci, ev, "ENVANTER", 32)
	var go: Rect2 = gr("gold")
	if go.size.x > 0.0:
		pix(ci, COIN, Vector2(go.position.x + 18.0, go.position.y + (go.size.y - 30.0) * 0.5).snapped(Vector2(P, P)), COIN_PAL)
		k_t(ci, Vector2(go.position.x + 60.0, go.position.y + roundf((go.size.y - 14.0) * 0.5)), _money_str(int(d.get("gold", 0))), 18, N,
				C_INK if skin == "C" else Color("#f6d27e"))
	var shd: Rect2 = gr("shard")
	if shd.size.x > 0.0:
		pix(ci, SHARD, Vector2(shd.position.x + 21.0, shd.position.y + (shd.size.y - 33.0) * 0.5).snapped(Vector2(P, P)), SHARD_PAL)
		k_t(ci, Vector2(shd.position.x + 60.0, shd.position.y + roundf((shd.size.y - 14.0) * 0.5)), str(d.get("shards", 0)), 18, N,
				C_INK if skin == "C" else Color("#cfe9f7"))
	## grup satırları
	var allies: Array = d.get("allies", [])
	var rows: Array = geo.get("party", [])
	for i in rows.size():
		var row: Dictionary = rows[i]
		var a: Dictionary = allies[i] if i < allies.size() else {}
		var nl: Rect2 = sn(row.get("name", Rect2()))
		k_t(ci, nl.position + Vector2(0, 3), str(a.get("name", "")), 32)
		var hbr: Rect2 = sn(row.get("hp", Rect2()))
		if hbr.size.x > 0.0:
			k_bar(ci, hbr, float(a.get("hp", 0)) / maxf(1.0, float(a.get("hp_max", 1))), HP_COLS, 0)
			txt_c(ci, hbr, "%d/%d" % [int(a.get("hp", 0)), int(a.get("hp_max", 0))], 9, CREAM, N, DEEP)
		var sbr: Rect2 = sn(row.get("sh", Rect2()))
		if sbr.size.x > 0.0:
			k_bar(ci, sbr, float(a.get("sh", 0)) / maxf(1.0, float(a.get("sh_max", 1))), SH_COLS, 0)
			if float(a.get("sh_max", 0)) > 0.0:
				txt_c(ci, sbr, "%d/%d" % [int(a.get("sh", 0)), int(a.get("sh_max", 0))], 9, CREAM, N, DEEP)
		var gb: Rect2 = sn(row.get("gold_btn", Rect2()))
		if gb.size.x > 0.0:
			pix_c(ci, COIN, gb, COIN_PAL, 2.0 if gb.size.y < 36.0 else P)
	var hb: Rect2 = gr("dmg_btn")
	if hb.size.x > 0.0:
		k_tc(ci, hb, "Hasar", 32)
	var bn: Rect2 = gr("banner")
	if bn.size.x > 0.0:
		var ic := Rect2(bn.position + Vector2(9, 9), Vector2(bn.size.y - 18.0, bn.size.y - 18.0))
		pix_c(ci, FLAG, ic, FLAG_PAL)
		var tx: float = ic.end.x + 12.0
		k_t(ci, Vector2(tx, bn.position.y + 9.0), str(d["mission"]["title"]), 32)
		var bw: float = bn.end.x - 12.0 - tx
		k_bar(ci, Rect2(tx, bn.end.y - 24.0, floorf(bw / P) * P, 15.0), float(d["mission"]["cur"]) / float(d["mission"]["max"]), XP_COLS, 0)
	## tuş kapakları (Q E R F, sağ alt köşe - bugünkü yer)
	var letters: Dictionary = {"q": "Q", "e": "E", "r": "R", "f": "F"}
	for key in letters:
		var r: Rect2 = gr(key)
		if r.size.x > 0.0:
			k_key(ci, Rect2(r.end.x - 21.0, r.end.y - 24.0, 24.0, 27.0), letters[key])
	## seviye rozeti (yuvarlak, bugünkü yerinde)
	var bd: Rect2 = gr("badge")
	if bd.size.x > 0.0:
		var c: Vector2 = bd.get_center().snapped(Vector2(P, P))
		var rad: float = floorf(bd.size.x * 0.5 / P) * P
		k_disc(ci, c, rad)
		var box := Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
		match skin:
			"A": txt_c(ci, box, str(d.get("level", 1)), 18, CREAM, N, A_OUT)
			"B": txt_c(ci, box, str(d.get("level", 1)), 18, B_TEXT, N, DEEP)
			"C": txt_c(ci, box, str(d.get("level", 1)), 18, C_INK, N)
			"D": txt_c(ci, box, str(d.get("level", 1)), 18, D_INK, N)
	## stat düğmesi: ok + dört sütun
	var tg: Rect2 = gr("toggle")
	if tg.size.x > 0.0:
		var ax: float = tg.position.x + 9.0
		var ay: float = tg.position.y + floorf((tg.size.y - 15.0) * 0.5 / P) * P
		pix(ci, ["..o", ".oo", "ooo", ".oo", "..o"], Vector2(ax, ay), {"o": Color("#f6d27e")})
		var bars: Array = [2, 4, 3, 5]
		for i in 4:
			var h: float = float(bars[i]) * P
			ci.draw_rect(Rect2(ax + 18.0 + i * 6.0, ay + 15.0 - h, P, h), Color("#f0d49a"))
	## kalpler + sayaç
	var hr: Rect2 = gr("hearts")
	if hr.size.x > 0.0:
		var full: int = int(d.get("hearts", 3))
		var hx: float = hr.end.x - 3.0 * 30.0 + 3.0
		for i in 3:
			pix(ci, HEART, Vector2(hx + i * 30.0, hr.position.y), HEART_PAL if i < full else HEART_EMPTY_PAL)
		var tc: Color = CREAM
		match skin:
			"A": tc = A_WELL
			"C": tc = Color("#efd9ad")
			"D": tc = D_END
		txt_c(ci, Rect2(hr.position.x, hr.end.y - 30.0, hr.size.x, 30.0), str(d.get("heart_timer", "-:--")), 32, tc)
	## can / kalkan: simge solda, çubuk, sayı sağda (bugünkü düzen)
	for key in ["hp", "sh"]:
		var r: Rect2 = gr(key)
		if r.size.x <= 0.0:
			continue
		var is_hp: bool = key == "hp"
		var icon_rows: Array = HEART if is_hp else SHIELD
		var ip := Vector2(r.position.x, r.position.y + floorf((r.size.y - pix_size(icon_rows).y) * 0.5 / P) * P)
		pix(ci, icon_rows, ip, HEART_PAL if is_hp else SHIELD_PAL)
		var br := Rect2(r.position.x + 36.0, r.position.y, r.size.x - 36.0, r.size.y)
		var ratio: float = float(d["hp"]) / float(d["hp_max"]) if is_hp else float(d["sh"]) / float(d["sh_max"])
		k_bar(ci, br, ratio, HP_COLS if is_hp else SH_COLS, 1)
		var val: String = ("%d/%d" % [int(d["hp"]), int(d["hp_max"])]) if is_hp else ("%d/%d" % [int(d["sh"]), int(d["sh_max"])])
		txt_r(ci, Vector2(br.end.x - 9.0, br.position.y + floorf((br.size.y - 14.0) * 0.5)), val, 18, CREAM, N, DEEP)
	## efsanevi boş yuva işareti
	var cells: Array = geo.get("legend_cells", [])
	var licons: Array = geo.get("legend_icons", [])
	for i in cells.size():
		if i >= licons.size() or licons[i] == null:
			var c2: Rect2 = sn(cells[i])
			var mk: Color = A_WELL_SH
			match skin:
				"B": mk = Color(B_RIM, 0.45)
				"C": mk = C_WELL_SH
				"D": mk = D_BARK_HI
			rr(ci, Rect2(c2.get_center().snapped(Vector2(P, P)) - Vector2(6, 6), Vector2(12, 12)), mk, 1)
