extends SceneTree

## Ruh Mağazası KOMPLE tasarım prototiplerini (ruh_komple_ekran.gd, madde 382) gerçek çizicide yakalar: her tasarımın karakter / silah (D: ayrıntı
## penceresi) / geliştirme ekranı.
## Sahte bakiye + açılmış öğeler + geliştirme seviyeleri soul_shop_real_capture.gd ile AYNI (karşılaştırılabilir), geçici kayıt (user://meta.cfg'ye DOKUNMAZ).
## Kullanım: tools/proto_20261024/ruh_komple/ruh_komple_run.ps1 [-Only "a,b"]   (RUH_KOMPLE_DIR = çıktı klasörü, RUH_KOMPLE_ONLY = süzgeç)

const FAKE_LV := {"pickup": 3, "attack": 5, "atk_speed": 2, "health": 4, "lifesteal": 1, "speed": 2, "shield_regen": 1,
		"crit_chance": 3, "luck": 2, "cooldown": 1, "free_reroll": 1}
## [ad, tasarım, sayfa, ayarlar]
const SHOTS := [["a_kar", "a", "char", {}], ["a_silah", "a", "weapon", {}], ["a_gel", "a", "upgrades", {"_sel_upg": "attack"}],
		["b_kar", "b", "char", {}], ["b_silah", "b", "weapon", {}], ["b_gel", "b", "upgrades", {"_sel_upg": "attack"}],
		["c_kar", "c", "char", {}], ["c_silah", "c", "weapon", {}], ["c_gel", "c", "upgrades", {"_sel_upg": "attack"}],
		["d_kar", "d", "char", {}], ["d_detay", "d", "char", {"modal_open": true}], ["d_gel", "d", "upgrades", {"_sel_upg": "attack"}]]
const SCREEN := "res://tools/proto_20261024/ruh_komple/ruh_komple_ekran.gd"

var _dir: String = OS.get_environment("RUH_KOMPLE_DIR")
var _only: String = OS.get_environment("RUH_KOMPLE_ONLY")


func _initialize() -> void:
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261024/ruh_komple/out")
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join("ruh_komple_" + name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	await process_frame
	var MP: GDScript = load("res://scripts/meta_progress.gd")
	var MU: GDScript = load("res://scripts/meta_upgrades.gd")
	MP.set_debug_open(false)
	MP.set_unlock_all(false)
	var tmp: String = _dir.path_join("_meta_komple.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 340)
	cfg.set_value("meta", "total_earned", 1900)
	cfg.set_value("meta", "starter_granted", true)
	cfg.set_value("unlocked", "char", [3])
	cfg.set_value("unlocked", "weapon", ["pence", "boomerang"])
	cfg.set_value("unlocked", "pet", ["papagan"])
	cfg.set_value("unlocked", "spirit", [])
	for id: String in FAKE_LV:
		var lv: int = int(FAKE_LV[id])
		var d: Dictionary = MU.def(id)
		var spent: int = 0
		for k in lv:
			spent += int(d["first"]) + int(d["step"]) * k
		cfg.set_value("upgrades", id, lv)
		cfg.set_value("upgrade_spent", id, spent)
	cfg.save(tmp)
	MP.set_path_override(tmp)
	var only: PackedStringArray = _only.split(",", false)
	for s: Array in SHOTS:
		if not only.is_empty() and not only.has(str(s[0])):
			continue
		var shop: CanvasLayer = (load(SCREEN) as GDScript).new()
		shop.set("variant", str(s[1]))
		shop.set("_page", str(s[2]))
		var extra: Dictionary = s[3]
		for k: String in extra:
			shop.set(k, extra[k])
		root.add_child(shop)
		await _shot(str(s[0]))
		shop.queue_free()
		await process_frame
		await process_frame
	DirAccess.remove_absolute(tmp)
	quit()
