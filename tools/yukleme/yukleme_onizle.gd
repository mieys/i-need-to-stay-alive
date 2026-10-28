extends SceneTree

## YÜKLEME EKRANI görsel doğrulama (madde 370): gerçek loading_screen.tscn yükleyicisiz kurulur, ilerleme elle sürülür, kareler
## tools/yukleme/cekim/onizle_<ad>.png'ye (1920x1080) yazılır: %10 / %55 / %95 + varış (_arrive) sırasında 3 an.
## Gizli masaüstünde: tools/yukleme/yukleme_capture.ps1 -Onizle

var _out: String = ProjectSettings.globalize_path("res://").path_join("tools/yukleme/cekim")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out.path_join("onizle_%s.png" % name))


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var s: Control = (load("res://scenes/loading_screen.tscn") as PackedScene).instantiate()
	s.set("autostart_loader", false)
	root.add_child(s)
	current_scene = s
	s.set_process(false)
	var bar: Range = s.get("progress_bar")
	for step: Array in [[10.0, "10"], [55.0, "55"], [95.0, "95"]]:
		for _k in range(45):
			bar.value = step[0]
			s.call("_animate_chasers", 1.0 / 60.0)
			s.call("_layout_chase", bar.value / 100.0)
			s.call("_update_gate_glow", bar.value / 97.0)
			await process_frame
		await _shot(step[1])
	s.set("_proceeded", true)
	var arrive_t0: int = Time.get_ticks_msec()
	s.call("_arrive")
	var marks: Array = [[300, "varis_kosu"], [480, "varis_parlama"], [900, "varis_karanlik"]]
	for m: Array in marks:
		while Time.get_ticks_msec() - arrive_t0 < int(m[0]):
			s.call("_animate_chasers", 1.0 / 60.0)
			s.call("_layout_chase", bar.value / 100.0)
			await process_frame
		await _shot(m[1])
	print("ONIZLE tamam")
	quit()
