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


## Masaüstü "Kahraman Çantası" (madde 341): tıklamak seçer, satış kartın SAT düğmesiyle; son silah / kalkan satılmaz; özellikler çantanın
## içinde (ayrı stats paneli açılmaz).
func test_hero_chest_select_sell_and_no_separate_stats_panel() -> void:
	var hud: Node = _make_hud()
	var inv: Control = hud.inventory_panel_instance as Control
	var saved_items: Array = GameManager.owned_items.duplicate(true)
	var saved_weapons: Array = GameManager.owned_weapons.duplicate(true)
	var saved_gold: int = GameManager.gold
	var key: String = ""
	for k in Items.DEFS.keys():
		if Items.sell_refund(str(k)) > 0 and Items.icon(str(k)) != null:
			key = str(k)
			break
	GameManager.owned_items = [{"key": key, "spent": 0}]
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("dagger", 1, 0)]
	GameManager.gold = 50
	hud._on_envanter_toggle()
	assert(inv.visible, "envanter açılır")
	assert(not hud.stats_panel_instance.visible, "masaüstünde özellikler çantanın içinde, ayrı panel açılmaz")
	await get_tree().process_frame
	assert(inv._item_slot_icons.has(0), "heybe yuvası kuruldu")
	inv._on_sell_item(0)
	assert(GameManager.owned_items.size() == 1, "tıklamak (seçmek) satmaz")
	assert(inv._ch_sell_btn != null and not inv._ch_sell_btn.disabled, "eşya kartında SAT var")
	inv._ch_sell_btn.pressed.emit()
	assert(GameManager.owned_items.is_empty(), "SAT eşyayı satar")
	assert(GameManager.gold == 50 + Items.sell_refund(key), "altın tek kez: %d" % GameManager.gold)
	inv._ch_select("weapon", 0)
	assert(inv._ch_sell_btn != null and inv._ch_sell_btn.disabled, "son silah satılamaz")
	if inv._owned_shield_type() != "":
		inv._ch_select("shield", 0)
		assert(inv._ch_sell_btn == null, "mana kalkanında SAT yok")
	hud._on_envanter_toggle()
	assert(not inv.visible)
	GameManager.owned_items = saved_items
	GameManager.owned_weapons = saved_weapons
	GameManager.gold = saved_gold
	hud.queue_free()
