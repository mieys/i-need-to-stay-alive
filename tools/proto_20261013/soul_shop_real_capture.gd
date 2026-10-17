extends SceneTree

## Gerçek soul_shop_screen.gd'nin 4 yerleşimini + GELİŞTİRMELER sekmesini gerçek çizicide yakalar (sahte bakiye, geçici kayıt).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261013/soul_shop_real_capture.gd   (SHOP_CAP_DIR)

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
	var tmp: String = _dir.path_join("_meta_real.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 340)
	cfg.set_value("meta", "total_earned", 900)
	cfg.set_value("unlocked", "char", [3])
	cfg.set_value("unlocked", "weapon", ["pence", "boomerang"])
	cfg.set_value("unlocked", "pet", ["papagan"])
	cfg.set_value("unlocked", "spirit", [])
	cfg.save(tmp)
	MP.set_path_override(tmp)
	var had_ui_cfg: bool = FileAccess.file_exists("user://soul_shop_ui.cfg")
	var shop: CanvasLayer = (load("res://scripts/soul_shop_screen.gd") as GDScript).new()
	root.add_child(shop)
	await _wait(0.5)
	for l: String in ["a", "b", "c", "d"]:
		shop.call("_on_layout_pressed", l)
		await _shot("gercek_" + l)
	## D'de bir kartı seç (alınamayan): hedef kartı seçilene dönmeli
	var items: Array = shop.call("_items")
	for it: Dictionary in items:
		if str(it["kind"]) == "char" and int(it["key"]) == 10:
			shop.call("_select", it)
	await _shot("gercek_d_secili")
	shop.call("_on_layout_pressed", "a")
	shop.call("_set_cat", "pet")
	await _shot("gercek_a_evcil")
	shop.call("_on_tab_pressed", "upgrades")
	await _shot("gercek_gelistirme")
	DirAccess.remove_absolute(tmp)
	if not had_ui_cfg:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://soul_shop_ui.cfg"))
	quit()
