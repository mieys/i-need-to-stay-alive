extends Node

## Silah satıcısı (demirci) dükkanı - kullanıcı isteği (2026-10-07): harita tmx'indeki yeni blacksmith binasının kapısından girilen,
## örse yaklaşınca etkileşimle açılan, tüm silahların ve kalkanların (+ geliştirmelerinin) satıldığı yeni dükkan; seyyar satıcıda
## artık silah yok. Kapsam: kurallar (weapon_shop_logic.gd), ekran (weapon_shop_screen.gd), iç mekan/giriş-çıkış (weapon_shop.gd +
## gerçek harita_baked.tscn + silah_saticisi_baked.tscn).

const Logic := preload("res://scripts/weapon_shop_logic.gd")
const ScreenScript := preload("res://scripts/weapon_shop_screen.gd")
const ShopScript := preload("res://scripts/weapon_shop.gd")
const MobileUIPath := "res://scripts/mobile_ui.gd"

## Oyuncu arayüzü (silah/kalkan satın alma + giriş/çıkış için).
class FakePlayer extends CharacterBody2D:
	var max_weapons: int = 5
	var accept_weapons: bool = true
	var bought: Array = []
	var cards: Array = []
	var is_indoors: bool = false
	var is_dead: bool = false
	var is_downed: bool = false
	var is_chat_typing: bool = false
	var combat_active: bool = true

	func get_max_owned_weapons() -> int:
		return max_weapons

	func buy_weapon_copy(key: String, _level: int) -> bool:
		if not accept_weapons:
			return false
		bought.append(key)
		return true

	func apply_enchant_choice(card: Dictionary) -> void:
		cards.append(card)
		ShieldEnchantDefs.apply(card)

	func set_combat_active(active: bool) -> void:
		combat_active = active

	func clear_input_state() -> void:
		pass


## Fizikle yürüyen gövde: move_and_slide yalnızca _physics_process içinde güvenle çağrılır (physics_frame sinyalinden çağrılınca
## "Body state is inaccessible" hatası verir) - waypoint'leri sırayla izler, bitince done olur.
class Walker extends CharacterBody2D:
	var waypoints: Array = []
	var speed: float = 150.0
	var done: bool = false

	func _physics_process(_delta: float) -> void:
		if waypoints.is_empty():
			done = true
			velocity = Vector2.ZERO
			return
		var to: Vector2 = (waypoints[0] as Vector2) - global_position
		## Son hedef çoğu zaman bir duvar/eşyaya komşu hücre: gövde (yarıçap 8) merkeze tam varamaz - son noktada pay.
		if to.length() < (11.0 if waypoints.size() == 1 else 5.0):
			waypoints.pop_front()
			return
		velocity = to.normalized() * speed
		move_and_slide()


var _saved: Dictionary = {}


func _save_state() -> void:
	_saved = {"gold": GameManager.gold, "weapons": GameManager.owned_weapons.duplicate(true), "enchant": GameManager.shield_enchant,
		"ups": GameManager.shield_enchant_ups.duplicate(true), "std": GameManager.shield_standart_level, "shards": GameManager.weapon_shards}
	GameManager.gold = 100000
	GameManager.weapon_shards = 1000 ## silah başına 10 parçacık: eski testler sınırına takılmasın (parçacık testleri kendi sayısını kurar)
	GameManager.owned_weapons = []
	GameManager.shield_enchant = ""
	GameManager.shield_enchant_ups = []


func _restore_state() -> void:
	GameManager.gold = int(_saved.get("gold", 0))
	GameManager.weapon_shards = int(_saved.get("shards", 0))
	GameManager.owned_weapons = _saved.get("weapons", [])
	GameManager.shield_enchant = str(_saved.get("enchant", ""))
	GameManager.shield_enchant_ups = _saved.get("ups", [])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ------------------------------------------------------------------ kurallar: silah

func test_all_fifteen_weapons_are_sold_at_the_old_prices() -> void:
	_save_state()
	var keys: Array = Logic.weapon_keys()
	assert(keys.size() == 15, "15 silahın hepsi satılmalı, bulunan: %d" % keys.size())
	assert(Logic.weapon_price(0) == ShopPanel.SECOND_WEAPON_COST and Logic.weapon_price(1) == ShopPanel.SECOND_WEAPON_COST,
		"ilk iki alım eski 'ikinci silah' fiyatı (30): %d / %d" % [Logic.weapon_price(0), Logic.weapon_price(1)])
	for n in range(2, 5):
		assert(Logic.weapon_price(n) == ShopPanel.LATER_WEAPON_COST, "3. ve sonraki silah 80: %d" % Logic.weapon_price(n))
	_restore_state()


