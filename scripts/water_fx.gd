extends Node

## SU EFEKTİ (madde 214, 2026-10-17): prototip C3 "Akıntılı Dalgacık" (madde 209, tools/proto_20261017/su_shader/) oyunda.
## harita_baked.tscn "Su/Su" katmanının shader'ı (scenes/su.gdshader) kıyıya uzaklık + akış dokularını BURADAN alır; "Su/Su collisionsuz"
## (çarpışmasız su karoları: köprü altı, göl kenarı - eskiden shader'sız düz opak su) aynı materyali paylaşır. Sahne dosyasına dokunulmaz
## (açık editör harita_baked.tscn'i yeniden kaydedebilir, bkz. map_color_grade.gd).
## Dokular haritadan PİŞİRİLİR: Su / Su collisionsuz / Su ayrıntılar katmanları değişince (harita yeniden bake edilince)
##   Godot --path . --windowed --resolution 320x180 -s tools/gen_su_dokusu.gd   (Python + numpy'yi kendisi çağırır)
## Dalgacıklar "Zemin ayrıntısı" grafik ayarına bağlı (UISound.gfx_ground_detail, Düşük'te kapalı): su ekran çözünürlüğünde çizilir,
## telefonda kamera ~3,25x yakın -> dalgacık döngüsü piksel başına pahalı. Kapalıyken düz su kalır (madde 424: derinlik tonu / kabarma / kıyı çizgisi artık yok).
## attach çağrılmazsa shader dokusuz çalışır: düz su, dalgacık yok (hint_default_white/black).

const NODE_NAME := "SuEfekti"
const WATER_PATH := "Su/Su"
const WATER_NOCOL_PATH := "Su/Su collisionsuz"
## Dokuların kapladığı dikdörtgen, HARİTA KÖKÜNÜN yerel koordinatında (= harita orijindeyken dünya) = Su katmanının kullanılan alanı +
## her yanda 4 hücre (tools/gen_su_dokusu.gd de BURADAN okur; su bu alanın dışına taşarsa araç uyarır - o zaman ikisini birlikte büyüt).
## attach bunu Harita'nın global dönüşümüyle dünyaya çevirir (main.tscn'de Harita (-2, 21)'de).
const TEX_ORIGIN := Vector2(-576, -384)
const TEX_WORLD_SIZE := Vector2(5248, 4864)
const MESAFE_TEXEL := 2 ## dünya px / su_mesafe.png tekseli (R = kıyıya uzaklık / 64 px)
const AKIS_TEXEL := 4 ## dünya px / su_akis.png tekseli (RG = akış, B = dalgacık doğabilir)
const MESAFE_TEX := "res://assets/map/su_mesafe.png"
const AKIS_TEX := "res://assets/map/su_akis.png"
## Altın Kumlar (madde 631): aynı dokular çöl haritasından pişirilir (`-- col`, tools/gen_su_dokusu.gd), alanı + yolları profilin "su_doku"sundan
## (scripts/map_profiles.gd) gelir; yoksa yukarıdaki ana harita sabitleri.
## TÜM SULAR BU SHADER (madde 714, kullanıcı 2026-11-15): Kara Bataklık / Altın Kumlar / Ayaz Dağı (sıcak kaynak) / Batık Nekropol de scenes/su.gdshader;
## profilin "su_doku"su: "renk" (sabit su rengi - karo rengi kullanılmaz), "sirt" (dalgacık sırtı), "katman" (su katmanının Harita'ya göre yolu,
## varsayılan "Su/Su"), "ayrinti" (kıyı ayrıntı katmanları, doku pişirme). Materyal make_material ile kurulur (bake betikleri de aynısını yazar).
const MapProfilesScript := preload("res://scripts/map_profiles.gd")
const SHADER_PATH := "res://scenes/su.gdshader"

var _mat: ShaderMaterial = null


