extends SceneTree

## Assasin Çocuk ULTİ (Gölge Hücumu) yeni efektlerinin (2026-10-16) GERÇEK ÇİZİCİDE, oyundaki gerçek ölçekle doğrulaması:
## düz çimen, gerçek Player (kök 0,5 ölçek), sabit kamera (zoom 2 = oyun kamerası), çevrede 5 sahte yaratık. R tetiklenir,
## ulti boyunca her 2 karede bir görüntü ASSASIN_CAP_DIR/f_###.png olarak kaydedilir (gif'e Python çevirir).
## Kullanım (pencere açar, ~6 sn): Godot --path . -s tools/proto_20261016/assasin_ult_capture.gd   (ASSASIN_CAP_DIR ortam değişkeni)

const CROP := Vector2i(880, 560)
const ORIGIN := Vector2(3000, 3000)

var _dir: String = OS.get_environment("ASSASIN_CAP_DIR")
var _player: Node2D = null
var _cam: Camera2D = null


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_frozen: bool = false

	func take_damage(_amount: float, _crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		var spr: CanvasItem = get_child(0) as CanvasItem
		if spr:
			spr.modulate = Color(3, 3, 3)
			create_tween().tween_property(spr, "modulate", Color(0.75, 1.0, 0.6), 0.12)


func _initialize() -> void:
	_run.call_deferred()


func _grab(i: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * ORIGIN)
	var rect := Rect2i(Vector2i(int(c.x), int(c.y)) - CROP / 2, CROP).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join("f_%03d.png" % i))


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 5
	gm.selected_character = 5
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 156, 74)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	## Yaratık yerine: başka bir karakterin karesi, yeşile boyanmış (sadece ölçek/bağlam için).
	var stand_in: SpriteFrames = load("res://assets/characters/cadi_frames.tres") as SpriteFrames
	var anim_name: StringName = stand_in.get_animation_names()[0]
	for off: Vector2 in [Vector2(120, -30), Vector2(-150, 40), Vector2(30, 95), Vector2(-70, -85), Vector2(190, 70)]:
		var e := FakeEnemy.new()
		e.add_to_group("enemies")
		var spr := Sprite2D.new()
		spr.texture = stand_in.get_frame_texture(anim_name, 0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2.ONE * 1.1
		spr.modulate = Color(0.75, 1.0, 0.6)
		e.add_child(spr)
		scene.add_child(e)
		e.global_position = ORIGIN + off
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	_player.z_index = 1
	scene.add_child(_player)
	_player.global_position = ORIGIN
	_player.set("item_shield_max", 1000.0)
	_player.set("item_shield_hp", 1000.0)
	var own_cam: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if own_cam:
		own_cam.enabled = false
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	scene.add_child(_cam)
	_cam.global_position = ORIGIN
	_cam.make_current()
	for _i in range(20):
		await process_frame
	_player.call("_activate_skill3")
	var n: int = 0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5600:
		await process_frame
		await _grab(n)
		n += 1
		await process_frame
	print("BITTI kare=%d durum=%s" % [n, str(_player.get("skill3_state"))])
	quit()
