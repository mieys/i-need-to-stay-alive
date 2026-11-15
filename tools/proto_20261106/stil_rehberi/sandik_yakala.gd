extends SceneTree

## Sandık doğrulama yakalaması (oyuna bağlı DEĞİL; madde 409, 2026-11-11'de madde 557 için yeniden yazıldı): gerçek chest_drop.tscn dünya
## ölçeğinde (sıradan + elit, kapalı ve açık kare, yanında karakter karesi 0,903) + ödül ekranı sandığı (chest_open_anim.gd) kapalı ve
## atlanmış (açık). Çıktı out/sandik_oyunda.png.
## Kullanım: Godot --path . --windowed --resolution 1600x700 -s tools/proto_20261106/stil_rehberi/sandik_yakala.gd
## (gizli masaüstünde: tools/fps_micro/hidden_launch.ps1 ile)

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
	cam.position = Vector2(60, -40)
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
	var i: int = 0
	for elite: bool in [false, true]:
		for opened: bool in [false, true]:
			var d: Node = scene.instantiate()
			d.set("is_elite", elite)
			d.position = Vector2(i * 44, 0)
			world.add_child(d)
			if opened:
				(d.get("sprite") as Sprite2D).frame = 1
			i += 1
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var Anim: GDScript = load("res://scripts/chest_open_anim.gd")
	var j: int = 0
	for elite: bool in [false, true]:
		for skipped: bool in [false, true]:
			var a: Control = Anim.new()
			a.setup(elite, 2, 5)
			a.position = Vector2(20 + j * 390, 300)
			layer.add_child(a)
			if skipped:
				a.call("skip")
			else:
				a.set_process(false) ## kapalı karede dondur (zaman çizelgesi ilerlemesin)
			j += 1
	await create_timer(1.2).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	print("yazildi ", OUT)
	quit(0)
