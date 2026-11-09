extends RefCounted

## HARİTA PROFİLLERİ (madde 444, harita seçimi; plan docs/harita_secimi/PLAN.md): oyunun hangi haritada koşacağının TEK kaynağı.
## Profil: ad, tür ("orman" = main.tscn'e gömülü ana harita Harita.tmx; "zindan" = tools/zindan üretecinin pişmiş sahnesi + DungeonData),
## sahne (boşsa main.tscn'deki Harita kalır), veri (zindan türünde hücre kodları), seçilebilir (oda kur / tek oyunculu ekranında görünür mü),
## özellik bayrakları (haritaya özgü sistemler buna bakar; tanımsız bayrak ana haritada AÇIK, diğerlerinde KAPALI sayılır).
## Seçim: GameManager.selected_map; geliştirmede HARITA=<id> ortam değişkeni ezer (oda/seçim arayüzü gelene kadar tek giriş yolu).
## Bu betik autoload'lardan ÖNCE derlenebilir (yükleme ekranı, -s betikleri): GameManager'a tanımlayıcıyla değil kök düğümden erişilir.

const DEFAULT_ID := "ana"
const KIND_ORMAN := "orman"
const KIND_ZINDAN := "zindan"
const MAP_NODE_NAME := "Harita"
const DungeonDataScript := preload("res://scripts/dungeon/dungeon_data.gd")
const BataklikMeta := preload("res://scripts/bataklik_meta.gd")
const ColMeta := preload("res://scripts/col_meta.gd")
## Zindan haritasında oyun sistemlerinin "orman katmanı" (GameManager.get_forest_layer: çarpışma, mermi, görüş sisi, yaratık yol ızgarası,
## yaratık doğuş denetimi) - görünmez, haritanın DUVAR hücreleriyle dolu (2. adım, madde 444). Yol GameManager._find_terrain_layers ile aynı.
const WALL_LAYER_PARENT := "Orman parçaları"
const WALL_LAYER_NAME := "Orman parçaları"
## Bayrağı kapalıyken Main'den (ağaca girmeden) kaldırılan main.tscn düğümleri.
const FEATURE_NODES := {"ev_acilisi": "HouseInterior", "seyyar_satici": "TravelingMerchant", "gorevler": "WorldEventManager"}
## Madde 496 (2026-11-08): zindan haritalarında da görevler AÇIK ("gorevler": true) - konum ulaşılabilir zeminden (mission_spots.gd), zindana uymayan
## Konvoy ve Ağacı Koru orada seçilmez (world_event_manager.gd _available_kinds).

static var _data_cache: Dictionary = {}

## Ana haritada açık olan, haritaya özgü sistemler (2. adımda her biri bayrağa bağlanır; 1. adımda yalnız "orman_gorselleri" bağlı).
const MAIN_FEATURES := {
	"orman_gorselleri": true, ## ot/ağaç sallanması, derinlik ön kopyaları, orman tacı, harita gölgeleri, renk ayarı, su, zemin geçişi, nehir sesi
	"ev_acilisi": true, ## açılış evi + kuşatma + babaanne (house_intro / house_siege / house_interior)
	"seyyar_satici": true,
	"gorevler": true,
	"hava": true, ## gün ışığı / yağmur / şimşek / bulut gölgesi (yeraltında yok)
	"madenler": true,
	"calilik": true, ## saklanma çalılıkları
	"kenar_bekcileri": true,
	## Madde 463: ana haritada zindan YOK (kapılar + üç zindan silindi). Tanımsız bayrak ana haritada AÇIK sayıldığı için açıkça kapalı:
	## DungeonManager yalnız zindan biçimli haritalarda kurulur (main.gd).
	"zindan_etkilesim": false,
}

