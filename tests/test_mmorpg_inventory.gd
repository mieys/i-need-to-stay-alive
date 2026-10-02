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
	assert(inv.items_grid_box != null, "items_grid_box must be created")
	
	hud.queue_free()
