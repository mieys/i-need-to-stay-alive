extends SceneTree

## Madde 409 doğrulama yakalaması (oyuna bağlı DEĞİL): gerçek chest_drop.tscn (6 kademe bandı + elit) dünya ölçeğinde, yanında
## karakter karesi (0,903) + ödül ekranı sandığı (chest_open_anim.gd) kapalı ve açık. Çıktı out/sandik_oyunda.png.
## Kullanım: Godot --path . --windowed --resolution 1600x700 -s tools/proto_20261106/stil_rehberi/sandik_yakala.gd

const OUT := "res://tools/proto_20261106/stil_rehberi/out/sandik_oyunda.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 700))
	var world := Node2D.new()
	root.add_child(world)
	var bg := ColorRect.new()
	bg.color = Color(0.29, 0.38, 0.2)
	bg.size = Vector2(4000, 4000)
	bg.position = Vector2(-2000, -2000)
	world.add_child(bg)
	var cam := Camera2D.new()
	cam.zoom = Vector2(3, 3)
	cam.position = Vector2(150, -40)
	world.add_child(cam)
	var ch := Sprite2D.new()
	var tex: Texture2D = load("res://assets/characters/talon/sheets/idle.png")
	ch.texture = tex
	ch.region_enabled = true
	ch.region_rect = Rect2(0, 0, 48, 48)
	ch.scale = Vector2.ONE * 0.903
	ch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ch.position = Vector2(-40, -14)
	world.add_child(ch)
	var scene: PackedScene = load("res://scenes/chest_drop.tscn")
	for i in 7:
		var d: Node = scene.instantiate()
		d.set("chest_tier", mini(i, 5))
		d.set("is_elite", i == 6)
		d.position = Vector2(i * 44, 0)
		world.add_child(d)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var Anim: GDScript = load("res://scripts/chest_open_anim.gd")
	for j in 2:
		var a: Control = Anim.new()
		a.setup(false, 2, 5)
		a.position = Vector2(60 + j * 420, 300)
		layer.add_child(a)
		if j == 1:
			a.call("skip")
	await create_timer(1.2).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("yazildi ", OUT)
	quit(0)
