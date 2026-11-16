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
const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const BataklikMeta := preload("res://scripts/bataklik_meta.gd")
const GuardScript := preload("res://scripts/security/security_guard.gd") ## HARITA ortam değişkeni yalnız editörde (hile koruması, 2026-11-12)
const ColMeta := preload("res://scripts/col_meta.gd")
const KisMeta := preload("res://scripts/kis_meta.gd")
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
	## madde 714 (cila): diğer haritaların FX'i ana haritada AÇIKÇA kapalı - tanımsız bayrak ana haritada açık sayıldığı için Kara Bataklık / Altın Kumlar /
	## Ayaz Dağı'nın meşale-kulübe ışıkları, ateş böcekleri, ısı noktaları ve dumanları kendi koordinatlarında ana haritaya da kuruluyordu.
	"bataklik_fx": false,
	"col_fx": false,
	"kis_fx": false,
	## madde 761: gece ateş böcekleri (ates_bocegi_fx.gd; alanlar ana_harita_bocek_meta.gd ANA HARİTANIN koordinatları). Diğer haritalarda
	## tanımsız = kapalı (Kara Bataklık'ın kendi böcekleri bataklik_fx.gd'de); test haritası "taban"dan açık alır.
	"ates_bocekleri": true,
}

## TEST HARİTASI (madde 731, kullanıcı 2026-11-16: "sadece debugmodda seçilebilen bir test haritası butonu ekle; bu haritada hiçbir yaratık doğmayacak
## fakat debug butonu açık olacak ve oradan istediğimiz yaratığı doğurabileceğiz, bosslar dahil"): ANA HARİTANIN ZEMİNİ (main.tscn'deki Harita, "taban")
## ama yaratık doğuran her sistem kapalı - kendiliğinden doğuş / boss / gece bossu / sonsuz dalga (enemy_spawner.gd is_test_map kapısı), görevler
## (WorldEventManager), açılış evi + kuşatma (HouseInterior), kenar bekçisi kampları (GuardCamps), seyyar satıcı. Seçim: dünya haritası ekranındaki
## "TEST HARİTASI" düğmesi, yalnız debug açılabilen derlemede (test_map_allowed = Godot editörü; exportta düğme yok). Main._enter_tree debug modunu
## açar (DEBUG düğmesi baştan görünür), hiçbir kayıt / Ruh Kıymığı / anahtar / balans satırı yazılmaz (main.gd _record_skip_reason, balance_log.gd).
## Ana menüye dönünce ya da yeni koşuda (GameManager.reset) haritanın açtığı debug kapanır, seçim ana haritaya döner.
const TEST_ID := "test"
## Doğuş: ana haritanın güneybatı çayırı - 560 px yarıçapta yüzde 93 açık zemin (ağaç / su / bina dışı; ölçüm 2026-11-16), büyük bosslar için yer var.
const TEST_SPAWN := Vector2(1352, 3496)
## Test haritasında kapalı olan, ana haritaya özgü sistemler (diğer bayraklar "taban"dan = ana haritadan gelir).
const TEST_FEATURES := {
	"ev_acilisi": false,
	"seyyar_satici": false,
	"gorevler": false,
	"kenar_bekcileri": false,
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
	## TEST HARİTASI (madde 731, yukarıdaki TEST_ID notu): seçilebilir DEĞİL (oylama / harita listesi / tek oyunculu satırları görmez), yalnız debug düğmesiyle.
	## "taban": tanımsız bayrak ve görünüm ana haritanınki (feature() tabana bakar); "onizleme": dünya haritası ekranının resmi ana haritanınki.
	## Kademe bossu yok: enemy_spawner.gd boss_tiers_for_map test haritasında BOŞ döner ("bosslar" tanımsız olsa ana haritanın tablosu gelirdi).
	TEST_ID: {
		"ad": "Test Haritası",
		"aciklama": "Yalnız debug: hiçbir yaratık kendiliğinden doğmaz; DEBUG menüsünden istenen yaratık ya da boss doğar.",
		"tur": KIND_ORMAN,
		"sahne": "",
		"veri": "",
		"secilebilir": false,
		"test_haritasi": true,
		"taban": DEFAULT_ID,
		"onizleme": DEFAULT_ID,
		"dogus": TEST_SPAWN,
		"ozellik": TEST_FEATURES,
	},
	## KARA BATAKLIK (2026-11-09, açık hava; tools/bataklik/gen_bataklik.py + bake_bataklik.gd, oyun alanı 214x214 = ana haritanın %70'i):
	## katmanları Harita.tmx ADLARINDA -> ana haritanın collision / derinlik / ağaç-ot sallanması / saklanma çalılığı / gün-gece / hava
	## sistemleri değişmeden çalışır. Ana haritaya özgü adımlar kapalı: renk ayarının başıboş çimen / köprü altı ayıklaması
	## ("harita_ayiklama"), zemin geçişi ("zemin_gecisi"). Su ana haritanın su shader'ı (madde 714, "su_efekti" + "su_doku": sabit bataklık rengi).
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
		## Batma + sudan pusu (bataklik_tehlike.gd, swamp_hazards()): "ozellik"te DEĞİL (feature() tanımsız bayrağı ana haritada açık sayar).
		"bataklik_tehlike": true,
		"su_maskesi": "res://assets/map/bataklik_su_derinlik.png",
		## Su = ana haritanın su shader'ı (madde 714; kullanıcı: "tüm sular ana haritadaki su shaderını kullanmalı"), renk setin su karosu #24674b, sırt
		## eski bataklık pırıltısı. Dokular: `Godot --headless --path . -s tools/gen_su_dokusu.gd -- bataklik`. Ayak örtüsü (wade_fx) aynı "renk"i çizer.
		## BULANIK SU (2026-11-16, kullanıcı: "biraz daha pis hissetsin ve saydam olsun altındaki toprak görünsün"): "bulanik" sözlüğü varsa
		## su shader'ı dibi (çamur, batık çakıl / dal) kendisi çizer, sabit su rengi üstüne yarı saydam + balçık bulutları + yüzen yosun
		## (shaders/su_bulanik.gdshaderinc; anahtar = uniform adı, boş = shader varsayılanları). Renk eski #24674b -> daha bulanık #2b5641.
		"su_doku": {"mesafe": "res://assets/map/bataklik_su_mesafe.png", "akis": "res://assets/map/bataklik_su_akis.png", "origin": Vector2(560, 336),
			"size": Vector2(3328, 3392), "renk": Color(0.169, 0.337, 0.255), "sirt": Color(0.561, 0.663, 0.522),
			"bulanik": {"bulanik_alfa": 0.55},
			## karolarında setin eski su rengi gömülü katmanlar (kıyı çimeni saçağı altı, nilüfer / mercimek / dalga izi) -> bulanık suya boyanır
			"su_karolari": ["Su/Su ayrıntılar 2", "Su/Su süsleri"]},
		"ozellik": {"orman_gorselleri": true, "hava": true, "calilik": true, "gorevler": true, "bataklik_fx": true, "su_efekti": true},
		## Kademe bossları (madde 682, kullanıcı 2026-11-14: "bu yaratık bataklığın 1. bossu olsun"): K5 Zehirli Gonca (yeni), K10 Banshee.
		"bosslar": {5: ["gonca1"], 10: ["banshee1"]},
	},
	## ALTIN KUMLAR (2026-11-09, çöl, açık hava; tools/col/gen_col.py + bake_col.gd, oyun alanı 243x243 = ana haritanın yüzde 90'ı): Kara
	## Bataklık gibi Harita.tmx katman adlarında (collision / derinlik / sallanma / saklanma / gün-gece sistemleri değişmeden çalışır) + üst üste
	## binen kaya yığınları için "Shader Eklenecek/Kayalar 1..3" (depth_occluders OBJECT_LAYERS, terrain_collision PROP_LAYERS). Vaha suyu
	## yürünmez. "hava_donusum": çölde yağmur yağmaz - hava seçimi Yağmurlu -> Rüzgarlı (atmosphere.gd map_weather). "kum_firtinasi" (madde 718):
	## Sağanak yuvası (%15) KUM FIRTINASI - yağmur / yıldırım yok, açık havada %20'ye kadar yavaşlatır (kum_firtinasi.gd, weather_sandstorm.gd).
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
		"hava_donusum": {2: 1},
		"kum_firtinasi": true,
		"cukur_zemin": "kum", ## Hadime Lanet Çukuru toprak tonları (madde 556; yoksa zindan = "tas", diğerleri çimen)
		## Vaha suyu ana haritanın su shader'ını kullanır (madde 631): kıyı uzaklığı + akış dokuları `-- col` ile pişirilir.
		"su_doku": {"mesafe": "res://assets/map/col_su_mesafe.png", "akis": "res://assets/map/col_su_akis.png", "origin": Vector2(784, 560), "size": Vector2(3456, 3136),
			"renk": Color(0.243, 0.557, 0.588), "sirt": Color(0.62, 0.86, 0.87)}, ## madde 714: eski col_su.gdshader'ın renkleri, shader artık su.gdshader
		"ozellik": {"orman_gorselleri": true, "hava": true, "calilik": true, "gorevler": true, "col_fx": true, "su_efekti": true},
		## Kademe bossları (madde 682, kullanıcı 2026-11-14: "Medusa da çölde final boss olsun"): K5 Yeraltı Canavarı, K10 Medusa (yeni).
		"bosslar": {5: ["underground1"], 10: ["medusa1"]},
	},
	## AYAZ DAĞI (2026-11-12, kış / dağ, açık hava; tools/kis/gen_kis.py + bake_kis.gd, oyun alanı 256x256 = ana haritanın alanı): Altın Kumlar
	## gibi Harita.tmx katman adlarında + "Kayalar 1..3" + yeni zemin katmanları "Yer/Buz" (donmuş göl: YÜRÜNÜR, collision yalnız "Su/Su"yu su
	## sayar) ve "Yer/Patika" (toprak yol). Sıcak kaynağın suyu yürünmez. "kar_yagisi": yağmur yerine kar yağar (atmosphere.gd ->
	## weather_snow.gd, yağmur sesi yok); "hava_donusum": kışta sağanak / şimşek yok (Sağanak -> Yağmurlu = kar). "kis_fx": ateş ışıkları,
	## duman, kaynak buharı ve ileride üşüme / ısınma mekaniğinin okuyacağı ısınma noktaları (kis_fx.gd, "isi_kaynagi" grubu; kis_meta.gd).
	"kis": {
		"ad": "Ayaz Dağı",
		"aciklama": "Karlı çam ormanları, donmuş Ayna Göl ve meşaleli patikalar: Ocak Başı Kampı, Kadim Buz Ağacı, Kristal Vadisi, Ayı Totemi Tapınağı, Yılbaşı Meydanı, Sıcak Kaynak.",
		"tur": KIND_ORMAN,
		"sahne": "res://scenes/kis_baked.tscn",
		"veri": "",
		"secilebilir": true,
		"oyun_alani": KisMeta.PLAY_CELLS,
		"dogus": KisMeta.SPAWN,
		"minimap": "res://assets/ui/minimap_kis.png",
		"hava_donusum": {3: 2},
		"kar_yagisi": true,
		"cukur_zemin": "kar",
		## "soguk": üşüme / ısınma / donma (madde 709, kis_soguk.gd): ateşten 2 dk uzak kalan donmaya başlar; ısı noktaları kis_fx.gd kurar.
		## "ozellik"te DEĞİL: feature() tanımsız bayrağı ana haritada açık sayar -> cold_climate() yalnız bu anahtara bakar.
		"soguk": true,
		## Sıcak kaynağın suyu = ana haritanın su shader'ı (madde 714), ılık turkuaz; buhar kis_fx.gd'de. Donmuş göller ("Yer/Buz") su değil, kis_buz.gdshader.
		"su_doku": {"mesafe": "res://assets/map/kis_su_mesafe.png", "akis": "res://assets/map/kis_su_akis.png", "origin": Vector2(3984, 1872),
			"size": Vector2(336, 272), "renk": Color(0.243, 0.596, 0.627), "sirt": Color(0.659, 0.89, 0.863)},
		"ozellik": {"orman_gorselleri": true, "hava": true, "calilik": true, "gorevler": true, "kis_fx": true, "su_efekti": true},
		## Kademe bossları (madde 682): ana haritanın K10'undan Üç Kardeş'e yer veren Wendigo buraya geldi (kar / buz efsanesi; kullanıcı: "yeri değiştiren
		## bossları boşta kalan haritalardan birine gönderirsin"). K5 için boşta boss yok: şimdilik ana haritayla ortak Minotaur.
		"bosslar": {5: ["minotaur1"], 10: ["wendigo1"]},
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
		"ozellik": {"zindan_etkilesim": true, "gorevler": true, "zemin_tasi": true, "su_efekti": true}, ## zemin_tasi: dungeon_floor.gd zemin shader'ı (madde 449)
		## Sarnıç suyu = ana haritanın su shader'ı (madde 714; dungeon_manager.gd bağlar), renk setin dalga karosu #386668; kıyı "Su ayrıntı" katmanları.
		"su_doku": {"mesafe": "res://assets/map/batik_nekropol_su_mesafe.png", "akis": "res://assets/map/batik_nekropol_su_akis.png", "origin": Vector2(1216, 160),
			"size": Vector2(2128, 2096), "katman": "Su", "ayrinti": ["Su ayrıntı", "Su ayrıntı 2"],
			"renk": Color(0.22, 0.4, 0.408), "sirt": Color(0.45, 0.66, 0.64)},
		## Kademe bossları (madde 682): Bataklık / Çöl'den yeri değişen iki boss buraya geldi (kullanıcı: "yeri değiştiren bossları boşta kalan
		## haritalardan birine gönderirsin") - mezarlık + kabak + şeytan; K5 Balkabağı Kafa, K10 Uçan Şeytan.
		"bosslar": {5: ["balkabagi1"], 10: ["ucansetan1"]},
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
		"secilebilir": false, ## madde 554: kullanıcı isteğiyle oyundan kaldırıldı (dosyalar + mekanik testleri duruyor, true geri açar)
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
		"secilebilir": false, ## madde 626: kullanıcı isteğiyle GEÇİCİ kapatıldı (dosyalar + mekanik testleri duruyor, true geri açar)
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


## Seçili haritada yağış kar mı (Ayaz Dağı): atmosphere.gd yağmur yerine weather_snow.gd çizer, yağmur sesi çalmaz.
static func snowfall() -> bool:
	return bool(current().get("kar_yagisi", false))


## Seçili haritada Sağanak yerine kum fırtınası mı (Altın Kumlar, madde 718): atmosphere.gd sand_intensity + weather_sandstorm.gd + yavaşlama.
static func sandstorm() -> bool:
	return bool(current().get("kum_firtinasi", false))


## Seçili haritada üşüme / ısınma / donma var mı (Ayaz Dağı, madde 709): main.gd kis_soguk.gd'yi kurar. Tanımsız = yok (ana harita dahil).
static func cold_climate() -> bool:
	return bool(current().get("soguk", false))


## Seçili haritada bataklık tehlikeleri (batma + sudan pusu, bataklik_tehlike.gd) var mı. Tanımsız = yok (ana harita dahil).
static func swamp_hazards() -> bool:
	return bool(current().get("bataklik_tehlike", false))


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
	var env: String = GuardScript.dev_env("HARITA")
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


## Seçili harita TEST HARİTASI mı (madde 731): yaratık doğuran sistemler kapalı, kayıt yazılmaz, debug açık.
static func is_test_map() -> bool:
	return bool(current().get("test_haritasi", false))


static func is_test_map_id(id: String) -> bool:
	return bool(get_profile(id).get("test_haritasi", false)) if PROFILES.has(id) else false


## TEST HARİTASI düğmesi bu derlemede gösterilir mi: yalnız tam debug modunun açılabildiği derleme (Godot editörü, security_guard.gd dev_allowed;
## dışarı verilen exe'de debug menüsü hiç açılamadığı için düğme de yok - madde 613 hile koruması).
static func test_map_allowed() -> bool:
	return GuardScript.dev_allowed()


## Dünya haritası ekranında gösterilecek önizleme kimliği (test haritası ana haritanın resmini kullanır).
static func preview_id(id: String) -> String:
	return str(get_profile(id).get("onizleme", id))


## Haritaya özgü sistem bu haritada açık mı (tanımsız bayrak: ana haritada açık, diğerlerinde kapalı). Kara Bataklık da açık hava
## ("orman" türü) ama ana haritanın ev / satıcı / maden / bekçi sistemleri orada yok: varsayılan TÜRE değil ana harita kimliğine bakar.
## "taban"lı profil (test haritası): kendi "ozellik"inde olmayan bayrak tabanın kuralıyla çözülür (ana harita zemini = ana haritanın görselleri).
static func feature(name: String) -> bool:
	## Oyun modu ezmesi (PvPvE, madde 607: PvP'de açılış evi kapalı) - mod bayrağı haritanınkinden önce.
	var mode_override: Variant = GameModeScript.feature_override(name)
	if mode_override != null:
		return bool(mode_override)
	return profile_feature(current_id(), name)


static func profile_feature(id: String, name: String, depth: int = 0) -> bool:
	if not PROFILES.has(id):
		id = DEFAULT_ID
	var p: Dictionary = PROFILES[id]
	var f: Dictionary = p.get("ozellik", {})
	if f.has(name):
		return bool(f[name])
	var base: String = str(p.get("taban", ""))
	if base != "" and base != id and PROFILES.has(base) and depth < 4:
		return profile_feature(base, name, depth + 1)
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
		## Ana harita sahnesi aynı kalır; yalnız oyun modunun kapattığı sistemler (PvP: açılış evi, madde 607) çıkarılır. Co-op'ta ana haritada
		## bütün bayraklar açık -> hiçbir şey silinmez (eski davranış).
		_remove_disabled_feature_nodes(main)
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
	_remove_disabled_feature_nodes(main)
	return true


static func _remove_disabled_feature_nodes(main: Node) -> void:
	for f: String in FEATURE_NODES:
		if not feature(f):
			var n: Node = main.get_node_or_null(str(FEATURE_NODES[f]))
			if n != null:
				main.remove_child(n)
				n.free()


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
