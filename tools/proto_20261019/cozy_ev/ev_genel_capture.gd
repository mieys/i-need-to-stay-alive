extends SceneTree

## Ev ici GENEL gorunum (madde 328): KAP_DIR/genel.png - tum ic mekan zoom 2; KAP_CHARS="x,y|x,y|..." ile karakterler (ic mekan yerel ayak konumu).
## Gizli masaustunde koşulur (ev_run.ps1 -Script ev_genel_capture.gd).

var _dir: String = OS.get_environment("KAP_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _fake(parent: Node, frames: String, clip: String, feet: Vector2) -> Node2D:
	var fp := Node2D.new()
	fp.scale = Vector2(0.5, 0.5)
	fp.z_index = 1
	var spr := AnimatedSprite2D.new()
	spr.name = "AnimatedSprite2D"
	spr.sprite_frames = load(frames)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2.ONE * 2.2368375 * EntityScale.SIZE
	spr.offset = Vector2(0.0, -5.0)
	fp.add_child(spr)
	fp.add_to_group("remote_players")
	parent.add_child(fp)
	fp.position = feet - Vector2(0.0, 12.75)
	spr.play(clip)
	return fp


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 672)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var player := CharacterBody2D.new()
	player.set_script(load("res://tests/test_babaanne.gd").FakePlayer)
	player.add_to_group("player")
	vp.add_child(player)
	var house := Node2D.new()
	house.set_script(load("res://scripts/house_interior.gd"))
	vp.add_child(house)
	await process_frame
	house.set_process(false)
	var offset: Vector2 = house.INTERIOR_OFFSET
	player.global_position = offset + Vector2(-5000.0, 0.0)
	var bab = house.get_babaanne()
	bab.set_process(false)
	bab.visible = false
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(2.0, 2.0)
	cam.position = offset + Vector2(320.0, 168.0)
	var inner: Node = house._interior_instance
	for spec in OS.get_environment("KAP_CHARS").split("|", false):
		var xy: PackedStringArray = spec.split(",")
		_fake(inner, "res://assets/characters/matthew_frames.tres", "idle_down", Vector2(float(xy[0]), float(xy[1])))
	await _wait(0.5)
	await RenderingServer.frame_post_draw
	var im: Image = vp.get_texture().get_image()
	im.save_png(_dir.path_join("genel.png"))
	print("KAP genel tamam")
	quit(0)
