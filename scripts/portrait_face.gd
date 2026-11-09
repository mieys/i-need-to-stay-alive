extends RefCounted

## PORTRE: YÜZ KIRPIMI + KARAKTERE ÖZEL ARKA PLAN (madde 464, 2026-11-08). Tek kaynak: masaüstü oyuncu paneli portresi (hud.gd) ve grup paneli
## avatarı (party_panel.gd). Kullanıcı: yüzler yakın ve "büyücü kızın şu hali gibi" çerçevelensin + karakter temalı arka plan, "sadece blurlu".
## - Yüz: LobbyUI.face_texture'ın 24x24 baş kırpımının içinden kare (panel 18, grup 16 sanat pikseli), ekranda 3x. Kırpımın üst satırı karakter
##   başına FACE_OY (gözler panelde ~%56, grupta %50 = Büyücü Kız'ın çerçevesi); tablo tools/gen_portrait_bg.py çıktısı - onaylanan önizlemeyle
##   (tools/proto_20261108/portre_tema/) birebir, GDScript round() 0,5'te farklı yuvarladığı için hesaplanmaz.
## - Arka plan: assets/ui/portrait_bg/<id>.png (28x28, bulanıklık dokuda hazır; çalışma anında shader yok), yüzle aynı katla çizilen orta kare.
## Tabloda olmayan (yeni) karakter: göz satırı 12 varsayılır, arka plan yok (çağıran eski zemine düşer).
## Kullanım: const PortraitFace := preload("res://scripts/portrait_face.gd") (class_name YOK, hud_theme.gd ile aynı sebep).

const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const BG_DIR := "res://assets/ui/portrait_bg/"
const PANEL_N := 18 ## panel portresi: 18x18 sanat pikseli (ekranda 3x = 54 px)
const PARTY_N := 16 ## grup paneli avatarı: 16x16 (3x = 48 px = AVATAR_SIZE)
const BG_SIZE := 28
## karakter id -> [panel kırpım üst satırı, grup kırpım üst satırı] (24'lük yüz kırpımı içinde)
const FACE_OY := {1: [0, 2], 2: [4, 6], 3: [2, 4], 4: [6, 8], 5: [5, 7], 7: [2, 4], 8: [2, 4], 9: [2, 4], 10: [4, 6], 11: [3, 5], 12: [4, 6],
	13: [2, 4], 14: [2, 4], 15: [4, 6]}
const DEFAULT_OY := [2, 4]

static var _cache: Dictionary = {}


## n = PANEL_N ya da PARTY_N. Kırpılamayan (atlas olmayan) portre olduğu gibi döner.
static func face(char_id: int, n: int) -> Texture2D:
	var key: String = "f%d_%d" % [char_id, n]
	if _cache.has(key):
		return _cache[key]
	var path: String = str(Characters.get_def(char_id).get("portrait", ""))
	var base: Texture2D = LobbyUI.face_texture(path)
	var out: Texture2D = base
	if base is AtlasTexture:
		var r: Rect2 = (base as AtlasTexture).region
		var oys: Array = FACE_OY.get(char_id, DEFAULT_OY)
		var oy: int = int(oys[0] if n == PANEL_N else oys[1])
		oy = clampi(oy, 0, int(r.size.y) - n)
		var ox: int = int((r.size.x - n) / 2)
		var at := AtlasTexture.new()
		at.atlas = (base as AtlasTexture).atlas
		at.region = Rect2(r.position + Vector2(ox, oy), Vector2(n, n))
		out = at
	_cache[key] = out
	return out


## Yüzle aynı katla çizilecek n x n arka plan (28'lik dokunun ortası, bir satır yukarı: motifler üst yarıda). Yoksa null.
static func background(char_id: int, n: int) -> Texture2D:
	var key: String = "b%d_%d" % [char_id, n]
	if _cache.has(key):
		return _cache[key]
	var path: String = BG_DIR + "%d.png" % char_id
	var out: Texture2D = null
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			var ox: int = (BG_SIZE - n) / 2
			var oy: int = maxi(0, (BG_SIZE - n) / 2 - 1)
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(ox, oy, n, n)
			out = at
	_cache[key] = out
	return out


