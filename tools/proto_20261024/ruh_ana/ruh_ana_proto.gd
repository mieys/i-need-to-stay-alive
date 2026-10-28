extends SceneTree

## Ruh Mağazası ANA EKRAN prototiplerini (ruh_ana_ekran.gd) gerçek çizicide yakalar: bugünkü ana sayfa + A/B/C/D (+ C'nin ikinci odağı).
## Sahte bakiye + açılmış öğeler + geliştirme seviyeleri soul_shop_real_capture.gd ile AYNI (karşılaştırılabilir), geçici kayıt (user://meta.cfg'ye DOKUNMAZ).
## Kullanım: tools/proto_20261024/ruh_ana/ruh_ana_run.ps1 [-Only "a,b"]   (RUH_ANA_DIR = çıktı klasörü, RUH_ANA_ONLY = süzgeç)

const FAKE_LV := {"pickup": 3, "attack": 5, "atk_speed": 2, "health": 4, "lifesteal": 1, "speed": 2, "shield_regen": 1,
		"crit_chance": 3, "luck": 2, "cooldown": 1, "free_reroll": 1}
const SHOTS := [["su_an", "", ""], ["a", "a", ""], ["b", "b", ""], ["c_kar", "c", "char"], ["c_silah", "c", "weapon"], ["d", "d", ""]]
const SCREEN := "res://tools/proto_20261024/ruh_ana/ruh_ana_ekran.gd"

var _dir: String = OS.get_environment("RUH_ANA_DIR")
var _only: String = OS.get_environment("RUH_ANA_ONLY")


func _initialize() -> void:
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261024/ruh_ana/out")
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await _wait(0.8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join("ruh_ana_" + name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	await process_frame
	var MP: GDScript = load("res://scripts/meta_progress.gd")
	var MU: GDScript = load("res://scripts/meta_upgrades.gd")
	MP.set_debug_open(false)
	MP.set_unlock_all(false)
	var tmp: String = _dir.path_join("_meta_proto.cfg")
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
		if str(s[2]) != "":
			shop.set("focus_kind", str(s[2]))
		root.add_child(shop)
		await _shot(str(s[0]))
		shop.queue_free()
		await process_frame
		await process_frame
	DirAccess.remove_absolute(tmp)
	quit()