const PROFILES := {
	"ana": {
		"ad": "Ana Harita",
		"aciklama": "Orman, ev ve nehirler - asıl harita.",
		"tur": KIND_ORMAN,
		"sahne": "",
		"veri": "",
		"secilebilir": true,
		"ozellik": MAIN_FEATURES,
	},
	## KARA BATAKLIK (2026-11-09, açık hava; tools/bataklik/gen_bataklik.py + bake_bataklik.gd, oyun alanı 214x214 = ana haritanın %70'i):
	## katmanları Harita.tmx ADLARINDA -> ana haritanın collision / derinlik / ağaç-ot sallanması / saklanma çalılığı / gün-gece / hava
	## sistemleri değişmeden çalışır. Ana haritaya özgü adımlar kapalı: renk ayarının başıboş çimen / köprü altı ayıklaması
	## ("harita_ayiklama"), su dokuları (water_fx.gd, "su_efekti" - bataklık suyu kendi shader'ı), zemin geçişi ("zemin_gecisi").
	## "bataklik_fx": ateş böcekleri + meşale / cadı kulübesi gece ışıkları (bataklik_fx.gd). Doğuş / ışıklar scripts/bataklik_meta.gd'de.
	"bataklik": {
		"ad": "Kara Bataklık",
		"aciklama": "Sisli göl, sazlıklar ve yosunlu kadim ağaçlar: cadı oyuğu, kemik tarlası, mantar korusu, yıkık tapınak, yüzlü ağaç.",
		"tur": KIND_ORMAN,
		"sahne": "res://scenes/bataklik_baked.tscn",
		"veri": "",
		"secilebilir": true,
		"oyun_alani": BataklikMeta.PLAY_CELLS,
		"dogus": BataklikMeta.SPAWN,
		"minimap": "res://assets/ui/minimap_bataklik.png",
		## madde 525 (kullanıcı: "bataklık sularından geçilebilmeli"): su collision'a girmez (terrain_collision.gd), suya giren yürüyen
		## karakter / yaratık / evcilin ayağı suyun altında görünür (wade_fx.gd, maske assets/map/bataklik_su_derinlik.png).
		"su_yurunur": true,
		"su_maskesi": "res://assets/map/bataklik_su_derinlik.png",
		"ozellik": {"orman_gorselleri": true, "hava": true, "calilik": true, "gorevler": true, "bataklik_fx": true},
	},
	## ALTIN KUMLAR (2026-11-09, çöl, açık hava; tools/col/gen_col.py + bake_col.gd, oyun alanı 243x243 = ana haritanın yüzde 90'ı): Kara
	## Bataklık gibi Harita.tmx katman adlarında (collision / derinlik / sallanma / saklanma / gün-gece sistemleri değişmeden çalışır) + üst üste
	## binen kaya yığınları için "Shader Eklenecek/Kayalar 1..3" (depth_occluders OBJECT_LAYERS, terrain_collision PROP_LAYERS). Vaha suyu
	## yürünmez. "hava_donusum": çölde yağmur yağmaz - hava seçimi Yağmurlu -> Rüzgarlı, Sağanak -> Açık (atmosphere.gd map_weather).
	## "col_fx": küre tapınağının gece ışığı (col_fx.gd). Doğuş / ışıklar scripts/col_meta.gd'de (üretilir).
	"col": {
		"ad": "Altın Kumlar",
		"aciklama": "Vahalar, palmiyeler ve rüzgârın oyduğu kaya sütunları: Büyük Vaha, Firavun Vadisi, Küre Tapınağı, Yılan Mezarlığı, Ölü Ağaçlar Ovası, Kaktüs Bahçesi.",
		"tur": KIND_ORMAN,
		"sahne": "res://scenes/col_baked.tscn",
		"veri": "",
		"secilebilir": true,
		"oyun_alani": ColMeta.PLAY_CELLS,
		"dogus": ColMeta.SPAWN,
		"minimap": "res://assets/ui/minimap_col.png",
		"hava_donusum": {2: 1, 3: 0},
		"ozellik": {"orman_gorselleri": true, "hava": true, "calilik": true, "gorevler": true, "col_fx": true},
	},
	"kadim_derinlikler": {
		"ad": "Kadim Derinlikler",
		"aciklama": "Yeraltı: beş dev salon, geniş yollar ve koridorlu oda kümeleri (Kemik, Et, Boynuz bölgeleri).",
		"tur": KIND_ZINDAN,
		"sahne": "res://scenes/zindan/kadim_derinlikler_baked.tscn",
		"veri": "res://scenes/zindan/kadim_derinlikler_data.tres",
		"secilebilir": false, ## madde 445: üç setin karışımı beğenilmedi, yerine tek temalı üç harita (dosyalar duruyor, mekanik testleri kullanıyor)
		"ozellik": {"zindan_etkilesim": true, "gorevler": true},
		## DungeonManager harita kipi (dungeon_light.gd): ortam = üç zindanın renklerinin ortası (tek CanvasModulate), oyuncu feneri nötr.
		## Nesnelerin `tema` özelliği hangi zindanın kaynağı / sunak teklifleri / kapı-tuzak görseli olduğunu seçer (DungeonManager.MAP_THEME_DUNGEON).
		"zindan_tanimi": {
			"ambient_day": Color(0.39, 0.37, 0.43),
			"ambient_night": Color(0.33, 0.31, 0.39),
			"player_light": Color(0.88, 0.9, 0.96),
		},
	},
	## TEK TEMALI ZİNDAN HARİTALARI (madde 445; tools/zindan/gen_tema_haritalari.py, 214x214 = ana haritanın alanının %70'i). Etkileşimler
	## (kapı / tuzak / kaynak / sunak-NPC / avcı / oda sakinleri) temanın zindanınınki; ortam ışığı o zindanın tanımı (dungeon_defs.gd).
	## YENİ ÜÇ HARİTA (madde 449, her biri tek zindan setinden, elle tasarlanmış plan): 1. BATIK NEKROPOL (tools/zindan/gen_batik_nekropol.py,
	## Dungeon3 seti): ortada su basmış sarnıç + adada Kemik Sunağı, halka cadde, 8 semt; bu haritaya özgü EJDER BAŞI tuzakları (tuzak tur
	## "ejder", dungeon_props.gd "tuzak_ejder"). Kemik Katakombu (madde 447) bunun yerine seçimden kalktı (dosyaları duruyor).
	"batik_nekropol": {
		"ad": "Batık Nekropol",
		"aciklama": "Su basmış sarnıcın çevresinde ölüler şehri: katedral, mozole avluları, lahit galerileri, kemik odaları. Ejder başları ruh ateşi püskürtür.",
		"tur": KIND_ZINDAN,
		"sahne": "res://scenes/zindan/batik_nekropol_baked.tscn",
		"veri": "res://scenes/zindan/batik_nekropol_data.tres",
		"secilebilir": true,
		"ozellik": {"zindan_etkilesim": true, "gorevler": true, "zemin_tasi": true}, ## zemin_tasi: dungeon_floor.gd zemin shader'ı (madde 449)
		## ince ayar (kullanıcı: "ışık / karanlık"): ortam Kemik Mahzeni'nden ~%25 açık
		"zindan_tanimi": {"ambient_day": Color(0.46, 0.50, 0.56), "ambient_night": Color(0.40, 0.44, 0.50), "player_light": Color(0.78, 0.92, 1.0)},
	},
	## 2. TAŞKIN HİSAR (tools/zindan/gen_taskin_hisar.py, Dungeon1 seti): KB taşkın havuzundan GD boşaltım havuzuna dik açılarla inen rıhtımlı
	## kanal, KD'de hisar / GB'de aşağı kale; bu haritaya özgü KÖPRÜ KOLLARI (nesne "kol" + "grup"lu parmaklıklar, dungeon_manager.gd
	## request_lever). Boynuz Mağaraları (madde 447) bunun yerine seçimden kalktı (dosyaları duruyor). zemin_rengi: zemin shader'ının taş
	## derzi çizdiği kum rengi (Dungeon1 zemini, dungeon_floor.gd).
	"taskin_hisar": {
		"ad": "Taşkın Hisar",
		"aciklama": "Kanalla ikiye bölünmüş kale: hisar, mahzenler, liman, zindan hücreleri. Köprü kollarıyla iki köprünün parmaklığı birden iner.",
		"tur": KIND_ZINDAN,
		"sahne": "res://scenes/zindan/taskin_hisar_baked.tscn",
		"veri": "res://scenes/zindan/taskin_hisar_data.tres",
		"secilebilir": true,
		"ozellik": {"zindan_etkilesim": true, "gorevler": true, "zemin_tasi": true},
		"zemin_rengi": Color8(128, 138, 163),
		"zindan_tanimi": {"ambient_day": Color(0.44, 0.47, 0.56), "ambient_night": Color(0.38, 0.41, 0.50), "player_light": Color(1.0, 0.90, 0.76)},
	},
	## 3. LAĞIM AĞI (tools/zindan/gen_lagim_agi.py, Kanalizasyon seti, özgün yeşil su): ortası kanallı tünel ağı, kavşak havuzları, güneyde
	## ana toplayıcı; bu haritaya özgü GAZ FIÇISI (nesne "fici", dungeon_manager.gd request_barrel). Kızıl Lağım (madde 447) bunun yerine
	## seçimden kalktı (dosyaları duruyor).
	"lagim_agi": {
		"ad": "Lağım Ağı",
		"aciklama": "Kanallı tüneller, kavşak havuzları, simyacının laboratuvarı. Gaz fıçılarını ateşle, peşindeki sürüyü havaya uçur.",
		"tur": KIND_ZINDAN,
		"sahne": "res://scenes/zindan/lagim_agi_baked.tscn",
		"veri": "res://scenes/zindan/lagim_agi_data.tres",
		"secilebilir": true,
		"ozellik": {"zindan_etkilesim": true, "gorevler": true, "zemin_tasi": true},
		"zemin_rengi": Color8(147, 124, 98),
		"zindan_tanimi": {"ambient_day": Color(0.42, 0.47, 0.40), "ambient_night": Color(0.36, 0.41, 0.35), "player_light": Color(1.0, 0.88, 0.72)},
	},
	"kemik_katakombu": {
		"ad": "Kemik Katakombu",
		"aciklama": "Gri taş kripta: ruh alevli sunak salonu, lahit galerileri, kemik ocakları. Parmaklık + diken kapılar, diken tuzakları.",
		"tur": KIND_ZINDAN,
		"sahne": "res://scenes/zindan/kemik_katakombu_baked.tscn",
		"veri": "res://scenes/zindan/kemik_katakombu_data.tres",
		"secilebilir": false,
		"ozellik": {"zindan_etkilesim": true, "gorevler": true},
		"zindan_tanimi": {"ambient_day": Color(0.36, 0.40, 0.46), "ambient_night": Color(0.30, 0.34, 0.40), "player_light": Color(0.78, 0.92, 1.0)},
	},
	"kizil_lagim": {
		"ad": "Kızıl Lağım",
		"aciklama": "Kanalizasyon: köprülü kan kanalları, hücre koğuşu, simya salonu, et bahçesi. Kafes kapılar, giyotinler, simyacı.",
		"tur": KIND_ZINDAN,
		"sahne": "res://scenes/zindan/kizil_lagim_baked.tscn",
		"veri": "res://scenes/zindan/kizil_lagim_data.tres",
		"secilebilir": false, ## madde 449: yerine Lağım Ağı
		"ozellik": {"zindan_etkilesim": true, "gorevler": true},
		"zindan_tanimi": {"ambient_day": Color(0.48, 0.33, 0.32), "ambient_night": Color(0.42, 0.28, 0.28), "player_light": Color(1.0, 0.82, 0.70)},
	},
	"boynuz_magaralari": {
		"ad": "Boynuz Mağaraları",
		"aciklama": "Tapınak ve kristal mağaralar: lav yarığı, mantar korusu, mühür salonu. Demir kapılar, kristal duvarlar, boynuz totemi.",
		"tur": KIND_ZINDAN,
		"sahne": "res://scenes/zindan/boynuz_magaralari_baked.tscn",
		"veri": "res://scenes/zindan/boynuz_magaralari_data.tres",
		"secilebilir": false, ## madde 449: yerine Taşkın Hisar
		"ozellik": {"zindan_etkilesim": true, "gorevler": true},
		"zindan_tanimi": {"ambient_day": Color(0.32, 0.36, 0.50), "ambient_night": Color(0.26, 0.30, 0.44), "player_light": Color(0.80, 0.90, 1.0)},
	},
}


