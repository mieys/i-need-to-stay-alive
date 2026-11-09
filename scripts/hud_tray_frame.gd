extends RefCounted

## Oyuncu paneli YUVA ÇERÇEVESİ "C Gömme Tepsi" dilinde (madde 459, 2026-11-08; kullanıcı: "demin yaptığın çerçeve değişikliğini skill
## butonları pasifler v.s diğer tüm skill barındaki çerçeveler için de yap" + "kenarlıkları hafif oval değil, portrede ve dış pencerede olduğu
## gibi onların da öyle görünmesi gerekiyor").
## Kenar ve DÖRT KÖŞE, ana tepsinin küçük kutusundan (assets/ui/kit/hud_dock_tray_side.png, 1 sanat px = 3 doku px) sanat pikseli sanat pikseli
## okunmuş kalıptır -> portre kutusu / dış pencereyle birebir: köşede 2 sanat px'lik basamaklı yuvarlama, üst/sol kenar dış hat-açık kenar-ahşap-
## koyu çizgi, alt/sağ kenar dış hat-ahşap-koyu ahşap-koyu çizgi, köşelerde kabartmanın dönüşü. İç gölge pikselleri (ikonun üstüne düşer) çizilmez.
## Dock 0,92 (ve SkillBar ayrıca) ölçekli olduğu için doku yerine EKRAN PİKSELİNDE çizilir: global dönüşüm geri alınır, dikdörtgen tam piksele ve
## sanat pikseli katına yuvarlanır -> her sanat pikseli tam layer_px (büyük yuva 2, küçük 1) ekran pikseli. Toplam kenar = 4 * layer_px.
## Kullanım: const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd"); HudTrayFrame.draw(self, Rect2(...), 2.0)
## (class_name YOK, hud_theme.gd ile aynı sebep). Kendi _draw'ının SONUNDA çağrılmalı (ikonun üstünde kalır).

const HudTheme := preload("res://scripts/hud_theme.gd")

## Köşe kalıpları (6x6 sanat pikseli; "." çizilmez). o dış hat / iç koyu çizgi, H açık kenar, R ahşap, L koyu ahşap, A = orta halka (accent)
## Orta halka (R) accent verilince o renge döner; dış/iç çizgi ve kabartma hep ahşap.
const TL: Array[String] = ["..oooo", ".oHHHH", "oHAAAA", "oHAooo", "oHAo..", "oHAo.."]
const TR: Array[String] = ["oooo..", "HHHHo.", "AAAAHo", "oooLAo", "..oLAo", "..oLAo"]
const BL: Array[String] = ["oHAo..", "oHAo..", "oHAooo", "oALLLL", ".oAAAA", "..oooo"]
const BR: Array[String] = ["..oLAo", "..oLAo", "oooLAo", "LLLLAo", "AAAAo.", "oooo.."]
## Düz kenarlar (dıştan içe): üst/sol o H A o, alt/sağ o A L o
const EDGE_TL := "oHAo"
const EDGE_BR := "oALo"


static func _col(ch: String, accent: Color) -> Color:
	match ch:
		"o": return HudTheme.OUTLINE
		"H": return HudTheme.RIM_HI
		"L": return HudTheme.RIM_LO
		"A": return accent if accent.a > 0.0 else HudTheme.RIM
	return Color(0, 0, 0, 0)


static func draw(ci: CanvasItem, r: Rect2, layer_px: float, accent: Color = Color(0, 0, 0, 0)) -> void:
	var xf: Transform2D = ci.get_global_transform()
	var a: Vector2 = (xf * r.position).round()
	var b: Vector2 = (xf * r.end).round()
	var t: float = maxf(1.0, layer_px)
	var aw: int = int(floorf((b.x - a.x) / t))
	var ah: int = int(floorf((b.y - a.y) / t))
	if aw < 12 or ah < 12:
		return
	## Sanat pikseli katına yuvarlanırken artan 1 px iki yana bölünmez: dikdörtgen ortalanır.
	var o := Vector2(a.x + floorf(((b.x - a.x) - aw * t) * 0.5), a.y + floorf(((b.y - a.y) - ah * t) * 0.5))
	ci.draw_set_transform_matrix(xf.affine_inverse())
	_draw_px(ci, o, aw, ah, t, accent)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Aynı çerçeve YEREL koordinatta (dönüşüm geri alınmaz): ölçeklenen / kayan / animasyonlu düğmelerin içinde (seçim ekranı portre kartları,
## madde 535) - draw() çizim anındaki global dönüşümü komutlara gömdüğü için düğme sonradan kayınca/büyüyünce çerçeve yerinde kalırdı.
## r.size, t'nin katı verilmeli (değilse artan kısım ortalanır).
static func draw_local(ci: CanvasItem, r: Rect2, t: float, accent: Color = Color(0, 0, 0, 0)) -> void:
	t = maxf(1.0, t)
	var aw: int = int(floorf(r.size.x / t))
	var ah: int = int(floorf(r.size.y / t))
	if aw < 12 or ah < 12:
		return
	var o := r.position + ((r.size - Vector2(aw, ah) * t) * 0.5).floor()
	_draw_px(ci, o, aw, ah, t, accent)


static func _draw_px(ci: CanvasItem, o: Vector2, aw: int, ah: int, t: float, accent: Color) -> void:
	## Köşeler (piksel piksel)
	_tile(ci, TL, o, t, accent)
	_tile(ci, TR, o + Vector2((aw - 6) * t, 0.0), t, accent)
	_tile(ci, BL, o + Vector2(0.0, (ah - 6) * t), t, accent)
	_tile(ci, BR, o + Vector2((aw - 6) * t, (ah - 6) * t), t, accent)
	## Düz kenarlar (köşeler arası tek parça)
	var run_w: float = (aw - 12) * t
	var run_h: float = (ah - 12) * t
	for k in 4:
		var c_tl: Color = _col(EDGE_TL[k], accent)
		var c_br: Color = _col(EDGE_BR[k], accent)
		if run_w > 0.0:
			ci.draw_rect(Rect2(o.x + 6.0 * t, o.y + k * t, run_w, t), c_tl) ## üst
			ci.draw_rect(Rect2(o.x + 6.0 * t, o.y + (ah - 1 - k) * t, run_w, t), c_br) ## alt
		if run_h > 0.0:
			ci.draw_rect(Rect2(o.x + k * t, o.y + 6.0 * t, t, run_h), c_tl) ## sol
			ci.draw_rect(Rect2(o.x + (aw - 1 - k) * t, o.y + 6.0 * t, t, run_h), c_br) ## sağ


static func _tile(ci: CanvasItem, rows: Array[String], p: Vector2, t: float, accent: Color) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if ch == ".":
				continue
			ci.draw_rect(Rect2(p.x + x * t, p.y + y * t, t, t), _col(ch, accent))
