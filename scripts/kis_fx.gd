extends Node2D

## AYAZ DAĞI (kış) atmosfer efektleri (2026-11-12; main.gd kurar, MapProfiles "kis_fx" bayrağı). Tamamen kozmetik + yerel: ağ gerekmez
## (gün saati / hava zaten eşitli, konumlar haritanın sabit verisi scripts/kis_meta.gd - tools/kis/gen_kis.py üretir).
##  - GECE IŞIKLARI: her alev (meşale / mangal / büyük mangal / kamp ateşi) -> kis_ates_isik.gd (titrek, sıcak); dev kristal, Kadim Buz Ağacı,
##    sıcak kaynak -> kis_kristal_isik.gd (sakin, soğuk). Işığı night_glow_catalog.gd takar.
##  - DUMAN: kamp ateşi + büyük mangalın üstünde oyunun onaylı yanma dumanı (fx_burn_smoke_*), kısık; sıcak kaynağın üstünde aynı kareler
##    beyaz BUHAR olarak (yavaş, rastgele evreli).
##  - ISINMA NOKTALARI (ileride üşüme / ısınma mekaniği için): kis_meta.gd HEAT_SOURCES'ın her biri "isi_kaynagi" grubunda bir Node2D
##    (meta "tur" = kamp_atesi / buyuk_mangal / mangal / mesale / kaplica, "yaricap" = dünya px). Mekanik bu grubu okuyacak; şimdilik etkisi yok.

const MetaScript := preload("res://scripts/kis_meta.gd")
const FireLightScript := preload("res://scripts/kis_ates_isik.gd")
const ColdLightScript := preload("res://scripts/kis_kristal_isik.gd")
const SMOKE_FRAMES := [
	preload("res://assets/generated/fx_burn_smoke_a_frames.tres"),
	preload("res://assets/generated/fx_burn_smoke_b_frames.tres"),
	preload("res://assets/generated/fx_burn_smoke_c_frames.tres"),
]
const HEAT_GROUP := "isi_kaynagi"

const LIGHT_PROFILES := {
	"mesale": {"c": Color(1.0, 0.55, 0.2), "r": 54.0},
	"mangal": {"c": Color(1.0, 0.52, 0.18), "r": 72.0},
	"buyuk_mangal": {"c": Color(1.0, 0.5, 0.16), "r": 104.0},
	"kamp_atesi": {"c": Color(1.0, 0.56, 0.22), "r": 84.0},
	"kaplica": {"c": Color(0.55, 0.95, 0.88), "r": 68.0, "cold": true},
	"kristal": {"c": Color(0.45, 0.85, 1.0), "r": 64.0, "cold": true},
	"buz_agaci": {"c": Color(0.5, 0.86, 1.0), "r": 120.0, "cold": true},
}
## Yanma dumanı kareleri koyu mavi-gri (#3f545b): karda kirli leke gibi durmasın diye modülasyon 1'in üstünde (2B'de çarpım, 1'de kırpılır):
## kamp dumanı açık gri (#9fa8ab civarı), kaynak buharı neredeyse beyaz; koyu pikseller içte gölge olarak kalır.
const SMOKE_TINT := Color(2.5, 2.0, 1.9, 0.32)
const SMOKE_SCALE := 0.55
const STEAM_TINT := Color(3.6, 2.9, 2.7, 0.2)
const STEAM_SCALE := 0.7


func _ready() -> void:
	z_index = 4 ## ağaçların ve ön kopyaların (z 2-3) üstünde: duman / buhar havada
	z_as_relative = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for l: Array in MetaScript.LIGHTS:
		var kind: String = l[0]
		var prof: Dictionary = LIGHT_PROFILES.get(kind, LIGHT_PROFILES["mesale"])
		var n: Node2D = (ColdLightScript if prof.get("cold", false) else FireLightScript).new()
		n.name = "Isik_" + kind
		n.set("glow_color", prof["c"])
		n.set("glow_radius", prof["r"])
		n.position = l[1]
		add_child(n)
	for h: Array in MetaScript.HEAT_SOURCES:
		var hn := Node2D.new()
		hn.name = "Isi_" + str(h[0])
		hn.position = h[1]
		hn.set_meta("tur", h[0])
		hn.set_meta("yaricap", h[2])
		hn.add_to_group(HEAT_GROUP)
		add_child(hn)
	var i := 0
	for p: Vector2 in MetaScript.SMOKE:
		_add_puff(p, SMOKE_FRAMES[i % SMOKE_FRAMES.size()], SMOKE_TINT, SMOKE_SCALE, 1.0)
		i += 1
	for s: Array in MetaScript.STEAM:
		var c: Vector2 = s[0]
		var rx: float = s[1]
		var ry: float = s[2]
		for k in range(5):
			var a: float = TAU * float(k) / 5.0 + 0.4
			var p := c + Vector2(cos(a) * rx * 0.45, sin(a) * ry * 0.35)
			_add_puff(p.round(), SMOKE_FRAMES[k % SMOKE_FRAMES.size()], STEAM_TINT, STEAM_SCALE, 0.55)


## Duman / buhar sütunu: kareler alttan yükselir; sprite'ın alt-ortası verilen noktada. Evre rastgele (yan yana sütunlar aynı anda atmasın).
func _add_puff(base: Vector2, frames: SpriteFrames, col: Color, sc: float, speed: float) -> void:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.centered = true
	s.modulate = col
	s.scale = Vector2(sc, sc)
	var tex: Texture2D = frames.get_frame_texture("burn", 0)
	var h: float = float(tex.get_height()) if tex != null else 128.0
	s.position = base + Vector2(0.0, -h * sc * 0.5 + 4.0)
	s.speed_scale = speed
	add_child(s)
	s.play("burn")
	s.frame = randi() % maxi(1, frames.get_frame_count("burn"))