static func ids() -> Array:
	return PROFILES.keys()


static func has_profile(id: String) -> bool:
	return PROFILES.has(id)


## Seçili haritada su yürünebilir mi (madde 525, Kara Bataklık): terrain_collision.gd su hücrelerini engel saymaz, wade_fx.gd kurulur.
static func water_walkable() -> bool:
	return bool(current().get("su_yurunur", false))


## Seçili haritanın hava dönüşümü (Altın Kumlar: yağmur yok). w = AtmosphereMath.Weather; profilde "hava_donusum" {kaynak: hedef}.
static func map_weather(w: int) -> int:
	var conv: Dictionary = current().get("hava_donusum", {})
	return int(conv.get(w, w))


## Oda kur / tek oyunculu ekranında gösterilen haritalar (profil sırasıyla).
static func selectable_ids() -> Array:
	var out: Array = []
	for id: String in PROFILES:
		if bool((PROFILES[id] as Dictionary).get("secilebilir", false)):
			out.append(id)
	return out


static func is_selectable(id: String) -> bool:
	return PROFILES.has(id) and bool((PROFILES[id] as Dictionary).get("secilebilir", false))


static func get_profile(id: String) -> Dictionary:
	return PROFILES.get(id, PROFILES[DEFAULT_ID])


## Seçili harita: HARITA ortam değişkeni (geçerliyse) > GameManager.selected_map (geçerliyse) > ana harita.
static func current_id() -> String:
	var env: String = OS.get_environment("HARITA")
	if env != "" and PROFILES.has(env):
		return env
	var gm: Node = _game_manager()
	if gm != null:
		var sel: String = str(gm.get("selected_map"))
		if PROFILES.has(sel):
			return sel
	return DEFAULT_ID


