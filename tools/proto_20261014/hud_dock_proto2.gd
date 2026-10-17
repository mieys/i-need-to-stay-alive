extends SceneTree

## Oyuncu paneli prototip sayfasını gerçek çizicide (oyunun yazı tipi + dokularıyla) üretir.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261014/hud_dock_proto2.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#4f7a3a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	var c := Control.new()
	c.set_script(load("res://tools/proto_20261014/hud_dock_proto2_draw.gd"))
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(c)
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	print("IMG ", img.get_size())
	img.save_png(ProjectSettings.globalize_path("res://tools/proto_20261014/out/proto2_sayfa.png"))
	quit()
