extends Node

## Madde 525: Kara Bataklık'ta su yürünür + suya giren ayak örtüsü (scripts/wade_fx.gd). Uçanlar (oyuncu durumları + uçan yaratık aileleri)
## suya girmez; su maskesi derin suda dolu, karada boş; ana haritada su engel kalır.

const WadeScript := preload("res://scripts/wade_fx.gd")
const MapProfiles: GDScript = preload("res://scripts/map_profiles.gd")
const Meta: GDScript = preload("res://scripts/bataklik_meta.gd")


func _fake(src: String) -> Node2D:
	var s := GDScript.new()
	s.source_code = "extends Node2D\n" + src
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	return n


func test_airborne_rules() -> void:
	var walker: Node2D = _fake("var _vampir_bat_form_active = false\nvar cadi_ride_host_peer = 0\n")
	assert(not WadeScript.is_airborne(walker))
	for src: String in ["var _vampir_bat_form_active = true\n", "var _cadi_broom = true\n", "var cadi_ride_host_peer = 7\n",
			"var _hadime_q_active = true\n", "var in_limbo = true\n", "var _matthew_ball = 2\n",
			"func is_buyucu_airborne() -> bool:\n\treturn true\n"]:
		var n: Node2D = _fake(src)
		assert(WadeScript.is_airborne(n), src)
		n.free()
	for fam: String in ["hayalet", "yarasa", "banshee", "rontgen", "ucansetan"]:
		var c: Node2D = _fake("func creature_family() -> String:\n\treturn \"%s\"\n" % fam)
		assert(WadeScript.is_airborne(c), fam)
		c.free()
	for fam: String in ["slime", "iskelet", "zombi", "mantar", "demon", "kabak"]:
		var c2: Node2D = _fake("func creature_family() -> String:\n\treturn \"%s\"\n" % fam)
		assert(not WadeScript.is_airborne(c2), fam)
		c2.free()
	walker.free()


func test_water_walkable_flag_and_mask() -> void:
	if OS.get_environment("HARITA") != "":
		return
	GameManager.selected_map = "ana"
	assert(not MapProfiles.water_walkable()) ## ana haritada su engel kalır
	GameManager.selected_map = "bataklik"
	assert(MapProfiles.water_walkable())
	var w: Node = WadeScript.new()
	add_child(w)
	assert(w.is_processing())
	assert(float(w.call("water_at", Meta.SPAWN)) == 0.0) ## doğuş karada
	## maskede en derin suyu bul: değer 1'e yakın olmalı; kıyı (0'dan büyük, küçük) de var
	var img: Image = (load(str(MapProfiles.current()["su_maskesi"])) as Texture2D).get_image()
	var deep := Vector2.INF
	var shallow := Vector2.INF
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var v: float = img.get_pixel(x, y).r
			if v > 0.99 and deep == Vector2.INF:
				deep = Vector2(x * 2 + 1, y * 2 + 1)
			if v > 0.0 and v < 0.15 and shallow == Vector2.INF:
				shallow = Vector2(x * 2 + 1, y * 2 + 1)
	assert(deep != Vector2.INF and shallow != Vector2.INF)
	assert(float(w.call("water_at", deep)) > 0.95)
	var sv: float = float(w.call("water_at", shallow))
	assert(sv > 0.0 and sv < 0.2)
	w.queue_free()
	GameManager.selected_map = "ana"