func test_weapon_purchase_rules_slot_cap_gold_and_duplicates() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	assert(Logic.buy_weapon(p, "fire_staff"), "ilk silah alınabilmeli")
	assert(Logic.buy_weapon(p, "fire_staff"), "aynı silahtan ikinci kopya da alınabilmeli (bağımsız kopya)")
	assert(Logic.owned_count("fire_staff") == 2 and GameManager.owned_weapons.size() == 2)
	assert(p.bought == ["fire_staff", "fire_staff"], "gerçek silah düğümleri de oluşturulmalı")
	assert(GameManager.gold == 100000 - 30 - 30, "iki alım 30+30 altın: kalan %d" % GameManager.gold)
	assert(int(GameManager.owned_weapons[0]["level"]) == 1 and int(GameManager.owned_weapons[0]["spent"]) == 30, "kayıt: seviye 1 + harcanan")
	for k in ["yay", "tufek", "dagger"]:
		assert(Logic.buy_weapon(p, k), "slot boşken %s alınabilmeli" % k)
	assert(GameManager.owned_weapons.size() == 5)
	assert(Logic.weapon_block_reason(p, "arcane") == "Silah slotları dolu (5/5)", "5/5'te sebep: %s" % Logic.weapon_block_reason(p, "arcane"))
	var gold: int = GameManager.gold
	assert(not Logic.buy_weapon(p, "arcane") and GameManager.gold == gold and GameManager.owned_weapons.size() == 5, "dolu slotta alım yok")
	assert(Logic.weapon_block_reason(p, "olmayan_silah") == "Bilinmeyen silah")
	GameManager.owned_weapons = []
	GameManager.gold = 20
	assert(not Logic.can_buy_weapon(p, "yay"), "30 altından azıyla silah alınamaz")
	GameManager.gold = 30
	assert(Logic.can_buy_weapon(p, "yay"), "tam fiyat yeter")
	p.free()
	_restore_state()


func test_weapon_purchase_is_rolled_back_when_player_refuses() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.accept_weapons = false
	add_child(p)
	assert(not Logic.buy_weapon(p, "yay"), "oyuncu silahı eklemezse alım başarısız")
	assert(GameManager.gold == 100000 and GameManager.owned_weapons.is_empty(), "altın ve defter geri alınmalı")
	p.free()
	_restore_state()


# ------------------------------------------------------------------ kurallar: silah parçacığı (kullanıcı isteği 2026-10-08)

func test_weapon_purchase_costs_ten_shards_plus_the_old_gold() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	assert(Logic.SHARD_COST_WEAPON == 10 and Logic.weapon_shard_cost() == 10, "silah 10 parçacık")
	GameManager.weapon_shards = 25
	assert(Logic.buy_weapon(p, "yay"), "25 parçacıkla ilk silah alınır")
	assert(GameManager.weapon_shards == 15 and GameManager.gold == 100000 - 30, "10 parçacık + 30 altın düşer: %d / %d" % [GameManager.weapon_shards, GameManager.gold])
	assert(Logic.buy_weapon(p, "tufek"), "ikinci silah (15 parçacık)")
	assert(GameManager.weapon_shards == 5 and GameManager.gold == 100000 - 60)
	var gold: int = GameManager.gold
	assert(Logic.weapon_block_reason(p, "dagger") == "Silah parçacığı yetersiz (5/10)", "sebep: %s" % Logic.weapon_block_reason(p, "dagger"))
	assert(not Logic.can_buy_weapon(p, "dagger") and not Logic.buy_weapon(p, "dagger"), "parçacık yetmeyince altın bol olsa da alınmaz")
	assert(GameManager.weapon_shards == 5 and GameManager.gold == gold and GameManager.owned_weapons.size() == 2, "başarısız alım hiçbir şeyi değiştirmez")
	GameManager.weapon_shards = 10
	assert(Logic.can_buy_weapon(p, "dagger"), "tam 10 parçacık yeter")
	assert(Logic.buy_weapon(p, "dagger") and GameManager.weapon_shards == 0, "sıfıra iner")
	## Slot dolu sebebi parçacık sebebinden ÖNCE gelir (oyuncu önce asıl engeli görsün).
	GameManager.owned_weapons = []
	GameManager.weapon_shards = 3
	for k in ["yay", "tufek", "dagger", "arcane", "fire_staff"]:
		GameManager.owned_weapons.append({"key": k, "level": 1, "spent": 0})
	assert(Logic.weapon_block_reason(p, "boomerang") == "Silah slotları dolu (5/5)", "slot dolu sebebi öncelikli: %s" % Logic.weapon_block_reason(p, "boomerang"))
	p.free()
	_restore_state()


func test_weapon_purchase_rollback_refunds_shards_too() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.accept_weapons = false
	add_child(p)
	GameManager.weapon_shards = 10
	assert(not Logic.buy_weapon(p, "yay"))
	assert(GameManager.weapon_shards == 10 and GameManager.gold == 100000 and GameManager.owned_weapons.is_empty(), "parçacık da iade edilmeli")
	p.free()
	_restore_state()


func test_shields_and_upgrades_need_no_shards() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	GameManager.weapon_shards = 0
	assert(Logic.entry_shard_cost("weapon") == 10 and Logic.entry_shard_cost("shield") == 0 and Logic.entry_shard_cost("upgrade") == 0,
		"kalkan türü ve geliştirmeler parçacıksız (kullanıcı kararı)")
	assert(Logic.buy_shield(p, "shield_savas"), "kalkan parçacıksız alınır")
	assert(Logic.buy_upgrade(p, 0), "geliştirme parçacıksız alınır")
	assert(GameManager.weapon_shards == 0, "kalkan/geliştirme parçacığa dokunmaz")
	assert(Logic.shard_shortfall_reason(0) == "" and Logic.shard_shortfall_reason(5) == "Silah parçacığı yetersiz (0/5)", "ileride maliyet konursa uyarı hazır")
	p.free()
	_restore_state()