## Profil "su_doku"suna göre su materyali (sabit renkli; "renk" yoksa ana haritanınki gibi karo rengi). Bake betikleri + attach.
static func make_material(cfg: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	if cfg.has("renk"):
		mat.set_shader_parameter("sabit_renk", true)
		mat.set_shader_parameter("su_rengi", cfg["renk"])
	if cfg.has("sirt"):
		mat.set_shader_parameter("sirt_renk", cfg["sirt"])
	apply_murk(mat, cfg)
	return mat


## BULANIK SU (2026-11-16, shaders/su_bulanik.gdshaderinc): profilin "su_doku" -> "bulanik" sözlüğü varsa açar, anahtarlar shader uniform
## adlarıdır (verilmeyen = shader varsayılanı). Su materyali + suya giren ayak örtüsü (wade_fx.gd) AYNI değerleri almalı.
static func apply_murk(mat: ShaderMaterial, cfg: Dictionary) -> void:
	var murk: Variant = cfg.get("bulanik", null)
	mat.set_shader_parameter("bulanik", murk is Dictionary)
	if murk is Dictionary:
		for k: String in (murk as Dictionary):
			mat.set_shader_parameter(k, (murk as Dictionary)[k])


## KARODA GÖMÜLÜ SU (2026-11-16, kullanıcı: "bitki kenarlarındaki su efekti uyumsuz oldu suyla"): profilin "su_doku" -> "su_karolari"
## katmanlarındaki setin eski su paleti pikselleri (kıyı çimeninin altındaki gölge / köpük, nilüfer gölgesi, mercimek, dalga izi) bulanık
## suya boyanır (shaders/su_bulanik.gdshaderinc su_bulanik_karo). Materyali bulanık su kodunu taşıyorsa (bataklik_zemin.gdshader, kıyı;
## Zemin Toprak / Çimen'le paylaşılan - onlarda su paleti yok) parametre yazılır; yoksa (renk ayarının PAYLAŞILAN düz materyali) katman
## kendi bataklik_su_susu.gdshader materyalini alır (paylaşılan düz materyale yazılmaz - öbür katmanlar / haritalar etkilenirdi).
const TILES_SHADER_PATH := "res://scenes/bataklik_su_susu.gdshader"


static func _setup_water_tiles(harita: Node, cfg: Dictionary) -> void:
	if not cfg.has("bulanik"):
		return
	for path: String in cfg.get("su_karolari", []):
		var layer := harita.get_node_or_null(path) as TileMapLayer
		if layer == null:
			continue
		var sm := layer.material as ShaderMaterial
		var has_murk := false
		if sm != null and sm.shader != null:
			for u: Dictionary in sm.shader.get_shader_uniform_list():
				if u["name"] == "bulanik":
					has_murk = true
					break
		if not has_murk:
			sm = ShaderMaterial.new()
			sm.shader = load(TILES_SHADER_PATH)
			layer.material = sm
			layer.use_parent_material = false
		if cfg.has("renk"):
			sm.set_shader_parameter("su_rengi", cfg["renk"])
		apply_murk(sm, cfg)


## main.gd (açık hava) ve dungeon_manager.gd (zindan biçimli harita) çağırır. Katman/doku yoksa hiçbir şey yapmaz.
static func attach(harita: Node) -> Node:
	if harita == null or harita.get_node_or_null(NODE_NAME) != null:
		return null
	var cfg: Dictionary = MapProfilesScript.current().get("su_doku", {})
	var water := harita.get_node_or_null(str(cfg.get("katman", WATER_PATH))) as TileMapLayer
	if water == null:
		return null
	## Sahnede su.gdshader materyali yoksa (zindan sahnesi ya da eski pişirim) profilden kurulur; varsa profil rengi yine yazılır.
	if not (water.material is ShaderMaterial) or (water.material as ShaderMaterial).shader == null \
			or (water.material as ShaderMaterial).shader.resource_path != SHADER_PATH:
		if not cfg.has("renk") and not (water.material is ShaderMaterial):
			return null
		water.material = make_material(cfg)
		water.use_parent_material = false
	elif cfg.has("renk"):
		(water.material as ShaderMaterial).set_shader_parameter("sabit_renk", true)
		(water.material as ShaderMaterial).set_shader_parameter("su_rengi", cfg["renk"])
		if cfg.has("sirt"):
			(water.material as ShaderMaterial).set_shader_parameter("sirt_renk", cfg["sirt"])
		apply_murk(water.material as ShaderMaterial, cfg)
	_setup_water_tiles(harita, cfg)
	var mesafe := load(str(cfg.get("mesafe", MESAFE_TEX))) as Texture2D
	var akis := load(str(cfg.get("akis", AKIS_TEX))) as Texture2D
	if mesafe == null or akis == null:
		push_warning("WaterFx: su dokuları yok - tools/gen_su_dokusu.gd çalıştır")
		return null
	var mat := water.material as ShaderMaterial
	mat.set_shader_parameter("su_mesafe", mesafe)
	mat.set_shader_parameter("su_akis", akis)
	## TEX_* HARİTA KÖKÜNE göre (araç haritayı orijinde pişirir); shader dünya koordinatıyla çalışır. main.tscn'de Harita (-2, 21)'de:
	## dönüşüm uygulanmayınca kıyı çizgileri / sığ tonlar suyun ortasına kayıyordu (kullanıcı ekran görüntüsü, 2026-10-17).
	var xf: Transform2D = (harita as Node2D).global_transform if harita is Node2D else Transform2D.IDENTITY
	var tex_origin: Vector2 = cfg.get("origin", TEX_ORIGIN)
	var tex_size: Vector2 = cfg.get("size", TEX_WORLD_SIZE)
	mat.set_shader_parameter("doku_origin", xf * tex_origin)
	mat.set_shader_parameter("doku_size", tex_size * xf.get_scale())
	var nocol := harita.get_node_or_null(WATER_NOCOL_PATH) as TileMapLayer
	if nocol != null:
		nocol.material = mat
	var fx: Node = (load("res://scripts/water_fx.gd") as GDScript).new()
	fx.name = NODE_NAME
	fx._mat = mat
	harita.add_child(fx)
	return fx


func _ready() -> void:
	UISound.graphics_changed.connect(_apply)
	_apply()


func _apply() -> void:
	if _mat != null:
		_mat.set_shader_parameter("dalgacik_acik", UISound.gfx_ground_detail)


func _exit_tree() -> void:
	if UISound.graphics_changed.is_connected(_apply):
		UISound.graphics_changed.disconnect(_apply)
