extends Node

func test_items_defs_exist() -> void:
	assert(Items.KEYS.size() > 0, "Items keys are empty!")
	for key in Items.KEYS:
		var def = Items.get_def(key)
		assert(def.size() > 0, "Item definition for %s is empty!" % key)
		assert(def.has("name"), "Item %s has no name!" % key)
		assert(def.has("desc"), "Item %s has no desc!" % key)
		assert(def.has("cost_base"), "Item %s has no cost_base!" % key)

func test_chest_drop_tier_sprite_frame() -> void:
	var scene = load("res://scenes/chest_drop.tscn")
	var drop = scene.instantiate()
	add_child(drop)
	drop._ready() # Force ready
	
	drop.chest_tier = 0
	assert(drop.sprite.frame == 0, "Chest tier 0 should map to frame 0")
	assert(drop.sprite.texture != null and "chest_tier_1_2.png" in str(drop.sprite.texture.get_meta("path", "")), "Expected chest_tier_1_2 texture")
	
	drop.chest_tier = 2
	assert(drop.sprite.frame == 0, "Chest tier 2 should also start at frame 0")
	assert(drop.sprite.texture != null and "chest_tier_5_6.png" in str(drop.sprite.texture.get_meta("path", "")), "Expected chest_tier_5_6 texture")
	
	drop.free()

func test_chest_menu_setup_populates_cards() -> void:
	var menu_scene = load("res://scenes/chest_menu.tscn")
	var menu = menu_scene.instantiate()
	add_child(menu)
	
	# Create a dummy player node with required methods
	var dummy_player = Node2D.new()
	dummy_player.add_to_group("player")
	# Add scripts or helper methods mock
	var script = GDScript.new()
	script.source_code = """
extends Node2D
func get_max_item_slots() -> int:
	return 2
func buy_item(key: String) -> bool:
	return true
"""
	script.reload()
	dummy_player.set_script(script)
	add_child(dummy_player)
	
	# Setup menu
	menu.setup(dummy_player, 1)
	
	# Check title
	assert(menu.title_label.text == "KADEME 3-4 SANDIK", "Expected KADEME 3-4 SANDIK for tier 1")
	
	# Check cards count
	var cards = menu.cards_container.get_children()
	assert(cards.size() == 3, "Expected exactly 3 cards")
	
	# Check card structure
	var first_card = cards[0]
	assert(first_card is PanelContainer, "Card should be PanelContainer")
	
	menu.free()
	dummy_player.free()
