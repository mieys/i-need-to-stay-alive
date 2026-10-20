extends Node

## COZY EV İÇ IŞIĞI (2026-10-19, madde 311, scripts/cozy_ev_light.gd): iç mekanın CanvasModulate'i + PointLight2D'leri yalnız evin
## içi görünürken açık; ortam gece/gündüz rengi AtmosphereMath.darkness ile; ışık kaynakları pişmiş karolardan önizlemedeki
## (tools/proto_20261019/cozy_ev/gen_cozy_ev.py) yerlerde; gündüz pencere yelpazeleri, gece ay haleleri; ışık veren eşyalar ışıksız.

const HouseInteriorScript: GDScript = preload("res://scripts/house_interior.gd")
const LightScript: GDScript = preload("res://scripts/cozy_ev_light.gd")
const FakePlayer = preload("res://tests/test_babaanne.gd").FakePlayer

## gen_cozy_ev.py build() m.lights "kaynak" noktaları (ev pikseli = iç mekan yerel birimi).
const PREVIEW_SOURCES: Dictionary = {
	"somine": [Vector2(408, 96)],
	"kazan_ocak": [Vector2(96, 116)], ## madde 313: kazan bir karo aşağı indi (gen_cozy_ev.py (5,5))
	"mum": [Vector2(140, 78), Vector2(92, 142), Vector2(92, 238), Vector2(204, 78), Vector2(284, 78), Vector2(556, 78)],
	"fener": [Vector2(368, 61), Vector2(448, 61)],
	"lamba": [Vector2(150, 208), Vector2(470, 128), Vector2(598, 208)],
}
const DAY_TIME := 60.0
const NIGHT_TIME := 450.0

var _spawned: Array = []


func _make_house() -> Dictionary:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	_spawned.append(p)
	var house: Node2D = HouseInteriorScript.new()
	add_child(house)
	_spawned.append(house)
	house.set_process(false)
	return {"house": house, "player": p, "light": house.get_light()}


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


static func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002


func test_light_sources_sit_where_the_preview_put_them() -> void:
	var w: Dictionary = _make_house()
	var light: CozyEvLight = w["light"]
	assert(light != null, "ev içi ışığı kurulmadı")
	var found: Dictionary = {}
	for s: Dictionary in light.source_lights():
		var key: String = s["key"]
		if not found.has(key):
			found[key] = []
		found[key].append((s["light"] as PointLight2D).position)
	for key: String in PREVIEW_SOURCES:
		var want: Array = PREVIEW_SOURCES[key]
		var got: Array = found.get(key, [])
		assert(got.size() == want.size(), "%s sayısı %d (önizleme %d) - ev Tiled'da değiştiyse PREVIEW_SOURCES'ı güncelle" % [key, got.size(), want.size()])
		for p: Vector2 in want:
			assert(got.has(p), "%s ışığı %s noktasında yok: %s" % [key, str(p), str(got)])
	## ateşler titrer, diğerleri sabit; elips = dikey ölçek
	for s: Dictionary in light.source_lights():
		var fire: bool = s["key"] == "somine" or s["key"] == "kazan_ocak"
		assert(is_nan(float(s["phase"])) != fire, "%s titreme evresi" % s["key"])
	var fp: PointLight2D = light.source_lights()[0]["light"]
	for s: Dictionary in light.source_lights():
		if s["key"] == "somine":
			fp = s["light"]
	assert(is_equal_approx(fp.scale.x * 256.0, 178.0) and is_equal_approx(fp.scale.y / fp.scale.x, 0.72), "şömine yarıçapı 178, basıklık 0,72")
	assert(light.window_night_lights().size() == 5, "5 kuzey penceresinde ay halesi: %d" % light.window_night_lights().size())
	assert(light.window_day_lights().size() == 5 * 2 + 4, "5 pencere x (yelpaze + parıltı) + 4 alt pencere: %d" % light.window_day_lights().size())
	_cleanup()


