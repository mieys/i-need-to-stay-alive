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
