extends RefCounted

## EVCİLE ÖZEL ARKA PLAN (madde 585, 2026-11-11). Kullanıcı: "petlerin bu ikonlardaki ve seçim ekranındaki görünüşleri için arkaplanlarına
## kendilerine özgü bir arkaplan tasarlar mısın". Karakter portresi arka planıyla (portrait_face.gd, madde 464) AYNI dil: 28x28 bulanık doku
## (tools/gen_pet_bg.py -> assets/ui/pet_bg/<anahtar>.png; bulanıklık dokuda hazır, çalışma anında shader YOK).
## - Kutu: arka plan kutuyu dolduran en küçük TAM katla (k = ceil(bw / 28)), kırpım n = floor(bw / k) -> kutu n * k (piksel bölünmez).
## - Evcil (PetCatalog.icon) kutuya sığan kendi tam katıyla ortada (en az 1x; DK.icon ile aynı boy kuralı).
## Kullananlar: HUD evcil yuvası + ipucu (hud_pet_slot.gd), seçim ekranı karosu / yükleme satırı / oyuncu kartı (lobby_select_desktop.gd),
## eski evcil seçici (menu_pet_picker.gd). Arka planı olmayan (yeni) evcil: kutu yalnız evcil (çağıran eski zemine düşer).
## Kullanım: const PetBadge := preload("res://scripts/pet_badge.gd") (class_name YOK, portrait_face.gd ile aynı sebep).

const PetCatalog := preload("res://scripts/pet_catalog.gd")
const PortraitFace := preload("res://scripts/portrait_face.gd")
const BG_DIR := "res://assets/ui/pet_bg/"
const BG_SIZE := 28

static var _cache: Dictionary = {}


## Ortadan n x n kırpım (n = 28: dokunun kendisi). Yoksa null.
static func background(key: String, n: int = BG_SIZE) -> Texture2D:
	n = clampi(n, 1, BG_SIZE)
	var ck: String = "%s_%d" % [key, n]
	if _cache.has(ck):
		return _cache[ck]
	var path: String = BG_DIR + key + ".png"
	var out: Texture2D = null
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex and n == BG_SIZE:
			out = tex
		elif tex:
			var at := AtlasTexture.new()
			at.atlas = tex
			var o: int = (BG_SIZE - n) / 2
			at.region = Rect2(o, o, n, n)
			out = at
	_cache[ck] = out
	return out


static func has_background(key: String) -> bool:
	return background(key) != null


## bw kutusu için [arka plan katı, kırpım]: kutu = kırpım * kat (<= bw, tam piksel).
static func fit(bw: float) -> Vector2i:
	var k: int = maxi(1, ceili(bw / float(BG_SIZE)))
	return Vector2i(k, mini(BG_SIZE, int(floorf(bw / float(k)))))


## Evcilin side kutusuna sığan tam katı (en az 1).
static func pet_scale(tex: Texture2D, side: float) -> float:
	var ts: Vector2 = tex.get_size()
	return maxf(1.0, floorf(side / maxf(ts.x, ts.y)))


## Arka plan + evcil kare kutusu (Control, clip_contents). dim = kilitli.
static func box(key: String, bw: float, dim: bool = false) -> Control:
	var f: Vector2i = fit(bw)
	var side: float = float(f.x * f.y)
	var b := Control.new()
	b.custom_minimum_size = Vector2(side, side)
	b.clip_contents = true
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: Texture2D = background(key, f.y)
	if bg:
		var tb := TextureRect.new()
		tb.texture = bg
		tb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tb.stretch_mode = TextureRect.STRETCH_SCALE
		tb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tb.set_anchors_preset(Control.PRESET_FULL_RECT)
		tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tb)
	var tex: Texture2D = PetCatalog.icon(key)
	if tex:
		var s: float = pet_scale(tex, side)
		var sz: Vector2 = (tex.get_size() * s).floor()
		var tp := TextureRect.new()
		tp.texture = tex
		tp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tp.stretch_mode = TextureRect.STRETCH_SCALE
		tp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tp.position = ((Vector2(side, side) - sz) * 0.5).floor()
		tp.size = sz
		b.add_child(tp)
	if dim:
		b.modulate = Color(0.45, 0.45, 0.5, 1.0)
	return b


## DK.icon yerine: bw x bw kutuda ortalı arka planlı evcil.
static func icon(key: String, bw: float, dim: bool = false) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(bw, bw)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box(key, bw, dim))
	return cc


## Seçim ekranı karosu: karakter kartı portresiyle aynı Gömme Tepsi çerçevesi (PortraitFace.wrap_framed); toplam boy en çok `total`.
static func framed_icon(key: String, total: float, frame_px: float = 1.0, dim: bool = false) -> CenterContainer:
	var t: float = maxf(1.0, roundf(frame_px))
	var b: Control = box(key, total - 8.0 * t)
	return PortraitFace.wrap_framed(b, b.custom_minimum_size, t, dim)
