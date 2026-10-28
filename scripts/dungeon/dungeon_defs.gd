extends RefCounted

## ZİNDANLAR (madde 373) - tek kaynak tanımlar. Haritalar tools/zindan/gen_*.py ile üretilir (harita/zindan/<id>.tmx, Tiled'da düzenlenebilir),
## tools/zindan/bake_zindan.gd ile pişirilir (scenes/zindan/<id>_baked.tscn + _data.tres).
## Zindanlar ana haritanın DOĞUSUNDA, aynı dünya koordinatlarında durur (orman katmanının hücre ızgarasında `origin` sol üst hücre): böylece duvarlar
## hareket/görüş/yaratık yol bulma ızgarasına aynen girer (scripts/dungeon/dungeon_world.gd). Kamera sınırı zindanın dikdörtgeni (camera_map_limits.gd).
## gate = DeepForestPlaces.GATES dizini (derin orman bölgesindeki mühürlü kapı, madde 361).

const DUNGEONS: Array[Dictionary] = [
	{
		"id": "kemik_mahzeni", "title": "Kemik Mahzeni", "gate": 0, "origin": Vector2i(296, -12),
		"resource": "ruh_kozu",
		"ambient_night": Color(0.30, 0.34, 0.40), "ambient_day": Color(0.36, 0.40, 0.46), ## ortam (CanvasModulate): soğuk mavi-gri, ruh alevi camgöbeği
		"player_light": Color(0.78, 0.92, 1.0),
		"lore": "Ölüler burada uyumaz, bekler. Ruh kandillerinin közünü topla - ama kandil sönünce karanlık gelir.",
		## yaratık profilleri (TMX "sakin" nesnelerinin profil özelliği): kademeye göre seçilen türler
		"profiles": {
			"lahit": ["iskelet1", "iskelet2", "rontgen1", "iskelet3"],
			"kemik": ["iskelet1", "iskelet2", "zombie1", "rontgen1"],
			"sutun": ["hayalet1", "hayalet2", "iskelet2"],
			"kalp": ["lich1", "lich2", "rontgen2", "iskelet3"],
			"oda": ["iskelet1", "zombie1", "zombie2", "hayalet1"],
		},
		"hunter": {"id": "rontgen3", "name": "Mahzen Bekçisi"},
	},
	{
		"id": "et_kuyusu", "title": "Et Kuyusu", "gate": 1, "origin": Vector2i(296, 94),
		"resource": "kan_kehribari",
		"ambient_night": Color(0.42, 0.28, 0.28), "ambient_day": Color(0.48, 0.33, 0.32),
		"player_light": Color(1.0, 0.82, 0.70),
		"lore": "Kuyunun dibinde bir simyacı hâlâ çalışıyor. Et keselerindeki kehribarı ona götür.",
		"profiles": {
			"kanal": ["slime1", "slime2", "zombie1", "zombie2"],
			"hucre": ["zombie1", "zombie2", "zombie3", "iblis1"],
			"bahce": ["bitki1", "bitki2", "slime3", "mantar1"],
			"lab": ["slime4", "slime5", "iblis1", "iblis2"],
			"kalp": ["zombie3", "iblis2", "demon1", "slime6"],
			"oda": ["slime1", "zombie1", "rat2", "rat3"],
		},
		"hunter": {"id": "zombie3", "name": "Kuyu Kasabı"},
	},
	{
		"id": "boynuzlu_kapi", "title": "Boynuzlu Kapı", "gate": 2, "origin": Vector2i(296, 210),
		"resource": "isik_kristali",
		"ambient_night": Color(0.26, 0.30, 0.44), "ambient_day": Color(0.32, 0.36, 0.50),
		"player_light": Color(0.80, 0.90, 1.0),
		"lore": "Kristaller ışığı yutar, boynuzlu bekçi gölgeleri. Kristali kır, ışığı al, yolunu kaybetme.",
		"profiles": {
			"magara": ["mantar1", "mantar2", "golem1", "slime3"],
			"kristal": ["golem1", "golem2", "hayalet2"],
			"salon": ["ork1", "ork2", "iskelet2", "lich1"],
			"lav": ["demon1", "demon2", "iblis2", "golem2"],
			"kalp": ["golem2", "demon2", "ork3", "golem3"],
			"oda": ["mantar1", "ork1", "rat3", "slime2"],
		},
		"hunter": {"id": "golem3", "name": "Boynuzlu Bekçi"},
	},
]

## Zindan kaynakları: KİŞİSEL koşu sayacı (GameManager.dungeon_resources), zindanın kendi sunağında / simyacısında harcanır.
const RESOURCES: Dictionary = {
	"ruh_kozu": {"name": "Ruh Közü", "color": Color(0.55, 1.0, 0.95)},
	"kan_kehribari": {"name": "Kan Kehribarı", "color": Color(1.0, 0.55, 0.3)},
	"isik_kristali": {"name": "Işık Kristali", "color": Color(0.7, 0.75, 1.0)},
}

const DATA_PATH := "res://scenes/zindan/%s_data.tres"
const SCENE_PATH := "res://scenes/zindan/%s_baked.tscn"


static func by_id(id: String) -> Dictionary:
	for d: Dictionary in DUNGEONS:
		if str(d["id"]) == id:
			return d
	return {}


static func index_of(id: String) -> int:
	for i in range(DUNGEONS.size()):
		if str(DUNGEONS[i]["id"]) == id:
			return i
	return -1
