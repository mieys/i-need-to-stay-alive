extends Node

## Silah kademe kontürü (scripts/enchant_weapon_glow.gd). Kullanıcı 2026-10-08: "çizgi ince ve kesik kesik" -> kontür artık dünya pikseli dokusu değil,
## ikonun alfa kapsamından EKRAN uzayında shader'da çizilir. Ekransız çalışmada shader derlenmez/çizilmez; burada kademe kuralları, doku şekli (kenar payı +
## mip zinciri + alfa korunumu), ikonla hizalama ve animasyonlu ikon yolu sınanır. Görsel doğrulama: scratchpad shot_glow2/shot_glow4 (gerçek renderer).

const GlowScript: GDScript = preload("res://scripts/enchant_weapon_glow.gd")

var _nodes: Array[Node] = []


func _icon(size: Vector2i = Vector2i(40, 30), scale_v: float = 0.3, centered: bool = true) -> Sprite2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(8, size.y - 8):
		for x in range(6, size.x - 6):
			img.set_pixel(x, y, Color(0.8, 0.2, 0.2, 1.0))
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.scale = Vector2.ONE * scale_v
	s.centered = centered
	add_child(s)
	_nodes.append(s)
	return s


func _cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func test_tier_for_follows_the_enchant_record() -> void:
	assert(GlowScript.tier_for({}) == 0, "efsun yok = 0")
	assert(GlowScript.tier_for({"id": "x", "ups": [], "final": false}) == 1, "temel = 1")
	assert(GlowScript.tier_for({"id": "x", "ups": [1, 2], "final": false}) == 3, "iki geliştirme = 3")
	assert(GlowScript.tier_for({"id": "x", "ups": [1, 2, 3, 4], "final": false}) == 4, "dört geliştirme en çok 4 (final 5)")
	assert(GlowScript.tier_for({"id": "x", "ups": [1, 2, 3, 4], "final": true}) == 5, "final = 5")


func test_base_tier_has_no_outline_and_upgrades_add_then_remove_it() -> void:
	var icon: Sprite2D = _icon()
	assert(GlowScript.attach(icon, 0) == null and icon.get_node_or_null("EnchantGlow") == null, "efsunsuz: kontür yok")
	assert(GlowScript.attach(icon, 1) == null and icon.get_node_or_null("EnchantGlow") == null, "Temel (1): kontür yok")
	var g: Node = GlowScript.attach(icon, 2)
	assert(g != null and icon.get_node_or_null("EnchantGlow") == g, "kademe 2: kontür var, ikonun çocuğu")
	assert(GlowScript.attach(icon, 4) == g, "ikinci çağrı aynı düğümü günceller (çoğalmaz)")
	assert(icon.get_child_count() == 1, "tek kontür düğümü")
	GlowScript.attach(icon, 1)
	await get_tree().process_frame
	assert(icon.get_node_or_null("EnchantGlow") == null or icon.get_node("EnchantGlow").is_queued_for_deletion(), "kademe düşünce kontür kalkar")
	_cleanup()


func test_tier_sets_color_and_final_gets_the_second_ring() -> void:
	var icon: Sprite2D = _icon()
	var g: Sprite2D = GlowScript.attach(icon, 3) as Sprite2D
	var mat: ShaderMaterial = g.material as ShaderMaterial
	assert(mat != null, "shader malzemesi var")
	assert((mat.get_shader_parameter("glow_color") as Color).is_equal_approx(GlowScript.TIER_COLORS[1]), "kademe 3 = mavi")
	assert(is_equal_approx(float(mat.get_shader_parameter("double_ring")), 0.0), "kademe 3: tek halka")
	assert(is_equal_approx(float(mat.get_shader_parameter("thick")), GlowScript.OUTLINE_PX), "kalınlık ekran pikseli sabiti")
	GlowScript.attach(icon, 5)
	assert((mat.get_shader_parameter("glow_color") as Color).is_equal_approx(GlowScript.TIER_COLORS[3]), "final = kırmızı")
	assert(is_equal_approx(float(mat.get_shader_parameter("double_ring")), 1.0), "final: ikinci halka açık")
	_cleanup()


func test_coverage_texture_pads_keeps_alpha_and_has_mipmaps() -> void:
	var icon: Sprite2D = _icon(Vector2i(40, 30), 0.3)
	var g: Sprite2D = GlowScript.attach(icon, 3) as Sprite2D
	var tex: Texture2D = g.texture
	assert(tex != null, "kapsam dokusu üretildi")
	var px: int = int(ceilf(GlowScript.PAD_WORLD_PX / 0.3)) + 1
	assert(tex.get_width() == 40 + px * 2 and tex.get_height() == 30 + px * 2, "doku = ikon + her kenara kenar payı: %s" % str(tex.get_size()))
	var img: Image = tex.get_image()
	assert(img.has_mipmaps(), "shader mip düzeyinden kapsam okuyor: mip zinciri şart")
	assert(img.get_pixel(0, 0).a == 0.0, "kenar payı şeffaf")
	assert(img.get_pixel(px + 10, py_center(px, 30)).a > 0.99, "ikonun dolu pikseli alfayı korur")
	assert(img.get_pixel(px + 1, px + 1).a == 0.0, "ikonun şeffaf köşesi şeffaf kalır")
	assert(g.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "doğrusal+mip süzme")
	_cleanup()


func py_center(pad: int, h: int) -> int:
	return pad + h / 2


func test_outline_node_is_aligned_with_the_icon() -> void:
	var icon: Sprite2D = _icon(Vector2i(40, 30), 0.3, true)
	icon.offset = Vector2(3, -2)
	var g: Sprite2D = GlowScript.attach(icon, 2) as Sprite2D
	assert(g.scale == Vector2.ONE, "kontür ikonun ölçeğini devralır, ek ölçek yok")
	assert(g.centered and g.offset.is_equal_approx(Vector2(3, -2)), "ortalı ikon: dokular aynı merkezde, ofset aynı")
	assert(g.show_behind_parent, "kontür ikonun arkasında")
	var icon2: Sprite2D = _icon(Vector2i(40, 30), 0.3, false)
	var g2: Sprite2D = GlowScript.attach(icon2, 2) as Sprite2D
	var px: int = int(ceilf(GlowScript.PAD_WORLD_PX / 0.3)) + 1
	assert(not g2.centered and g2.offset.is_equal_approx(Vector2(-px, -px)), "ortasız ikon: sol üst köşe kenar payı kadar geri: %s" % str(g2.offset))
	icon.flip_h = true
	await get_tree().process_frame
	assert(g.flip_h, "aynalama ikonu izler")
	_cleanup()


func test_animated_icon_rebuilds_when_the_frame_changes() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("a")
	var f1: ImageTexture = ImageTexture.create_from_image(_solid(30, 20))
	var f2: ImageTexture = ImageTexture.create_from_image(_solid(36, 24))
	frames.add_frame("a", f1)
	frames.add_frame("a", f2)
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	anim.animation = "a"
	anim.scale = Vector2.ONE * 0.3
	add_child(anim)
	_nodes.append(anim)
	var g: Sprite2D = GlowScript.attach(anim, 3) as Sprite2D
	var w1: int = g.texture.get_width()
	anim.frame = 1
	await get_tree().process_frame
	await get_tree().process_frame
	assert(g.texture.get_width() > w1, "kare değişince kontür dokusu yeni karenin boyutuna göre yeniden kurulur: %d -> %d" % [w1, g.texture.get_width()])
	_cleanup()


func _solid(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.9, 1.0))
	return img
