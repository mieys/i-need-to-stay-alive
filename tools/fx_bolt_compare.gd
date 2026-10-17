extends SceneTree

## Madde 215: totem ateş topu YENİ (shader + pişirilmiş) ile ÖZGÜN (tools/fx_bake_src) yan yana; --fixed-fps 60 ile belirli karelerde ekran görüntüsü.
## Üst şerit yeni, alt şerit özgün. BOLT_CAP_DIR ortam değişkeni. Çalıştırma: Godot --path . --windowed --resolution 1280x720 --fixed-fps 60 -s tools/fx_bolt_compare.gd

var _dir: String = OS.get_environment("BOLT_CAP_DIR")


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
	cam.zoom = Vector2(2.5, 2.5)
	scene.add_child(cam)
	cam.global_position = Vector2(3150, 3000)
	cam.make_current()
	var NewB: GDScript = load("res://scripts/fx_totem_fire_bolt.gd")
	var OldB: GDScript = load("res://tools/fx_bake_src/fx_totem_fire_bolt.gd")
	var tgt1 := Node2D.new()
	var tgt2 := Node2D.new()
	scene.add_child(tgt1)
	scene.add_child(tgt2)
	tgt1.global_position = Vector2(3300, 2940)
	tgt2.global_position = Vector2(3300, 3060)
	await process_frame
	NewB.spawn(scene, Vector2(3000, 2940), tgt1, Color(1.0, 0.55, 0.25), 0.0)
	OldB.spawn(scene, Vector2(3000, 3060), tgt2, Color(1.0, 0.55, 0.25), 0.0)
	var want := {4: "f04", 9: "f09", 14: "f14", 17: "f17", 24: "i24", 32: "i32", 44: "i44"}
	for i in range(1, 50):
		await process_frame
		if want.has(i):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(_dir.path_join(want[i] + ".png"))
	print("BOLTCMP done")
	quit()
