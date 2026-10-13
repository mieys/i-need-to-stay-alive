extends SceneTree

## Demirci iç mekanında yürünebilir/çarpışma hücrelerini ve NPC'nin raf noktalarını görselleştirir (madde 112, nokta seçimi için).
## Kullanım: Godot --path . -s tools/proto_20261013/smithy_overlay_capture.gd   (NPC_CAP_DIR ortam değişkeni; pencere kısa süre açılır)

var _dir: String = OS.get_environment("NPC_CAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 960)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var shop := Node2D.new()
	shop.set_script(load("res://scripts/weapon_shop.gd"))
	vp.add_child(shop)
	await process_frame
	var interior: Node2D = shop._interior
	interior.visible = true
	var smith: Node2D = shop.get_smith()
	print("demirci=", smith, " calisma ayagi=", smith.work_feet() if smith else null)
	var overlay := Node2D.new()
	overlay.z_index = 50
	interior.add_child(overlay)
	var font: Font = ThemeDB.fallback_font
	var walk: Dictionary = smith._walkable
	for y in range(-8, 6):
		for x in range(-11, 12):
			var c := Vector2i(x, y)
			var r := ColorRect.new()
			r.position = Vector2(x * 16 + 1, y * 16 + 1)
			r.size = Vector2(14, 14)
			r.color = Color(0.1, 0.9, 0.2, 0.18) if walk.has(c) else Color(0.95, 0.1, 0.1, 0.42)
			overlay.add_child(r)
			if x % 2 == 0 and y % 2 == 0:
				var l := Label.new()
				l.text = "%d,%d" % [x, y]
				l.add_theme_font_size_override("font_size", 7)
				l.position = Vector2(x * 16 + 1, y * 16 + 1)
				overlay.add_child(l)
	for i in smith.SHELF_SPOTS.size():
		var m := ColorRect.new()
		m.color = Color(0.2, 0.5, 1.0, 0.9)
		m.size = Vector2(4, 4)
		m.position = smith.SHELF_SPOTS[i]["pos"] - Vector2(2, 2)
		overlay.add_child(m)
	var wm := ColorRect.new()
	wm.color = Color(1, 1, 0, 0.9)
	wm.size = Vector2(4, 4)
	wm.position = smith.work_feet() - Vector2(2, 2)
	overlay.add_child(wm)
	# demirciyi örs başında göster (ayak noktası kareler üstünde)
	smith.set_feet(smith.work_feet())
	smith.lock_clip("strike", "down")
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.global_position = shop.INTERIOR_OFFSET + Vector2(8, -40)
	cam.zoom = Vector2(2.6, 2.6)
	cam.make_current()
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(_dir.path_join("smithy_overlay.png"))
	print("kaydedildi")
	quit()