static func current() -> Dictionary:
	return get_profile(current_id())


static func is_main_map() -> bool:
	return current_id() == DEFAULT_ID


## Haritaya özgü sistem bu haritada açık mı (tanımsız bayrak: ana haritada açık, diğerlerinde kapalı). Kara Bataklık da açık hava
## ("orman" türü) ama ana haritanın ev / satıcı / maden / bekçi sistemleri orada yok: varsayılan TÜRE değil ana harita kimliğine bakar.
static func feature(name: String) -> bool:
	var id: String = current_id()
	var f: Dictionary = (PROFILES.get(id, PROFILES[DEFAULT_ID]) as Dictionary).get("ozellik", {})
	if f.has(name):
		return bool(f[name])
	return id == DEFAULT_ID


## Yükleme ekranının iş parçacığında önceden yükleyeceği kaynaklar (seçili haritanın sahnesi + verisi).
static func preload_paths() -> Array[String]:
	var out: Array[String] = []
	var p: Dictionary = current()
	for k: String in ["sahne", "veri"]:
		var path: String = str(p.get(k, ""))
		if path != "" and ResourceLoader.exists(path):
			out.append(path)
	return out


## Main._enter_tree'den (çocuklar henüz ağaca girmeden): seçili haritanın sahnesi varsa main.tscn'deki "Harita"nın yerine konur (aynı ad,
## aynı sıra; zindan sahnesi kendi koordinatında, kayma yok). Ana haritada hiçbir şey yapmaz. Dönüş: harita değişti mi.
static func install(main: Node) -> bool:
	var p: Dictionary = current()
	var path: String = str(p.get("sahne", ""))
	if path == "":
		return false
	var old: Node = main.get_node_or_null(MAP_NODE_NAME)
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("Harita sahnesi yüklenemedi: " + path)
		return false
	var map_node: Node = packed.instantiate()
	if str(p.get("tur", "")) == KIND_ZINDAN:
		_add_wall_layer(map_node)
	var idx: int = -1
	if old != null:
		idx = old.get_index()
		main.remove_child(old)
		old.free()
	map_node.name = MAP_NODE_NAME
	main.add_child(map_node)
	if idx >= 0:
		main.move_child(map_node, idx)
	for f: String in FEATURE_NODES:
		if not feature(f):
			var n: Node = main.get_node_or_null(str(FEATURE_NODES[f]))
			if n != null:
				main.remove_child(n)
				n.free()
	return true


