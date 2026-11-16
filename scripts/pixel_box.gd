extends StyleBox
## PİKSEL KUTU (madde 417, 2026-11-06; kullanıcı seçimi "B - Kabartma", prototip madde 414). Pencere/kart kutularının StyleBoxFlat yerine
## geçen sürümü: renkler AYNI (Kısık Ahşap, hud_theme.gd), ama kenar + köşe karakterlerle aynı piksel ızgarasında (1 sanat px = 3 ekran px):
##   - köşe = yarıçap/3 sanat pikselinde piksel daire basamağı (ince 45° pah yerine),
##   - kenar = round(kalınlık/3) sanat pikseli,
##   - kabartma: kenarın hemen içinde 1 sanat px ışık (üst/sol, dolgu ile kenarın ortası) ve gölge (alt/sağ, dolgunun koyusu).
## StyleBoxFlat ile AYNI özellik adları (bg_color, border_color, border_width_*, corner_radius_*, expand_margin_*, draw_center, set_*_all...)
## -> kitlerin döndürdüğü kutuyu sonradan değiştiren kod aynen çalışır; değişince `changed` yayılır, kutu yeniden çizilir.
## Her yanın kenarı / her köşenin yarıçapı ayrı olabilir (altı açık sekme). Yumuşak gölge (shadow_size) eskisi gibi düz kutuyla arkada çizilir;
## 9 dilime sığmayan çok ince kutu eski düz kutuya düşer.
## İçerik payı StyleBoxFlat gibi: elle verilmemişse kenar kalınlığı (`_auto_cm`).
## Doku: sanat pikselinde boyanır, x3 en yakın komşu büyütülür, 9 dilim (köşe 1:1, kenar/orta düz renk esner); genel önbellek `_cache`.

const PX := 3 ## 1 sanat pikseli = 3 ekran px (stil rehberi)
const SMALL := 30.0 ## bundan küçük kutuda kabartma yok, köşe en çok 1 sanat px

## AHŞAP DAMAR DOKUSU (madde 662, kullanıcı seçimi E "Akan Damar", 2026-11-13; düz zemin "kusursuz ve ruhsuz" bulundu): pencere zemininde
## 9 dilimin ORTA bölgesine (kenar + kabartma + köşe basamağının içi) karo döşenir; renk, kenar, köşe, saydamlık AYNEN kalır.
## Yalnız pencere dolgusu (WIN_PANEL / WIN_PANEL2 / WIN_PANEL3) ve en kısa kenarı GRAIN_MIN ve üstü olan kutuda: düğme, kuyu (WIN_INSET),
## altın düğme, küçük kutu düz kalır. %88 pencere (menu_dark_kit C_PANEL) = onaylanan prototip; daha saydam dolguda doku orantılı söner.
## Kapatmak için kutuda `grain = false`. Karo 2026-11-16'dan beri R2 "Kabartma Damar" (madde 752, kullanıcı: "daha kaliteli ve okunurluğu
## daha iyi"): E'nin arıtılmışı - temiz 1 px merdiven, seyrek düzensiz aralık, kesik damar + altında 1 px oyma ışığı, düşük kontrast.
## Üretici `tools/proto_20261116/panel_doku3/gen_panel_doku3.py --oyun r2` (320x192 sanat px, x3 hazır, 1:1 döşenir; yalnız RIM_HI / DEEP
## alfa bantları, yeni renk yok; bant sayısı karo boyunca tam -> tekrar sınırında düz çizgi yok). Eski E: gen_panel_doku2.py --oyun.
const GRAIN_TEX: Texture2D = preload("res://assets/ui/panel_doku/ahsap_damar.png")
## Çizimde kullanılan karo (varsayılan GRAIN_TEX); prototip yakalamaları (tools/proto_20261116/panel_doku3) geçici olarak değiştirir.
static var grain_tex: Texture2D = GRAIN_TEX
const GRAIN_MIN := 90.0
const GRAIN_REF_ALPHA := 0.88
const HT := preload("res://scripts/hud_theme.gd")
const GRAIN_FILLS := [HT.WIN_PANEL, HT.WIN_PANEL2, HT.WIN_PANEL3]
## İç kart / seçim karosu dolgusu (WIN_PANEL2 / WIN_PANEL3: silah/evcil/karakter/harita kartları, düğme) doku gücü (madde 753, kullanıcı:
## "silahlar zor okunur hale geldi"): 1 = pencereyle aynı, 0 = düz. Kullanıcı seçimi B %35 (A düz / şimdi 1,0 da denendi): kart yine
## ahşap, ama damar ince silah çizgileriyle yarışmaz. Prototip yakalaması (tools/proto_20261116/panel_doku3 kart_capture.gd) değiştirir.
static var grain_card_alpha := 0.35
const GRAIN_CARD_FILLS := [HT.WIN_PANEL2, HT.WIN_PANEL3]