## Seçim ekranı / oyuncu kartı için: 24x24 TAM yüz kırpımı (LobbyUI.face_texture, kırpım değişmez) + arkasında aynı katla karakterin bulanık
## arka planı (28'liğin ortası, 24x24). DK.icon gibi bw kutusunda tam katla ortalanır; dim = kilitli kart. Arka planı yoksa sadece yüz.
static func face_icon(char_id: int, bw: float, dim: bool = false) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(bw, bw)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ftex: Texture2D = LobbyUI.face_texture(str(Characters.get_def(char_id).get("portrait", "")))
	if ftex == null:
		return cc
	var ts: Vector2 = ftex.get_size()
	var k: float = floorf(bw / maxf(ts.x, ts.y))
	if k < 1.0:
		k = bw / maxf(ts.x, ts.y)
	var box := Control.new()
	box.custom_minimum_size = (ts * k).floor()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	var bg: Texture2D = background(char_id, int(ts.x))
	for tex: Texture2D in ([bg, ftex] if bg else [ftex]):
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(tr)
	if dim:
		box.modulate = Color(0.45, 0.45, 0.5, 1.0)
	cc.add_child(box)
	return cc


## ÇERÇEVELİ portre (madde 535, 2026-11-09; kullanıcı: seçim ekranında "portrelerin kenarları anında kesiliyor ... çerçeveleri v.s yok tuhaf
## duruyor kartların içinde"): face_icon'un yüz + arka plan kutusu, oyuncu panelinin portresiyle aynı "Gömme Tepsi" çerçevesinin
## (HudTrayFrame kalıbı: basamaklı köşe, dış hat - açık kenar - ahşap - iç koyu çizgi) içinde. Çerçeve 4 * frame_px kalınlığında, yüzün
## DIŞINDA (yüzden piksel yemez); YEREL koordinatta çizilir (`draw_local`) -> düğme nefesi / basma yaylanması / kaydırma ile birlikte hareket eder.
## Çerçeve katmanı yüzün ÜSTÜNDE: yarım piksele düşen konumda bile kenarda boşluk / taşma görünmez. accent = orta halka rengi (seçili kart).
static func framed_icon(char_id: int, face_bw: float, frame_px: float = 2.0, dim: bool = false) -> CenterContainer:
	var t: float = maxf(1.0, roundf(frame_px))
	var border: float = 4.0 * t
	var inner: CenterContainer = face_icon(char_id, face_bw)
	var face_size := Vector2(face_bw, face_bw).floor()
	var box: Control = null
	if inner.get_child_count() > 0:
		box = inner.get_child(0) as Control
		face_size = box.custom_minimum_size
		inner.remove_child(box)
	inner.free()
	var holder := FramedPortrait.new()
	holder.custom_minimum_size = face_size + Vector2(border, border) * 2.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if box:
		box.position = Vector2(border, border)
		box.size = face_size
		holder.add_child(box)
	holder.frame = FrameLayer.new()
	holder.frame.t = t
	holder.frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(holder.frame)
	if dim:
		holder.modulate = Color(0.45, 0.45, 0.5, 1.0)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = holder.custom_minimum_size
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(holder)
	return cc


## framed_icon'un kutusu: yüzün arkasında iç koyu çizgi renginde zemin (yüz yarım piksel kayarsa açık çizgi kalmasın) + çerçeve katmanı.
class FramedPortrait extends Control:
	const HudTheme := preload("res://scripts/hud_theme.gd")
	var frame: FrameLayer = null

	func set_accent(c: Color) -> void:
		if frame and frame.accent != c:
			frame.accent = c
			frame.queue_redraw()

	func _draw() -> void:
		var b: float = 3.0 * (frame.t if frame else 2.0)
		draw_rect(Rect2(Vector2(b, b), size - Vector2(b, b) * 2.0), HudTheme.OUTLINE)


class FrameLayer extends Control:
	const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd")
	var t: float = 2.0
	var accent: Color = Color(0, 0, 0, 0)

	func _ready() -> void:
		resized.connect(queue_redraw)

	func _draw() -> void:
		HudTrayFrame.draw_local(self, Rect2(Vector2.ZERO, size), t, accent)