# ------------------------------------------------------------------ kurallar: kalkan

func test_shield_types_cost_250_and_lock_after_the_first_pick() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	assert(Logic.SHIELD_PRICE == 250 and Logic.shield_price() == 250, "kalkan 250 altın")
	assert(Logic.shield_keys() == ShieldEnchantDefs.ENCHANT_KEYS, "3 tür: Savaş/Enerji/Kale")
	assert(Logic.upgrade_block_reason(0) == "Önce bir kalkan türü al", "tür yokken geliştirme alınamaz")
	assert(Logic.upgrade_lines().is_empty())
	assert(Logic.buy_shield(p, "shield_kale"), "Kale kalkanı alınabilmeli")
	assert(GameManager.gold == 100000 - 250 and GameManager.shield_enchant == "shield_kale", "250 düşer, tür yazılır")
	assert(p.cards == [{"type": "shield_pick", "slot": -1, "id": "shield_kale"}], "efsun kartıyla aynı yol: apply_enchant_choice")
	assert(GameManager.shield_enchant_ups.size() == 3, "Kale'nin 3 geliştirme sayacı kurulmalı")
	assert(Logic.shield_block_reason("shield_kale") == "Bu kalkan sende")
	assert(Logic.shield_block_reason("shield_savas") == "Başka bir kalkan türü seçildi", "tür kalıcı: diğerleri kilitli")
	var gold: int = GameManager.gold
	assert(not Logic.buy_shield(p, "shield_savas") and GameManager.gold == gold and GameManager.shield_enchant == "shield_kale")
	assert(Logic.shield_block_reason("shield_standart") == "Bilinmeyen kalkan", "Standart satılmaz")
	p.free()
	_restore_state()


func test_shield_upgrades_escalate_in_price_and_respect_limits() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	assert(Logic.buy_shield(p, "shield_savas"))
	## Savaş: satır 0 sınırsız (+60 kalkan +2 yenilenme), satır 1 limit 8 (+60 kalkan +%3 soğurma).
	assert(Logic.upgrade_lines().size() == 2 and Logic.upgrade_limit(0) == 0 and Logic.upgrade_limit(1) == 8)
	assert(Logic.upgrade_price(0) == Logic.UPGRADE_BASE_PRICE, "ilk geliştirme taban fiyat")
	var before: Dictionary = ShieldEnchantDefs.stats()
	assert(Logic.buy_upgrade(p, 0))
	assert(Logic.upgrade_count(0) == 1 and Logic.upgrade_price(0) == Logic.UPGRADE_BASE_PRICE + Logic.UPGRADE_PRICE_STEP, "fiyat her alımda artar")
	assert(float(ShieldEnchantDefs.stats()["power"]) == float(before["power"]) + 60.0, "kalkan statı artmalı")
	assert(p.cards.back() == {"type": "shield_up", "slot": -1, "index": 0}, "geliştirme kartı efsunla aynı yolda")
	for i in range(5):
		assert(Logic.buy_upgrade(p, 0), "sınırsız satır alınmaya devam eder")
	assert(Logic.upgrade_count(0) == 6 and Logic.upgrade_block_reason(0) == "")
	for i in range(8):
		assert(Logic.buy_upgrade(p, 1), "limitli satır %d. alım" % (i + 1))
	assert(Logic.upgrade_block_reason(1) == "Sınıra ulaşıldı (8/8)", "limit dolunca sebep: %s" % Logic.upgrade_block_reason(1))
	var gold: int = GameManager.gold
	assert(not Logic.buy_upgrade(p, 1) and GameManager.gold == gold, "limit dolunca alım yok")
	assert(Logic.upgrade_block_reason(7) == "Bilinmeyen geliştirme")
	GameManager.gold = 10
	assert(not Logic.can_buy_upgrade(0), "yetersiz altın")
	assert(Logic.upgrade_effect_text(0) == "+60 Kalkan\n+2 Yenilenme/sn", "etki metni: %s" % Logic.upgrade_effect_text(0))
	assert(Logic.upgrade_effect_text(1) == "+60 Kalkan\n+3% Soğurma", "etki metni 2: %s" % Logic.upgrade_effect_text(1))
	assert(Logic.shield_summary("shield_kale") == "200 kalkan · %75 soğurma · 7/sn", "özet: %s" % Logic.shield_summary("shield_kale"))
	p.free()
	_restore_state()


func test_shop_discount_applies_to_everything() -> void:
	_save_state()
	var saved: Variant = GameManager.get("shop_discount_percent") if "shop_discount_percent" in GameManager else null
	var base_weapon: int = Logic.weapon_price(3)
	var base_shield: int = Logic.shield_price()
	assert(GameManager.apply_shop_discount(100) <= 100, "indirim fonksiyonu fiyatı artırmaz")
	assert(base_weapon <= ShopPanel.LATER_WEAPON_COST and base_shield <= Logic.SHIELD_PRICE, "indirimsiz üst sınır")
	if saved != null:
		GameManager.set("shop_discount_percent", saved)
	_restore_state()


