extends Node

## Yemek ikonları (2026-11-11): beş kademe kullanıcının 32x32 çizimleri - her kademenin dosyası var, 32x32, birbirinden farklı,
## sahnede tam 1x çizilir (nearest filtrede kesirli ölçek bazı piksel sütunlarını çiftler).

const FoodScene: PackedScene = preload("res://scenes/food_drop.tscn")
const FoodDrop: GDScript = preload("res://scripts/food_drop.gd")


func test_every_tier_has_a_distinct_32px_icon() -> void:
	var seen: Dictionary = {}
	for tier in range(1, 6):
		assert(FoodDrop.FOOD_TIER_TEXTURES.has(tier), "kademe %d ikon yolu" % tier)
		var path: String = FoodDrop.FOOD_TIER_TEXTURES[tier]
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(path))
		assert(img != null, "kademe %d dosyasi okunur: %s" % [tier, path])
		assert(img.get_width() == 32 and img.get_height() == 32, "kademe %d ikonu 32x32 (%dx%d)" % [tier, img.get_width(), img.get_height()])
		assert(not seen.has(path), "kademe %d ikonu baska kademeyle ayni dosya" % tier)
		seen[path] = true


func test_icon_drawn_at_native_scale() -> void:
	for tier in range(1, 6):
		var food: Area2D = FoodScene.instantiate()
		add_child(food)
		food.tier = tier
		var s: Sprite2D = food.get("sprite") as Sprite2D
		assert(s != null and s.texture != null, "kademe %d dokusu yuklendi" % tier)
		assert(is_equal_approx(s.scale.x, 1.0) and is_equal_approx(s.scale.y, 1.0), "kademe %d tam 1x (%s)" % [tier, str(s.scale)])
		food.free()
