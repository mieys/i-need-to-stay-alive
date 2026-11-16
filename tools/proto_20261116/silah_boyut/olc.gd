extends SceneTree

## Seçim ekranı silah karolarında her silahın menü ikonunun tuval / dolu kutu / opak piksel ölçüsü + bugünkü tam kat ölçeği (madde 759).
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var wc = load("res://scripts/weapon_catalog.gd")
	for key: String in wc.KEYS:
		var tex: Texture2D = wc.menu_icon(key)
		if tex == null:
			print("OLC %s yok" % key)
			continue
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		var r: Rect2i = img.get_used_rect()
		var n: int = 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if img.get_pixel(x, y).a > 0.5:
					n += 1
		var k: float = floorf(minf(84.0 / r.size.x, 84.0 / r.size.y))
		print("OLC %-12s tuval=%dx%d dolu=%dx%d opak=%d k=%d ekran=%dx%d" % [key, img.get_width(), img.get_height(), r.size.x, r.size.y, n, int(k), int(r.size.x * k), int(r.size.y * k)])
	quit(0)
