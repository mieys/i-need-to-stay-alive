extends SceneTree

## Demirci iç mekanı ve seyyar satıcı görselinin düzenini (katman adları, örs işaretçisi, boyutlar) PNG + metin olarak döker.
## Kullanım: Godot --path . -s tools/proto_20261013/npc_layout_capture.gd   (NPC_CAP_DIR ortam değişkeni; pencere kısa süre açılır)

var _dir: String = OS.get_environment("NPC_CAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _shot(scene_path: String, out_name: String, grid_step: int) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 960)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color8(60, 90, 60)
	bg.position = Vector2(-2000, -2000)
	bg.size = Vector2(4000, 4000)
	vp.add_child(bg)
	var inst: Node2D = (load(scene_path) as PackedScene).instantiate()
	vp.add_child(inst)
	var rect := Rect2()
	var first := true
	print("== ", scene_path)
	for c in inst.get_children():
		if c is TileMapLayer:
			var l: TileMapLayer = c
			var used: Rect2i = l.get_used_rect()
			print("katman '%s' pos=%s hucre=%d kullanilan=%s z=%d vis=%s" % [l.name, l.position, l.get_used_cells().size(), used, l.z_index, l.visible])
			if used.size != Vector2i.ZERO:
				var ts: Vector2 = Vector2(l.tile_set.tile_size) if l.tile_set else Vector2(16, 16)
				var r := Rect2(l.position + Vector2(used.position) * ts, Vector2(used.size) * ts)
				rect = r if first else rect.merge(r)
				first = false
		else:
			print("dugum '%s' %s" % [c.name, c.get_class()])
	print("sinir kutusu=", rect)
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.position = rect.get_center()
	var z: float = minf(1280.0 / (rect.size.x + 32.0), 960.0 / (rect.size.y + 32.0))
	cam.zoom = Vector2(z, z)
	cam.make_current()
	# ızgara çizgisi (her grid_step px) - koordinat okumak için
	var grid := Node2D.new()
	grid.z_index = 100
	vp.add_child(grid)
	grid.set_script(null)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(_dir.path_join(out_name))
	print("kaydedildi ", out_name, " zoom=", z)
	vp.queue_free()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	await _shot("res://scenes/silah_saticisi_baked.tscn", "demirci_ic.png", 16)
	await _shot("res://scenes/seyyar_satici_baked.tscn", "seyyar.png", 16)
	quit()
