extends Node
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## Madde 388 -> 432: level atlama pazarı. Kart ekranı yalnız kart seçtirir ve seçince kapanır; pazar ayrı ekran
## (level_market_screen.gd) - EŞYALAR (6) + GELİŞTİRMELER (3) iki bölüm, tek KARIŞTIR, KAYDET (karıştırma ve sonraki pazarda
## kalır) + YASAKLA (en çok 3, koşu boyu çıkmaz). Fiyat/satın alma demirci + satıcı kurallarıyla aynı.

const Market := preload("res://scripts/level_market.gd")
const Logic := preload("res://scripts/weapon_shop_logic.gd")
const MetaProgressTestScript := preload("res://scripts/meta_progress.gd")
const MarketScreenScript := preload("res://scripts/level_market_screen.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")


class FakePlayer extends Node2D:
	var level: int = 12
	var luck: float = 0.0
	var max_health: float = 300.0
	var is_chat_typing: bool = false
	var bought_weapons: Array = []
	var cards: Array = []

	func get_upgrade_count(_id: String) -> int:
		return 0

	func get_max_owned_weapons() -> int:
		return 3

	func get_max_item_slots() -> int:
		return 9

	func buy_weapon_copy(key: String, _level: int) -> bool:
		bought_weapons.append(key)
		return true

	func apply_enchant_choice(card: Dictionary) -> void:
		cards.append(card)
		ShieldEnchantDefs.apply(card)

	func acquire_item(key: String, plan: Dictionary = {}, _paid: int = 0) -> bool:
		for idx in (plan.get("consume", []) as Array).duplicate():
			GameManager.owned_items.remove_at(int(idx))
		GameManager.owned_items.append({"key": key})
		return true


var _saved: Dictionary = {}


func _save_state() -> void:
	_saved = {"gold": GameManager.gold, "weapons": GameManager.owned_weapons.duplicate(true), "enchant": GameManager.shield_enchant,
		"ups": GameManager.shield_enchant_ups.duplicate(true), "shards": GameManager.weapon_shards,
		"items": GameManager.owned_items.duplicate(true), "free": GameManager.free_rerolls_per_card,
		"msaved": GameManager.market_saved.duplicate(true), "mbanned": GameManager.market_banned.duplicate()}
	GameManager.gold = 1480
	GameManager.weapon_shards = 17
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("uzunkilic", 1, 0)]
	EnchantDefs.ensure_trait(GameManager.owned_weapons[0])
	GameManager.shield_enchant = ""
	GameManager.shield_enchant_ups = []
	GameManager.owned_items = [{"key": "kanli_yakut"}]
	GameManager.free_rerolls_per_card = 0
	GameManager.market_saved = []
	GameManager.market_banned = []
	MetaProgressTestScript.unlock_all_override = true


func _restore_state() -> void:
	MetaProgressTestScript.unlock_all_override = false
	GameManager.gold = int(_saved["gold"])
	GameManager.weapon_shards = int(_saved["shards"])
	GameManager.owned_weapons = _saved["weapons"]
	GameManager.shield_enchant = str(_saved["enchant"])
	GameManager.shield_enchant_ups = _saved["ups"]
	GameManager.owned_items = _saved["items"]
	GameManager.free_rerolls_per_card = int(_saved["free"])
	GameManager.market_saved = _saved["msaved"]
	GameManager.market_banned = _saved["mbanned"]


func _ids(arr: Array) -> Array:
	return arr.map(func(e: Dictionary) -> String: return Market.offer_id(e))


## Kullanıcı: "geliştirmelerin de pazarda ayrı bir bölmesi olsun ... 6 eşya ve 3 geliştirme". Bölüm türleri karışmaz, çekilişte
## tekrar yok, havuz her türü kapsar; kalkan türü yalnız Standart'ta, kalkan geliştirmesi yalnız tür alınınca.
func test_offers_split_into_items_and_upgrades() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var pool: Dictionary = Market.candidates(p)
	var up_pool: int = (pool["wupgrade"] as Array).size() + (pool["upgrade"] as Array).size()
	var seen: Dictionary = {}
	for n in 200:
		var o: Dictionary = Market.open_offers(p)
		assert((o["items"] as Array).size() == Market.ITEM_COUNT, "eşya bölümü 6: %d" % (o["items"] as Array).size())
		assert((o["upgrades"] as Array).size() == mini(Market.UPGRADE_COUNT, up_pool), "geliştirme bölümü 3: %d" % (o["upgrades"] as Array).size())
		var ids: Array = _ids(o["items"]) + _ids(o["upgrades"])
		for id in ids:
			assert(ids.count(id) == 1, "aynı pazarda tekrar: %s" % id)
		for e: Dictionary in o["items"]:
			assert(Market.section_of(e) == "items" and not e["type"] in ["wupgrade", "wplus", "upgrade"], "eşya bölümünde geliştirme: %s" % e)
			seen[e["type"] if e["type"] != "item" else "item%d" % Items.kademe(str(e["key"]))] = true
			if e["type"] == "weapon":
				assert(not GameManager.owns_weapon(str(e["key"])), "sahip olunan silah satılmaz")
			if e["type"] == "item" and Items.kademe(str(e["key"])) >= Items.KADEME_EPIK:
				assert(not Items.owns(GameManager.owned_items, str(e["key"])), "tekil eşya ikinci kez çıkmaz")
		for e: Dictionary in o["upgrades"]:
			assert(e["type"] in ["wupgrade", "wplus"], "tür alınmadan kalkan geliştirmesi çıkmaz / bölüm yalnız geliştirme: %s" % e)
			seen[e["type"]] = true
		for e: Dictionary in o["items"] + o["upgrades"]:
			var d: Dictionary = Market.describe(e, p)
			assert(str(d["name"]) != "" and str(d["tag"]) != "" and d["tex"] is Texture2D, "her seçeneğin adı/türü/simgesi olmalı: %s" % e)
	for k: String in ["weapon", "shield", "item1", "item2", "item3", "wupgrade"]:
		assert(seen.has(k), "200 çekilişte %s hiç çıkmadı: %s" % [k, seen.keys()])
	GameManager.shield_enchant = "shield_kale"
	GameManager.shield_enchant_ups = [0, 0]
	var up_seen: bool = false
	for n in 100:
		var o2: Dictionary = Market.open_offers(p)
		for e: Dictionary in o2["items"]:
			assert(e["type"] != "shield", "tür seçildikten sonra başka tür satılmaz")
		for e: Dictionary in o2["upgrades"]:
			up_seen = up_seen or e["type"] == "upgrade"
	assert(up_seen, "tür alınınca kalkan geliştirmesi GELİŞTİRMELER bölümüne girer")
	p.free()
	_restore_state()