# ------------------------------------------------------------------ ekran

func _open_screen(player: Node) -> CanvasLayer:
	(load(MobileUIPath) as GDScript).set(&"enabled", false)
	var screen: CanvasLayer = ScreenScript.new()
	add_child(screen)
	screen.setup(player)
	await _frames(6)
	return screen


func test_screen_lists_every_weapon_and_buys_through_the_rules() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var screen: CanvasLayer = await _open_screen(p)
	assert(screen._rows.size() == 15, "15 silah plakası, bulunan: %d" % screen._rows.size())
	var seen: Dictionary = {}
	for r in screen._rows:
		seen[str(r["entry"]["key"])] = true
		assert((r["buy"] as Button).disabled == false, "altın varken AL açık: %s" % r["entry"]["key"])
		assert(str(r["price"].text) == "30", "ilk silah fiyatı 30: %s" % r["price"].text)
	assert(seen.size() == 15, "plakalar 15 FARKLI silah olmalı")
	assert(screen._status_label.text == "Silah yuvası 0/5", "durum: %s" % screen._status_label.text)
	var first: Dictionary = screen._rows[0]["entry"]
	screen._on_buy_pressed(first)
	assert(GameManager.owned_weapons.size() == 1 and str(GameManager.owned_weapons[0]["key"]) == str(first["key"]), "AL silahı vermeli")
	assert(screen._status_label.text == "Silah yuvası 1/5")
	assert(str(screen._rows[1]["price"].text) == "30", "ikinci silah de 30")
	screen._on_buy_pressed(screen._rows[1]["entry"])
	assert(str(screen._rows[2]["price"].text) == "80", "üçüncü silah 80: %s" % screen._rows[2]["price"].text)
	for i in range(2, 5):
		screen._on_buy_pressed(screen._rows[i]["entry"])
	assert(GameManager.owned_weapons.size() == 5)
	for r in screen._rows:
		assert((r["buy"] as Button).disabled, "slotlar dolunca tüm AL düğmeleri kapanmalı")
	screen._select(screen._rows[7]["entry"])
	assert(screen._details_block.text == "Silah slotları dolu (5/5)", "ayrıntıda sebep: %s" % screen._details_block.text)
	screen._on_close_pressed()
	p.free()
	_restore_state()


## Ekran: üst çubukta parçacık sayacı, her silah plakasında "10" parçacık maliyeti, yetmeyince AL kapalı + ayrıntıda sebep.
func test_screen_shows_shard_counter_cost_and_disables_buy_when_short() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	GameManager.weapon_shards = 9
	var screen: CanvasLayer = await _open_screen(p)
	assert(screen._shard_label != null and screen._shard_label.text == "9", "sayaç 9: %s" % screen._shard_label.text)
	for r in screen._rows:
		assert((r["shard_row"] as Control).visible and str(r["shard_cost"].text) == "10", "her silah plakasında 10 parçacık maliyeti")
		assert((r["buy"] as Button).disabled, "9 parçacıkla AL kapalı (altın bol): %s" % r["entry"]["key"])
	screen._select(screen._rows[0]["entry"])
	assert(screen._details_shard.visible and "10" in screen._details_shard.text and "Sende: 9" in screen._details_shard.text, "ayrıntı: %s" % screen._details_shard.text)
	assert(screen._details_block.text == "Silah parçacığı yetersiz (9/10)", "ayrıntıda sebep: %s" % screen._details_block.text)
	## Parçacık gelince ekran kendiliğinden güncellenir (bir sonraki _process).
	GameManager.add_weapon_shards(1)
	await get_tree().create_timer(0.4).timeout ## ekran durumu 0,25 sn'de bir yoklar
	assert(screen._shard_label.text == "10", "sayaç kendiliğinden güncellenmeli: %s" % screen._shard_label.text)
	for r in screen._rows:
		assert(not (r["buy"] as Button).disabled, "10 parçacıkla AL açılmalı")
	screen._on_buy_pressed(screen._rows[0]["entry"])
	assert(GameManager.weapon_shards == 0 and GameManager.owned_weapons.size() == 1, "AL parçacığı da harcar")
	assert(screen._shard_label.text == "0", "harcayınca sayaç düşer: %s" % screen._shard_label.text)
	for r in screen._rows:
		assert((r["buy"] as Button).disabled, "parçacık bitince hepsi kapanır")
	## Kalkan sekmesi: parçacık maliyeti satırı gizli (0), AL parçacıksız açık.
	screen._show_tab(screen.Tab.SHIELDS)
	for r in screen._rows:
		assert(not (r["shard_row"] as Control).visible and not (r["buy"] as Button).disabled, "kalkan türleri parçacıksız")
	screen._on_close_pressed()
	p.free()
	_restore_state()


