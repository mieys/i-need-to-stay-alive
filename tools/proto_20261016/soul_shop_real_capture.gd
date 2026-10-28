extends SceneTree

## GERÇEK soul_shop_screen.gd sayfalarını gerçek çizicide yakalar (2026-10-24'ten beri tasarım C "Ocak Başı Defteri", madde 383; ana sayfa yok):
## 4 bölüm, onay adımı, kilitli öğe, geliştirmeler (+ sıfırlama onayı). Çıktı adı: gercek_c_<sayfa>.png. Gizli masaüstünde: tools/proto_20261024/ruh_c_gercek_run.ps1
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
	await _shot("gercek_c_char")
	for kind: String in ["weapon", "pet", "spirit"]:
		shop.call("_on_tab_pressed", kind)
		await _shot("gercek_c_" + kind)
	shop.call("_on_tab_pressed", "char")
	var items: Array = shop.call("_items")
	for it: Dictionary in items:
		if str(it["kind"]) == "char" and int(it["key"]) == 5:
			shop.call("_on_buy_pressed", "char", it["key"]) ## ilk basış: ONAYLA?
	await _shot("gercek_c_char_onay")
	for it: Dictionary in items:
		if str(it["kind"]) == "char" and not bool(it["can"]) and not bool(it["open"]):
			shop.call("_select", it) ## kilitli (kıymık yetmeyen) bir karakter
			break
	await _shot("gercek_c_char_kilitli")
	shop.call("_on_tab_pressed", "upgrades")
	await _shot("gercek_c_gelistirme")
	shop.call("_on_reset_pressed") ## ilk basış: sıfırlama onayı
	await _shot("gercek_c_gelistirme_sifirla")
	DirAccess.remove_absolute(tmp)
	quit()
