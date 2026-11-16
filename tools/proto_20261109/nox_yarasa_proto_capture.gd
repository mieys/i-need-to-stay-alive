extends SceneTree

## NOX YARASA FORMU güzelleştirme prototipleri (nox_yarasa_proto.py, 2026-11-16) GERÇEK OYUNDA: Nox ile E basılır, form sürerken
## oyuncunun bat_* karelerinin dokusu VD_PROTO_DIR/<kod>.png ile değiştirilir (bölgeler aynı), 4 yön sabit karede çekilir.
## Kalkan baloncuğu çekimde gizlenir. Çıktı VD_DIR/<kod>_<yön>.png + <kod>_<yön>_anim<nn>.png (sağa uçarken birkaç kare).
## Koşturucu: vampir_donusum_run.ps1 -Script nox_yarasa_proto_capture.gd -OutSub nox_yarasa_formu\oyun_proto
## -s betikleri autoload'lardan ÖNCE derlenir: oyun betiklerini preload ETME.

const SHOT_FRAME := 8
var _dir: String = OS.get_environment("VD_DIR")
var _proto: String = OS.get_environment("VD_PROTO_DIR")
var _main: Node2D = null
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _hide_bubble() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var sv: Variant = _player.get("shield_visual")
	if sv is CanvasItem and is_instance_valid(sv):
		(sv as CanvasItem).visible = false
	var mfx: Node = _player.get_node_or_null("ManaShieldFx")
	if mfx is CanvasItem:
		(mfx as CanvasItem).visible = false


func _purge() -> void:
	for e in get_nodes_in_group("enemies"):
		if not e.is_queued_for_deletion():
			e.queue_free()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
		_purge()


func _shot(tag: String, rel: Rect2i) -> void:
	var img: Image = root.get_texture().get_image()
	var k: float = float(img.get_width()) / 1920.0
	var c: Vector2 = (_player.get_viewport().get_canvas_transform() * _player.global_position) * k
	var r := Rect2i(int(c.x) + int(rel.position.x * k), int(c.y) + int(rel.position.y * k), int(rel.size.x * k), int(rel.size.y * k))
	img.get_region(r).save_png(_dir.path_join(tag + ".png"))


func _frames_with(base: SpriteFrames, tex: Texture2D) -> SpriteFrames:
	var sf: SpriteFrames = base.duplicate() as SpriteFrames
	for dir in ["down", "left", "right", "up"]:
		var clip := StringName("bat_" + dir)
		for i in sf.get_frame_count(clip):
			var old: AtlasTexture = sf.get_frame_texture(clip, i) as AtlasTexture
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = old.region
			sf.set_frame(clip, i, at)
	return sf


func _run() -> void:
	await process_frame
	var gm: Node = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	gm.call("reset")
	var chars: GDScript = load("res://scripts/characters.gd")
	gm.set("selected_char_id", 13)
	gm.set("selected_character", chars.get_def(13).get("skill", 1))
	gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene as Node2D
	_main.set("_run_end_recorded", true)
	gm.set("run_record_suppressed", true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	RenderingServer.frame_pre_draw.connect(_hide_bubble)
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	_player = _main.get_node("Player")
	_player.global_position += Vector2(-170.0, 100.0)
	_player.set("health", 1.0e6)
	await _wait(1.0)
	var anim: AnimatedSprite2D = _player.get("anim") as AnimatedSprite2D
	var base: SpriteFrames = anim.sprite_frames
	var rel := Rect2i(-90, -110, 180, 130)
	for code in ["O", "A", "B", "C"]:
		var img: Image = Image.load_from_file(_proto.path_join(code + ".png"))
		var sf: SpriteFrames = _frames_with(base, ImageTexture.create_from_image(img))
		_player.set("skill2_state", "ready")
		_player.set("skill2_timer", 0.0)
		_player.call("_activate_skill2")
		await _wait(1.1)
		anim.sprite_frames = sf
		for dir in ["down", "left", "right", "up"]:
			_player.set("facing", dir)
			await _wait(0.12)
			await process_frame
			anim.pause()
			anim.frame = SHOT_FRAME
			await RenderingServer.frame_post_draw
			_shot("%s_%s" % [code, dir], rel)
		anim.play()
		print("SHOT ", code, " anim=", anim.animation, " olcek=", anim.global_transform.get_scale().x)
		_player.call("_vampir_cancel_bat_form")
		anim.sprite_frames = base
		await _wait(0.9)
	print("BITTI")
	quit()