func test_screen_shield_tab_flow_and_upgrade_rows() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var screen: CanvasLayer = await _open_screen(p)
	screen._show_tab(screen.Tab.SHIELDS)
	assert(screen._rows.size() == 3, "tür yokken 3 kalkan plakası, bulunan: %d" % screen._rows.size())
	for r in screen._rows:
		assert(str(r["price"].text) == "250" and not (r["buy"] as Button).disabled, "250 altın, alınabilir")
	var kale: Dictionary = {}
	for r in screen._rows:
		if str(r["entry"]["key"]) == "shield_kale":
			kale = r["entry"]
	screen._on_buy_pressed(kale)
	assert(GameManager.shield_enchant == "shield_kale")
	## Alınca sekme yeniden kurulur: 3 tür + 3 geliştirme, diğer türler kilitli, seçim ilk geliştirmede.
	assert(screen._rows.size() == 6, "3 tür + Kale'nin 3 geliştirmesi, bulunan: %d" % screen._rows.size())
	var locked: int = 0
	var upgrades: int = 0
	for r in screen._rows:
		var t: String = str(r["entry"]["type"])
		if t == "shield":
			if str(r["price"].text) == "KİLİTLİ":
				locked += 1
				assert((r["buy"] as Button).disabled)
			else:
				assert(str(r["price"].text) == "SENDE" and (r["buy"] as Button).disabled, "alınan tür 'SENDE'")
		else:
			upgrades += 1
			assert(not (r["buy"] as Button).disabled and str(r["price"].text) == "100", "geliştirme 100 altın")
	assert(locked == 2 and upgrades == 3, "2 kilitli tür + 3 geliştirme")
	assert(str(screen._selected.get("type")) == "upgrade", "seçim ilk geliştirmeye geçmeli")
	screen._on_buy_pressed(screen._selected)
	assert(Logic.upgrade_count(0) == 1)
	var up_row: Dictionary = {}
	for r in screen._rows:
		if str(r["entry"]["type"]) == "upgrade" and int(r["entry"]["index"]) == 0:
			up_row = r
	assert(str(up_row["price"].text) == "125", "ikinci alım fiyatı 125: %s" % up_row["price"].text)
	assert("(1/∞)" in str(up_row["sub"].text), "sınırsız satırda sayaç 1/∞: %s" % up_row["sub"].text)
	screen._on_close_pressed()
	p.free()
	_restore_state()


## Düzen döngüsü koruması (bkz. test_shop_layout_loop.gd, CLAUDE.md madde 20): tüm plakalar ve sekmeler art arda seçilirken hiçbir
## kontrolün min-boyut değişimi tekrar tekrar tetiklenmemeli.
func test_screen_selection_does_not_cause_layout_loops() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var screen: CanvasLayer = await _open_screen(p)
	var counts: Dictionary = {}
	var watch: Callable = func(n: Node) -> void:
		if n is Control and not (n as Control).minimum_size_changed.is_connected(_count.bind(counts, n)):
			(n as Control).minimum_size_changed.connect(_count.bind(counts, n))
	var stack: Array = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		watch.call(n)
		stack.append_array(n.get_children())
	for tab in [screen.Tab.WEAPONS, screen.Tab.SHIELDS, screen.Tab.WEAPONS]:
		screen._show_tab(tab)
		await _frames(2)
		for r in screen._rows.duplicate():
			screen._select(r["entry"])
			await _frames(1)
		stack = [screen]
		while not stack.is_empty():
			var n2: Node = stack.pop_back()
			watch.call(n2)
			stack.append_array(n2.get_children())
	var worst: int = 0
	for k in counts:
		worst = maxi(worst, int(counts[k]))
	assert(worst < 120, "bir kontrolün min-boyut değişimi %d kez tetiklendi (yerleşim döngüsü şüphesi)" % worst)
	screen._on_close_pressed()
	p.free()
	_restore_state()


func _count(counts: Dictionary, n: Node) -> void:
	counts[n.get_instance_id()] = int(counts.get(n.get_instance_id(), 0)) + 1


## Telefon (merchant_shop_screen.gd ile aynı PHONE_K deseni, bkz. test_shop_phone_layout.gd): pencere her sekmede ve her seçimde
## güvenli alanın boyunda kalmalı (yan paneller kendi kaydırma kutusunda, ortadaki plakalar kaydırılır).
func test_phone_window_stays_inside_the_safe_area_when_rows_are_selected() -> void:
	_save_state()
	(load(MobileUIPath) as GDScript).set(&"enabled", true)
	Input.use_accumulated_input = false
	DisplayServer.window_set_size(Vector2i(2400, 1080))
	get_tree().root.size = Vector2i(2400, 1080)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await _frames(2)
	var p := FakePlayer.new()
	add_child(p)
	var screen: CanvasLayer = ScreenScript.new()
	add_child(screen)
	screen.setup(p)
	await _frames(30)
	assert(screen._phone, "telefon kipi açık olmalı")
	assert(screen._phone_scroll != null, "ortadaki plakalar telefonda kaydırma kutusunda olmalı")
	var window := screen.get_child(1) as Control
	var rect_h: float = (screen.call("_phone_rect") as Rect2).size.y
	for tab in [screen.Tab.WEAPONS, screen.Tab.SHIELDS]:
		screen._show_tab(tab)
		await _frames(4)
		for r in screen._rows.duplicate():
			screen._select(r["entry"])
			await _frames(3)
			assert(absf(window.size.y - rect_h) < 1.0, "sekme %d, %s seçilince pencere güvenli alanı (%.0f) aşmamalı: %.0f" % [tab, str(r["entry"].get("key")), rect_h, window.size.y])
	screen._on_close_pressed()
	p.free()
	(load(MobileUIPath) as GDScript).set(&"enabled", false)
	_restore_state()