func test_ambient_and_window_light_follow_day_and_night() -> void:
	var w: Dictionary = _make_house()
	var light: CozyEvLight = w["light"]
	var mum: PointLight2D = null
	for s: Dictionary in light.source_lights():
		if s["key"] == "mum":
			mum = s["light"]
	light.clock_override = DAY_TIME
	light._process(0.016)
	assert(light.darkness < 0.001, "gündüz karanlık 0")
	assert(_close(light.ambient.color, Color(0.72, 0.68, 0.66)), "gündüz ortam rengi: %s" % str(light.ambient.color))
	assert(is_equal_approx(mum.energy, 0.85 * 0.6), "gündüz kaynak şiddeti x0,6: %f" % mum.energy)
	for d: Dictionary in light.window_day_lights():
		assert((d["light"] as PointLight2D).enabled and (d["light"] as PointLight2D).energy > 0.4, "gündüz pencere ışığı açık")
	for d: Dictionary in light.window_night_lights():
		assert(not (d["light"] as PointLight2D).enabled, "gündüz ay halesi kapalı")
	var fan: PointLight2D = light.window_day_lights()[0]["light"]
	assert(fan.texture == LightScript.FAN_TEX and is_equal_approx(fan.energy, 0.6), "kuzey yelpaze şiddeti 0,6")
	light.clock_override = NIGHT_TIME
	light._process(0.016)
	assert(light.darkness > 0.999, "gece karanlık 1")
	assert(_close(light.ambient.color, Color(0.42, 0.37, 0.48)), "gece ortam rengi: %s" % str(light.ambient.color))
	assert(is_equal_approx(mum.energy, 0.85), "gece kaynak tam şiddet: %f" % mum.energy)
	for d: Dictionary in light.window_day_lights():
		assert(not (d["light"] as PointLight2D).enabled, "gece pencere yelpazesi kapalı")
	for d: Dictionary in light.window_night_lights():
		assert((d["light"] as PointLight2D).enabled and is_equal_approx((d["light"] as PointLight2D).energy, 0.45), "gece ay halesi")
	_cleanup()


func test_lighting_only_while_inside_the_house() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var light: CozyEvLight = w["light"]
	## oyun başı: oyuncu evin içinde doğar
	assert(w["player"].is_indoors, "oyuncu evde başlar")
	assert(light.ambient.is_visible_in_tree(), "içeride ortam rengi (CanvasModulate) açık")
	assert((light.source_lights()[0]["light"] as PointLight2D).is_visible_in_tree(), "içeride ışıklar açık")
	house._do_exit_house()
	assert(not light.ambient.is_visible_in_tree(), "dışarıda CanvasModulate kapalı (dünya etkilenmez)")
	assert(not (light.source_lights()[0]["light"] as PointLight2D).is_visible_in_tree(), "dışarıda ışıklar kapalı")
	assert(get_tree().get_nodes_in_group("_canvas_modulate_%d" % get_viewport().world_2d.canvas.get_id()).filter(
		func(n: Node) -> bool: return (n as CanvasItem).is_visible_in_tree()).is_empty(), "dışarıda görünür CanvasModulate yok")
	house._do_enter_house()
	assert(light.ambient.is_visible_in_tree(), "geri girince yine açık")
	_cleanup()


