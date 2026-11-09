extends SceneTree

## Dikey Movie Maker boyut deneyi (tanitim_capture.gd için): kök viewport / pencere / doku boyutları + köşe desenleri.
## TN_MODE: viewport (content_scale VIEWPORT 1080x1920) / window (pencereyi 1080x1920 yap) / both.

var _mode: String = OS.get_environment("TN_MODE")
var _f: int = 0


func _initialize() -> void:
	if _mode == "viewport" or _mode == "both":
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
		root.content_scale_size = Vector2i(1080, 1920)
	if _mode == "window" or _mode == "both":
		DisplayServer.window_set_size(Vector2i(1080, 1920))
	var bg := ColorRect.new()
	bg.color = Color(0.5, 0.0, 0.0)
	bg.size = Vector2(1080, 1920)
	root.add_child.call_deferred(bg)
	for spec in [[Vector2(0, 0), Color.GREEN], [Vector2(880, 1720), Color.BLUE], [Vector2(440, 860), Color.WHITE]]:
		var r := ColorRect.new()
		r.color = spec[1]
		r.position = spec[0]
		r.size = Vector2(200, 200)
		root.add_child.call_deferred(r)
	process_frame.connect(_tick)


func _tick() -> void:
	_f += 1
	if _f % 10 == 0:
		print("TN f=%d win=%s root.size=%s vis=%s tex=%s screen=%s" % [_f, str(DisplayServer.window_get_size()), str(root.size),
				str(root.get_visible_rect().size), str(root.get_texture().get_size()), str(DisplayServer.screen_get_size())])
	if _f >= 40:
		quit()
