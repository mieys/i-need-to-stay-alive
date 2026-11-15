extends SceneTree

## Ruh Mağazası karakter ayrıntısı prototiplerini (ruh_kar_ekran.gd) gerçek çizicide yakalar. Gizli masaüstünde: ruh_kar_run.ps1
## Sahte bakiye + açılmış öğeler geçici kayıtta (user://meta.cfg'ye DOKUNMAZ). Çıktı: $RK_DIR/<ad>.png (1920x1080 tam ekran).

var _dir: String = OS.get_environment("RK_DIR")
var _only: String = OS.get_environment("RK_ONLY")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await _wait(0.7)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(name + ".png"))
	print("SHOT ", name)


func _char_item(shop: Node, key: int) -> Dictionary:
	for it: Dictionary in shop.call("_items"):
		if str(it["kind"]) == "char" and int(it["key"]) == key:
			return it
	return {}


func _show(shop: Node, variant: String, key: int, sk: int, page: String = "genel") -> bool:
	var it: Dictionary = _char_item(shop, key)
	if it.is_empty():
		print("!! karakter yok: ", key)
		return false
	shop.set("variant", variant)
	shop.call("_select", it)
	shop.set("sk_sel", sk)
	shop.set("dpage", page)
	shop.call("_rebuild_list", true)
	return true


func _want(name: String) -> bool:
	return _only == "" or name in _only.split(",")


func _run() -> void:
	await process_frame
	var MP: GDScript = load("res://scripts/meta_progress.gd")
	var tmp: String = _dir.path_join("_meta_rk.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 340)
	cfg.set_value("meta", "total_earned", 1900)
	cfg.set_value("meta", "starter_granted", true)
	cfg.set_value("unlocked", "char", [3])
	cfg.set_value("unlocked", "weapon", [])
	cfg.set_value("unlocked", "pet", [])
	cfg.set_value("unlocked", "spirit", [])
	cfg.save(tmp)
	MP.set_path_override(tmp)
	var shop: CanvasLayer = (load("res://tools/proto_20261112/ruh_karakter/ruh_kar_ekran.gd") as GDScript).new()
	root.add_child(shop)
	await _wait(0.6)
	## [ad, varyant, karakter, seçili yetenek (0 P, 1 Q, 2 E, 3 R), C sayfası]
	var shots: Array = [
		["now_vampir", "now", 13, 0, "genel"],
		["a_vampir", "a", 13, 2, "genel"],
		["b_vampir", "b", 13, 2, "genel"],
		["c_vampir_genel", "c", 13, 0, "genel"],
		["c_vampir_yetenek", "c", 13, 0, "yetenek"],
		["d_vampir", "d", 13, 2, "genel"],
		## en uzun metinler (yalnız denetim): Cadı R 552 harf, Oakley pasif 478 / R 503
		["a_cadi_r", "a", 15, 3, "genel"],
		["b_cadi_r", "b", 15, 3, "genel"],
		["a_oakley_p", "a", 2, 0, "genel"],
		["d_oakley_r", "d", 2, 3, "genel"],
	]
	for s: Array in shots:
		if not _want(str(s[0])):
			continue
		if not _show(shop, str(s[1]), int(s[2]), int(s[3]), str(s[4])):
			continue
		if str(s[1]) == "d":
			await _wait(0.3)
			for b: Node in shop.find_children("*", "Button", true, false):
				if b.has_meta("sid") and str(b.get_meta("sid")) == "tip:%d" % int(s[3]):
					(b as Button).mouse_entered.emit()
		await _shot(str(s[0]))
	DirAccess.remove_absolute(tmp)
	quit()