func test_light_giving_furniture_draws_unlit() -> void:
	var w: Dictionary = _make_house()
	var house: Node2D = w["house"]
	var interior: Node2D = house._interior_instance
	var checked: Dictionary = {}
	for child: Node in interior.get_children():
		var layer := child as TileMapLayer
		if layer == null:
			continue
		for c: Vector2i in layer.get_used_cells():
			var src := layer.tile_set.get_source(layer.get_cell_source_id(c)) as TileSetAtlasSource
			var tex: String = src.texture.resource_path.get_file()
			var td: TileData = src.get_tile_data(layer.get_cell_atlas_coords(c), layer.get_cell_alternative_tile(c))
			var unlit: bool = td.material is CanvasItemMaterial and (td.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED
			if tex in ["Candles.png", "Fireplace.png", "Kazan_ocak.png"]:
				assert(unlit, "%s karosu %s ışıksız olmalı" % [tex, str(c)])
				checked[tex] = true
			elif layer.name == "zemin" or layer.name == "Duvarlar":
				assert(not unlit, "%s / %s ışık almalı" % [layer.name, tex])
	assert(checked.size() == 3, "mum + şömine + kazan karoları bulundu: %s" % str(checked.keys()))
	for wd: Dictionary in house._windows:
		var src := (wd["layer"] as TileMapLayer).tile_set.get_source(int(wd["sid"])) as TileSetAtlasSource
		assert(src.get_tile_data(Vector2i(1, 0), 0).material != null, "gündüz camı ışıksız")
		assert(src.get_tile_data(Vector2i(0, 0), 0).material == null, "gece camı ışık alır (ay halesi)")
	_cleanup()


func test_overlays_above_players_stay_unlit_indoors() -> void:
	var w: Dictionary = _make_house()
	var light: CozyEvLight = w["light"]
	var p: Node = w["player"]
	var bar := Node2D.new()
	bar.name = "OverheadBar"
	var icon := Sprite2D.new()
	bar.add_child(icon)
	p.add_child(bar)
	var sprite := Sprite2D.new()
	sprite.name = "AnimatedSprite2D"
	p.add_child(sprite)
	light._keep_overlays_unlit()
	assert(bar.material == CozyEvLight.unlit_material(), "can çubuğu ışıksız")
	assert(icon.use_parent_material, "çubuğun çocukları ebeveyn malzemesini kullanır")
	assert(sprite.material == null, "karakter karesi ışık alır")
	_cleanup()


func test_every_tile_quadrant_stays_within_the_light_budget() -> void:
	## Godot 2D çizim öğesi başına en fazla 16 ışık; alacakaranlıkta (gündüz + gece pencere ışıkları birlikte açık) bile her karo
	## dörtgeni sınırın altında kalmalı (fazlası sessizce düşer -> dörtgen sınırında ışık kesilir). Eve mum/lamba eklenince bunu koş.
	var w: Dictionary = _make_house()
	var light: CozyEvLight = w["light"]
	var interior: Node2D = w["house"]._interior_instance
	var rects: Array[Rect2] = []
	for d: Dictionary in light.source_lights() + light.window_day_lights() + light.window_night_lights():
		var l: PointLight2D = d["light"]
		var fire: bool = not is_nan(float(d.get("phase", NAN)))
		## ateşin texture_scale'i titremeyle 0,9..1,1 arası: taban boy x 1,1 (en büyük hâli)
		var size: Vector2 = l.texture.get_size() * l.scale * (1.1 if fire else l.texture_scale)
		rects.append(Rect2(l.position - size * 0.5, size))
	var q: float = CozyEvLight.LIGHT_QUADRANT * 16.0
	var worst: int = 0
	for child: Node in interior.get_children():
		if child is TileMapLayer:
			assert((child as TileMapLayer).rendering_quadrant_size == CozyEvLight.LIGHT_QUADRANT, "%s dörtgen boyu" % child.name)
	for qy in range(0, 3):
		for qx in range(0, 5):
			var qr := Rect2(Vector2(qx, qy) * q, Vector2(q, q))
			var n: int = 0
			for r: Rect2 in rects:
				if r.intersects(qr):
					n += 1
			worst = maxi(worst, n)
			assert(n <= CozyEvLight.MAX_LIGHTS_PER_ITEM, "dörtgen %s: %d ışık (sınır %d)" % [str(qr), n, CozyEvLight.MAX_LIGHTS_PER_ITEM])
	assert(worst >= 8, "sayım çalışıyor: en kötü %d" % worst)
	_cleanup()