static var _cache: Dictionary = {}

@export_storage var bg_color := Color(0.6, 0.6, 0.6):
	set(v):
		bg_color = v
		_dirty()
@export_storage var border_color := Color(0.8, 0.8, 0.8):
	set(v):
		border_color = v
		_dirty()
@export_storage var draw_center := true:
	set(v):
		draw_center = v
		_dirty()
@export_storage var border_width_left := 0:
	set(v):
		border_width_left = v
		_auto_margin(SIDE_LEFT, v)
		_dirty()
@export_storage var border_width_top := 0:
	set(v):
		border_width_top = v
		_auto_margin(SIDE_TOP, v)
		_dirty()
@export_storage var border_width_right := 0:
	set(v):
		border_width_right = v
		_auto_margin(SIDE_RIGHT, v)
		_dirty()
@export_storage var border_width_bottom := 0:
	set(v):
		border_width_bottom = v
		_auto_margin(SIDE_BOTTOM, v)
		_dirty()
@export_storage var corner_radius_top_left := 0:
	set(v):
		corner_radius_top_left = v
		_dirty()
@export_storage var corner_radius_top_right := 0:
	set(v):
		corner_radius_top_right = v
		_dirty()
@export_storage var corner_radius_bottom_right := 0:
	set(v):
		corner_radius_bottom_right = v
		_dirty()
@export_storage var corner_radius_bottom_left := 0:
	set(v):
		corner_radius_bottom_left = v
		_dirty()
@export_storage var expand_margin_left := 0.0:
	set(v):
		expand_margin_left = v
		_dirty()
@export_storage var expand_margin_top := 0.0:
	set(v):
		expand_margin_top = v
		_dirty()
@export_storage var expand_margin_right := 0.0:
	set(v):
		expand_margin_right = v
		_dirty()
@export_storage var expand_margin_bottom := 0.0:
	set(v):
		expand_margin_bottom = v
		_dirty()
@export_storage var shadow_color := Color(0, 0, 0, 0.6):
	set(v):
		shadow_color = v
		_dirty()
@export_storage var shadow_size := 0:
	set(v):
		shadow_size = v
		_dirty()
@export_storage var shadow_offset := Vector2.ZERO:
	set(v):
		shadow_offset = v
		_dirty()
## Kabartmanın üst/sol ışık bandı (madde 428). Saydam = otomatik: dolgu ile kenarın ortası (ahşap kenarda doğal ışık). Renkli kenarda
## (evrim kartı mor/kırmızı) bu karışım iki paletin arasında çamurlu bir ton verir -> çağıran kenar renginin kendi koyusunu verir.
@export_storage var bevel_hi := Color(0, 0, 0, 0):
	set(v):
		bevel_hi = v
		_dirty()
## StyleBoxFlat uyumu için (piksel kutuda anlamı yok)
@export_storage var anti_aliasing := false
@export_storage var corner_detail := 1
## ahşap damar dokusu izni (koşullar: grain_applies). false = bu kutu hep düz.
@export_storage var grain := true:
	set(v):
		grain = v
		_dirty()

## kenar kalınlığından otomatik verilen içerik payı (elle verilen pay ezilmez)
var _auto_cm: Array = [-1.0, -1.0, -1.0, -1.0]
var _flat: StyleBoxFlat = null
var _shadow: StyleBoxFlat = null


func _auto_margin(side: int, bw: int) -> void:
	var cur: float = get_content_margin(side)
	if cur < 0.0 or is_equal_approx(cur, float(_auto_cm[side])):
		set_content_margin(side, float(bw))
		_auto_cm[side] = float(bw)


