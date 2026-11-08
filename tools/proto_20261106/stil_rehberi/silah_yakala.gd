extends SceneTree

## Madde 410 doğrulama yakalaması (oyuna bağlı DEĞİL): yeniden yazılan eski silah ikonları, oyundaki dünya ölçekleriyle (asa dışı
## Icon.scale x 0,9 x 0,85 x 0,5; Yıldırım 0,99 x 0,85 x 0,15; kullanıcının Uzunkılıç'ı 0,575) karakter karesinin (0,903) yanında.
## Kullanım: Godot --path . --windowed -s tools/proto_20261106/stil_rehberi/silah_yakala.gd  -> out/silah_oyunda.png

const OUT := "res://tools/proto_20261106/stil_rehberi/out/silah_oyunda.png"
const NONWAND := 0.9 * 0.85 * 0.5
const ITEMS := [
	["res://assets/weapons/yeni/uzunkilic.png", 0.575],
	["res://assets/weapons/base_knife/icon_v2.png", 0.2805 * NONWAND],
	["res://assets/weapons/topuz/icon.png", 0.25900875 * NONWAND],
	["res://assets/weapons/pence/icon.png", 0.2941125 * NONWAND],
	["res://assets/weapons/lightning/icon_v3.png", 0.99 * 0.85 * 0.15],
	["res://assets/weapons/tabanca/icon_v2.png", 0.28875 * NONWAND],
	["res://assets/weapons/tufek/icon.png", 0.35475 * NONWAND],
	["res://assets/weapons/yay/draw1.png", 0.307395 * NONWAND],
	["res://assets/weapons/crossbow/icon.png", 0.396 * NONWAND],
	["res://assets/weapons/boomerang/icon.png", 0.33 * NONWAND],
	["res://assets/weapons/fisek/icon.png", 0.561 * NONWAND],
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var bg := ColorRect.new()
	bg.color = Color(0.29, 0.38, 0.2)
	bg.size = Vector2(4000, 4000)
	bg.position = Vector2(-2000, -2000)
	world.add_child(bg)
	var cam := Camera2D.new()
	cam.zoom = Vector2(4, 4)
	cam.position = Vector2(170, 0)
	world.add_child(cam)
	var ch := Sprite2D.new()
	ch.texture = load("res://assets/characters/talon/sheets/idle.png")
	ch.region_enabled = true
	ch.region_rect = Rect2(0, 0, 48, 48)
	ch.scale = Vector2.ONE * 0.903
	ch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ch.position = Vector2(-30, 0)
	world.add_child(ch)
	var x := 10.0
	for it: Array in ITEMS:
		var s := Sprite2D.new()
		s.texture = load(str(it[0]))
		s.scale = Vector2.ONE * float(it[1])
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(x, 0)
		world.add_child(s)
		x += 34.0
	await create_timer(0.5).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("yazildi ", OUT)
	quit(0)
