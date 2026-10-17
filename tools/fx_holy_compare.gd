extends SceneTree

## Madde 215: Melek R (Kutsal Korku) YENİ (pişirilmiş + halka shader) ile ÖZGÜN (tools/fx_bake_src) yan yana. Sol yeni, sağ özgün.
## Godot --path . --windowed --resolution 1280x720 --fixed-fps 60 -s tools/fx_holy_compare.gd  (HOLY_CAP_DIR)

var _dir: String = OS.get_environment("HOLY_CAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	var cam := Camera2D.new()
	cam.zoom = Vector2(0.75, 0.75)
	scene.add_child(cam)
	cam.global_position = Vector2(3000, 3000)
	cam.make_current()
	var hosts: Array = []
	for i in 2:
		var h := Node2D.new()
		h.scale = Vector2(0.5, 0.5)
		scene.add_child(h)
		h.global_position = Vector2(2700 + i * 600, 3000)
		hosts.append(h)
	await process_frame
	var fa: Node2D = (load("res://scenes/fx_melek_holy.tscn") as PackedScene).instantiate()
	hosts[0].add_child(fa)
	var fb := Node2D.new()
	fb.set_script(load("res://tools/fx_bake_src/fx_melek_holy.gd"))
	hosts[1].add_child(fb)
	var want := {6: "h06", 12: "h12", 24: "h24", 50: "h50"}
	for i in range(1, 60):
		await process_frame
		if want.has(i):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_dir.path_join(want[i] + ".png"))
	print("HOLYCMP done")
	quit()