func _dirty() -> void:
	_flat = null
	_shadow = null
	emit_changed()


## ---------------------------------------------------------------- StyleBoxFlat API'si
func set_border_width_all(w: int) -> void:
	border_width_left = w
	border_width_top = w
	border_width_right = w
	border_width_bottom = w


func get_border_width_min() -> int:
	return mini(mini(border_width_left, border_width_right), mini(border_width_top, border_width_bottom))


func set_border_width(side: int, w: int) -> void:
	match side:
		SIDE_LEFT: border_width_left = w
		SIDE_TOP: border_width_top = w
		SIDE_RIGHT: border_width_right = w
		_: border_width_bottom = w


func get_border_width(side: int) -> int:
	match side:
		SIDE_LEFT: return border_width_left
		SIDE_TOP: return border_width_top
		SIDE_RIGHT: return border_width_right
	return border_width_bottom


func set_corner_radius_all(r: int) -> void:
	corner_radius_top_left = r
	corner_radius_top_right = r
	corner_radius_bottom_right = r
	corner_radius_bottom_left = r


func set_expand_margin_all(m: float) -> void:
	expand_margin_left = m
	expand_margin_top = m
	expand_margin_right = m
	expand_margin_bottom = m


func set_expand_margin(side: int, m: float) -> void:
	match side:
		SIDE_LEFT: expand_margin_left = m
		SIDE_TOP: expand_margin_top = m
		SIDE_RIGHT: expand_margin_right = m
		_: expand_margin_bottom = m


## ---------------------------------------------------------------- çizim
func _get_draw_rect(rect: Rect2) -> Rect2:
	return rect.grow_individual(expand_margin_left, expand_margin_top, expand_margin_right, expand_margin_bottom)


func _draw(ci: RID, rect: Rect2) -> void:
	var r: Rect2 = _get_draw_rect(rect)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	if shadow_size > 0 and shadow_color.a > 0.0:
		_shadow_box().draw(ci, rect) ## yumuşak pencere gölgesi eskisi gibi (kutunun arkasında)
	var small: bool = minf(r.size.x, r.size.y) < SMALL
	var info: Array = texture_for(bg_color if draw_center else Color(0, 0, 0, 0), border_color,
		[border_width_left, border_width_top, border_width_right, border_width_bottom],
		[corner_radius_top_left, corner_radius_top_right, corner_radius_bottom_right, corner_radius_bottom_left], small, bevel_hi)
	var tex: Texture2D = info[0]
	var m: Array = info[1] ## sol, üst, sağ, alt (ekran px)
	if r.size.x < float(m[0] + m[2]) or r.size.y < float(m[1] + m[3]):
		_flat_box().draw(ci, rect) ## 9 dilime sığmayan ince şerit: eski düz kutu
		return
	RenderingServer.canvas_item_add_nine_patch(ci, r, Rect2(Vector2.ZERO, tex.get_size()), tex.get_rid(),
		Vector2(m[0], m[1]), Vector2(m[2], m[3]), RenderingServer.NINE_PATCH_STRETCH, RenderingServer.NINE_PATCH_STRETCH, true)
	if grain and draw_center and grain_applies(bg_color, r.size):
		_draw_grain(ci, Rect2(r.position + Vector2(m[0], m[1]), r.size - Vector2(m[0] + m[2], m[1] + m[3])), r.size)


## Doku bu kutuya düşer mi: pencere dolgusu + yeterince büyük (madde 662).
static func grain_applies(fill: Color, size: Vector2) -> bool:
	if fill.a <= 0.0 or minf(size.x, size.y) < GRAIN_MIN:
		return false
	if grain_card_alpha <= 0.0 and _is_card_fill(fill):
		return false
	for c: Color in GRAIN_FILLS:
		if absf(fill.r - c.r) + absf(fill.g - c.g) + absf(fill.b - c.b) < 0.02:
			return true
	return false


static func _is_card_fill(fill: Color) -> bool:
	for c: Color in GRAIN_CARD_FILLS:
		if absf(fill.r - c.r) + absf(fill.g - c.g) + absf(fill.b - c.b) < 0.02:
			return true
	return false


