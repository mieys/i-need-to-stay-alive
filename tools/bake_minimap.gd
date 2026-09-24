extends SceneTree

## Minimap arka plan haritasını üretir -> res://assets/ui/minimap_map.png
## Kullanıcı isteği (2026-09-24): "minimap arkaplanında harita düşük kalitede gözüksün. nerde olduğumu anlayamıyorum."
## Gerçek harita sahnesi (main.tscn içindeki "Harita" + "Node2D") bir SubViewport'ta GERÇEK çiziciyle, uzaklaştırılmış bir
## kamerayla parça parça çizilir; sonra her MAP_TEXEL_WORLD x MAP_TEXEL_WORLD dünya pikseli TEK bir piksele ortalanır (kutu
## filtresi) - bilerek düşük çözünürlüklü, pikselli bir "harita" çıkar. Harita dışı (kenar payı) OUTSIDE_COLOR ile doldurulur.
## Doku, GameManager.get_map_world_rect() ile AYNI dünya dikdörtgenini (TileMapLayer'ların kullanılan alanı) kapsar;
## minimap.gd doku-dünya eşlemesini bu dikdörtgen + MAP_TEXEL_WORLD + MAP_PAD_TEXELS (aşağıdaki kopyalarla aynı) ile yapar.
##
## Harita Tiled'dan yeniden bake edilince (bkz. tools/bake_harita.gd) BUNU DA yeniden çalıştır - PENCERELİ (headless'ta
## çizim yapılmaz, boş doku çıkar):
##   Godot_v4.7.2-stable_win64.exe --path . -s tools/bake_minimap.gd
## sonra bir kez `--headless --import`.

const OUT_PATH := "res://assets/ui/minimap_map.png"
const RENDER_WORLD_PER_PX := 4.0 ## ara çizim: 1 çizim pikseli = 4 dünya pikseli (sonra kutu filtresiyle küçültülür)
const CHUNK_PX := 1024
const OUTSIDE_COLOR := Color("#2b3a24")
## minimap.gd MAP_TEXEL_WORLD / MAP_PAD_TEXELS ile AYNI olmalı (Minimap sınıfına -s betiğinden erişmek autoload
## (GameManager) derleme hatası verdiği için kopya).
const MAP_TEXEL_WORLD := 32.0
const MAP_PAD_TEXELS := 32

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var vp := SubViewport.new()
	vp.size = Vector2i(CHUNK_PX, CHUNK_PX)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(vp)
	RenderingServer.set_default_clear_color(OUTSIDE_COLOR)
	for node_name in ["Harita", "Node2D"]:
		var n: Node = main.get_node_or_null(node_name)
		if n == null:
			continue
		main.remove_child(n)
		n.owner = null
		vp.add_child(n)
	main.free()
	var cam := Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.zoom = Vector2.ONE / RENDER_WORLD_PER_PX
	vp.add_child(cam)
	cam.make_current()
	await process_frame

	var rect: Rect2 = _map_rect(vp.get_node("Harita"))
	print("MAP_RECT ", rect)
	if rect.size == Vector2.ZERO:
		push_error("bake_minimap: harita dikdörtgeni bulunamadı")
		quit(1)
		return
	var texel: float = MAP_TEXEL_WORLD
	var pad: int = MAP_PAD_TEXELS
	var map_tex_size := Vector2i(int(ceil(rect.size.x / texel)), int(ceil(rect.size.y / texel)))
	var full_px := Vector2i(int(ceil(map_tex_size.x * texel / RENDER_WORLD_PER_PX)), int(ceil(map_tex_size.y * texel / RENDER_WORLD_PER_PX)))
	var full := Image.create(full_px.x, full_px.y, false, Image.FORMAT_RGBA8)
	var chunk_world: float = CHUNK_PX * RENDER_WORLD_PER_PX
	var cy: int = 0
	while cy < full_px.y:
		var cx: int = 0
		while cx < full_px.x:
			cam.position = rect.position + Vector2(cx, cy) * RENDER_WORLD_PER_PX
			for i in 4:
				await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			var w: int = mini(CHUNK_PX, full_px.x - cx)
			var h: int = mini(CHUNK_PX, full_px.y - cy)
			full.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(cx, cy))
			cx += CHUNK_PX
		cy += CHUNK_PX
	print("RENDERED ", full_px, " chunk_world=", chunk_world)

	## Kutu filtresi: her texel = (texel / RENDER_WORLD_PER_PX)^2 çizim pikselinin ortalaması.
	var k: int = int(texel / RENDER_WORLD_PER_PX)
	var out := Image.create(map_tex_size.x + pad * 2, map_tex_size.y + pad * 2, false, Image.FORMAT_RGBA8)
	out.fill(OUTSIDE_COLOR)
	var inv: float = 1.0 / float(k * k)
	for ty in map_tex_size.y:
		for tx in map_tex_size.x:
			var r: float = 0.0
			var g: float = 0.0
			var b: float = 0.0
			for yy in k:
				for xx in k:
					var c: Color = full.get_pixel(tx * k + xx, ty * k + yy)
					r += c.r
					g += c.g
					b += c.b
			out.set_pixel(tx + pad, ty + pad, Color(r * inv, g * inv, b * inv, 1.0))
	var err: int = out.save_png(ProjectSettings.globalize_path(OUT_PATH))
	print("SAVED ", OUT_PATH, " size=", out.get_size(), " err=", err)
	quit()


## GameManager.get_map_world_rect() ile birebir aynı hesap (harita sahnede değilken o fonksiyon çalışmadığı için kopya).
func _map_rect(harita: Node) -> Rect2:
	var total := Rect2()
	var found := false
	var stack: Array[Node] = [harita]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if not (n is TileMapLayer):
			continue
		var layer: TileMapLayer = n
		var used: Rect2i = layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var half: Vector2 = (Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(16.0, 16.0)) * 0.5
		var top_left: Vector2 = layer.to_global(layer.map_to_local(used.position) - half)
		var bottom_right: Vector2 = layer.to_global(layer.map_to_local(used.position + used.size - Vector2i.ONE) + half)
		var r := Rect2(top_left, Vector2.ZERO).expand(bottom_right)
		total = r if not found else total.merge(r)
		found = true
	return total