## Fiyat/parçacık/engel demirci + satıcı kuralıyla aynı, satın alma onların yolundan geçer, alınan seçenek ikinci kez alınmaz.
func test_buying_uses_the_smithy_and_merchant_rules() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var w: Dictionary = {"type": "weapon", "key": "mizrak"}
	assert(Market.price(w) == Logic.weapon_price(1) and Market.shards(w) == 10, "silah fiyatı demircininki")
	var gold: int = GameManager.gold
	assert(Market.buy(p, w) and bool(w["sold"]), "silah alınır")
	assert(GameManager.gold == gold - Logic.weapon_price(1) and GameManager.weapon_shards == 7 and p.bought_weapons == ["mizrak"], "altın + 10 parçacık düşer")
	assert(not Market.buy(p, w) and Market.block_reason(p, w) == "Alındı", "alınan seçenek ikinci kez alınmaz")
	var kolye: Dictionary = {"type": "item", "key": "kemik_kolye"}
	var plan: Dictionary = Items.plan_purchase("kemik_kolye", GameManager.owned_items)
	assert(Market.price(kolye) == GameManager.apply_shop_discount(int(plan["cost"])) and Market.price(kolye) < Items.cost("kemik_kolye"),
		"tarif indirimi (Kanlı Yakut sende): %d" % Market.price(kolye))
	assert(Market.full_price(kolye) == GameManager.apply_shop_discount(Items.cost("kemik_kolye")), "üstü çizili tam fiyat")
	gold = GameManager.gold
	var cost: int = Market.price(kolye)
	assert(Market.buy(p, kolye) and GameManager.gold == gold - cost, "eşya satıcının yoluyla alınır")
	assert(Items.owns(GameManager.owned_items, "kemik_kolye") and not Items.owns(GameManager.owned_items, "kanli_yakut"), "tarif parçası tüketilir")
	var kale: Dictionary = {"type": "shield", "key": "shield_kale"}
	var savas: Dictionary = {"type": "shield", "key": "shield_savas"}
	assert(Market.buy(p, kale) and GameManager.shield_enchant == "shield_kale", "mana kalkanı türü alınır")
	assert(Market.block_reason(p, savas) != "" and not Market.buy(p, savas), "ikinci tür alınamaz (demirci kuralı)")
	var up: Dictionary = {"type": "upgrade", "index": 0, "stype": "shield_kale"}
	assert(Market.price(up) == Logic.upgrade_price(0) and Market.shards(up) == Logic.SHARD_COST_UPGRADE)
	GameManager.gold = 50
	assert(Market.block_reason(p, up) == "%d altın eksik" % (Logic.upgrade_price(0) - 50) and not Market.buy(p, up), "altın yetmezse alınmaz")
	assert(Items.item_name("isik_parcacigi") == "Işık Küresi", "eşya adı para birimi 'parçacık' ile karışmaz")
	p.free()
	_restore_state()


## Kullanıcı: "kaydetmeye basınca rerollamak veya sonraki seviyeye geçmek o eşyayı geliştirme seçeneğini v.s yok etmemeli".
## Karıştırma: kayıtlılar YERİNDE kalır, gerisi yeni (yeterli seçenek varken öncekiler geri gelmez); sonraki pazar: kayıtlılar
## bölümün başında; alınca kayıt düşer; kalıcı olarak alınamaz hâle gelen kayıt düşer, geçici engel (altın/yuva) kaydı silmez.
func test_saved_offers_survive_reroll_and_next_level() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	for n in 20:
		GameManager.market_saved = []
		var o: Dictionary = Market.open_offers(p)
		var it: Dictionary = o["items"][2]
		var ug: Dictionary = o["upgrades"][0]
		Market.set_saved(it, true)
		Market.set_saved(ug, true)
		assert(Market.is_saved(it) and Market.is_saved(ug) and GameManager.market_saved.size() == 2, "iki kayıt")
		var before_items: Array = _ids(o["items"])
		var r: Dictionary = Market.reroll(p, o)
		assert(Market.offer_id(r["items"][2]) == Market.offer_id(it), "kayıtlı eşya karıştırmada yerinde kalır")
		assert(Market.offer_id(r["upgrades"][0]) == Market.offer_id(ug), "kayıtlı geliştirme karıştırmada yerinde kalır")
		for i in (r["items"] as Array).size():
			if i != 2:
				assert(not before_items.has(Market.offer_id(r["items"][i])), "karıştırma kayıtsız eski seçeneği geri getirdi")
		var nxt: Dictionary = Market.open_offers(p)
		assert(_ids(nxt["items"]).has(Market.offer_id(it)) and Market.offer_id(nxt["items"][0]) == Market.offer_id(it), "sonraki pazarda kayıtlı eşya başta")
		assert(Market.offer_id(nxt["upgrades"][0]) == Market.offer_id(ug), "sonraki pazarda kayıtlı geliştirme başta")
	## geçici engel: altın yok -> kayıt kalır; alınınca kayıt düşer
	GameManager.market_saved = []
	var kut: Dictionary = {"type": "item", "key": "kutsal_tilsim"}
	Market.set_saved(kut, true)
	var gold0: int = GameManager.gold
	GameManager.gold = 0
	assert(_ids(Market.open_offers(p)["items"]).has(Market.offer_id(kut)), "altın yetmese de kayıt pazarda")
	GameManager.gold = gold0
	var kopya: Dictionary = (Market.open_offers(p)["items"] as Array).filter(func(e: Dictionary) -> bool: return e["key"] == "kutsal_tilsim")[0]
	assert(Market.buy(p, kopya) and not Market.is_saved(kut), "alınca kayıt düşer")
	## kalıcı engel: silah başka yoldan alındı -> kayıt düşer; geliştirmenin kaydı yuvası değişse de silahına bağlı
	var w: Dictionary = {"type": "weapon", "key": "yay"}
	Market.set_saved(w, true)
	GameManager.owned_weapons.insert(0, EnchantDefs.new_weapon_entry("yay", 1, 0))
	EnchantDefs.ensure_trait(GameManager.owned_weapons[0])
	var o3: Dictionary = Market.open_offers(p)
	assert(not Market.is_saved(w) and not _ids(o3["items"]).has(Market.offer_id(w)), "sahip olunan silahın kaydı düşer")
	p.free()
	_restore_state()