## Karonun kutudaki başlangıç kayması (ekran px, sanat pikseline oturur): kutudan kutuya farklı olsun diye BOYUTA bağlı -> üstüne gelince /
## basınca (aynı boy, başka kutu örneği) doku kaymaz.
static func grain_offset(box_size: Vector2) -> Vector2:
	var ts: Vector2 = grain_tex.get_size()
	var h: int = absi(hash(Vector2i(int(box_size.x), int(box_size.y))))
	return Vector2(float((h % int(ts.x / PX)) * PX), float(((h / 7) % int(ts.y / PX)) * PX))


func _draw_grain(ci: RID, inner: Rect2, box_size: Vector2) -> void:
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return
	var ts: Vector2 = grain_tex.get_size()
	var mod := Color(1, 1, 1, clampf(bg_color.a / GRAIN_REF_ALPHA, 0.0, 1.0))
	if _is_card_fill(bg_color):
		mod.a *= clampf(grain_card_alpha, 0.0, 1.0)
	var off: Vector2 = grain_offset(box_size)
	var rid: RID = grain_tex.get_rid()
	var y: float = -off.y
	while y < inner.size.y:
		var x: float = -off.x
		while x < inner.size.x:
			var tr := Rect2(inner.position + Vector2(x, y), ts)
			var cl: Rect2 = tr.intersection(inner)
			if cl.size.x > 0.0 and cl.size.y > 0.0:
				RenderingServer.canvas_item_add_texture_rect_region(ci, cl, rid, Rect2(cl.position - tr.position, cl.size), mod)
			x += ts.x
		y += ts.y


func _shadow_box() -> StyleBoxFlat:
	if _shadow == null:
		_shadow = _flat_box().duplicate()
		_shadow.bg_color = Color(0, 0, 0, 0)
		_shadow.border_color = Color(0, 0, 0, 0)
	return _shadow


func _flat_box() -> StyleBoxFlat:
	if _flat == null:
		var f := StyleBoxFlat.new()
		f.bg_color = bg_color
		f.border_color = border_color
		f.draw_center = draw_center
		f.border_width_left = border_width_left
		f.border_width_top = border_width_top
		f.border_width_right = border_width_right
		f.border_width_bottom = border_width_bottom
		f.corner_radius_top_left = corner_radius_top_left
		f.corner_radius_top_right = corner_radius_top_right
		f.corner_radius_bottom_right = corner_radius_bottom_right
		f.corner_radius_bottom_left = corner_radius_bottom_left
		f.expand_margin_left = expand_margin_left
		f.expand_margin_top = expand_margin_top
		f.expand_margin_right = expand_margin_right
		f.expand_margin_bottom = expand_margin_bottom
		f.shadow_color = shadow_color
		f.shadow_size = shadow_size
		f.shadow_offset = shadow_offset
		f.corner_detail = 1
		f.anti_aliasing = false
		_flat = f
	return _flat


## ---------------------------------------------------------------- doku (sanat pikseli -> x3)
static func profile(n: int) -> Array:
	## Köşe basamağı: satır i'de köşeden kaç sanat pikseli kesilir (simetrik piksel daire). 1 -> [1], 2 -> [2,1], 3 -> [3,1,1], 6 -> [6,3,2,1,1,1].
	if n <= 0:
		return []
	if n == 1:
		return [1]
	var out: Array = []
	for i in n:
		var d: int = n - i
		out.append(n - int(floor(sqrt(float(n * n - d * d)))))
	return out


## [doku, [sol, üst, sağ, alt] kenar payı (ekran px), Image]. bws = [sol, üst, sağ, alt], radii = [sol üst, sağ üst, sağ alt, sol alt] (ekran px).
static func texture_for(fill: Color, border: Color, bws: Array, radii: Array, small: bool, hi_col: Color = Color(0, 0, 0, 0)) -> Array:
	var b: Array = [0, 0, 0, 0]
	if border.a > 0.0:
		for i in 4:
			if int(bws[i]) > 0:
				b[i] = maxi(1, int(round(int(bws[i]) / 3.0)))
	var n: Array = []
	for i in 4:
		var ni: int = int(round(int(radii[i]) / 3.0))
		n.append(mini(ni, 1) if small else ni)
	var bevel: bool = not small and fill.a > 0.0 and (b[0] + b[1] + b[2] + b[3]) > 0
	var key := "%s|%s|%s|%s|%s" % [fill.to_html(), border.to_html() if bevel or b != [0, 0, 0, 0] else "-", str(b), str(n), "b" if bevel else "-"]
	if bevel and hi_col.a > 0.0:
		key += "|" + hi_col.to_html()
	var hit: Array = _cache.get(key, [])
	if hit.is_empty():
		hit = _paint(fill, border, b, n, bevel, hi_col)
		_cache[key] = hit
	return hit


