extends Node

## 2026-10-02: eski ekstralar silindi, liste boş olabilir (kullanıcı yenilerini tasarlıyor) - tanımlı olanlar eksiksiz olmalı.
func test_items_defs_exist() -> void:
	assert(Items.KEYS.size() == Items.DEFS.size(), "KEYS ile DEFS aynı eşyaları listelemeli")
	for key in Items.KEYS:
		var def = Items.get_def(key)
		assert(def.size() > 0, "Item definition for %s is empty!" % key)
		assert(def.has("name"), "Item %s has no name!" % key)
		## 2026-10-02 yeni eşya sistemi: açıklama statlardan üretilir (Items.describe), fiyat "cost", kademe 1-3.
		assert(Items.describe(key) != "", "Item %s has no description!" % key)
		assert(def.has("cost") and int(def["cost"]) > 0, "Item %s has no cost!" % key)
		assert(int(def.get("kademe", 0)) in [1, 2, 3], "Item %s has no kademe!" % key)

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
	assert(menu.title_label.text == "KADEME III-IV SANDIK", "Expected KADEME III-IV SANDIK for tier 1")
	
	## Kullanıcı kararları: sandıktan 3 aday yerine TEK kart çıkar ve açılış animasyonu bitince (kapak patlayınca) sandığın içinden
	## fırlar - setup sonrası kart alanı GİZLİ ve boş; kart _reveal_reward_card ile gelir. 2026-10-02'den beri sadece parça
	## (1. kademe) eşyalar çıkar. _build_card kart + altındaki AL/SAT satırlarından oluşan bir sütun döndürür (2026-10-03 test güncellemesi).
	assert(not menu.cards_container.visible, "Açılış animasyonu sürerken kart alanı gizli olmalı")
	var parts: Array = Items.KEYS.filter(func(k): return Items.kademe(str(k)) == Items.KADEME_PARCA)
	assert(not parts.is_empty(), "Sandık havuzunda parça eşya olmalı")
	for c in menu.cards_container.get_children():
		menu.cards_container.remove_child(c)
		c.queue_free()
	await menu._reveal_reward_card({"type": "item", "key": str(parts[0])})
	var cards = menu.cards_container.get_children()
	assert(cards.size() == 1, "Sandıktan tek kart çıkmalı, bulunan: %d" % cards.size())
	
	# Check card structure
	var first_card = cards[0].get_child(0)
	assert(first_card is PanelContainer, "Card should be PanelContainer")
	
	menu.free()
	dummy_player.free()
