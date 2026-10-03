extends Node

func _make_hud() -> Node:
	var scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: Node = scene.instantiate()
	add_child(hud)
	## (2026-10-03) add_child zaten _ready'yi çalıştırıyor; Godot 4.7'de elle _ready() @onready'leri yeniden çözüyor ve
	## _ready'de başka katmana taşınan InventoryPanelInstance'ı null yapıyordu - ikinci çağrı kaldırıldı.
	return hud

func test_inventory_mmorpg_layout_nodes_constructed() -> void:
	var hud: Node = _make_hud()
	## hud._ready paneli üst katmana (party_layer) taşıyor - yol değişir, HUD'un referansı geçerli kalır.
	var inv: Control = hud.inventory_panel_instance as Control
	assert(inv != null and is_instance_valid(inv), "InventoryPanelInstance must exist")
	
	# Verify dynamic grid nodes
	assert(inv.weapons_grid != null, "weapons_grid must be created")
	assert(inv.equip_grid != null, "equip_grid must be created")
	assert(inv.items_grid_box != null, "items_grid_box must be created")
	
	hud.queue_free()