## Sanat pikseli koordinatında: köşe kesiği mi? (x, y) görüntü içinde; c = merkez piksel.
static func _inside(x: int, y: int, W: int, H: int, c: Vector2i, profs: Array) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return false
	var left: bool = x <= c.x
	var top: bool = y <= c.y
	var dx: int = x if left else W - 1 - x
	var dy: int = y if top else H - 1 - y
	var prof: Array = profs[(0 if left else 1) if top else (3 if left else 2)]
	if dy < prof.size() and dx < int(prof[dy]):
		return false
	if dx < prof.size() and dy < int(prof[dx]):
		return false
	return true


static func _paint(fill: Color, border: Color, b: Array, n: Array, bevel: bool, hi_col: Color = Color(0, 0, 0, 0)) -> Array:
	var profs: Array = []
	for i in 4:
		profs.append(profile(int(n[i])))
	var ev: int = 1 if bevel else 0
	## kenar payları (sanat px): köşe basamağı + kenar + kabartma sığsın
	var ml: int = maxi(maxi(int(n[0]), int(n[3])), int(b[0]) + (ev if b[0] > 0 else 0))
	var mt: int = maxi(maxi(int(n[0]), int(n[1])), int(b[1]) + (ev if b[1] > 0 else 0))
	var mr: int = maxi(maxi(int(n[1]), int(n[2])), int(b[2]) + (ev if b[2] > 0 else 0))
	var mb: int = maxi(maxi(int(n[3]), int(n[2])), int(b[3]) + (ev if b[3] > 0 else 0))
	ml = maxi(ml, 1)
	mt = maxi(mt, 1)
	mr = maxi(mr, 1)
	mb = maxi(mb, 1)
	var W: int = ml + 1 + mr
	var H: int = mt + 1 + mb
	var c := Vector2i(ml, mt)
	var hi := Color(hi_col, fill.a) if hi_col.a > 0.0 else Color(fill.lerp(border, 0.5), fill.a)
	var lo := Color(fill.darkened(0.45), fill.a)
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	## yön başına: (adım, kenar kalınlığı, ışık mı)
	var dirs: Array = [[Vector2i(-1, 0), int(b[0]), true], [Vector2i(0, -1), int(b[1]), true],
		[Vector2i(1, 0), int(b[2]), false], [Vector2i(0, 1), int(b[3]), false]]
	for y in H:
		for x in W:
			if not _inside(x, y, W, H, c, profs):
				continue
			var col: Color = fill
			var is_border := false
			var bev_hi := false
			var bev_lo := false
			for dd: Array in dirs:
				var st: Vector2i = dd[0]
				var bw: int = dd[1]
				if bw <= 0:
					continue
				## bu yönde bw adım içinde dışarısı var mı -> kenar; bw+1'de -> kabartma halkası
				for k in range(1, bw + ev + 1):
					if not _inside(x + st.x * k, y + st.y * k, W, H, c, profs):
						if k <= bw:
							is_border = true
						elif dd[2]:
							bev_hi = true
						else:
							bev_lo = true
						break
			if is_border:
				col = border
			elif bevel and (bev_hi or bev_lo):
				if bev_hi and bev_lo:
					col = hi if mini(y, x) <= mini(H - 1 - y, W - 1 - x) else lo
				else:
					col = hi if bev_hi else lo
			img.set_pixel(x, y, col)
	img.resize(W * PX, H * PX, Image.INTERPOLATE_NEAREST)
	return [ImageTexture.create_from_image(img), [ml * PX, mt * PX, mr * PX, mb * PX], img] ## görüntü: testler (headless doku okunmaz)