## Kullanıcı: "3 yasak". Yasaklanan koşu boyu hiç çekilmez, yerine ücretsiz yeni seçenek gelir, 4. yasak reddedilir, yasaklanan
## kayıtlıysa kaydı düşer; yasak kimliği silah anahtarına bağlı (yuva sırası değişse de).
func test_ban_limit_and_never_offered_again() -> void:
	_save_state()
	var p := FakePlayer.new()
	add_child(p)
	var o: Dictionary = Market.open_offers(p)
	Market.set_saved(o["items"][0], true)
	var banned: Array = []
	for i in 3:
		var e: Dictionary = o["items"][i]
		banned.append(Market.offer_id(e))
		assert(Market.ban(e), "yasak %d" % (i + 1))
		o["items"] = Market.replace_at(p, o, "items", i)
		assert((o["items"] as Array).size() == Market.ITEM_COUNT and not banned.has(Market.offer_id(o["items"][i])), "yerine yeni seçenek")
	assert(GameManager.market_saved.is_empty(), "yasaklanan kayıtlıysa kaydı düşer")
	assert(Market.bans_left() == 0 and not Market.ban(o["items"][4]), "4. yasak reddedilir")
	for n in 150:
		var o2: Dictionary = Market.open_offers(p)
		for id in _ids(o2["items"]) + _ids(o2["upgrades"]):
			assert(not banned.has(id), "yasaklı seçenek yeniden çıktı: %s" % id)
	var ug: Dictionary = {"type": "wupgrade", "slot": 0, "index": 0}
	var uid: String = Market.offer_id(ug)
	assert(uid == "wupgrade|uzunkilic|0", "geliştirme kimliği silah anahtarıyla: %s" % uid)
	p.free()
	_restore_state()


## Madde 396 (prototip C "Artı / Eksi"): kart sütunu 380 px ve boyu içeriği kadar. Her kart x her kademede başlık (32) +
## "▲ kazanç" + "▼ bedel" (24) yazı sütununa, satır kartın boyuna sığar. Madde 432: sütun ekranın ORTASINDA, pazar yok.
func test_card_lines_fit_every_card() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	## madde 456: masaüstü varsayılanı yine kart sütunu (COMPACT_CARD_COLUMN true); kapalıysa burada elle kurulup denetlenir.
	if screen.get("_market_view") == null:
		screen.call("_build_market")
	var view: Control = screen.get("_market_view")
	assert(view.get("mode") == "cards" and view.find_child("Market", true, false) == null, "kart ekranında pazar yok")
	var kit = view.get("_k")
	var card: Button = screen.cards[0]
	var Special := preload("res://scripts/level_special_cards.gd")
	var all: Array = (load("res://scripts/level_up_screen.gd") as GDScript).get_script_constant_map()["UPGRADES"].duplicate()
	for id: String in Special.ORDER:
		all.append(Special.as_card(id))
	var widest: Dictionary = {"title": 0.0, "gain": 0.0, "cost": 0.0, "h": 0.0}
	var trade_label_seen: bool = false
	for u: Dictionary in all:
		for tier in range(1, 5):
			var data: Dictionary = screen.call("_market_card_data", u, tier, 3)
			view.fill_card(card, data)
			var face: Control = card.get_node("MarketFace")
			var gain: Control = face.find_child("Gain", true, false) as Control
			var cost: Control = face.find_child("Cost", true, false) as Control
			assert(gain != null and cost != null, "%s k%d: kazanç/bedel satırı olmalı" % [u["id"], tier])
			var tw: float = kit.tw(str(data["title"]), 32)
			var gw: float = gain.get_combined_minimum_size().x
			var cw: float = cost.get_combined_minimum_size().x
			var fh: float = face.get_combined_minimum_size().y
			widest["title"] = maxf(widest["title"], tw)
			widest["gain"] = maxf(widest["gain"], gw)
			widest["cost"] = maxf(widest["cost"], cw)
			widest["h"] = maxf(widest["h"], fh)
			var tag: String = "%s k%d" % [u["id"], tier]
			assert(tw <= view.CARD_TEXT_W, "%s: başlık sığmıyor %.0f > %.0f" % [tag, tw, view.CARD_TEXT_W])
			assert(gw <= view.CARD_TEXT_W, "%s: kazanç satırı sığmıyor %.0f > %.0f" % [tag, gw, view.CARD_TEXT_W])
			assert(cw <= view.CARD_TEXT_W, "%s: bedel satırı sığmıyor %.0f > %.0f" % [tag, cw, view.CARD_TEXT_W])
			assert(fh <= view.CARD_H, "%s: kart satırı kartın boyunu aşıyor %.0f > %.0f" % [tag, fh, view.CARD_H])
			## madde 456: bedelsiz kartta bedel satırı ("artar") gizli; simge çerçevesiz; kademe rengi satırın kenarında
			assert(cost.visible == bool(data["cost_red"]), "%s: bedel satırı yalnız bedelli kartta görünür" % tag)
			var med: PanelContainer = face.find_child("Medal", true, false) as PanelContainer
			assert(med.get_theme_stylebox("panel") is StyleBoxEmpty, "%s: simge çerçevesiz" % tag)
			var fsb: StyleBox = (face as PanelContainer).get_theme_stylebox("panel")
			var edge: Color = fsb.get("border_color")
			assert(int(fsb.get("border_width_left")) > 0 and edge.is_equal_approx(Color(HudTheme.LEVEL_TIER_EDGE[tier - 1], view.CARD_EDGE_ALPHA)),
				"%s: satır kenarı kademe renginde" % tag)
			if str(data["label"]) != "":
				trade_label_seen = true
				assert(str(data["label"]) in ((gain.get_child(1) as Label).text), "%s: takas kartında neyin arttığı yazmalı" % tag)
	print("en geniş başlık %.0f / kazanç %.0f / bedel %.0f (yazı sütunu %.0f), en uzun satır %.0f / %.0f" % [widest["title"],
		widest["gain"], widest["cost"], view.CARD_TEXT_W, widest["h"], view.CARD_H])
	assert(trade_label_seen, "takas kartları kazancın yanında neyin arttığını yazar")
	await get_tree().process_frame
	await get_tree().process_frame
	var left: Control = view.find_child("LevelCards", true, false)
	for chosen in [-1, 1]:
		view.set_chosen(chosen)
		await get_tree().process_frame
		var ms: Vector2 = left.get_combined_minimum_size()
		assert(ms.x <= view.LEFT_W, "sütun genişliği aşıyor (seçim %d): %.0f > %.0f" % [chosen, ms.x, view.LEFT_W])
		assert(is_equal_approx(left.size.x, view.LEFT_W), "sütun %.0f px olmalı: %.0f" % [view.LEFT_W, left.size.x])
		assert(left.size.y < 600.0, "sütun içeriği kadar kısa: %.0f" % left.size.y)
		var gr: Rect2 = left.get_global_rect()
		assert(absf(gr.get_center().x - 960.0) <= 1.0, "sütun ekranın ortasında: %s" % [gr])
		print("kart sütunu (seçim %d): %s, başlıklı blok %s" % [chosen, gr, (view.find_child("CardColumn", true, false) as Control).get_rect()])
	screen.free()
	p.free()
	_restore_state()


