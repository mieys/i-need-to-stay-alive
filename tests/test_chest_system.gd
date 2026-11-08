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

## 2026-11-06 (madde 409): İLK sürümün paket sandıkları geri geldi - kademe bandı (chest_tier 0-5) sandığın görünüşünü seçer,
## elit ayrı paket sandığı; 20 kare x 32 px, 0,8 ölçek; ışık sütunu ve ek gölge yok (ChestArt.BEAM_ENABLED / EXTRA_SHADOW).
func test_chest_drop_uses_pack_sheet_by_kademe() -> void:
	var drop = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
	add_child(drop)
	assert(drop.sprite.texture.resource_path.ends_with("chests/paket_k0.png"), "kademe I-II sandığı: %s" % drop.sprite.texture.resource_path)
	assert(drop.sprite.hframes == 20 and drop.sprite.vframes == 1, "sayfa 20 yatay kare olmalı")
	assert(drop.sprite.frame == 0, "kapalı sandık karesiyle başlamalı")
	assert(drop.sprite.texture.get_width() == 32 * 20 and is_equal_approx(drop.sprite.scale.x, 0.8), "32 px kare, 0,8 ölçek (ilk sürüm)")
	assert(drop.get_node_or_null("Beam") == null, "ışık sütunu yok")
	assert(drop.get_node_or_null("Shadow") == null, "üretilmiş ek gölge yok (paket sanatının kendi gölgesi var)")
	var chest_bottom: Vector2 = drop.sprite.position + (Vector2(16, 31) - Vector2(16, 16)) * drop.sprite.scale
	assert(is_equal_approx(chest_bottom.y, 8.0), "sandık tabanı kökün 8 px altında: %s" % chest_bottom)
	drop.chest_tier = 3
	assert(drop.sprite.texture.resource_path.ends_with("chests/paket_k3.png"), "kademe bandı görseli değiştirir (ilk sürümdeki gibi)")
	drop.is_elite = true
	assert(drop.sprite.texture.resource_path.ends_with("chests/paket_elite.png"), "elit sandık elit sayfayı kullanmalı")
	drop.free()


## Paket sayfaları gerçekten ilk sürümün çizimleri: kapalı kare = chest_tier_*.png'nin ilk karesi (piksel piksel).
func test_pack_sheets_are_original_art() -> void:
	var names := ["chest_tier_1_2", "chest_tier_3_4", "chest_tier_5_6", "chest_tier_7_8", "chest_tier_9_10", "chest_tier_11_up"]
	for k in names.size():
		var src: Image = (load("res://assets/sprites/%s.png" % names[k]) as Texture2D).get_image()
		var sheet: Image = (load("res://assets/sprites/chests/paket_k%d.png" % k) as Texture2D).get_image()
		for y in 32:
			for x in 32:
				assert(src.get_pixel(x, y).is_equal_approx(sheet.get_pixel(x, y)), "%s kapalı kare birebir (%d,%d)" % [names[k], x, y])


## Gece ışığı (madde 243): sandık katalogda, rengi sütunla aynı (normal sıcak altın / elit mor), kalıcı (ışık bütçesine takılmaz).
func test_chest_beam_glows_at_night() -> void:
	get_tree().current_scene = self
	var Catalog: GDScript = load("res://scripts/night_glow_catalog.gd")
	var AtmosphereScript: GDScript = load("res://scripts/atmosphere.gd")
	var atmo := Node2D.new()
	atmo.set_script(AtmosphereScript)
	add_child(atmo)
	for elite: bool in [false, true]:
		var drop = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
		drop.is_elite = elite
		add_child(drop)
		var raw: Dictionary = Catalog.profile_for(drop)
		assert(bool(raw.get("perm", false)), "sandık ışığı kalıcı olmalı (yerde uzun kalır, bütçe doluyken de yansın)")
		var prof: Dictionary = Catalog.resolve(drop, raw)
		var want: Color = Color(0.86, 0.64, 1.0) if elite else Color(1.0, 0.8, 0.45)
		assert((prof["color"] as Color).is_equal_approx(want), "ışık rengi sütunla aynı (elit=%s): %s" % [elite, prof["color"]])
		atmo._attach_glow(drop, raw)
		var glow: Node = drop.get_node_or_null("NightGlow")
		assert(glow != null and glow.is_in_group(AtmosphereScript.PERM_GLOW_GROUP), "sandığa kalıcı gece ışığı takılmalı")
		drop.free()
	atmo.free()


## Ödül ekranı: kutu yine 384 px (yerleşim aynı), sandık tam kat (8x) ve kademe bandının sandığı; sütun yok, atlama çalışır.
func test_reward_screen_chest_matches_kademe() -> void:
	var anim: Control = (load("res://scripts/chest_open_anim.gd") as GDScript).new()
	anim.setup(false, 2, 4)
	add_child(anim)
	assert(anim.custom_minimum_size == Vector2(384, 384), "ödül ekranı kutusu yine 384 px")
	var rect: TextureRect = anim.get("_rect")
	assert(rect.size == Vector2(256, 256), "sandık 32 px x 8 tam kat: %s" % rect.size)
	assert((rect.texture as AtlasTexture).atlas.resource_path.ends_with("chests/paket_k4.png"), "kademe bandı 4 sandığı")
	assert(anim.get("_beam_rect") == null, "ışık sütunu yok")
	anim.skip()
	anim.free()


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


## Çift açılış düzeltmesi (2026-10-12): host teması + istemci isteği aynı sandığı iki kez ödüllendirmemeli (hangi sırayla gelirse gelsin).
func _sfx_count(drop: Node) -> int:
	var n: int = 0
	for c in drop.get_children():
		if c is AudioStreamPlayer2D:
			n += 1
	return n


func test_chest_is_awarded_only_once_via_open_for_player() -> void:
	var drop = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
	add_child(drop)
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	drop._open_for_player(p)
	assert(drop._awarded and drop.get_meta("claimed", false), "ilk açılış sandığı işaretlemeli")
	drop._open_for_player(p) ## ikinci giriş (ör. aynı anda gelen RPC)
	assert(_sfx_count(drop) == 1, "ikinci açılış hiçbir şey yapmamalı (tek açılış sesi): %d" % _sfx_count(drop))
	p.remove_from_group("player")
	p.queue_free()
	drop.queue_free()


func test_body_contact_after_rpc_claim_does_nothing() -> void:
	var drop = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
	add_child(drop)
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	drop._awarded = true ## istemci isteği sandığı zaten ödüllendirdi
	drop._on_body_entered(p)
	assert(not drop._is_opening and _sfx_count(drop) == 0, "ödüllendirilmiş sandığa temas yeni açılış başlatmamalı")
	p.remove_from_group("player")
	p.queue_free()
	drop.queue_free()
