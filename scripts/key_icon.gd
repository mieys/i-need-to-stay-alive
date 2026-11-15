extends RefCounted

## HARİTA ANAHTARLARI: görseller + görünen adlar (madde 605, plan docs/harita_icerik/PLAN.md Aşama 4). TEK kaynak: harita kimliği -> doku, ad.
## Her haritanın TEK anahtar türü var (anahtar türü = harita kimliği); o haritanın bossları düşürür, Ruh Mağazası'nda bazı karakter/evcil
## için Ruh Kıymığı'na EK şart olur (kayıt + kural: meta_progress.gd keys/KEY_COSTS). Çizim 32x32, tam katlarda (32 / 64 / 96 px) çizilir.
## Görseller kullanıcının çizimleri (assets/ui/anahtar/<kimlik>.png) - üretme/çizme yok.

const Loc := preload("res://scripts/localization.gd")
const MAP_PROFILES := "res://scripts/map_profiles.gd" ## tembel yüklenir: meta_progress.gd bu betiği önceden yükler, harita profilleri ağır

const DIR := "res://assets/ui/anahtar/"
const ART := 32 ## dokunun kenarı (piksel)
## Sıra = anahtarlar bölümünün sırası. SADECE seçilebilir haritaların anahtarı (map_profiles.gd `secilebilir`).
const IDS := ["ana", "bataklik", "col", "batik_nekropol", "lagim_agi"]
const NAMES := {
	"ana": "Orman Anahtarı",
	"bataklik": "Bataklık Anahtarı",
	"col": "Çöl Anahtarı",
	"batik_nekropol": "Nekropol Anahtarı",
	"lagim_agi": "Lağım Anahtarı",
}

static var _cache: Dictionary = {}


static func has_id(id: String) -> bool:
	return NAMES.has(id)


## Anahtarın dokusu (yoksa null). ÖNEMLİ: `_draw` içinde İLK yükleme beyaz çıkar (madde 156) - ekranlar `_refresh`/kurulumda çağırmalı.
static func texture(id: String) -> Texture2D:
	if not NAMES.has(id):
		return null
	if not _cache.has(id):
		var p: String = DIR + id + ".png"
		_cache[id] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _cache[id]


## "Orman Anahtarı" (seçili dilde).
static func display_name(id: String) -> String:
	return Loc.t(str(NAMES.get(id, id)))


## Harita adı ("Kara Bataklık"): map_profiles.gd `ad` (profilde yoksa kimlik).
static func map_name(id: String) -> String:
	var profiles: Dictionary = (load(MAP_PROFILES) as GDScript).get_script_constant_map().get("PROFILES", {})
	return Loc.t(str((profiles.get(id, {}) as Dictionary).get("ad", id)))


## İstenen boya en yakın tam kat kenar (32 / 64 / 96 ...; en az 1 kat).
static func side_for(px: float) -> float:
	return float(ART * maxi(1, roundi(px / ART)))


## Tek kaynak çizim (kutu başına): o = sol üst, h = kutu kenarı; anahtar kutunun ortasına tam katta oturur. dimmed = soluk (yetmiyor).
static func paint(ci: CanvasItem, o: Vector2, h: float, id: String, dimmed: bool = false) -> void:
	var tex: Texture2D = texture(id)
	if tex == null:
		return
	var side: float = side_for(h)
	var k: float = 0.5 if dimmed else 1.0
	var at := (o + Vector2(h - side, h - side) * 0.5).floor()
	ci.draw_texture_rect(tex, Rect2(at, Vector2(side, side)), false, Color(k, k, k, 1.0))