func _open_market(p: Node, offers: Dictionary = {}) -> CanvasLayer:
	var s: CanvasLayer = MarketScreenScript.new()
	s.player_ref = p
	s.level = 13
	s.offers = offers
	add_child(s)
	return s


## Pazar ekranı (madde 472 "B3 - Geniş Önizleme"): ortalı; solda GELİŞTİRMELER (3) üstte + EŞYALAR (6) altta satır listesi, sağda
## önizleme; havuzdaki HER seçeneğin önizlemesi pencereye sığar; satırlarda tür / nadirlik yazısı yok (tür önizlemede, 32), önizlemenin
## kenarı nötr ahşap (kullanıcı: "dışı neden mor"), bakiye önizlemenin altında; silah simgeleri tam kat.
func test_market_layout_fits_every_offer() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = _open_market(p)
	var view: Control = screen.get("view")
	var mr: Rect2 = view.MARKET_RECT
	assert(is_equal_approx(mr.position.x, 1920.0 - mr.end.x) and mr.position.x >= 100.0, "pencere yatayda ortalı, kenardan oyun görünür: %s" % [mr])
	await get_tree().process_frame
	await get_tree().process_frame
	var items_box: Container = view.find_child("ItemRows", true, false)
	var rows: Container = view.find_child("UpgradeRows", true, false)
	assert(items_box.get_child_count() == 6 and rows.get_child_count() == 3, "6 eşya satırı + 3 geliştirme satırı")
	assert(rows.get_global_rect().end.y <= items_box.get_global_rect().position.y, "GELİŞTİRMELER üstte, EŞYALAR altta")
	var list: Control = view.find_child("MarketList", true, false)
	var detail: Control = view.find_child("Detail", true, false)
	assert(detail.get_global_rect().position.x >= list.get_global_rect().end.x, "önizleme listenin sağında")
	assert((list as PanelContainer).get_theme_stylebox("panel").get("bg_color").a == 1.0, "liste envanter kuyusu gibi opak")
	## nadirlik / geliştirme türü yazısı hiçbir yerde yok; tür etiketi satırda değil önizlemede (madde 472)
	var tag_words: Array = ["PARÇA", "EPİK", "EFSANEVİ", "SİLAH GELİŞTİRME", "KALKAN GELİŞTİRME", "Eşya", "Tarifli eşya"]
	for host: Node in [items_box, rows, detail]:
		for l: Node in host.find_children("*", "Label", true, false):
			assert(not tag_words.has((l as Label).text), "tür/nadirlik yazısı görünmemeli: %s" % (l as Label).text)
	for host: Node in [items_box, rows]:
		for l: Node in host.find_children("Kind", "Label", true, false):
			assert(false, "satırda tür etiketi yok")
		for b: Node in host.get_children():
			if not (b is Button):
				continue
			var face: Control = b.get_node("Face")
			assert(face.get_combined_minimum_size().y <= view.ROW_H + 0.5, "satır ROW_H'ye sığar: %s %s" % [b.name, face.get_combined_minimum_size()])
			assert((face.find_child("Title", true, false) as Label).get_theme_font_size("font_size") == 32, "satır adı m5x7 32")
	var market: Control = view.get_node("Market")
	## madde 462: envanterin çift ahşap çerçevesi (dış RIM + OUTLINE, iç panel + RIM_LO); içerik kenardan PANEL_PAD
	var content_min: Vector2 = (view.find_child("MarketBody", true, false) as Control).get_combined_minimum_size() + Vector2(2.0, 2.0) * view.PANEL_PAD
	assert(content_min.x <= mr.size.x + 0.5 and content_min.y <= mr.size.y + 0.5, "liste + önizleme pencereye sığar: %s / %s" % [content_min, mr.size])
	var msb: StyleBox = (market as PanelContainer).get_theme_stylebox("panel")
	assert(msb.get("bg_color") == HudTheme.RIM and msb.get("border_color") == HudTheme.OUTLINE, "dış çerçeve envanterin ahşap kenarı")
	var body_r: Rect2 = view.find_child("MarketBody", true, false).get_global_rect()
	assert(absf(body_r.position.x - (market.get_global_rect().position.x + view.PANEL_PAD)) < 0.5, "içerik pencere kenarından PANEL_PAD içeride")
	## bakiye önizlemenin altında ("ELİNDE"); pencereye yapışık sekme yok
	assert(view.get_node_or_null("Purse") == null and detail.find_child("Purse", true, false) != null, "bakiye önizlemede")
	## pencerenin altı: karıştır solda, DEVAM sağda, pencerenin dışında
	var go: Rect2 = (view.get("go_button") as Control).get_global_rect()
	var bottom: Rect2 = view.find_child("MarketBottom", true, false).get_global_rect()
	assert(go.position.y >= mr.end.y and bottom.position.y >= mr.end.y and absf(go.end.x - mr.end.x) < 0.5 and absf(bottom.position.x - mr.position.x) < 0.5,
		"karıştır sol altta, DEVAM sağ altta: %s %s" % [bottom, go])
	var WeaponCatalogS: GDScript = load("res://scripts/weapon_catalog.gd")
	for key: String in ["buz_asasi", "uzunkilic", "gokkusagi", "yay", "crossbow"]:
		var tex: Texture2D = WeaponCatalogS.call("icon", key)
		var wi: Control = view.call("_icon", {"wtier": 5, "tex": tex}, view.DETAIL_ICON)
		## kademe 5 bile olsa kontür / parıltı katmanı yok: tek çizim (kullanıcı 2026-11-06)
		assert(wi.get_child_count() == 1, "%s pazarda kontürsüz tek çizim olmalı: %d katman" % [key, wi.get_child_count()])
		var top: TextureRect = wi.get_child(0) as TextureRect
		var used: Vector2 = (top.texture as AtlasTexture).region.size
		assert(maxf(used.x, used.y) < 34.0, "%s boş kenarı kırpılmadı: %s" % [key, used])
		var kk: float = floorf(view.WEAPON_FIT / maxf(used.x, used.y))
		assert(kk >= 2.0 and top.size.is_equal_approx((used * kk).floor()), "%s önizlemede tam kat değil: %s / %s" % [key, top.size, used])
		assert(maxf(top.size.x, top.size.y) <= view.WEAPON_FIT, "%s eşyalardan büyük çizilmemeli: %s" % [key, top.size])
		wi.free()
	var room: float = mr.size.y - 2.0 * view.PANEL_PAD
	var tallest: float = 0.0
	var tallest_id: String = ""
	var n: int = 0
	var upg_checked: int = 0
	var items_with_tree: int = 0
	var kinds: Dictionary = {"weapon": "SİLAH", "shield": "MANA KALKANI", "item": "EŞYA"}
	var name_w: float = 0.0
	var pool: Dictionary = Market.candidates(p)
	for k: String in pool:
		for e: Dictionary in pool[k]:
			var sec: String = Market.section_of(e)
			view.offers = {"items": [e] if sec == "items" else [], "upgrades": [e] if sec == "upgrades" else []}
			view.set("_focus", [sec, 0])
			Market.set_saved(e, true) ## kayıtlı hâl: yeşil kuyu + KAYITLI düğmesi
			view.call("_refresh_detail")
			await get_tree().process_frame
			var h: float = detail.get_combined_minimum_size().y
			var sb: StyleBox = (detail as PanelContainer).get_theme_stylebox("panel")
			assert(Color(sb.get("border_color")) == HudTheme.WIN_LINE_HI, "önizlemenin kenarı nötr ahşap (nadirlik rengi değil): %s" % Market.offer_id(e))
			var nm: Label = detail.find_child("DetailName", true, false)
			assert(nm.get_line_count() <= 2, "önizleme adı en çok 2 satır: %s" % nm.text)
			name_w = maxf(name_w, nm.size.x)
			if sec == "items":
				var kl: Label = detail.find_child("Kind", true, false)
				assert(kl != null and kl.text == kinds[str(e["type"])] and kl.get_theme_font_size("font_size") == 32,
					"önizlemede tür 32: %s" % (kl.text if kl else "yok"))
			else:
				assert(detail.find_child("Badge", true, false) != null, "geliştirmede kademe rozeti: %s" % Market.offer_id(e))
				upg_checked += 1
			if str(e["type"]) == "item": ## madde 433 ek 5: seyyar satıcıdaki gibi tarif ağacı + şuna dönüşür
				var ik: String = str(e["key"])
				var has_tree: bool = detail.find_child("RecipeTree", true, false) != null
				var has_ups: bool = detail.find_child("BuildsInto", true, false) != null
				assert(has_tree != (Items.recipe(ik) as Array).is_empty(), "%s: tarif ağacı" % ik)
				assert(has_ups != (Items.builds_into(ik) as Array).is_empty(), "%s: şuna dönüşür" % ik)
				items_with_tree += 1 if not (Items.recipe(ik) as Array).is_empty() else 0
				if has_tree: ## madde 433 ek 7: yalnız doğrudan alt eşyalar, okunur boyda (yuva >= 56 px)
					var tv: Control = detail.find_child("RecipeTree", true, false)
					var tile: Control = tv.get_child(0) as Control
					assert(tile.size.x >= 56.0, "%s: tarif simgesi okunur boyda olmalı: %.0f" % [ik, tile.size.x])
					assert(tv.custom_minimum_size.y <= view.RECIPE_AREA.y and tv.custom_minimum_size.x <= view.RECIPE_AREA.x,
						"%s: ağaç alanına sığar %s" % [ik, tv.custom_minimum_size])
			Market.set_saved(e, false)
			n += 1
			if h > tallest:
				tallest = h
				tallest_id = Market.offer_id(e)
	print("en uzun önizleme: %s %.0f / %.0f (%d seçenek, %d geliştirme)" % [tallest_id, tallest, room, n, upg_checked])
	assert(upg_checked >= 3, "geliştirmeler de denetlendi: %d" % upg_checked)
	assert(items_with_tree >= 5, "tarifli eşyalar denetlendi: %d" % items_with_tree)
	## havuzda olmayanlar dahil BÜTÜN silah geliştirme adları önizlemenin ad alanında (48) en çok 2 satır
	var probe := Label.new()
	probe.add_theme_font_override("font", load("res://assets/fonts/m5x7.ttf"))
	probe.add_theme_font_size_override("font_size", 48)
	probe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(probe)
	probe.size = Vector2(name_w, 400)
	var names: int = 0
	for defs: Dictionary in [load("res://scripts/weapon_traits/weapon_traits.gd").get("DEFS"), load("res://scripts/enchant_defs.gd").get("DEFS")]:
		for id in defs:
			var def: Dictionary = defs[id]
			if not def.has("upgrades"):
				continue
			for u: Dictionary in (def["upgrades"] as Array) + [def["final"]]:
				probe.text = str(u["name"])
				assert(probe.get_line_count() <= 2, "geliştirme adı önizlemede 2 satıra sığmıyor: %s" % u["name"])
				names += 1
	assert(names >= 100, "bütün geliştirme adları tarandı: %d" % names)
	probe.free()
	assert(n >= 20, "havuz her türü kapsar: %d" % n)
	assert(tallest <= room, "önizleme pazar penceresine sığmıyor: %s %.0f > %.0f" % [tallest_id, tallest, room])
	screen.free()
	p.free()
	_restore_state()


