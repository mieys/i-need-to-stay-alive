extends SceneTree
## PvPvE takım kampı gerçek çizici görüntüsü (madde 607). Gizli masaüstünde tools/pvp/kamp_goruntu.ps1 koşar (MOD=pvp, HARITA, CAP_OUT).
## Main'i açar, üsler kurulunca oyuncunun kendi kampında (başlangıç yeri) ve rakip kampta birer 960x540 PNG alır.

const BaseZonesScript := preload("res://scripts/pvp/base_zones.gd")

var _out: String = OS.get_environment("CAP_OUT")
var _tag: String = OS.get_environment("HARITA") if OS.get_environment("HARITA") != "" else "ana"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_texture().get_image()
	img.resize(960, 540, Image.INTERPOLATE_NEAREST)
	img.save_png(_out.path_join("kamp_%s_%s.png" % [_tag, name]))
	print("CAP ", name)


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	var gm: Node = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	gm.call("reset")
	gm.set("selected_char_id", 1)
	gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(1).get("skill", 1))
	gm.set("selected_start_weapon", "sword")
	gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
	await _wait(6.0)
	if BaseZonesScript.active.size() < 2:
		print("CAP HATA üs yok")
		quit(1)
		return
	await _shot("kendi")
	var p: Node2D = main.get_node_or_null("Player") as Node2D
	if p != null:
		p.global_position = BaseZonesScript.center_of(1) + Vector2(0, 150)
		p.reset_physics_interpolation()
		await _wait(1.5)
		await _shot("rakip")
	quit(0)
