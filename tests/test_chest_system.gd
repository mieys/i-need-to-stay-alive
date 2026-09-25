extends Node

func test_items_defs_exist() -> void:
	assert(Items.KEYS.size() > 0, "Items keys are empty!")
	for key in Items.KEYS:
		var def = Items.get_def(key)
		assert(def.size() > 0, "Item definition for %s is empty!" % key)
		assert(def.has("name"), "Item %s has no name!" % key)
		assert(def.has("desc"), "Item %s has no desc!" % key)
		assert(def.has("cost_base"), "Item %s has no cost_base!" % key)

## 2026-09-25: sandıklar yeniden çizildi (tools/gen_chest_sprites.py, 20 kare x 48 px) - kademe artık görseli
## değiştirmiyor, normal/elit ayrımı değiştiriyor.
func test_chest_drop_uses_normal_or_elite_sheet() -> void:
	var drop = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
	add_child(drop)
	assert(drop.sprite.texture.resource_path.ends_with("chests/chest_normal_t1.png"), "normal sandık normal sayfayı kullanmalı")
	assert(drop.sprite.hframes == 20 and drop.sprite.vframes == 1, "sayfa 20 yatay kare olmalı")
	assert(drop.sprite.frame == 0, "kapalı sandık karesiyle başlamalı")
	drop.chest_tier = 3
	assert(drop.sprite.texture.resource_path.ends_with("chests/chest_normal_t1.png"), "kademe görseli değiştirmemeli")
	drop.is_elite = true
	assert(drop.sprite.texture.resource_path.ends_with("chests/chest_elite.png"), "elit sandık elit sayfayı kullanmalı")
	drop.free()


## Elit sandıklar ayrı sayaçta ama normal sandıklarla AYNI "bekleyen sandık var mı" kapısından geçer (main.gd sandık akışı).
func test_elite_chest_queue_counts_as_pending() -> void:
	var saved_tiers: Array = GameManager.pending_chest_tiers.duplicate()
	var saved_elite: int = GameManager.pending_elite_chests
	GameManager.pending_chest_tiers = []
	GameManager.pending_elite_chests = 0
	assert(not GameManager.has_pending_chests(), "boş kuyruk")
	GameManager.add_pending_elite_chest()
	assert(GameManager.has_pending_chests(), "tek elit sandık da bekleyen sandık sayılmalı")
	assert(GameManager.pop_pending_elite_chest(), "elit sandık çekilebilmeli")
	assert(not GameManager.pop_pending_elite_chest(), "boşken çekilememeli")
	assert(not GameManager.has_pending_chests(), "çekildikten sonra kuyruk boş")
	GameManager.pending_chest_tiers = saved_tiers
	GameManager.pending_elite_chests = saved_elite


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