class FakePartyPanel extends Control:
	var reasons: Dictionary = {}

	func set_suppressed(reason: String, on: bool) -> void:
		if on:
			reasons[reason] = true
		else:
			reasons.erase(reason)
		visible = reasons.is_empty()


## Çok oyunculu (kullanıcı 2026-10-28: "panel sola doğru kayık"): grup paneli açıkken pazar onu gizler ve ekranın TAM ortasında
## 1:1 durur; ekran kapanınca panel geri gelir.
func test_market_stays_centered_with_party_panel() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var layer := CanvasLayer.new()
	add_child(layer)
	var pp := FakePartyPanel.new()
	pp.add_to_group(&"party_panel")
	pp.position = Vector2(1614, 120)
	pp.size = Vector2(270, 400)
	layer.add_child(pp)
	var screen: CanvasLayer = _open_market(p)
	var view: Control = screen.get("view")
	assert(not pp.visible and pp.reasons.has("level_market"), "pazar açıkken grup paneli gizli")
	assert(view.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(view.position.x, 0.0), "küçülmez, kaymaz: %s %s" % [view.scale, view.position])
	screen.free()
	assert(pp.visible and pp.reasons.is_empty(), "ekran kapanınca grup paneli geri gelir")
	layer.free()
	p.free()
	_restore_state()


