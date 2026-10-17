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
	assert(drop.sprite.texture.resource_path.ends_with("chests/chest_normal.png"), "normal sandık dünya sayfasını kullanmalı")
	assert(drop.sprite.hframes == 20 and drop.sprite.vframes == 1, "sayfa 20 yatay kare olmalı")
	assert(drop.sprite.frame == 0, "kapalı sandık karesiyle başlamalı")
	## 2026-10-17 (madde 242 "B Işık Sütunu"): 96 px kare x 0,5 = eski 48 dünya px; arkasında ayrı ışık sütunu sprite'ı.
	assert(drop.sprite.texture.get_width() == 96 * 20 and is_equal_approx(drop.sprite.scale.x, 0.5), "96 px kare, 0,5 ölçek")
	var beam: Sprite2D = drop.get_node_or_null("Beam")
	assert(beam != null and beam.texture.resource_path.ends_with("chests/chest_beam.png"), "normal sandığın arkasında ışık sütunu olmalı")
	assert(beam.get_index() < drop.sprite.get_index(), "ışık sütunu sandığın ARKASINDA çizilmeli")
	assert(beam.hframes == 37 and beam.texture.get_height() == 192, "sütun sayfası 37 kare x 128x192")
	## İki sprite'ta sandığın alt-ortası aynı dünya noktasına düşmeli (sütun sandıktan kaymasın).
	var chest_bottom: Vector2 = drop.sprite.position + (Vector2(48, 84) - Vector2(48, 48)) * drop.sprite.scale
	var beam_bottom: Vector2 = beam.position + (Vector2(64, 176) - Vector2(64, 96)) * beam.scale
	assert(chest_bottom.distance_to(beam_bottom) < 0.01, "sütun sandığın altına hizalı olmalı: %s / %s" % [chest_bottom, beam_bottom])
	assert(is_equal_approx(chest_bottom.y, 8.0), "sandık tabanı kökün 8 px altında (gölge ile aynı)")
	drop.chest_tier = 3
	assert(drop.sprite.texture.resource_path.ends_with("chests/chest_normal.png"), "kademe görseli değiştirmemeli")
	drop.is_elite = true
	assert(drop.sprite.texture.resource_path.ends_with("chests/chest_elite.png"), "elit sandık elit sayfayı kullanmalı")
	assert(beam.texture.resource_path.ends_with("chests/chest_beam_elite.png"), "elit sandığın sütunu elit sayfadan")
	drop.free()


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


## Açılışta ışık sütunu sandıkla eş: sallanmada 24-27, patlamadan sonra çöker ve biter (dünyada çökme 2 kat hızlı).
func test_chest_beam_frames_follow_open_sequence() -> void:
	var ChestArt: GDScript = load("res://scripts/chest_art.gd")
	assert(ChestArt.beam_frame_for_open(4) == 24 and ChestArt.beam_frame_for_open(7) == 27, "sallanma kareleri eş")
	assert(ChestArt.beam_frame_for_open(8) == 28, "patlamada çökme başlar")
	assert(ChestArt.beam_frame_for_open(12) == 36, "dünya açılışının son karesinde son çökme karesi")
	assert(ChestArt.beam_frame_for_open(13) == -1, "çökmeden sonra sütun gizlenir")
	var anim: Control = (load("res://scripts/chest_open_anim.gd") as GDScript).new()
	anim.setup(false, 2)
	add_child(anim)
	assert(anim.custom_minimum_size == Vector2(384, 384), "ödül ekranı sandığı yine 384 px")
	assert(anim.get("_beam_sheet").resource_path.ends_with("chests/chest_beam_t2.png"), "ödül ekranında sütun rengi = nadirlik")
	anim.skip()
	assert(not anim.get("_beam_rect").visible, "atlanınca sütun gizlenir")
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