## Seçili zindan haritasının verisi (DungeonData: hücre kodları + nesneler), yoksa null. Önbellekli.
static func data() -> Resource:
	var path: String = str(current().get("veri", ""))
	if path == "":
		return null
	if not _data_cache.has(path):
		_data_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _data_cache[path]


## Doğuş noktası (harita düğümünün yerel px'i = dünya; Harita (0,0)'da): zindan haritasında `dogus` nesnesinin ortası, yoksa Vector2.INF.
static func spawn_position() -> Vector2:
	var p: Dictionary = current()
	if p.has("dogus"):
		return p["dogus"]
	var d: Resource = data()
	if d == null:
		return Vector2.INF
	for o: Dictionary in d.objects:
		if str(o.get("type", "")) == "dogus":
			return (o["rect"] as Rect2).get_center()
	return Vector2.INF


## Minimap dokusu (zindan haritası; 1 doku pikseli = 1 hücre, köken Harita (0,0)): ana haritanın pişmiş resmi gibi TAMAMI görünür, renkler
## zindan minimapinin (dungeon_manager.gd MM_*) - duvar yalnız zemine değen kenarda, kanallar kan rengi. Önbellekli.
const MM_DEEP := Color(0.07, 0.065, 0.085)
const MM_FLOOR := Color(0.62, 0.55, 0.43)
const MM_WALL := Color(0.22, 0.18, 0.16)
const MM_SOLID := Color(0.42, 0.35, 0.29)
const MM_HIDE := Color(0.38, 0.5, 0.34)
const MM_WATER := Color(0.45, 0.1, 0.1)
static var _mm_cache: Dictionary = {}