## Kart ekranı: karta tıklamak seçer, kutlama sonrası ekranı kapatır (upgrade_chosen bir kez); süre dolunca otomatik seçer.
## Madde 433 ek 6 (kullanıcı: "Kritik hasarın %5 artar" / "Saldırı gücün 10 artar ancak canın 20 azalır", renkli, başka yazı yok): her kart x
## her kademede tek cümle; stat adı kalıptan (yedek başlığa düşmez), bedelli kartta "ancak ... azalır" kırmızı; satırda yalnız cümle görünür, 2 satıra sığar.
func test_card_sentences() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	var Special := preload("res://scripts/level_special_cards.gd")
	var HT := preload("res://scripts/hud_theme.gd")
	var phrases: Dictionary = screen.get("SENTENCE_STAT")
	var all: Array = (load("res://scripts/level_up_screen.gd") as GDScript).get_script_constant_map()["UPGRADES"].duplicate()
	for id: String in Special.ORDER:
		all.append(Special.as_card(id))
	var card: Button = screen.cards[0]
	var sen: RichTextLabel = card.find_child("RowSentence", true, false)
	## madde 456: masaüstü kart sütununda satır cümlesi + satır yazıları GİZLİ (kart yüzü çizer; eskiden _fill_row cümleyi yeniden açıyordu);
	## sütun kapalıysa (Yüzen Kapsül) cümle görünür. Cümle kalıbı ölçümü için kutu burada açılır.
	var column: bool = screen.get("_market_view") != null
	var sbox: Control = card.get_node("RowSentenceBox") as Control
	assert(sen != null and sbox.visible == not column, "cümle yalnız satır görünümünde görünür (sütun %s)" % column)
	for n: String in ["RowName", "RowSub", "RowValue", "RowVerb"]:
		assert(not (card.get_node(n) as CanvasItem).visible, "%s gizli (başka yazı yok)" % n)
	if column:
		assert(card.get_node("MarketFace") != null and (card.get_node("MarketFace") as Control).visible, "sütunda kart yüzü görünür")
		sbox.visible = true
	var widest: int = 0
	## madde 446: cümle İngilizcede de (kelime sırası kalıptan) 2 satıra sığmalı
	for lang: String in ["tr", "en"]:
		Loc.apply(lang)
		widest = maxi(widest, await _check_sentences(screen, all, phrases, sen, Special, HT))
	Loc.apply(UISound.language)
	print("en çok %d satır" % widest)
	screen.free()
	p.free()
	_restore_state()


