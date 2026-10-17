extends SceneTree

## Efekt PİŞİRİCİ - 1. aşama (madde 215): bir efekt sahnesini gerçek çizicide, SABİT kare hızında (--fixed-fps) siyah ve beyaz
## zeminde iki kez oynatıp her kareyi geçici klasöre yazar; 2. aşama `tools/fx_bake_pack.py` (siyah/beyaz farkından alfa çıkarır,
## kırpar, sprite sayfası + SpriteFrames .tres üretir). Sürücü: `tools/fx_bake.ps1 <ad>`.
## Ortam: BAKE_SCENE (res://...tscn), BAKE_DUR (sn), BAKE_FPS (--fixed-fps ile AYNI olmalı), BAKE_TEXEL (1 viewport pikseli = kaç
## yerel birim; piksel sanatı efektler 1,212, düz çizimler 1,0), BAKE_VIEW (viewport kenarı, px), BAKE_OUT (klasör).
## Not: efekt ebeveyni olarak boş bir Node2D alır (merkez = viewport ortası); rastgelelik her geçişte aynı tohumla başlar.

var _scene: String = OS.get_environment("BAKE_SCENE")
var _dur: float = float(OS.get_environment("BAKE_DUR"))
var _fps: int = int(OS.get_environment("BAKE_FPS"))
var _texel: float = float(OS.get_environment("BAKE_TEXEL"))
var _view: int = int(OS.get_environment("BAKE_VIEW"))
var _out: String = OS.get_environment("BAKE_OUT")


func _initialize() -> void:
	_run.call_deferred()


func _pass(tag: String, bg: Color) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(_view, _view)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var s: float = 1.0 / _texel
	vp.canvas_transform = Transform2D(Vector2(s, 0), Vector2(0, s), Vector2(_view * 0.5, _view * 0.5))
	root.add_child(vp)
	var back := ColorRect.new()
	back.color = bg
	back.size = Vector2(_view, _view) * _texel * 2.0
	back.position = -back.size * 0.5
	back.z_index = -4096
	vp.add_child(back)
	var host := Node2D.new()
	vp.add_child(host)
	seed(4242)
	await process_frame
	var fx: Node = (load(_scene) as PackedScene).instantiate()
	host.add_child(fx)
	var n: int = int(ceil(_dur * float(_fps)))
	for i in range(n):
		await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		img.save_png(_out.path_join("%s_%03d.png" % [tag, i]))
	vp.queue_free()
	await process_frame


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(_out)
	await _pass("b", Color(0, 0, 0))
	await _pass("w", Color(1, 1, 1))
	print("CAPTURED %s frames=%d" % [_scene, int(ceil(_dur * float(_fps)))])
	quit()
