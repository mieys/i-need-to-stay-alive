extends SceneTree

## Madde 740 doğrulama yakalaması: oyundaki Şovalye Q efekti (fx_sovalye_taunt.tscn, "A Kalkan Darbesi") GERÇEK ÇİZİCİDE, uzak
## oyuncu kuklasında (diğer oyuncuların gördüğü yol: sahne + props, network_manager "skill_scene" ile aynı), kamera zoom 2.
## İki tur: "temel" (taunt=false) ve "mo" (Meydan Okuma, taunt=true). SQ_DIR/<tur>/t_<ms>.png - TIMES anlarında.
## Kullanım: yakala.ps1 (gizli masaüstü, --fixed-fps 30).

const TIMES := [0.1, 0.25, 0.45, 0.6, 1.05, 1.3, 2.6, 5.75]
const CROP := Vector2i(600, 330)

var _dir: String = OS.get_environment("SQ_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	for tur: String in ["temel", "mo"]:
		await _run_case(tur)
	print("BITTI")
	quit()


func _run_case(tur: String) -> void:
	DirAccess.make_dir_recursive_absolute(_dir.path_join(tur))
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(122, 173, 85)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var c := Vector2(3000, 3000)
	var k: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(k)
	k.setup(81, 7, "Şovalye")
	k.global_position = c
	k.set("_target_position", c)
	var sv: Node2D = k.get_node_or_null("ShieldVisual")
	if sv != null:
		sv.visible = false
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = c + Vector2(0, -6)
	cam.make_current()
	for i in range(12):
		await process_frame
	var fx: Node = (load("res://scenes/fx_sovalye_taunt.tscn") as PackedScene).instantiate()
	fx.set("duration", 6.0)
	fx.set("taunt", tur == "mo")
	k.add_child(fx)
	var idx := 0
	var frame := 0
	while idx < TIMES.size():
		await RenderingServer.frame_post_draw
		var t: float = frame / 30.0
		frame += 1
		if t + 0.001 < float(TIMES[idx]):
			continue
		var img: Image = root.get_texture().get_image()
		var ctr := Vector2i(img.get_width() / 2, img.get_height() / 2)
		var rect := Rect2i(ctr - CROP / 2, CROP).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(rect).save_png(_dir.path_join(tur).path_join("t_%04d.png" % int(round(float(TIMES[idx]) * 1000))))
		idx += 1
	print("TUR %s tamam" % tur)
	scene.queue_free()
	for i in range(4):
		await process_frame