func _check_sentences(screen: CanvasLayer, all: Array, phrases: Dictionary, sen: RichTextLabel, Special: GDScript, HT: GDScript) -> int:
	var widest: int = 0
	for u: Dictionary in all:
		var id: String = str(u["id"])
		var special: bool = bool(u.get("special", false))
		var gk: String = Special.gain_stat(id) if special else id
		assert(phrases.has(gk), "%s: kazanç statının cümle kalıbı yok (%s)" % [id, gk])
		var cs: String = Special.cost_stat(id)
		if cs != "":
			assert(phrases.has(cs), "%s: bedel statının cümle kalıbı yok (%s)" % [id, cs])
		for tier in range(1, 5):
			var t: String = screen.call("card_sentence", u, tier)
			assert(HT.GOOD.to_html(false) in t, "%s k%d: kazanç yeşil" % [id, tier])
			assert((TranslationServer.translate("ancak") in t) == (cs != "") and ((HT.BAD.to_html(false) in t) == (cs != "")), "%s k%d: bedel kısmı" % [id, tier])
			sen.text = t
			await get_tree().process_frame
			widest = maxi(widest, sen.get_line_count())
			assert(sen.get_line_count() <= 2, "%s k%d (%s): cümle 2 satıra sığmıyor: %s" % [id, tier, Loc.current(), sen.get_parsed_text()])
			if tier == 1 and id in ["crit_damage", "trade_glass", "cooldown_reduction", "class_melee", "dodge"]:
				print("CÜMLE %s %s: %s" % [Loc.current(), id, sen.get_parsed_text()])
	return widest


func test_card_pick_closes_card_screen() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen)
	## madde 456 (kullanıcı 2026-11-08): masaüstünde kart sütunu ("C Artı/Eksi", ahşap, başlıksız); Yüzen Kapsül satırları gizli
	var rows: Control = screen.get_node_or_null("Rows")
	var view: Control = screen.get("_market_view")
	assert(view != null and rows != null and not rows.visible, "kart ekranı kart sütunu, eski satırlar gizli")
	var col: Control = view.find_child("LevelCards", true, false)
	for c: Button in screen.cards:
		assert(col.is_ancestor_of(c), "kartlar sütunda")
	for lbl: Label in view.find_children("*", "Label", true, false):
		assert(lbl.text != "LEVEL KARTI" and lbl.text != "Bir kart seç", "başlık / alt yazı yok: %s" % lbl.text)
	screen.call("_on_card_hover", screen.cards[2], true)
	var hs: StyleBox = (screen.cards[2].get_node("MarketFace") as PanelContainer).get_theme_stylebox("panel")
	assert((hs.get("border_color") as Color).is_equal_approx(HudTheme.ACCENT), "üstündeki kart altın kenar")
	screen.call("_on_card_hover", screen.cards[2], false)
	var got: Array = []
	screen.upgrade_chosen.connect(func(id: String, tier: int) -> void: got.append([id, tier]))
	(screen.cards[1] as Button).pressed.emit()
	(screen.cards[0] as Button).pressed.emit()
	assert(bool(screen.get("_has_chosen")) and screen.reroll_button.disabled, "seçim kilitlenir, kart karıştırma kapanır")
	await get_tree().create_timer(1.6).timeout
	assert(got.size() == 1 and str(got[0][0]) == str(screen._card_ids[1]) and int(got[0][1]) == int(screen._card_tiers[1]),
		"kutlama sonrası seçilen kart bir kez gider: %s" % [got])
	screen.free()
	var screen2: CanvasLayer = (load("res://scenes/level_up_screen.tscn") as PackedScene).instantiate()
	add_child(screen2)
	var got2: Array = []
	screen2.upgrade_chosen.connect(func(id: String, _t: int) -> void: got2.append(id))
	screen2.call("_on_level_up_timer_tick", 0.0)
	await get_tree().create_timer(1.6).timeout
	assert(got2.size() == 1 and screen2._card_ids.has(got2[0]), "süre dolunca otomatik seçim + kapanış: %s" % [got2])
	screen2.free()
	p.free()
	_restore_state()


## Pazar ekranı: tık = al, tek KARIŞTIR (satıcı bedeli, kendi sayacı) kayıtlıyı korur, YASAKLA iki basış ister, DEVAM / süre bir
## kez kapatır.
func _move_mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)


