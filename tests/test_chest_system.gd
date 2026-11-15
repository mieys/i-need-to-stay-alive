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

## 2026-11-11 (madde 557): kullanıcının yeni sandık çizimleri - sıradan + elit, her biri 64x32 (kare 0 KAPALI, kare 1 AÇIK), 0,8 ölçek;
## kademe bandı görünüşü DEĞİŞTİRMEZ; ışık sütunu yok, gölge standart drop_shadow.gd (yeni çizimin kendi gölgesi yok).
func test_chest_drop_uses_new_sheets() -> void:
	var drop = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
	add_child(drop)
	assert(drop.sprite.texture.resource_path.ends_with("chests/sandik_normal.png"), "sıradan sandık: %s" % drop.sprite.texture.resource_path)
	assert(drop.sprite.hframes == 2 and drop.sprite.vframes == 1, "sayfa 2 yatay kare olmalı (kapalı, açık)")
	assert(drop.sprite.frame == 0, "yerdeki sandık KAPALI karede durmalı")
	assert(drop.sprite.texture.get_width() == 64 and drop.sprite.texture.get_height() == 32 and is_equal_approx(drop.sprite.scale.x, 0.8), "32 px kare, 0,8 ölçek")
	assert(drop.get_node_or_null("Beam") == null, "ışık sütunu yok")
	assert(drop.get_node_or_null("Shadow") == null, "eski üretilmiş ek gölge yok")
	var ShadowsFlag: GDScript = load("res://scripts/shadows_flag.gd")
	assert((drop.get_node_or_null("DropShadow") != null) == bool(ShadowsFlag.entities), "yer objesi gölgesi standart drop_shadow.gd (bayrak açıkken)")
	var chest_bottom: Vector2 = drop.sprite.position + (Vector2(16, 31) - Vector2(16, 16)) * drop.sprite.scale
	assert(is_equal_approx(chest_bottom.y, 8.0), "sandık tabanı kökün 8 px altında: %s" % chest_bottom)
	drop.chest_tier = 3
	assert(drop.sprite.texture.resource_path.ends_with("chests/sandik_normal.png"), "kademe bandı görünüşü değiştirmez (tek sıradan sandık)")
	drop.is_elite = true
	assert(drop.sprite.texture.resource_path.ends_with("chests/sandik_elit.png"), "elit sandık elit sayfayı kullanmalı")
	assert(drop.sprite.frame == 0, "elit de kapalı karede")
	drop.free()


## Tam saydam pikselin RGB'si içe aktarmada değişebilir: ikisi de saydamsa eşit say.
func _same_px(a: Color, b: Color) -> bool:
	return (a.a == 0.0 and b.a == 0.0) or a.is_equal_approx(b)


## Sayfalar gerçekten kullanıcının çizimleri: kare 0 = kapalı çizim (3 px aşağı, tabanlar hizalansın), kare 1 = açık çizim (piksel piksel).
func test_sheets_are_user_art() -> void:
	for kind: String in ["siradan", "elit"]:
		var closed: Image = Image.load_from_file(ProjectSettings.globalize_path("res://tools/chest_sanat/%s_kapali.png" % kind))
		var opened: Image = Image.load_from_file(ProjectSettings.globalize_path("res://tools/chest_sanat/%s_acik.png" % kind))
		var sheet: Image = (load("res://assets/sprites/chests/sandik_%s.png" % ("normal" if kind == "siradan" else "elit")) as Texture2D).get_image()
		assert(closed != null and opened != null, "%s kaynak çizimleri okunamadı" % kind)
		var base_closed: int = -1
		var base_open: int = -1
		for y in 32:
			for x in 32:
				assert(_same_px(sheet.get_pixel(32 + x, y), opened.get_pixel(x, y)), "%s açık kare birebir (%d,%d)" % [kind, x, y])
				var want: Color = closed.get_pixel(x, y - 3) if y >= 3 else Color(0, 0, 0, 0)
				assert(_same_px(sheet.get_pixel(x, y), want), "%s kapalı kare (3 px aşağıda) birebir (%d,%d)" % [kind, x, y])
				if sheet.get_pixel(x, y).a > 0.0:
					base_closed = maxi(base_closed, y)
				if sheet.get_pixel(32 + x, y).a > 0.0:
					base_open = maxi(base_open, y)
		assert(base_closed == 30 and base_open == 30, "%s: iki karede de son dolu satır 30 = taban kenarı 31 (açılırken yerinde kalmalı): %d / %d" % [kind, base_closed, base_open])


