extends Node

func _make_hud() -> Node:
	var scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: Node = scene.instantiate()
	add_child(hud)
	hud._ready()
	var inv: Control = hud.get_node("InventoryPanelInstance") as Control
	if inv:
		inv._ready()
	return hud

func test_inventory_mmorpg_layout_nodes_constructed() -> void:
	var hud: Node = _make_hud()
	var inv: Control = hud.get_node("InventoryPanelInstance") as Control
	assert(inv != null, "InventoryPanelInstance must exist")
	
	# Verify dynamic grid nodes
	assert(inv.weapons_grid != null, "weapons_grid must be created")
	assert(inv.equip_grid != null, "equip_grid must be created")
	assert(inv.mods_grid != null, "mods_grid must be created")
	assert(inv.items_grid_box != null, "items_grid_box must be created")
	
	hud.queue_free()

func test_inventory_mod_drag_source_get_drag_data() -> void:
	# Mock GameManager levels
	GameManager.set("shield_mod_resilience_level", 0)
	var drag_source: Button = load("res://scripts/inventory_mod_drag_source.gd").new() as Button
	add_child(drag_source)
	
	# Set up
	var tex: ImageTexture = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	drag_source.setup("resilience", tex)
	
	# Should return null if level <= 0
	var data: Variant = drag_source._get_drag_data(Vector2.ZERO)
	assert(data == null, "Should not allow drag if battle mode is locked (level 0)")
	
	# Unlock and check drag data
	GameManager.set("shield_mod_resilience_level", 1)
	var data_unlocked: Variant = drag_source._get_drag_data(Vector2.ZERO)
	assert(data_unlocked is Dictionary, "Should return drag data dict when unlocked")
	var data_dict: Dictionary = data_unlocked as Dictionary
	assert(data_dict.get("type") == "battle_mode", "Expected type to be battle_mode")
	assert(data_dict.get("mode") == "resilience", "Expected mode to be resilience")
	
	drag_source.free()

func test_hud_slot_drop_handler_can_drop_and_drop() -> void:
	var hud: Node = _make_hud()
	var slot: Button = hud.shield_mode_slots[0] as Button
	
	# Test _can_drop_data
	GameManager.set("shield_mod_resilience_level", 0)
	var can_drop_locked: bool = slot._can_drop_data(Vector2.ZERO, {"type": "battle_mode", "mode": "resilience"})
	assert(can_drop_locked == false, "Should not accept drop if locked (level 0)")
	
	GameManager.set("shield_mod_resilience_level", 1)
	var can_drop_unlocked: bool = slot._can_drop_data(Vector2.ZERO, {"type": "battle_mode", "mode": "resilience"})
	assert(can_drop_unlocked == true, "Should accept drop if unlocked (level > 0)")
	
	# Test _drop_data
	slot._drop_data(Vector2.ZERO, {"type": "battle_mode", "mode": "resilience"})
	var hud_slots: Array = GameManager.get_meta("hud_shield_slots") as Array
	assert(hud_slots[0] == "resilience", "Expected resilience to be assigned to HUD slot 0")
	
	hud.queue_free()
