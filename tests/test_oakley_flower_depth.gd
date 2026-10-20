extends Node

## Oakley çiçeği y-sıralaması (2026-10-19, kullanıcı: "çiçek Y eksenine tabi değil bazı şeylerin üstünde duruyor"): eskiden z 5'te
## oyuncu/yaratık/ağaç kopyalarının hepsinin üstündeydi. Kural (oakley_flower.gd DERİNLİK notu): z 0 + yaratık ayak sırası (ysort_props),
## arkasında duran karakter varsa z 2, ağaç/ev ön kopyaları örter (depth_props).

const FlowerScript: GDScript = preload("res://scripts/oakley_flower.gd")
const DepthScript: GDScript = preload("res://scripts/depth_occluders.gd")

var _made: Array[Node] = []


func _flower(pos: Vector2) -> Node2D:
	var f := Node2D.new()
	f.set_script(FlowerScript)
	add_child(f)
	f.global_position = pos
	f.call("setup", 40.0, "depth_test")
	_made.append(f)
	return f


## Ayağı (kök + FEET_OFFSET) verilen noktada duran sahte oyuncu (depth_occluders.character_nodes "player" grubunu okur).
func _char_at_feet(feet: Vector2) -> Node2D:
	var p := Node2D.new()
	add_child(p)
	p.add_to_group("player")
	p.global_position = feet - Vector2(0.0, DepthScript.FEET_OFFSET)
	_made.append(p)
	return p


func _cleanup() -> void:
	for n in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func test_flower_sits_low_and_joins_depth_groups() -> void:
	var f: Node2D = _flower(Vector2(500.0, 500.0))
	assert(f.z_index == FlowerScript.FLOWER_Z and f.z_index < 1, "çiçek oyuncuların (z 1) altında başlamalı - eskiden z 5")
	assert(f.is_in_group(FlowerScript.YSORT_GROUP) and f.is_in_group(FlowerScript.DEPTH_GROUP))
	assert(f.get_node_or_null("AnimatedSprite2D") is AnimatedSprite2D, "main.gd/depth_occluders görseli bu adla buluyor")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.contains('"%s"]' % FlowerScript.YSORT_GROUP), "main.gd CREATURE_SORT_GROUPS ysort_props'u içermeli")
	var occ_src: String = FileAccess.get_file_as_string("res://scripts/depth_occluders.gd")
	assert(occ_src.contains('"%s"]' % FlowerScript.DEPTH_GROUP), "depth_occluders.update_creatures depth_props'u okumalı")
	_cleanup()


func test_character_behind_flower_goes_under_it() -> void:
	var f: Node2D = _flower(Vector2(500.0, 500.0))
	var base_y: float = 500.0 + FlowerScript.FOOT_Y
	## filiz (aşama 0, 14 px boy): ayağı kökün 6 px üstünde -> arkasında, çiçek üste
	var p: Node2D = _char_at_feet(Vector2(503.0, base_y - 6.0))
	f.call("_update_depth")
	assert(f.z_index == FlowerScript.FLOWER_FRONT_Z, "arkasındaki oyuncunun üstüne çıkmalı")
	## önünde (ayağı kökün altında) -> oyuncu üstte kalır
	p.global_position.y = base_y + 4.0 - DepthScript.FEET_OFFSET
	f.call("_update_depth")
	assert(f.z_index == FlowerScript.FLOWER_Z, "önündeki oyuncunun altında kalmalı")
	## çiçeğin tepesinden yukarıda (gövdeleri örtüşmüyor) -> yükselmeye gerek yok
	p.global_position.y = base_y - 30.0 - DepthScript.FEET_OFFSET
	f.call("_update_depth")
	assert(f.z_index == FlowerScript.FLOWER_Z, "filiz 14 px - 30 px yukarıdaki oyuncuyla örtüşmez")
	## büyüyünce (aşama 2, 34 px) aynı oyuncu artık çiçeğin arkasında
	f.set("_growth_stage", 2)
	f.call("_update_depth_body")
	f.call("_update_depth")
	assert(f.z_index == FlowerScript.FLOWER_FRONT_Z, "açmış çiçek (34 px) 30 px yukarıdaki oyuncuyu örter")
	var body: Vector2 = f.get_meta("_depth_body")
	assert(body.y >= 34.0, "ağaç kopyası örtüsü büyümüş boyu kullanmalı")
	## yatayda uzak -> örtüşme yok
	p.global_position.x = 560.0
	f.call("_update_depth")
	assert(f.z_index == FlowerScript.FLOWER_Z)
	_cleanup()