## Envanter simgesi (ENVANTER düğmesi): kullanıcının çanta çizimi, 32x32 olduğu gibi.
func test_inventory_bag_icon_is_user_art() -> void:
	var kit: GDScript = load("res://scripts/hud_tray_kit.gd")
	var tex: Texture2D = kit.BAG_ICON
	assert(tex.get_width() == 32 and tex.get_height() == 32, "çanta 32x32: %s" % tex.get_size())
	var src: Image = Image.load_from_file(ProjectSettings.globalize_path("res://tools/chest_sanat/envanter_canta.png"))
	var img: Image = tex.get_image()
	for y in 32:
		for x in 32:
			assert(_same_px(img.get_pixel(x, y), src.get_pixel(x, y)), "çanta birebir (%d,%d)" % [x, y])


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


## Ödül ekranı: kutu yine 384 px (yerleşim aynı), sandık tam kat (8x), KAPALI karede başlar, atlayınca AÇIK kare; elit ayrı sayfa.
func test_reward_screen_chest_shows_closed_then_open() -> void:
	var anim: Control = (load("res://scripts/chest_open_anim.gd") as GDScript).new()
	anim.setup(false, 2, 4)
	add_child(anim)
	assert(anim.custom_minimum_size == Vector2(384, 384), "ödül ekranı kutusu yine 384 px")
	var rect: TextureRect = anim.get("_rect")
	assert(rect.size == Vector2(256, 256), "sandık 32 px x 8 tam kat: %s" % rect.size)
	assert(rect.position == Vector2(64, 88), "sandık tabanı kutunun %%87,5'inde: %s" % rect.position)
	assert((rect.texture as AtlasTexture).atlas.resource_path.ends_with("chests/sandik_normal.png"), "kademe bandı görünüşü değiştirmez")
	assert((rect.texture as AtlasTexture).region == Rect2(0, 0, 32, 32), "KAPALI kareyle başlamalı: %s" % (rect.texture as AtlasTexture).region)
	anim.skip()
	assert((rect.texture as AtlasTexture).region == Rect2(32, 0, 32, 32), "atlayınca AÇIK kare: %s" % (rect.texture as AtlasTexture).region)
	assert(rect.position == Vector2(64, 88), "sarsıntı dinlenme konumuna dönmeli (eskiden kutunun köşesine kayıyordu): %s" % rect.position)
	anim.free()
	var elite: Control = (load("res://scripts/chest_open_anim.gd") as GDScript).new()
	elite.setup(true)
	add_child(elite)
	assert(((elite.get("_rect") as TextureRect).texture as AtlasTexture).atlas.resource_path.ends_with("chests/sandik_elit.png"), "elit sandık elit sayfa")
	elite.free()


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


## 2026-11-11: yerdeki sandık diğer yer objeleri (altın/yemek/mıknatıs) gibi süzülür: kök yukarı-aşağı gider (genlik 3 px), sprite dinlenme
## konumunda kalır (açılış sallanması orada), gölge bob'u kökten okur (`_last_bob_offset`).
func test_chest_drop_bobs_like_other_drops() -> void:
	var drop = (load("res://scenes/chest_drop.tscn") as PackedScene).instantiate()
	add_child(drop)
	drop.position = Vector2(100.0, 200.0)
	var sprite_y: float = drop.sprite.position.y
	var lo: float = INF
	var hi: float = -INF
	for i in 120:
		drop._process(1.0 / 60.0)
		lo = minf(lo, drop.position.y)
		hi = maxf(hi, drop.position.y)
		assert(is_equal_approx(drop.position.y, 200.0 + drop._last_bob_offset), "kök konumu = taban + bob ofseti (kayma birikmez)")
		assert(is_equal_approx(drop.sprite.position.y, sprite_y), "sprite dinlenme konumunda kalır")
	assert(hi - lo > 4.0 and hi - lo <= 6.01, "belirgin süzülme, genlik 3 px (zirveden zirveye ~6): %f" % (hi - lo))
	assert(is_equal_approx(drop.position.x, 100.0), "yatay kayma yok")
	var shadow: Node = drop.get_node_or_null("DropShadow")
	if shadow != null:
		assert(bool(shadow.get("_root_bob")), "gölge kök süzülmesini izler (yerde kalır)")
	drop.free()


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