static func minimap_texture() -> Texture2D:
	## Açık hava haritası (Kara Bataklık): üretecin pişirdiği resim, 1 doku pikseli = 1 hücre, köken (0,0) (çerçeve dahil tüm harita).
	var mm_path: String = str(current().get("minimap", ""))
	if mm_path != "":
		return load(mm_path) as Texture2D if ResourceLoader.exists(mm_path) else null
	var d: Resource = data()
	if d == null:
		return null
	var key: String = str(current().get("veri", ""))
	if _mm_cache.has(key):
		return _mm_cache[key]
	var w: int = d.size.x
	var h: int = d.size.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var code: int = d.cells[y * w + x]
			var col: Color = MM_FLOOR
			match code:
				DungeonDataScript.CELL_WALL:
					col = MM_DEEP
					for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if d.cell_at(Vector2i(x, y) + o) != DungeonDataScript.CELL_WALL:
							col = MM_WALL
							break
				DungeonDataScript.CELL_SOLID:
					col = MM_SOLID
				DungeonDataScript.CELL_WATER:
					col = MM_WATER
				DungeonDataScript.CELL_HIDE:
					col = MM_HIDE
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_mm_cache[key] = tex
	return tex


## Görünmez duvar katmanı (bkz. WALL_LAYER_*): her CELL_WALL hücresine tek karo. Görsel değil - yalnız get_cell_source_id / get_used_cells.
static func _add_wall_layer(map_node: Node) -> void:
	var d: Resource = data()
	if d == null or map_node.get_node_or_null(WALL_LAYER_PARENT + "/" + WALL_LAYER_NAME) != null:
		return
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(16, 16)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.name = WALL_LAYER_NAME
	layer.tile_set = ts
	layer.visible = false
	var w: int = d.size.x
	var cells: PackedByteArray = d.cells
	for i in range(cells.size()):
		if cells[i] == DungeonDataScript.CELL_WALL:
			layer.set_cell(Vector2i(i % w, i / w), 0, Vector2i.ZERO)
	var holder := Node2D.new()
	holder.name = WALL_LAYER_PARENT
	holder.add_child(layer)
	map_node.add_child(holder)


static func _game_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("GameManager")
