extends SceneTree

## Cozy ev İÇ IŞIĞI gerçek çizicide (madde 311): evin tamamı gece / gündüz (zoom 2) + şömine ve kazan yakından (zoom 4, gece).
## ISIK_CAP_DIR'e gece.png, gunduz.png, aksam.png, yakin.png yazar. Gizli masaüstünde koşulur (tools/fps_micro/hidden_launch.ps1).
## Önizlemeyle yan yana: python tools/proto_20261019/cozy_ev/isik_karsilastir.py

var _dir: String = OS.get_environment("ISIK_CAP_DIR")


class FakeAtmo extends Node:
	var cycle_time: float = 60.0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _grab(vp: SubViewport) -> Image:
	await RenderingServer.frame_post_draw
	var im: Image = vp.get_texture().get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 608)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	var atmo := FakeAtmo.new()
	atmo.add_to_group("atmosphere")
	vp.add_child(atmo)
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
	bab.visible = OS.get_environment("ISIK_BAB") == "1"
	var light = house.get_light()
	print("ISIK_CAP isik=", light != null, " kaynak=", light.light_count() if light != null else 0)
	var cam := Camera2D.new()
	vp.add_child(cam)
	cam.make_current()
	cam.zoom = Vector2(2.0, 2.0)
	cam.position = offset + Vector2(320.0, 184.0) ## önizlemenin kırpımı: x 0..640, y 32..336
	## aksam (karanlık ~0,56): gündüz yelpazeleri + ay haleleri birlikte açık = en çok ışık (dörtgen başına ışık sınırı denetimi)
	for kip: Array in [["gece", 450.0], ["gunduz", 60.0], ["aksam", 360.0]]:
		atmo.cycle_time = kip[1]
		if light != null:
			light.clock_override = kip[1]
		house._window_check = 0.0
		house._process_windows(0.1)
		await _wait(0.6)
		(await _grab(vp)).save_png(_dir.path_join("%s.png" % kip[0]))
	## yakın: şömine + kazan (gece), titreme ve "piksel piksel" denetimi
	atmo.cycle_time = 450.0
	if light != null:
		light.clock_override = 450.0
	house._window_check = 0.0
	house._process_windows(0.1)
	vp.size = Vector2i(640, 360)
	cam.zoom = Vector2(4.0, 4.0)
	var shots: Array[Image] = []
	for pos: Vector2 in [Vector2(408.0, 110.0), Vector2(110.0, 110.0)]:
		cam.position = offset + pos
		await _wait(0.4)
		shots.append(await _grab(vp))
	var out := Image.create(1280, 360, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		out.blit_rect(shots[i], Rect2i(0, 0, 640, 360), Vector2i(i * 640, 0))
	out.save_png(_dir.path_join("yakin.png"))
	print("ISIK_CAP tamam")
	quit(0)
