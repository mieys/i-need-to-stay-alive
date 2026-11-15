extends SceneTree

## HARİTA ANAHTARI görsel kontrolü (madde 605): Ruh Mağazası'nın anahtarlı karakter / evcil ayrıntısı + ANAHTARLAR sayfası + bildirim levhası,
## gerçek çizicide, geçici kayıt (user://meta.cfg'ye DOKUNMAZ). Kullanım: tools/anahtar_gorsel/anahtar_run.ps1  (ANAHTAR_DIR = çıktı klasörü)

const SHOTS := [["char", "char", {"_sel": {"char": 15}}], ["pet", "pet", {"_sel": {"pet": "peri"}}], ["keys", "keys", {"_sel_key": "bataklik"}],
		["char_can", "char", {"_sel": {"char": 12}}]]
const SHOP := "res://scripts/soul_shop_screen.gd"

var _dir: String = OS.get_environment("ANAHTAR_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await _wait(0.9)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join("anahtar_" + name + ".png"))
	print("SHOT ", name)


func _run() -> void:
	await process_frame
	var MP: GDScript = load("res://scripts/meta_progress.gd")
	MP.set_debug_open(false)
	MP.set_unlock_all(false)
	var tmp: String = _dir.path_join("_meta_anahtar.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 1000)
	cfg.set_value("meta", "total_earned", 1900)
	cfg.set_value("meta", "starter_granted", true)
	cfg.set_value("unlocked", "char", [3])
	cfg.set_value("unlocked", "weapon", [])
	cfg.set_value("unlocked", "pet", ["papagan"])
	cfg.set_value("unlocked", "spirit", [])
	cfg.set_value("keys", "bataklik", 1)
	cfg.set_value("keys", "ana", 3)
	cfg.save(tmp)
	MP.set_path_override(tmp)
	for s: Array in SHOTS:
		var shop: CanvasLayer = (load(SHOP) as GDScript).new()
		shop.set("_page", str(s[1]))
		var extra: Dictionary = s[2]
		for k: String in extra:
			shop.set(k, extra[k])
		root.add_child(shop)
		await _shot(str(s[0]))
		shop.queue_free()
		await process_frame
		await process_frame
	## bildirim levhası (anahtarın kendi simgesiyle)
	var layer := CanvasLayer.new()
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.2, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var GN: GDScript = load("res://scripts/game_notice.gd")
	var KI: GDScript = load("res://scripts/key_icon.gd")
	var y: float = 80.0
	for id: String in ["bataklik", "ana", "col", "batik_nekropol", "lagim_agi"]:
		var n: Control = GN.call("toast", "key", "+2 %s" % KI.call("display_name", id), "", 30.0, false)
		n.set("icon_tex", KI.call("texture", id))
		n.position = Vector2(1400, y)
		layer.add_child(n)
		y += 90.0
	root.add_child(layer)
	await _shot("notice")
	DirAccess.remove_absolute(tmp)
	quit()
