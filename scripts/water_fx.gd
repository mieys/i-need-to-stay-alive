extends Node

## SU EFEKTİ (madde 214, 2026-10-17): prototip C3 "Akıntılı Dalgacık" (madde 209, tools/proto_20261017/su_shader/) oyunda.
## harita_baked.tscn "Su/Su" katmanının shader'ı (scenes/su.gdshader) kıyıya uzaklık + akış dokularını BURADAN alır; "Su/Su collisionsuz"
## (çarpışmasız su karoları: köprü altı, göl kenarı - eskiden shader'sız düz opak su) aynı materyali paylaşır. Sahne dosyasına dokunulmaz
## (açık editör harita_baked.tscn'i yeniden kaydedebilir, bkz. map_color_grade.gd).
## Dokular haritadan PİŞİRİLİR: Su / Su collisionsuz / Su ayrıntılar katmanları değişince (harita yeniden bake edilince)
##   Godot --path . --windowed --resolution 320x180 -s tools/gen_su_dokusu.gd   (Python + numpy'yi kendisi çağırır)
## Dalgacıklar "Zemin ayrıntısı" grafik ayarına bağlı (UISound.gfx_ground_detail, Düşük'te kapalı): su ekran çözünürlüğünde çizilir,
## telefonda kamera ~3,25x yakın -> dalgacık döngüsü piksel başına pahalı. Kapalıyken derinlik tonu + kabarma + kıyı çizgisi kalır.
## attach çağrılmazsa shader dokusuz çalışır: her yer "derin" ton, kıyı çizgisi ve dalgacık yok (hint_default_white/black).

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

var _mat: ShaderMaterial = null


## main.gd çağırır (MapColorGrade'den sonra). Katman/materyal/doku yoksa hiçbir şey yapmaz.
static func attach(harita: Node) -> Node:
	if harita == null or harita.get_node_or_null(NODE_NAME) != null:
		return null
	var water := harita.get_node_or_null(WATER_PATH) as TileMapLayer
	if water == null or not (water.material is ShaderMaterial):
		return null
	var mesafe := load(MESAFE_TEX) as Texture2D
	var akis := load(AKIS_TEX) as Texture2D
	if mesafe == null or akis == null:
		push_warning("WaterFx: su dokuları yok - tools/gen_su_dokusu.gd çalıştır")
		return null
	var mat := water.material as ShaderMaterial
	mat.set_shader_parameter("su_mesafe", mesafe)
	mat.set_shader_parameter("su_akis", akis)
	## TEX_* HARİTA KÖKÜNE göre (araç haritayı orijinde pişirir); shader dünya koordinatıyla çalışır. main.tscn'de Harita (-2, 21)'de:
	## dönüşüm uygulanmayınca kıyı çizgileri / sığ tonlar suyun ortasına kayıyordu (kullanıcı ekran görüntüsü, 2026-10-17).
	var xf: Transform2D = (harita as Node2D).global_transform if harita is Node2D else Transform2D.IDENTITY
	mat.set_shader_parameter("doku_origin", xf * TEX_ORIGIN)
	mat.set_shader_parameter("doku_size", TEX_WORLD_SIZE * xf.get_scale())
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
