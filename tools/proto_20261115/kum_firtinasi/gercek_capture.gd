extends SceneTree

## KUM FIRTINASI oyun içi doğrulama (madde 718): prototip katmanı YOK - gerçek atmosphere.gd / weather_sandstorm.gd yolu. Altın Kumlar'da
## (HARITA=col) Sağanak zorlanır, şiddet tam oturunca kare + oyuncu hızı / rozet / yağmur-yıldırım durumu yazılır.
## Kullanım: tools/proto_20261115/kum_firtinasi/run.ps1 -Script gercek_capture.gd

var _dir: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _run() -> void:
	await process_frame
	_dir = OS.get_environment("KUM_DIR")
	AudioServer.set_bus_mute(0, true)
	root.get_node("NetworkManager").call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	var gm: Node = root.get_node("GameManager")
	gm.call("reset")
	gm.set("selected_char_id", 2)
	gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", 2).get("skill", 1))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	var sp: Node = current_scene.get_node_or_null("EnemySpawner")
	if sp:
		sp.set_process(false)
		sp.set_physics_process(false)
	await _wait(3.0)
	var main: Node = current_scene
	var player: Node2D = main.get_node_or_null("Player") as Node2D
	var atm: Node = get_first_node_in_group(&"atmosphere")
	var full: float = float(player.call("get_effective_move_speed"))
	var order: Array = []
	for c: Node in main.get_children():
		if c is CanvasLayer:
			order.append("%s(%d)" % [c.name, (c as CanvasLayer).layer])
	print("KATMAN SIRASI ", order)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join("gercek_once.png"))
	atm.call("debug_set_weather", 3)
	await _wait(11.0) ## WEATHER_FADE_TIME 9 sn
	var kinds: Array = []
	for s: Dictionary in player.call("get_status_effects"):
		kinds.append(s["kind"])
	print("SONUC sand=", atm.get("sand_intensity"), " rain=", atm.get("rain_intensity"), " storm=", atm.get("storm_intensity"),
			" hiz_orani=", float(player.call("get_effective_move_speed")) / full, " rozetler=", kinds, " hava=", atm.call("debug_describe"))
	for i in 3:
		await _wait(0.12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_dir.path_join("gercek_firtina_%d.png" % i))
	var sl: Node = main.get_node_or_null("KumFirtinasi")
	if sl:
		var m: ShaderMaterial = (sl.get_node("Kum") as ColorRect).material as ShaderMaterial
		print("SONUC aci=", atm.get("wind_angle"), " slope=", m.get_shader_parameter("slope"), " sign=", m.get_shader_parameter("wind_sign"),
				" amount=", m.get_shader_parameter("amount"), " wpp=", m.get_shader_parameter("world_per_px"), " t=", m.get_shader_parameter("t"))
	print("SHOT gercek")
	quit(0)
