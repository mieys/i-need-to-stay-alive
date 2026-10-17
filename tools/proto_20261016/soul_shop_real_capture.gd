extends SceneTree

## GERÇEK soul_shop_screen.gd (tasarım F, 2026-10-16) sayfalarını gerçek çizicide yakalar: ana sayfa, 4 kategori, onay adımı, geliştirmeler.
## Sahte bakiye + sahte açılmış öğeler + sahte geliştirme seviyeleri, geçici kayıt (user://meta.cfg'ye DOKUNMAZ).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261016/soul_shop_real_capture.gd   (SHOP_CAP_DIR = çıktı klasörü)

const FAKE_LV := {"pickup": 3, "attack": 5, "atk_speed": 2, "health": 4, "lifesteal": 1, "speed": 2, "shield_regen": 1,
		"crit_chance": 3, "luck": 2, "cooldown": 1, "free_reroll": 1}

var _dir: String = OS.get_environment("SHOP_CAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await _wait(0.6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	await process_frame
	var MP: GDScript = load("res://scripts/meta_progress.gd")
	var MU: GDScript = load("res://scripts/meta_upgrades.gd")
	var tmp: String = _dir.path_join("_meta_real.cfg")
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
	var shop: CanvasLayer = (load("res://scripts/soul_shop_screen.gd") as GDScript).new()
	root.add_child(shop)
	await _wait(0.5)
	await _shot("gercek_f_ana")
	for kind: String in ["char", "weapon", "pet", "spirit"]:
		shop.call("_on_tab_pressed", kind)
		await _shot("gercek_f_" + kind)
	shop.call("_on_tab_pressed", "char")
	var items: Array = shop.call("_items")
	for it: Dictionary in items:
		if str(it["kind"]) == "char" and int(it["key"]) == 5:
			shop.call("_on_buy_pressed", "char", it["key"]) ## ilk basış: ONAYLA?
	await _shot("gercek_f_char_onay")
	shop.call("_step_selection", "char", 3) ## kilitli bir karaktere geç (eksik kıymık görünümü)
	await _shot("gercek_f_char_kilitli")
	shop.call("_on_tab_pressed", "upgrades")
	await _shot("gercek_f_gelistirme")
	DirAccess.remove_absolute(tmp)
	quit()
