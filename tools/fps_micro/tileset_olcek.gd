extends SceneTree

## TileSetAtlasSource.create_tile ölçek testi (madde 371): N tanımlı karoluk tek kaynağın kurulum süresi - karo sayısıyla ikinci dereceden mi büyüyor?
## Kullanım: Godot --headless --path . -s res://tools/fps_micro/tileset_olcek.gd


func _initialize() -> void:
	_run.call_deferred()


func _build(n: int, tex: Texture2D, cols: int, with_data: bool) -> float:
	var t0: int = Time.get_ticks_usec()
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
	for i in range(n):
		var c := Vector2i(i % cols, i / cols)
		src.create_tile(c)
		if with_data:
			src.get_tile_data(c, 0)
	return float(Time.get_ticks_usec() - t0) / 1000.0


func _run() -> void:
	var img := Image.create(2048, 2176, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	for n in [1000, 2000, 4000, 8000, 16000]:
		print("TS n=%d create_tile=%.0f ms (tek kaynak)" % [n, _build(n, tex, 128, false)])
	## aynı 16000 karo 8 kaynağa bölünmüş
	var t0: int = Time.get_ticks_usec()
	for k in range(8):
		_build(2000, tex, 128, false)
	print("TS 8 x 2000 = %.0f ms (8 ayrı kaynak)" % (float(Time.get_ticks_usec() - t0) / 1000.0))
	quit()