# ------------------------------------------------------------------ iç mekan + giriş/çıkış

## Gerçek harita (Harita düğümü) + WeaponShop, Main'in kardeşi olarak - weapon_shop.gd yolları ("../Harita/...") çalışsın diye.
func _make_world(as_current_scene: bool = false) -> Dictionary:
	var main := Node2D.new()
	main.name = "Main"
	if as_current_scene:
		get_tree().root.add_child(main) ## current_scene sadece köke bağlı bir düğüm olabilir
		get_tree().current_scene = main
	else:
		add_child(main)
	var harita: Node = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	harita.name = "Harita"
	main.add_child(harita)
	var player := FakePlayer.new()
	player.add_to_group("player")
	player.collision_layer = 2
	player.collision_mask = 0
	main.add_child(player)
	var shop: Node2D = ShopScript.new()
	shop.name = "WeaponShop"
	main.add_child(shop)
	return {"main": main, "player": player, "shop": shop}


func _door_world() -> Vector2:
	## harita_baked.tscn "ev/blacksmith kapı" hücreleri (80-81, 146-147): alt kenarın ortası (Harita burada kaydırılmamış).
	return Vector2(81.0 * 16.0, 148.0 * 16.0)


func test_exterior_door_is_found_on_the_real_map() -> void:
	var w: Dictionary = _make_world()
	await _frames(2)
	var shop: Node2D = w["shop"]
	assert(shop._exterior_door_pos.distance_to(_door_world()) < 1.0, "dış kapı konumu haritadan okunmalı: %s" % str(shop._exterior_door_pos))
	assert(shop._entrance_area != null and shop._entrance_area.position.distance_to(_door_world() + Vector2(0, 8)) < 1.0, "giriş tetikleyicisi kapının önünde")
	assert(shop._exterior_return_pos.y > shop._exterior_door_pos.y, "çıkış noktası kapının GÜNEYİNDE")
	assert(not bool(w["player"].is_indoors))
	(w["main"] as Node).free()


func test_interior_has_door_anvil_collisions_and_a_reachable_exit() -> void:
	var w: Dictionary = _make_world()
	await _frames(2)
	var shop: Node2D = w["shop"]
	assert(shop._door_cells.size() == 2, "çıkış kapısı 2 hücre ('blacksmith kapı iç'): %d" % shop._door_cells.size())
	assert(shop._anvil_local.is_finite(), "örs işaretleyicisi ('Eleman pozisyon') bulunmalı")
	assert(shop._anvil_local.is_equal_approx(Vector2(-3.0 * 16.0 + 8.0, -5.0 * 16.0 + 8.0)), "örs noktası (-3,-5) hücresinin ortası: %s" % str(shop._anvil_local))
	var marker: TileMapLayer = shop._find_layer("eleman pozisyon")
	assert(marker != null and not marker.visible, "işaretleyici katman görünmez olmalı (örsün üstüne çizilmesin)")
	var front: TileMapLayer = shop._find_layer("walls_top")
	assert(front != null and front.z_index > 1, "ön katmanlar oyuncunun (z=1) üstünde çizilmeli")
	var body: StaticBody2D = shop.get_node_or_null("WeaponShopCollision") as StaticBody2D
	assert(body != null and body.get_child_count() > 5, "çalışma anı çarpışması üretilmeli: %d" % (body.get_child_count() if body else -1))
	assert(shop.get_node_or_null("WeaponShopBounds") != null, "oda sınırları")
	## Çarpışma ızgarası: kapı hücreleri AÇIK, doğma noktası açık, doğma -> kapı ve doğma -> örsün önü erişilebilir (BFS).
	var blocked: Dictionary = _blocked_cells(body)
	for c: Vector2i in shop._door_cells:
		assert(not blocked.has(c), "kapı hücresi çarpışmasız olmalı: %s" % str(c))
	var spawn_cell := Vector2i(int(floor(shop._interior_spawn_local.x / 16.0)), int(floor(shop._interior_spawn_local.y / 16.0)))
	assert(not blocked.has(spawn_cell), "doğma noktası duvarın içinde olmamalı: %s" % str(spawn_cell))
	var reach: Dictionary = _flood(blocked, spawn_cell, Rect2i(-10, -7, 21, 10))
	for c: Vector2i in shop._door_cells:
		assert(reach.has(c), "kapıya doğma noktasından yürünebilmeli: %s" % str(c))
	var anvil_cell := Vector2i(-3, -5)
	var near_anvil: bool = false
	for dy in range(-1, 5):
		for dx in range(-4, 3):
			if reach.has(Vector2i(anvil_cell.x + dx, anvil_cell.y + dy)):
				var cpos: Vector2 = Vector2((anvil_cell.x + dx) * 16 + 8, (anvil_cell.y + dy) * 16 + 8)
				if cpos.distance_to(shop._anvil_local) <= shop.ANVIL_INTERACT_RADIUS - 8.0:
					near_anvil = true
	assert(near_anvil, "örsün etkileşim yarıçapı içinde yürünebilir bir hücre olmalı")
	(w["main"] as Node).free()


