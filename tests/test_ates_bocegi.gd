extends Node

## Ana haritanın gece ateş böcekleri (madde 761): alanlar ana haritanın oyun alanında, hale menüdeki gibi DÜZ alfa bantları (benek yok),
## böcekler alanının sınırında kalır, yanıp söner, yalnız ana haritada (+ test haritası) açık, zemin ışığı overlay'in sağlayıcı grubunda.

const FxScript := preload("res://scripts/ates_bocegi_fx.gd")
const MetaScript := preload("res://scripts/ana_harita_bocek_meta.gd")
const MapProfiles := preload("res://scripts/map_profiles.gd")
const AtmosphereOverlay := preload("res://scripts/atmosphere_overlay.gd")


func test_zones_inside_main_play_area() -> void:
	var zones: Array = MetaScript.FIREFLY_ZONES
	assert(zones.size() >= 20 and zones.size() <= 60, "alan sayısı %d" % zones.size())
	for z: Array in zones:
		var c: Vector2 = z[0]
		var r: float = z[1]
		assert(c.x > r and c.y > r and c.x < 4096.0 - r and c.y < 4096.0 - r, "alan oyun alanı dışında: %s" % c)
		assert(r >= 40.0 and r <= 120.0)


func test_feature_only_main_and_test_map() -> void:
	assert(MapProfiles.profile_feature("ana", "ates_bocekleri"))
	assert(MapProfiles.profile_feature(MapProfiles.TEST_ID, "ates_bocekleri"))
	for id: String in MapProfiles.ids():
		if id == "ana" or id == MapProfiles.TEST_ID:
			continue
		assert(not MapProfiles.profile_feature(id, "ates_bocekleri"), "başka haritada açık: " + id)


func test_glow_is_flat_bands_no_dither() -> void:
	var img: Image = FxScript.make_glow().get_image()
	var allowed: Array[float] = [0.0, 0.08, 0.2, 0.45, 1.0]
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var a: float = img.get_pixel(x, y).a
			var ok := false
			for v in allowed:
				if absf(a - v) < 0.01:
					ok = true
			assert(ok, "beklenmeyen alfa %f (%d,%d)" % [a, x, y])
	## halkalar merkezden dışa azalır (aynı uzaklıkta aynı alfa = düz bant)
	assert(img.get_pixel(7, 7).a > img.get_pixel(8, 7).a)
	assert(img.get_pixel(8, 7).a > img.get_pixel(10, 7).a)
	assert(img.get_pixel(10, 7).a > img.get_pixel(13, 7).a)
	assert(is_equal_approx(img.get_pixel(0, 0).a, 0.0))


func test_bugs_stay_in_zone_bound_and_blink() -> void:
	var xf := Transform2D(0.0, Vector2(-2.0, 21.0))
	var zones: Array = FxScript.build_zones(MetaScript.FIREFLY_ZONES, xf)
	assert(zones.size() == MetaScript.FIREFLY_ZONES.size())
	## sabit tohum: iki kurulum aynı
	var again: Array = FxScript.build_zones(MetaScript.FIREFLY_ZONES, xf)
	assert(Vector2(zones[3][1][0]["pos"]) == Vector2(again[3][1][0]["pos"]))
	for zone: Array in zones:
		var bound: Rect2 = zone[0]
		var bugs: Array = zone[1]
		assert(bugs.size() >= FxScript.BUGS_MIN and bugs.size() <= FxScript.BUGS_MAX)
		for f: Dictionary in bugs:
			var lit := 0
			for i in range(60):
				var t: float = i * 0.37
				assert(bound.has_point(FxScript.bug_position(f, t)), "böcek alan dışına çıktı")
				var b: float = FxScript.bug_brightness(f, t)
				assert(b >= 0.0 and b <= 1.0)
				if b > 0.5:
					lit += 1
			assert(lit > 0 and lit < 60, "böcek hiç yanmıyor ya da hiç sönmüyor (%d)" % lit)


func test_light_provider_group_and_night_lights() -> void:
	assert(FxScript.LIGHT_PROVIDER_GROUP == AtmosphereOverlay.LIGHT_PROVIDER_GROUP)
	var fx: CanvasLayer = FxScript.new()
	add_child(fx)
	fx.set("_zones", FxScript.build_zones(MetaScript.FIREFLY_ZONES, Transform2D.IDENTITY))
	assert(fx.is_in_group(FxScript.LIGHT_PROVIDER_GROUP))
	## gündüz / gizliyken ışık yok
	assert(fx.call("get_night_lights").is_empty())
	fx.visible = true
	fx.set("_alpha", 1.0)
	fx.set("_visible_zones", PackedInt32Array([0, 1, 2, 3]))
	var best := 0
	for i in range(40):
		fx.set("_t", i * 0.31)
		var lights: Array = fx.call("get_night_lights")
		best = maxi(best, lights.size())
		for l: Array in lights:
			assert(l.size() == 4 and float(l[1]) > 0.0 and float(l[3]) > 0.0 and float(l[3]) <= FxScript.LIGHT_ENERGY)
	assert(best > 0, "gece yanan böcek ışık vermedi")
	fx.queue_free()