## Madde 472: KAYDET / YASAKLA önizlemede yazılı düğmeler ve SEÇİLİ seçeneğe işler; satırın üstüne gelmek yalnız satırı vurgular,
## önizlemeyi değiştirmez (fareyi SATIN AL'a götürürken aradaki satırlar seçimi bozmasın). Gerçek fare hareketi.
func test_preview_save_and_ban_buttons() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = _open_market(p)
	var view: Control = screen.get("view")
	for k in 3:
		await get_tree().process_frame
	view.call("_select", "items", 1)
	await get_tree().process_frame
	var name0: String = (view.find_child("DetailName", true, false) as Label).text
	var slot2: Control = view.find_child("Slot2", true, false)
	_move_mouse(slot2.get_global_rect().get_center())
	for k in 3:
		await get_tree().process_frame
	assert(view.get("_hover") == ["items", 2], "satırın üstünde: %s" % [view.get("_hover")])
	assert(view.get("_focus") == ["items", 1] and (view.find_child("DetailName", true, false) as Label).text == name0,
		"üstüne gelmek önizlemeyi değiştirmez")
	var hsb: StyleBox = (slot2.get_node("Face") as PanelContainer).get_theme_stylebox("panel")
	assert(Color(hsb.get("border_color")).a > 0.0, "üstündeki satır vurgulu")
	_move_mouse(Vector2(4, 4))
	for k in 3:
		await get_tree().process_frame
	assert(view.get("_hover") == [], "satırın dışında vurgu kalkar")
	var o: Dictionary = view.get("offers")
	var e1: Dictionary = o["items"][1]
	## KAYDET seçiliye işler, kayıtlıyken yeşil "KAYITLI"; tekrar basınca kayıt kalkar (bağlantı ertelenmiş: düğme önizlemeyle yeniden kurulur)
	(view.find_child("SaveButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert(Market.is_saved(e1), "KAYDET seçiliyi kaydeder")
	var sb2: Button = view.find_child("SaveButton", true, false)
	assert(((sb2.get_meta("row") as HBoxContainer).get_child(1) as Label).text == "KAYITLI", "kayıtlıyken düğme KAYITLI yazar")
	sb2.pressed.emit()
	await get_tree().process_frame
	assert(not Market.is_saved(e1), "ikinci basış kaydı kaldırır")
	## YASAKLA: ilk basış kurar ("TEKRAR BAS"), ikinci basış yasaklar, yerine yeni seçenek
	var target: String = Market.offer_id(e1)
	(view.find_child("BanButton", true, false) as Button).pressed.emit()
	await get_tree().process_frame
	assert(str(view.get("_ban_armed")) == "items:1" and not GameManager.market_banned.has(target), "ilk basış yalnız kurar")
	var bb: Button = view.find_child("BanButton", true, false)
	assert(((bb.get_meta("row") as HBoxContainer).get_child(1) as Label).text == "TEKRAR BAS", "kurulunca TEKRAR BAS")
	bb.pressed.emit()
	await get_tree().process_frame
	assert(GameManager.market_banned.has(target), "ikinci basış yasaklar")
	assert(Market.offer_id((view.get("offers") as Dictionary)["items"][1]) != target, "yerine yeni seçenek")
	screen.free()
	p.free()
	_restore_state()


func test_market_screen_buy_save_ban_and_close() -> void:
	_save_state()
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	var screen: CanvasLayer = _open_market(p)
	var view: Control = screen.get("view")
	var closed: Array = []
	screen.closed.connect(func() -> void: closed.append(1))
	var o: Dictionary = view.get("offers")
	## tık = SEÇ (almaz); alma ayrıntıdaki SATIN AL düğmesiyle (madde 433 ek 3)
	var bought: bool = false
	for i in (o["items"] as Array).size():
		var e: Dictionary = o["items"][i]
		if Market.block_reason(p, e) == "":
			var gold: int = GameManager.gold
			var cost: int = Market.price(e)
			(view.find_child("Slot%d" % i, true, false) as Button).pressed.emit()
			assert(GameManager.gold == gold and not bool(e.get("sold", false)), "yuvaya tıklamak satın ALMAZ")
			assert(view.get("_focus") == ["items", i], "tıklanan yuva seçilir")
			var bb: Button = view.find_child("BuyButton", true, false)
			assert(bb != null and not bb.disabled and bb.text == "SATIN AL", "ayrıntıda açık SATIN AL düğmesi")
			bb.pressed.emit()
			assert(GameManager.gold == gold - cost and bool(e["sold"]), "SATIN AL seçili seçeneği alır")
			bought = true
			break
	assert(bought, "alınabilir bir eşya olmalı")
	## alınamayan seçilince düğme kapalı
	GameManager.gold = 0
	view.call("refresh")
	view.call("_select", "items", 0)
	var bb0: Button = view.find_child("BuyButton", true, false)
	assert(bb0 == null or bb0.disabled or bool((o["items"][0] as Dictionary).get("sold", false)), "altın yetmezken SATIN AL kapalı")
	GameManager.gold = 99999
	view.call("refresh")
	## kaydet + tek karıştırma
	view.call("toggle_save", "upgrades", 0)
	var saved_id: String = Market.offer_id(o["upgrades"][0])
	## kayıtlı görünüş (madde 433 "B - Yosun Kuyu" + kilit simgesi): yosun iç + yeşil kenar + kilitli "KAYITLI"
	var face0: PanelContainer = view.find_child("Upgrade0", true, false).get_node("Face")
	var st0: StyleBox = face0.get_theme_stylebox("panel")
	assert(st0.get("bg_color") in [HudTheme.SAVED_FILL, HudTheme.SAVED_FILL_HOVER] and Color(st0.get("border_color"), 1.0).is_equal_approx(HudTheme.SAVED_EDGE),
		"kayıtlı satır yeşil: %s / %s" % [st0.get("bg_color"), st0.get("border_color")])
	assert(face0.find_child("SavedLock", true, false) != null, "kayıtlı geliştirme satırında adın önünde kilit simgesi")
	## pazarda yeşil kenar yalnız "kayıtlı": silah geliştirmesinin tür rengi turuncu
	for e: Dictionary in o["upgrades"]:
		if str(e["type"]) in ["wupgrade", "wplus"]:
			assert(Market.describe(e, p)["tag_col"] == Market.TAG_WEAPON, "silah geliştirme kenarı turuncu: %s" % e)
	var gold2: int = GameManager.gold
	view.call("reroll")
	assert(GameManager.gold == gold2 - Market.reroll_cost(0) and int(view.get("shop_rerolls")) == 1, "karıştırma bedeli satıcınınki")
	var o2: Dictionary = view.get("offers")
	assert(Market.offer_id(o2["upgrades"][0]) == saved_id, "kayıtlı geliştirme karıştırmada kalır")
	## yasak: ilk basış kurar, ikinci basış yasaklar
	var target: String = Market.offer_id(o2["items"][1])
	view.call("press_ban", "items", 1)
	assert(Market.bans_left() == Market.BAN_LIMIT and not GameManager.market_banned.has(target), "ilk basış yasaklamaz")
	view.call("press_ban", "items", 1)
	assert(GameManager.market_banned.has(target) and Market.bans_left() == Market.BAN_LIMIT - 1, "ikinci basış yasaklar")
	assert(Market.offer_id((view.get("offers") as Dictionary)["items"][1]) != target, "yerine yeni seçenek")
	## DEVAM bir kez
	(view.get("go_button") as Button).pressed.emit()
	screen.call("close")
	assert(closed.size() == 1, "DEVAM ekranı bir kez kapatır")
	screen.free()
	var screen2: CanvasLayer = _open_market(p)
	var closed2: Array = []
	screen2.closed.connect(func() -> void: closed2.append(1))
	screen2.call("_on_timer_tick", 0.0)
	assert(closed2.size() == 1, "süre dolunca pazar kapanır")
	screen2.free()
	p.free()
	_restore_state()