## Çarpışma gövdesindeki dikdörtgenlerin kapsadığı hücreler (iç mekan yerel hücre koordinatı).
func _blocked_cells(body: StaticBody2D) -> Dictionary:
	var out: Dictionary = {}
	for ch: Node in body.get_children():
		var cs := ch as CollisionShape2D
		if cs == null or not (cs.shape is RectangleShape2D):
			continue
		var size: Vector2 = (cs.shape as RectangleShape2D).size
		var tl: Vector2 = cs.position - size * 0.5
		for y in range(int(round(tl.y / 16.0)), int(round((tl.y + size.y) / 16.0))):
			for x in range(int(round(tl.x / 16.0)), int(round((tl.x + size.x) / 16.0))):
				out[Vector2i(x, y)] = true
	return out


func _flood(blocked: Dictionary, start: Vector2i, bounds: Rect2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or blocked.has(n):
				continue
			if not bounds.has_point(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


## GERÇEK FİZİKLE yürüme (BFS hücre yolu yetmez: oyuncu yarıçapı 8 px, 16 px'lik geçitlerde takılabilir): doğma noktasından kapıya ve
## örsün önüne, iç mekanın gerçek çarpışma gövdelerine karşı move_and_slide ile yürünebilmeli.
func test_player_can_physically_walk_to_the_exit_door_and_the_anvil() -> void:
	var w: Dictionary = _make_world()
	await _frames(2)
	var shop: Node2D = w["shop"]
	var body_node: StaticBody2D = shop.get_node("WeaponShopCollision") as StaticBody2D
	var blocked: Dictionary = _blocked_cells(body_node)
	var start := Vector2i(int(floor(shop._interior_spawn_local.x / 16.0)), int(floor(shop._interior_spawn_local.y / 16.0)))
	var door_target: Vector2 = Vector2(shop._door_cells[0].x * 16 + 8, shop._door_cells[0].y * 16 + 8)
	## Örsün önünde, etkileşim yarıçapının içinde ama örse yapışık olmayan erişilebilir bir hücre.
	var reach: Dictionary = _flood(blocked, start, Rect2i(-10, -7, 21, 10))
	var anvil_cell: Vector2i = Vector2i.ZERO
	var best: float = INF
	for c: Vector2i in reach:
		var cp := Vector2(c.x * 16 + 8, c.y * 16 + 8)
		var d: float = cp.distance_to(shop._anvil_local)
		if d <= shop.ANVIL_INTERACT_RADIUS - 12.0 and d < best:
			best = d
			anvil_cell = c
	assert(best < INF, "örsün etkileşim yarıçapında erişilebilir hücre yok")
	var anvil_target := Vector2(anvil_cell.x * 16 + 8, anvil_cell.y * 16 + 8)
	## Oyuncu (player.tscn) varsayılan hareket modunu (GROUNDED) kullanır; FLOATING modunun wall_min_slide_angle (15 derece) kuralı
	## duvara sürterek giderken yapay takılma yaratır - test oyuncuyla aynı modda yürür.
	var walker := Walker.new()
	walker.collision_layer = 0
	walker.collision_mask = shop.INTERIOR_COLLISION_LAYER
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0 ## player.tscn 16 x ölçek 0.5
	cs.shape = circle
	walker.add_child(cs)
	(w["main"] as Node).add_child(walker)
	for target: Vector2 in [door_target, anvil_target]:
		walker.global_position = shop.INTERIOR_OFFSET + shop._interior_spawn_local
		var path: Array = _cell_path(blocked, start, Vector2i(int(floor(target.x / 16.0)), int(floor(target.y / 16.0))), Rect2i(-10, -7, 21, 10))
		assert(not path.is_empty(), "hücre yolu bulunmalı: %s" % str(target))
		walker.done = false
		walker.waypoints = []
		for cell: Vector2i in path:
			walker.waypoints.append(shop.INTERIOR_OFFSET + Vector2(cell.x * 16 + 8, cell.y * 16 + 8))
		var t0: int = Time.get_ticks_msec()
		while not walker.done and Time.get_ticks_msec() - t0 < 12000:
			await get_tree().physics_frame
		var final_pos: Vector2 = walker.global_position - shop.INTERIOR_OFFSET
		var arrived: bool = walker.done and final_pos.distance_to(target) < 12.0
		assert(arrived, "fizikle hedefe yürünebilmeli: hedef %s, varılan %s" % [str(target), str(final_pos)])
	(w["main"] as Node).free()


## En az "duvara yakınlık cezalı" yol (Dijkstra): oyuncu hücre ortalarında, mümkün olduğunca duvardan uzak yürür (tam teğet geçiş
## fizikte yapay köşe takılması yaratır; gerçek oyuncu serbest yönlendirir).
func _cell_path(blocked: Dictionary, start: Vector2i, goal: Vector2i, bounds: Rect2i) -> Array:
	var dist: Dictionary = {start: 0.0}
	var parent: Dictionary = {start: start}
	var open: Array = [start]
	while not open.is_empty():
		var best_i: int = 0
		for i in range(open.size()):
			if float(dist[open[i]]) < float(dist[open[best_i]]):
				best_i = i
		var c: Vector2i = open[best_i]
		open.remove_at(best_i)
		if c == goal:
			break
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if blocked.has(n) or not bounds.has_point(n):
				continue
			var near_wall: bool = false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if blocked.has(Vector2i(n.x + dx, n.y + dy)):
						near_wall = true
			var nd: float = float(dist[c]) + 1.0 + (3.0 if near_wall else 0.0)
			if not dist.has(n) or nd < float(dist[n]):
				dist[n] = nd
				parent[n] = c
				open.append(n)
	if not parent.has(goal):
		return []
	var path: Array = [goal]
	var cur: Vector2i = goal
	while cur != start:
		cur = parent[cur]
		path.push_front(cur)
	return path


func test_enter_and_exit_teleport_and_flags() -> void:
	var w: Dictionary = _make_world()
	await _frames(2)
	var shop: Node2D = w["shop"]
	var p: FakePlayer = w["player"]
	p.global_position = shop._exterior_return_pos
	shop._do_enter()
	assert(p.is_indoors and shop.is_inside(), "içeride bayrağı")
	assert(p.global_position.is_equal_approx(shop.INTERIOR_OFFSET + shop._interior_spawn_local), "iç mekanın doğma noktasına ışınlanmalı")
	assert(not p.combat_active, "silahlar/yaratıklar gizlenmeli (ev içiyle aynı)")
	assert((p.collision_mask & shop.INTERIOR_COLLISION_LAYER) != 0, "oyuncu iç duvarlara çarpmalı")
	assert(shop._interior.visible)
	assert(shop.is_interior_position(p.global_position) and not shop.is_interior_position(Vector2(2000, 2000)), "iç/dış konum ayrımı")
	assert(shop.INTERIOR_OFFSET.distance_to(Vector2(20000.0, 0.0)) >= 4000.0, "ev içinden (20000,0) uzak olmalı")
	shop._do_exit()
	assert(not p.is_indoors and not shop.is_inside() and p.combat_active, "çıkınca normale dönmeli")
	assert(p.global_position.is_equal_approx(shop._exterior_return_pos), "kapının önüne çıkmalı")
	assert((p.collision_mask & shop.INTERIOR_COLLISION_LAYER) == 0 and not shop._interior.visible)
	(w["main"] as Node).free()


func test_anvil_proximity_and_exit_trigger_only_inside() -> void:
	var w: Dictionary = _make_world()
	await _frames(2)
	var shop: Node2D = w["shop"]
	var p: FakePlayer = w["player"]
	p.global_position = shop.INTERIOR_OFFSET + shop._anvil_local + Vector2(0, 40)
	assert(shop._near_anvil(), "örsün yanında etkileşim mümkün")
	p.global_position = shop.INTERIOR_OFFSET + shop._anvil_local + Vector2(0, 200)
	assert(not shop._near_anvil(), "uzakta etkileşim yok")
	## Dışarıdayken çıkış alanına girilse bile (ör. ev içi/başka yer) tetiklenmez.
	assert(not shop.is_inside())
	shop._on_exit_body_entered(p)
	assert(not shop._transitioning and not shop.is_inside(), "içeride değilken çıkış işlemi yok")
	shop._do_enter()
	shop._on_exit_body_entered(p)
	assert(shop._transitioning, "içerideyken kapıya basınca çıkış geçişi başlar")
	await get_tree().create_timer(0.8).timeout
	assert(not shop.is_inside() and not bool(p.is_indoors), "geçiş bitince dışarıda")
	(w["main"] as Node).free()


func test_player_dying_or_leaving_closes_the_shop_screen() -> void:
	_save_state()
	var w: Dictionary = _make_world()
	await _frames(2)
	var shop: Node2D = w["shop"]
	var p: FakePlayer = w["player"]
	shop._do_enter()
	p.global_position = shop.INTERIOR_OFFSET + shop._anvil_local + Vector2(0, 40)
	shop._open_shop()
	await _frames(2)
	assert(is_instance_valid(shop._shop_screen), "örste etkileşimle ekran açılır")
	p.is_downed = true
	await _frames(3)
	assert(not is_instance_valid(shop._shop_screen) or shop._shop_screen.is_queued_for_deletion(), "yere düşünce ekran kapanmalı")
	(w["main"] as Node).free()
	_restore_state()


# ------------------------------------------------------------------ seyyar satıcı ilişkisi

func test_merchant_maps_smithy_indoor_players_to_the_smithy_door() -> void:
	var previous_scene: Node = get_tree().current_scene
	## current_scene bu testte Main olmalı (merchant get_tree().current_scene altında WeaponShop arar).
	var w: Dictionary = _make_world(true)
	var main: Node = w["main"]
	var merchant: Node2D = (load("res://scripts/traveling_merchant.gd") as GDScript).new()
	merchant.name = "TravelingMerchant"
	main.add_child(merchant)
	await _frames(2)
	var shop: Node2D = w["shop"]
	shop._do_enter()
	var anchors: Array = merchant.call("_players_anchor_positions")
	assert(anchors.has(shop.get_exterior_anchor_pos()), "demirciye girmiş oyuncunun haritadaki karşılığı dükkan kapısı: %s" % str(anchors))
	shop._do_exit()
	get_tree().current_scene = previous_scene
	main.free()
