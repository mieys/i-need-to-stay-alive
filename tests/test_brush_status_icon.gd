extends Node

## Saklanma göstergesi (madde 275): çalıdaki oyuncunun can barının üstünde göz simgesi - 1 saklı (çizik yeşil göz), 2 görüldü (kırmızı göz), 0 yok.
## bkz. scripts/brush_status_icon.gd + overhead_bar.gd set_brush_state + player.gd / remote_player.gd set_brush_state.

const IconScript: GDScript = preload("res://scripts/brush_status_icon.gd")
const OverheadBarScript: GDScript = preload("res://scripts/overhead_bar.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const HideBrushScript: GDScript = preload("res://scripts/hide_brush.gd")

var _spawned: Array = []


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


func _icon_of(bar: Node) -> Sprite2D:
	return bar.get_node_or_null("BrushStatusIcon") as Sprite2D


func test_images_differ_and_hidden_has_slash() -> void:
	var hid: Image = IconScript.build_image(1)
	var spot: Image = IconScript.build_image(2)
	var w: int = (IconScript.EYE[0] as String).length()
	var h: int = IconScript.EYE.size()
	assert(hid.get_width() == w + 1 and hid.get_height() == h + 1, "göz + 1 px gölge")
	## çizik: saklı simgede sağ üst köşeden sol alta koyu piksel (göz deseninde orası boş)
	assert(hid.get_pixel(9, 0).a == 1.0 and spot.get_pixel(9, 0).a == 0.0, "saklıda çizik var, görüldüde yok")
	assert(hid.get_pixel(1, 8).a == 1.0, "çizik sol alta iner")
	## iris rengi: saklı yeşil, görüldü kırmızı
	var ih: Color = hid.get_pixel(8, 4) ## (4,4) çiziğin açık kenarına düşer
	var isp: Color = spot.get_pixel(8, 4)
	assert(ih.g > ih.r, "saklı iris yeşil")
	assert(isp.r > isp.g * 2.0, "görüldü iris kırmızı")
	## gölge: alt kapağın son pikselinin (8,7) sağ altında yarı saydam siyah
	var sh: Color = spot.get_pixel(9, 8)
	assert(sh.a > 0.2 and sh.a < 0.5 and sh.r == 0.0, "1 px gölge")
	assert(IconScript.texture_for(1) == IconScript.texture_for(1), "doku önbellekte")


func test_overhead_bar_shows_and_hides_icon() -> void:
	var holder := Node2D.new()
	holder.scale = Vector2(0.5, 0.5) ## oyuncu kökü gibi
	add_child(holder)
	_spawned.append(holder)
	var bar: Node2D = OverheadBarScript.new()
	holder.add_child(bar)
	bar.set_offset(OverheadBarScript.CHARACTER_Y_OFFSET)
	bar.set_brush_state(0)
	assert(_icon_of(bar) == null, "hiç saklanmadıysa simge kurulmaz (yaratık barları)")
	bar.set_brush_state(1)
	var icon: Sprite2D = _icon_of(bar)
	assert(icon != null and icon.visible, "saklıda simge görünür")
	assert(icon.texture == IconScript.texture_for(1))
	assert(absf(icon.position.y - (OverheadBarScript.CHARACTER_Y_OFFSET - IconScript.GAP)) < 0.01, "altı can barının hemen üstünde")
	assert(icon.position.y < bar.y_offset, "can barının ÜSTÜNDE")
	## açılış yaylanması küçükten başlar; bitince 1 sanat pikseli = 1 dünya pikseli (kök 0,5 -> yerel ölçek 2)
	assert(icon.global_scale.x < IconScript.TEXEL, "yaylanarak açılır")
	await get_tree().create_timer(IconScript.POP_TIME + 0.1).timeout
	assert(absf(icon.global_scale.x - IconScript.TEXEL) < 0.01, "dünya pikseline oturur: %s" % icon.global_scale.x)
	bar.set_brush_state(2)
	assert(icon.texture == IconScript.texture_for(2) and icon.visible, "görüldü simgesine geçer")
	bar.set_offset(-80.0)
	assert(absf(icon.position.y - (-80.0 - IconScript.GAP)) < 0.01, "bar yükselince simge de")
	bar.set_brush_state(0)
	assert(icon.state == 0, "çalıdan çıkınca kapanır")
	await get_tree().create_timer(IconScript.HIDE_TIME + 0.1).timeout
	assert(not icon.visible, "kapanış animasyonu sonunda gizli")
	_cleanup()


func test_player_and_remote_wire_to_icon() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(98, 1, "Dost")
	rp.set_brush_state(1)
	var ric: Sprite2D = _icon_of(rp.get_node("OverheadBar"))
	assert(ric != null and ric.visible and ric.state == 1, "kuklada (arkadaşın ekranında) saklı simgesi")
	var p: Node2D = PlayerScene.instantiate()
	p.scale = Vector2(0.5, 0.5)
	add_child(p)
	_spawned.append(p)
	p.set_brush_state(2)
	var pic: Sprite2D = _icon_of(p.get_node("OverheadBar"))
	assert(pic != null and pic.visible and pic.state == 2, "kendi oyuncunda görüldü simgesi")
	assert(absf(pic._base_scale * absf(p.get_node("OverheadBar").global_scale.y) - IconScript.TEXEL) < 0.01, "oyuncuda da dünya pikseli")
	p.set_brush_state(0)
	assert(pic.state == 0)
	_cleanup()


## madde 283: algı halkası - RING_RADIUS'ta 1 px çember (ortası boş), sadece kendi oyuncunda; saklı yeşilimsi, görüldü kırmızı, 0'da söner.
func test_ring_follows_brush_state_on_own_player() -> void:
	var ring_script: GDScript = load("res://scripts/brush_ring_fx.gd")
	var r: float = HideBrushScript.RING_RADIUS
	var img: Image = ring_script.build_image(r)
	var c: int = img.get_width() / 2
	assert(img.get_pixel(c, c).a == 0.0, "halkanın ortası boş")
	assert(img.get_pixel(c + int(r), c).a > 0.5 or img.get_pixel(c + int(r) - 1, c).a > 0.5, "yarıçapta çizgi")
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var p: Node2D = PlayerScene.instantiate()
	p.scale = Vector2(0.5, 0.5)
	add_child(p)
	_spawned.append(p)
	assert(p.get_node_or_null("BrushRing") == null, "çalıda değilken halka yok")
	p.set_brush_state(HideBrushScript.STATE_HIDDEN)
	var ring: Sprite2D = p.get_node_or_null("BrushRing") as Sprite2D
	assert(ring != null and ring.visible, "saklıyken halka var")
	assert(ring.self_modulate.g > ring.self_modulate.r, "saklı halka yeşilimsi")
	assert(absf(ring.global_scale.x - 1.0) < 0.01, "1 sanat pikseli = 1 dünya pikseli")
	p.set_brush_state(HideBrushScript.STATE_SPOTTED)
	assert(ring.self_modulate.r > ring.self_modulate.g, "görülünce kırmızı")
	p.set_brush_state(0)
	await get_tree().create_timer(0.3).timeout
	assert(not ring.visible, "çalıdan çıkınca söner")
	_cleanup()
