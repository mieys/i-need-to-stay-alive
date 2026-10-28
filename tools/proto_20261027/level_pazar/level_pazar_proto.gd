extends SceneTree

## LEVEL ATLAMA + PAZAR ekranı PROTOTİPLERİ (2026-10-27, madde 386). Kullanıcı: "bundan sonra her level atlandığında solda 3 level
## atlama kartı seçeneği ve sağında da 6 adet silah alma-silah geliştirme-kalkan alma-kalkan geliştirme-dükkandaki tüm eşyaları
## kapsayacak şekilde rasgele 6 adet seçenek çıkacak. her level atlayışta ücretsiz olacak şekilde 1 level atlama kartı seçilebilecek,
## diğer seçenekler tıpkı mevcut fiyatlarındaki bedellerindeki gibi çalışacak. level atlama kartının kendine özel rerollu bulunacak
## diğer 6 eşyanın da kendine özel rerollu bulunacak. bu tasarım için 4 prototip üretir misin".
## Oyuna BAĞLI DEĞİL: gerçek SP main.tscn açılır, gerçek oyuncuya gerçek yollarla silah/eşya verilir; kart değerleri
## level_up_screen._scaled_desc_value + level_special_cards (bedel satırı), fiyatlar weapon_shop_logic / items.plan_purchase /
## merchant_shop_screen.reroll_cost (indirim + engel sebepleri dahil), ikonlar oyunun kendi dokuları. İki an:
##  "ilk"   - ekran açıldı: 3 kart (1 özel takas kartı), pazarda silah / silah geliştirme / mana kalkanı türü / parça / epik /
##            efsanevi (altını yetmiyor), 2. seçeneğin üstünde duruluyor.
##  "sonra" - Efsanevi kart seçildi (ücretsiz), Kale Mana Kalkanı alındı, pazar 1 kez karıştırıldı (kalkan geliştirmesi geldi),
##            Kan Dişi alındı; DEVAM açıldı.
##  A Ahşap Tezgâh   (demirci ahşabı PAL_WOOD): solda bugünkü kapsül satırları, sağda 3x2 tezgâh kartı
##  B Klasik Pazar   (seyyar satıcı PAL_SLATE): tek pencere, solda 3 dikey kart, sağda 6 satır + AL
##  C Ateş Işığı     (ESC/Ayarlar dili): kutusuz, solda mumlu liste, sağda 2 raf + asılı fiyat levhaları
##  D Gece Sıvası    (menüler PAL_NIGHT): solda kart sütunu, sağda 2x3 yuva + LoL tarzı ayrıntı kartı
## Kullanım: tools/proto_20261027/level_pazar/level_pazar_run.ps1 [-Only "A,B"]  (gizli masaüstü, APPDATA yalıtılır)

var DarkKit = null
var FMK = null
var DK = null
var HT = null
var WTA = null
var WC = null
var Logic = null
var CharsScript = null
var IT = null
var ED = null
var SED = null
var LSC = null
var TS = null
var UIK = null
var MSS = null
var GM = null

const CHAR_ID := 2 ## Oakley
const PET := "kirpi"
const LEVEL := 13
const GOLD := 1480
const SHARDS := 17
const GAME_TIME := 1350.0 ## satıcı fiyat ölçeği (karıştırma bedeli) ~Kademe 10
const COUNTDOWN := 17
## [id, tier] - ortadaki özel takas kartı (madde 367: her turda 1 özel)
const CARDS := [["damage", 2], ["trade_trigger", 3], ["crit_chance", 4]]
const PICK := 2
const HOVER := 1

const ROMAN := ["I", "II", "III", "IV", "V"]
const TIER_UPPER := ["SIRADAN", "NADİR", "EPİK", "EFSANEVİ"]
## level_up_screen.gd ROW_TIER_TEXT / ROW_GLOW_COLORS / ROW_VALUE_COLOR / ROW_COST_COLOR
const TIER_TXT := [Color("#cdd1d6"), Color("#a6c6f4"), Color("#d8aef4"), Color("#f8a890")]
const TIER_RIM := [Color("#dfe4ea"), Color("#9cc4ff"), Color("#dcb0ff"), Color("#ffc65a")]
const VALUE_COL := Color("#ffd66e")
const COST_COL := Color("#ff9a86")
const ROW_TEX := ["res://assets/ui/game/levelup_row_1.png", "res://assets/ui/game/levelup_row_2.png",
	"res://assets/ui/game/levelup_row_3.png", "res://assets/ui/game/levelup_row_4.png"]
const ROW_GLOW := "res://assets/ui/game/levelup_row_glow.png"
const DIE := "res://assets/ui/game/levelup_die.png"
const C_WEAPON := Color("#e8a05a")
const C_WUP := Color("#9fd27e")
const C_SHIELD := Color("#8ecdf0")

var _only: Array = []
var _player: Node = null
var D: Dictionary = {} ## o anki an: cards, pick, offers, hover, gold, shards, lvl_free, lvl_cost, shop_cost, can_go
var _ilk: Dictionary = {}
var _sonra: Dictionary = {}
var _shots: Dictionary = {}


func _initialize() -> void:
	var env: String = OS.get_environment("LEVEL_PAZAR_ONLY")
	if env != "":
		_only = Array(env.split(","))
	_run.call_deferred()


func _want(n: String) -> bool:
	return _only.is_empty() or _only.has(n)


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _out() -> String:
	var d: String = OS.get_environment("LEVEL_PAZAR_DIR")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261027/level_pazar/out")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _shot(name: String) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920: ## gizli masaüstünde kök doku x2 gelebilir
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	img.convert(Image.FORMAT_RGBA8)
	img.save_png(_out().path_join(name))
	print("SHOT %s" % name)
	return img


func _grid(imgs: Array) -> Image:
	var out := Image.create_empty(1920, 1080, false, Image.FORMAT_RGBA8)
	for i in mini(4, imgs.size()):
		var h: Image = (imgs[i] as Image).duplicate() as Image
		h.resize(960, 540, Image.INTERPOLATE_BILINEAR)
		out.blit_rect(h, Rect2i(0, 0, 960, 540), Vector2i((i % 2) * 960, (i / 2) * 540))
	return out


## ---------------------------------------------------------------- kurulum
func _load_scripts() -> void:
	DarkKit = load("res://scripts/shop_dark_kit.gd")
	FMK = load("res://scripts/fire_menu_kit.gd")
	DK = load("res://scripts/menu_dark_kit.gd")
	HT = load("res://scripts/hud_theme.gd")
	WTA = load("res://scripts/weapon_tier_art.gd")
	WC = load("res://scripts/weapon_catalog.gd")
	Logic = load("res://scripts/weapon_shop_logic.gd")
	CharsScript = load("res://scripts/characters.gd")
	IT = load("res://scripts/items.gd")
	ED = load("res://scripts/enchant_defs.gd")
	SED = load("res://scripts/shield_enchant_defs.gd")
	LSC = load("res://scripts/level_special_cards.gd")
	TS = load("res://scripts/tier_system.gd")
	UIK = load("res://scripts/ui_kit.gd")
	MSS = load("res://scripts/merchant_shop_screen.gd")
	GM = root.get_node("GameManager")


func _run() -> void:
	await process_frame
	_load_scripts()
	AudioServer.set_bus_mute(0, true)
	var nm: Node = root.get_node("NetworkManager")
	root.get_node("UISound").set("show_fps", false)
	nm.call("disconnect_from_room")
	GM.call("reset")
	GM.set("selected_char_id", CHAR_ID)
	GM.set("selected_character", CharsScript.get_def(CHAR_ID).get("skill", 1))
	GM.set("selected_start_weapon", "uzunkilic")
	GM.set("selected_pet", PET)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	var main: Node = current_scene
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	_kill_intro(main) ## açılışın "ADAYA CANAVARLAR SALDIRIYOR" duyurusu başlıkların üstüne düşüyordu
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	_player = main.get_node_or_null("Player")
	(_player as Node2D).global_position += Vector2(40, 170) ## kapının "eve gir" yazısı arka planda görünmesin
	_setup_state(_player)
	var hud: Node = main.get_node_or_null("HUD")
	if hud and hud.has_method("update_level"):
		hud.call("update_level", LEVEL)
	if hud:
		hud.set("visible", false) ## HUD'un sol üst / alt çubuğu başlık ve DEVAM'ın altında karışıyordu; tasarım temiz görünsün
	await _wait(1.0)
	_ilk = _collect_ilk(_player)
	_sonra = _collect_sonra(_player)
	GM.gold = int(_ilk["gold"]) ## HUD ilk anı göstersin
	await _wait(0.4)

	var ilk_imgs: Array = []
	var sonra_imgs: Array = []
	for k: String in ["A", "B", "C", "D"]:
		if not _want(k):
			continue
		for moment: String in ["ilk", "sonra"]:
			D = _ilk if moment == "ilk" else _sonra
			GM.gold = int(D["gold"])
			GM.add_weapon_shards(int(D["shards"]) - int(GM.weapon_shards))
			var layer := CanvasLayer.new()
			layer.layer = 120
			root.add_child(layer)
			var host := Control.new()
			host.set_anchors_preset(Control.PRESET_FULL_RECT)
			host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(host)
			match k:
				"A": _build_a(host)
				"B": _build_b(host)
				"C": _build_c(host)
				"D": _build_d(host)
			_caption(host, "%s · %s" % [{"A": "A - Ahşap Tezgâh", "B": "B - Klasik Pazar", "C": "C - Ateş Işığı Rafları",
				"D": "D - Gece Sıvası Yuvalar"}[k], "ekran açıldı" if moment == "ilk" else "kart seçildi + alışveriş + karıştırma"])
			await _wait(0.7)
			var img: Image = await _shot("%s_%s.png" % [k, moment])
			(ilk_imgs if moment == "ilk" else sonra_imgs).append(img)
			layer.queue_free()
			await _wait(0.2)
	if ilk_imgs.size() == 4:
		_grid(ilk_imgs).save_png(_out().path_join("ozet_ilk.png"))
		_grid(sonra_imgs).save_png(_out().path_join("ozet_sonra.png"))
		print("SHOT ozet")
	quit()


func _setup_state(p: Node) -> void:
	(load("res://scripts/meta_progress.gd") as GDScript).call("set_unlock_all", true) ## pazar yalnız açılmış silahları önerir
	GM.gold = 99999
	GM.add_weapon_shards(999 - int(GM.weapon_shards))
	if not Logic.buy_weapon(p, "fire_staff"):
		print("!! silah alınamadı: ", Logic.weapon_block_reason(p, "fire_staff"))
	for i in GM.owned_weapons.size():
		var e: Dictionary = GM.owned_weapons[i]
		ED.ensure_trait(e)
		if str(e.get("key", "")) == "uzunkilic" and e.has("enchant"):
			(e["enchant"] as Dictionary)["ups"] = [0, 1]
			e["shards_spent"] = int(e.get("shards_spent", 0)) + 10
	if "max_item_slots" in p:
		p.set("max_item_slots", 9)
	for key: String in ["kanli_yakut", "ceviklik_yuzugu"]:
		if not p.call("buy_item", key):
			print("!! eşya alınamadı: ", key)
	GM.set("game_time", GAME_TIME)
	GM.set("free_rerolls_per_card", 1)
	GM.gold = GOLD
	GM.add_weapon_shards(SHARDS - int(GM.weapon_shards))
	p.set("level", LEVEL)


## ---------------------------------------------------------------- veri
func _collect_cards(p: Node) -> Array:
	var lus: GDScript = load("res://scripts/level_up_screen.gd")
	var lscr: Object = lus.new()
	var ups: Array = lus.get_script_constant_map()["UPGRADES"]
	var sim: Dictionary = (load("res://scripts/stat_icon.gd") as GDScript).get_script_constant_map()
	var out: Array = []
	for spec: Array in CARDS:
		var id: String = spec[0]
		var tier: int = spec[1]
		var c: Dictionary = {"id": id, "tier": tier, "count": 0}
		var icon_id: String = id
		if LSC.is_special(id):
			var sc: Dictionary = LSC.as_card(id)
			icon_id = str(sc["icon"])
			c["title"] = str(sc["title"])
			c["cat"] = str(sc["cat"])
			c["value"] = str(LSC.gain_text(id, tier))
			c["cost"] = str(LSC.verb_text(id, tier))
			c["label"] = str(sc.get("gain_label", ""))
		else:
			var up: Dictionary = {}
			for u: Dictionary in ups:
				if str(u["id"]) == id:
					up = u
			var val: String = str(lscr.call("_scaled_desc_value", str(up["desc"]), tier, id)).replace("+", "").replace("-", "")
			c["title"] = str(up["title"])
			c["cat"] = str(up["cat"])
			c["value"] = ("-" if id == "cooldown_reduction" else "+") + val
			c["cost"] = str(LSC.cost_text(id, tier)) if LSC.has_cost(id) else "artar"
			c["label"] = ""
		if p and p.has_method("get_upgrade_count"):
			c["count"] = int(p.call("get_upgrade_count", id))
		c["icon"] = load(str(sim["ICON_DIR"]) + str((sim["ICON_PATHS"] as Dictionary).get(icon_id, "stat_damage.png")))
		out.append(c)
	(lscr as Node).free()
	return out


func _finish(o: Dictionary) -> Dictionary:
	if str(o.get("reason", "")) == "" and GM.gold < int(o["gold"]):
		o["reason"] = "%d altın eksik" % (int(o["gold"]) - GM.gold)
	o["bought"] = false
	return o


func _trait_lines(key: String) -> Array:
	var parts: PackedStringArray = WC.trait_text(key).split(" · ")
	var out: Array = []
	for i in range(1, parts.size()):
		out.append(parts[i])
	if not parts.is_empty():
		out.append(parts[0].replace("HASAR: ", "Hasar ").replace("saldırı gücü", "SG"))
	return out


func _o_weapon(p: Node, key: String) -> Dictionary:
	return _finish({"kind": "weapon", "tag": "SİLAH", "tag_col": C_WEAPON, "name": WC.display_name(key),
		"sub": "Yeni silah · %s" % WC.category_label(key), "lines": _trait_lines(key), "tex": WTA.texture(key, 1), "wtier": 1,
		"gold": Logic.weapon_price(GM.owned_weapons.size()), "shards": Logic.weapon_shard_cost(), "full": 0,
		"reason": Logic.weapon_block_reason(p, key)})


func _o_wup(slot: int) -> Dictionary:
	var e: Dictionary = GM.owned_weapons[slot]
	var key: String = str(e.get("key", ""))
	var rows: Array = Logic.slot_upgrade_rows(slot)
	var idx: int = rows.size() - 1
	for i in rows.size():
		if not Logic.wupgrade_taken(slot, i):
			idx = i
			break
	var row: Dictionary = rows[idx]
	var now_t: int = 1 + Logic.wupgrade_taken_count(slot)
	var next_t: int = 5 if bool(row["final"]) else now_t + 1
	return _finish({"kind": "wupgrade", "tag": "SİLAH GELİŞTİRME", "tag_col": C_WUP, "name": WC.display_name(key),
		"sub": "Kademe %s → %s · %s" % [ROMAN[now_t - 1], ROMAN[next_t - 1], str(row["name"])], "lines": [str(row["text"])],
		"tex": WTA.texture(key, next_t), "wtier": next_t, "gold": Logic.wupgrade_price(slot, idx),
		"shards": Logic.wupgrade_shard_cost(slot, idx), "full": 0, "reason": Logic.wupgrade_block_reason(slot, idx)})


func _o_shield(key: String) -> Dictionary:
	var d: Dictionary = SED.TYPES.get(key, {})
	return _finish({"kind": "shield", "tag": "MANA KALKANI", "tag_col": C_SHIELD, "name": SED.type_name(key),
		"sub": "Kalkan türü · Standart'ın yerine", "lines": [Logic.shield_summary(key), str(d.get("desc", ""))],
		"tex": DarkKit.tex(str(SED.ICONS.get(key, ""))), "wtier": 0, "gold": Logic.shield_price(), "shards": 0, "full": 0,
		"reason": Logic.shield_block_reason(key)})


func _o_supgrade(index: int) -> Dictionary:
	var st: String = SED.owned_type()
	return _finish({"kind": "supgrade", "tag": "KALKAN GELİŞTİRME", "tag_col": C_SHIELD, "name": SED.type_name(st),
		"sub": "Geliştirme · %d kez alındı" % Logic.upgrade_count(index), "lines": Array(Logic.upgrade_effect_text(index).split("\n")),
		"tex": DarkKit.tex(str(SED.ICONS.get(st, ""))), "wtier": 0, "gold": Logic.upgrade_price(index),
		"shards": Logic.SHARD_COST_UPGRADE, "full": 0, "reason": Logic.upgrade_block_reason(index)})


func _o_item(p: Node, key: String) -> Dictionary:
	var plan: Dictionary = IT.plan_purchase(key, GM.owned_items)
	var kd: int = IT.kademe(key)
	var gold: int = GM.apply_shop_discount(int(plan["cost"]))
	var sub: String = "Eşya"
	var cons: Array = plan.get("consume", [])
	if not cons.is_empty():
		var names: Array = []
		for idx in cons:
			names.append(IT.item_name(str((GM.owned_items[int(idx)] as Dictionary).get("key", ""))))
		sub = "Tarif: %s sende" % ", ".join(names)
	elif kd == 1 and IT.part_copies(key, GM.owned_items) > 0:
		sub = "%d. kopya · fiyat +%%%d" % [IT.part_copies(key, GM.owned_items) + 1, int(round((IT.repeat_mult(key, GM.owned_items) - 1.0) * 100.0))]
	elif not IT.recipe(key).is_empty():
		sub = "Tarifli eşya"
	var lines: Array = []
	for ln in IT.describe(key).split("\n\n")[0].split("\n"):
		if ln.strip_edges() != "":
			lines.append(ln.strip_edges())
	var passive: String = str(IT.get_def(key).get("passive", "")).split(". ")[0].trim_suffix(".")
	if passive != "" and not lines.any(func(l: String) -> bool: return l.replace("+", "").trim_suffix(".") == passive):
		lines.append(passive + ".")
	return _finish({"kind": "item", "tag": ["PARÇA", "EPİK", "EFSANEVİ"][kd - 1], "tag_col": DarkKit.TIER_COL[kd - 1],
		"name": IT.item_name(key), "sub": sub, "lines": lines, "tex": IT.icon(key), "wtier": 0, "gold": gold, "shards": 0,
		"full": int(plan["full"]) if int(plan["cost"]) < int(plan["full"]) else 0,
		"reason": IT.purchase_block_reason(key, GM.owned_items, int(p.call("get_max_item_slots")), plan)})


func _collect_ilk(p: Node) -> Dictionary:
	var out: Dictionary = {"cards": _collect_cards(p), "pick": -1, "hover": HOVER, "gold": GM.gold, "shards": GM.weapon_shards,
		"lvl_free": int(GM.get("free_rerolls_per_card")), "lvl_cost": MSS.reroll_cost(0), "shop_cost": MSS.reroll_cost(0),
		"shop_rerolls": 0, "can_go": false}
	out["offers"] = [_o_weapon(p, "mizrak"), _o_wup(0), _o_shield("shield_kale"), _o_item(p, "bile_tasi"),
		_o_item(p, "kemik_kolye"), _o_item(p, "kabuk_delen")]
	print("VERI ilk kartlar=", (out["cards"] as Array).map(func(c: Dictionary) -> String: return "%s %s (%s)" % [c["title"], c["value"], c["cost"]]))
	for o: Dictionary in out["offers"]:
		print("  ", o["tag"], " | ", o["name"], " | ", o["sub"], " | ", o["gold"], "+", o["shards"], " | ", o["reason"], " | ", o["lines"])
	return out


## Kale Mana Kalkanı alınır, pazar 1 kez karıştırılır (bedel düşer), yeni 6 seçenekten Kan Dişi alınır.
func _collect_sonra(p: Node) -> Dictionary:
	if not Logic.buy_shield(p, "shield_kale"):
		print("!! kalkan alınamadı: ", Logic.shield_block_reason("shield_kale"))
	var cost0: int = MSS.reroll_cost(0)
	GM.gold -= cost0
	var offers: Array = [_o_supgrade(0), _o_wup(1), _o_item(p, "kan_disi"), _o_item(p, "savascinin_kilici"), _o_weapon(p, "tabanca"),
		_o_item(p, "ceviklik_yuzugu")]
	var kd: Dictionary = offers[2]
	GM.gold -= int(kd["gold"])
	p.call("buy_item", "kan_disi")
	kd["bought"] = true
	## altın değişti: engel sebeplerini yeniden hesapla (alınan hariç)
	for o: Dictionary in offers:
		if not bool(o["bought"]) and str(o["reason"]).ends_with("altın eksik"):
			o["reason"] = ""
		if not bool(o["bought"]):
			_finish(o)
	var out: Dictionary = {"cards": _ilk["cards"], "pick": PICK, "hover": -1, "gold": GM.gold, "shards": GM.weapon_shards,
		"lvl_free": int(GM.get("free_rerolls_per_card")), "lvl_cost": MSS.reroll_cost(0), "shop_cost": MSS.reroll_cost(1),
		"shop_rerolls": 1, "can_go": true, "offers": offers}
	print("VERI sonra altın=%d karıştırma0=%d karıştırma1=%d" % [GM.gold, cost0, MSS.reroll_cost(1)])
	for o: Dictionary in offers:
		print("  ", o["tag"], " | ", o["name"], " | ", o["sub"], " | ", o["gold"], "+", o["shards"], " | ", o["reason"], " | ", o["lines"])
	return out


## ---------------------------------------------------------------- ortak çizim yardımcıları
func _place(parent: Control, n: Control, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> Control:
	parent.add_child(n)
	n.position = pos
	if sz != Vector2.ZERO:
		n.custom_minimum_size = sz
		n.size = sz
	return n


## Sağ kenarı right_x'te duran düğüm: en küçük boyu sola doğru büyür (ağaç dışı genişlik tahmini yanlış çıkıyordu).
func _place_right(parent: Control, n: Control, right_x: float, y: float) -> Control:
	parent.add_child(n)
	n.anchor_left = 0.0
	n.anchor_right = 0.0
	n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	n.offset_left = right_x
	n.offset_right = right_x
	n.offset_top = y
	n.offset_bottom = y
	return n


func _kill_intro(n: Node) -> void:
	for c in n.get_children():
		var s: Script = c.get_script()
		if s and s.resource_path.ends_with("house_intro.gd"):
			c.set_process(false) ## silmek başka betiklerde "freed instance" hatası veriyordu
		else:
			_kill_intro(c)


func _dim(host: Control, a: float) -> void:
	var r := ColorRect.new()
	r.color = Color(0.02, 0.02, 0.04, a)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(r)


func _caption(host: Control, text: String) -> void:
	var k = DarkKit.new(DarkKit.PAL_SLATE)
	var b: PanelContainer = k.box(Color(0, 0, 0, 0.7), Color(0, 0, 0, 0), 6, 0, 4)
	b.add_child(k.lbl(text, 24, Color("#e8e2d0")))
	_place_right(host, b, 1904, 1036)


func _card_list() -> Array:
	return D["cards"]


func _offers() -> Array:
	return D["offers"]


func _icon(k, o: Dictionary, s: float, dim: bool = false) -> Control:
	if int(o["wtier"]) > 0:
		return k.wicon(o["tex"], s, int(o["wtier"]), dim)
	return k.icon(o["tex"], s, dim)


## Fiyat satırı: [altın] (+ [parçacık]); indirimli fiyatın önünde üstü çizili tam fiyat; altını yetmiyorsa kırmızı.
func _price(k, o: Dictionary, fs: int, gold_col: Color, center: bool = true) -> HBoxContainer:
	var r: HBoxContainer = k.h(14)
	if center:
		r.alignment = BoxContainer.ALIGNMENT_CENTER
	if int(o["full"]) > 0:
		r.add_child(k.strike_lbl(str(o["full"]), 24, k.c("dim")))
	var short: bool = str(o["reason"]).ends_with("altın eksik")
	r.add_child(k.amt(int(o["gold"]), fs, k.c("bad") if short else gold_col))
	if int(o["shards"]) > 0:
		var shard_short: bool = int(D["shards"]) < int(o["shards"])
		r.add_child(k.amt(int(o["shards"]), fs, k.c("bad") if shard_short else DarkKit.SHARD_TEXT, "shard"))
	return r


func _die_row(k, text: String, fs: int, col: Color, free: int, cost: int) -> HBoxContainer:
	var r: HBoxContainer = k.h(10)
	r.add_child(k.icon(load(DIE), 33))
	r.add_child(k.lbl(text, fs, col))
	if free > 0:
		r.add_child(k.lbl("%d ücretsiz" % free, 24, k.c("good")))
	else:
		r.add_child(k.amt(cost, 24, k.c("price")))
	return r


func _lvl_reroll(k, fs: int = 32, kind: String = "ghost", ht: float = 60.0, w: float = 0.0) -> Button:
	var free: int = int(D["lvl_free"]) if int(D["pick"]) < 0 else 0
	var b: Button = k.row_btn(_die_row(k, "KARIŞTIR", fs, k.c("text"), free, int(D["lvl_cost"])), kind, ht, w)
	if int(D["pick"]) >= 0:
		b.disabled = true
		b.modulate = Color(1, 1, 1, 0.45)
	return b


func _shop_reroll(k, fs: int = 32, kind: String = "ghost", ht: float = 60.0, w: float = 0.0) -> Button:
	return k.row_btn(_die_row(k, "KARIŞTIR", fs, k.c("text"), 0, int(D["shop_cost"])), kind, ht, w)


func _go_btn(k, w: float = 420.0, ht: float = 72.0, fs: int = 40) -> Button:
	var b: Button = k.btn("DEVAM ET" if bool(D["can_go"]) else "ÖNCE KART SEÇ", "primary", fs, ht, w)
	b.disabled = not bool(D["can_go"])
	return b


func _countdown(k, fs: int = 32) -> PanelContainer:
	var p: PanelContainer = k.box(k.c("inset"), k.c("line_hi"), 8, 3, 6)
	var r: HBoxContainer = k.h(10)
	r.add_child(k.lbl("KALAN", 24, k.c("dim")))
	r.add_child(k.lbl("%d sn" % COUNTDOWN, fs, k.c("accent")))
	p.add_child(r)
	return p


func _chips(k) -> HBoxContainer:
	var r: HBoxContainer = k.h(12)
	var cg: PanelContainer = k.chip("gold", "ALTIN")
	(cg.get_meta("label") as Label).text = str(D["gold"])
	r.add_child(cg)
	var cs: PanelContainer = k.chip("shard", "PARÇACIK")
	(cs.get_meta("label") as Label).text = str(D["shards"])
	r.add_child(cs)
	return r


func _free_badge(k, fs: int = 24) -> PanelContainer:
	var used: bool = int(D["pick"]) >= 0
	var p: PanelContainer = k.box(k.c("inset"), k.c("line") if used else k.c("good"), 6, 3, 4)
	var r: HBoxContainer = k.h(8)
	r.add_child(k.glyph(DarkKit.G_CHECK if used else DarkKit.G_STAR, k.c("dim") if used else k.c("good"), 3))
	r.add_child(k.lbl("ÜCRETSİZ SEÇİM KULLANILDI" if used else "1 ÜCRETSİZ SEÇİM", fs, k.c("dim") if used else k.c("good")))
	p.add_child(r)
	return p


func _bought_stamp(k, fs: int = 32) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: PanelContainer = k.box(Color(k.c("inset"), 0.92), k.c("good"), 8, 3, 4)
	var r: HBoxContainer = k.h(8)
	r.add_child(k.glyph(DarkKit.G_CHECK, k.c("good"), 4))
	r.add_child(k.lbl("ALINDI", fs, k.c("good")))
	p.add_child(r)
	cc.add_child(p)
	return cc


func _sec_head(k, pat: Array, title: String, fs: int = 40) -> HBoxContainer:
	var r: HBoxContainer = k.h(12)
	r.add_child(k.glyph(pat, k.c("accent"), 4))
	r.add_child(k.lbl(title, fs, k.c("accent")))
	return r


## ================================================================ A - AHŞAP TEZGÂH (demirci ahşabı)
func _build_a(host: Control) -> void:
	var k = DarkKit.new(DarkKit.PAL_WOOD)
	host.theme = k.theme()
	_dim(host, 0.55)
	var t: Label = k.lbl("SEVİYE %d" % LEVEL, 64, k.c("accent"), HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_outline_color", Color("#20150d"))
	t.add_theme_constant_override("outline_size", 10)
	_place(host, t, Vector2(0, 28), Vector2(1920, 72))
	_place(host, k.lbl("1 kart ücretsiz  ·  tezgâhtan dilediğini al", 32, k.c("dim"), HORIZONTAL_ALIGNMENT_CENTER), Vector2(0, 100), Vector2(1920, 36))
	var ch: HBoxContainer = _chips(k)
	ch.add_child(_countdown(k))
	ch.move_child(ch.get_child(ch.get_child_count() - 1), 0)
	_place_right(host, ch, 1856, 44)

	## sol: kapsül satırları (bugünkü level_up_screen dokuları, dar)
	var lb: PanelContainer = k.box(k.c("panel"), k.c("line_hi"), 20, 3, 8)
	_place(host, lb, Vector2(64, 160), Vector2(708, 780))
	var lv: VBoxContainer = k.v(18)
	lb.add_child(lv)
	var lh: HBoxContainer = _sec_head(k, DarkKit.G_STAR, "LEVEL KARTI")
	lh.add_child(k.sp(0, 0, true))
	lh.add_child(_free_badge(k))
	lv.add_child(lh)
	lv.add_child(k.hline())
	var cards: Array = _card_list()
	for i in cards.size():
		lv.add_child(_a_row(k, cards[i], i))
	lv.add_child(k.sp(0, 0, false, true))
	var rr: HBoxContainer = k.h(0)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rr.add_child(_lvl_reroll(k, 32, "ghost", 60, 360))
	lv.add_child(rr)

	## sağ: tezgâh 3x2
	var rb: PanelContainer = k.box(k.c("panel"), k.c("line_hi"), 20, 3, 8)
	_place(host, rb, Vector2(796, 160), Vector2(1060, 780))
	var rv: VBoxContainer = k.v(16)
	rb.add_child(rv)
	var rh: HBoxContainer = _sec_head(k, DarkKit.G_BAG, "TEZGÂH")
	rh.add_child(k.lbl("satıcı + demirci", 24, k.c("dim")))
	rh.add_child(k.sp(0, 0, true))
	rh.add_child(_shop_reroll(k, 32, "ghost", 56))
	rv.add_child(rh)
	rv.add_child(k.hline())
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 16)
	var offers: Array = _offers()
	for i in offers.size():
		g.add_child(_a_offer(k, offers[i], i == int(D["hover"]), 329, 316))
	rv.add_child(g)

	var go: Button = _go_btn(k)
	_place(host, go, Vector2(750, 966), Vector2(420, 72))


func _a_row(k, c: Dictionary, i: int) -> Control:
	var tier: int = int(c["tier"])
	var sel: bool = int(D["pick"]) == i
	var dim: bool = int(D["pick"]) >= 0 and not sel
	var w: float = 668.0
	var hh: float = 156.0
	var root_c := Control.new()
	root_c.custom_minimum_size = Vector2(w, hh)
	root_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if sel:
		var glow := NinePatchRect.new()
		glow.texture = load(ROW_GLOW)
		glow.patch_margin_left = 30
		glow.patch_margin_right = 30
		glow.patch_margin_top = 30
		glow.patch_margin_bottom = 30
		glow.modulate = TIER_RIM[tier - 1]
		_place(root_c, glow, Vector2(-15, -12), Vector2(w + 30, hh + 24))
	var np := NinePatchRect.new()
	np.texture = load(ROW_TEX[tier - 1])
	np.patch_margin_left = 24
	np.patch_margin_right = 24
	np.patch_margin_top = 24
	np.patch_margin_bottom = 24
	_place(root_c, np, Vector2.ZERO, Vector2(w, hh))
	var ic: CenterContainer = k.icon(c["icon"], 96)
	_place(root_c, ic, Vector2(24, 24), Vector2(102, 102))
	_place(root_c, k.lbl(str(c["title"]), 32, k.c("text")), Vector2(148, 22))
	var sub: String = "%s  ·  %s" % [TS.NAMES[tier - 1], c["cat"]]
	if str(c["label"]) != "":
		sub += "  ·  " + str(c["label"])
	_place(root_c, k.lbl(sub, 24, TIER_TXT[tier - 1]), Vector2(148, 62))
	if sel:
		var sr: HBoxContainer = k.h(8)
		sr.add_child(k.glyph(DarkKit.G_CHECK, k.c("good"), 3))
		sr.add_child(k.lbl("SEÇİLDİ · ücretsiz", 24, k.c("good")))
		_place(root_c, sr, Vector2(148, 98))
	elif int(c["count"]) > 0:
		_place(root_c, k.lbl("%dx alındı" % int(c["count"]), 24, k.c("dim")), Vector2(148, 98))
	var rv: VBoxContainer = k.v(0)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_child(k.lbl(str(c["value"]), 64, VALUE_COL, HORIZONTAL_ALIGNMENT_RIGHT))
	rv.add_child(k.lbl(str(c["cost"]), 24, COST_COL, HORIZONTAL_ALIGNMENT_RIGHT))
	## satır ağaca eklenmeden kuruluyor: sabit genişlik yedek fontla ölçülüp büyük kalıyordu -> sağ kenara yapışık, sola büyür
	_place_right(root_c, rv, w - 36, 30)
	if dim:
		root_c.modulate = Color(1, 1, 1, 0.42)
	return root_c


func _a_offer(k, o: Dictionary, hover: bool, w: float, hh: float) -> Control:
	var col: Color = o["tag_col"]
	var card: PanelContainer = k.box(k.c("panel3") if hover else k.c("panel2"), k.c("accent") if hover else k.c("line"), 12, 3, 6)
	card.custom_minimum_size = Vector2(w, hh)
	var v: VBoxContainer = k.v(4)
	card.add_child(v)
	var tag: PanelContainer = k.box(Color(col, 0.16), Color(0, 0, 0, 0), 4, 0, 4)
	var tr: HBoxContainer = k.h(8)
	tr.alignment = BoxContainer.ALIGNMENT_CENTER
	tr.add_child(k.glyph(DarkKit.G_DIAMOND, col, 3))
	tr.add_child(k.lbl(str(o["tag"]), 24, col))
	tag.add_child(tr)
	v.add_child(tag)
	v.add_child(k.sp(0, 4))
	var well: PanelContainer = k.box(k.c("inset"), Color(col, 0.5), 6, 2, 6)
	well.custom_minimum_size = Vector2(112, 104)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.add_child(k.center(_icon(k, o, 88)))
	v.add_child(well)
	v.add_child(k.clip(str(o["name"]), 32, k.c("text"), w - 24, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.clip(str(o["sub"]), 24, k.c("dim"), w - 24, HORIZONTAL_ALIGNMENT_CENTER))
	var lines: Array = o["lines"]
	if not lines.is_empty():
		v.add_child(k.clip(str(lines[0]), 24, k.c("good"), w - 24, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.sp(0, 0, false, true))
	if str(o["reason"]) != "" and not bool(o["bought"]):
		v.add_child(k.clip(str(o["reason"]), 24, k.c("bad"), w - 24, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_price(k, o, 32, k.c("price")))
	if bool(o["bought"]):
		v.modulate = Color(1, 1, 1, 0.3)
		card.add_child(_bought_stamp(k))
	return card


## ================================================================ B - KLASİK PAZAR (seyyar satıcı kayrağı, LoL)
func _build_b(host: Control) -> void:
	var k = DarkKit.new(DarkKit.PAL_SLATE)
	host.theme = k.theme()
	_dim(host, 0.45)
	var win: PanelContainer = k.box(k.c("panel"), k.c("line_hi"), 24, 3, 8)
	_place(host, win, Vector2(72, 32), Vector2(1776, 1000))
	var col: VBoxContainer = k.v(14)
	win.add_child(col)
	var head: HBoxContainer = k.h(16)
	head.add_child(k.glyph(DarkKit.G_CROWN, k.c("accent"), 5))
	head.add_child(k.lbl("SEVİYE %d" % LEVEL, 48, k.c("accent")))
	head.add_child(k.lbl("ödül ve pazar", 32, k.c("dim")))
	head.add_child(k.sp(0, 0, true))
	head.add_child(_countdown(k))
	head.add_child(_chips(k))
	col.add_child(head)
	col.add_child(k.hline())
	var body: HBoxContainer = k.h(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	## sol: 3 dikey kart
	var left: VBoxContainer = k.v(14)
	left.custom_minimum_size.x = 768
	body.add_child(left)
	var lh: HBoxContainer = _sec_head(k, DarkKit.G_STAR, "LEVEL KARTI", 32)
	lh.add_child(k.sp(0, 0, true))
	lh.add_child(_lvl_reroll(k, 24, "ghost", 48))
	left.add_child(lh)
	left.add_child(_free_badge(k))
	var cr: HBoxContainer = k.h(16)
	cr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var cards: Array = _card_list()
	for i in cards.size():
		cr.add_child(_b_card(k, cards[i], i))
	left.add_child(cr)

	var div := ColorRect.new()
	div.color = k.c("line")
	div.custom_minimum_size = Vector2(3, 0)
	body.add_child(div)

	## sağ: 6 satır
	var right: VBoxContainer = k.v(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var rh: HBoxContainer = _sec_head(k, DarkKit.G_BAG, "PAZAR", 32)
	rh.add_child(k.lbl("silah · geliştirme · mana kalkanı · eşya", 24, k.c("dim")))
	rh.add_child(k.sp(0, 0, true))
	rh.add_child(_shop_reroll(k, 24, "ghost", 48))
	right.add_child(rh)
	var offers: Array = _offers()
	for i in offers.size():
		right.add_child(_b_row(k, offers[i], i == int(D["hover"])))
	right.add_child(k.sp(0, 0, false, true))

	col.add_child(k.hline())
	var foot: HBoxContainer = k.h(16)
	foot.add_child(k.lbl("Aldığın her şey anında işlenir · kart seçilmeden çıkılmaz · süre dolarsa kart otomatik seçilir", 24, k.c("dim")))
	foot.add_child(k.sp(0, 0, true))
	foot.add_child(_go_btn(k, 360, 64, 32))
	col.add_child(foot)


func _b_card(k, c: Dictionary, i: int) -> Control:
	var tier: int = int(c["tier"])
	var tc: Color = TIER_RIM[tier - 1]
	var sel: bool = int(D["pick"]) == i
	var dim: bool = int(D["pick"]) >= 0 and not sel
	var card: PanelContainer = k.box(k.c("panel3") if sel else k.c("panel2"), k.c("accent") if sel else Color(tc, 0.7), 12, 3, 6)
	card.custom_minimum_size = Vector2(245, 0)
	var v: VBoxContainer = k.v(6)
	card.add_child(v)
	var strip: PanelContainer = k.box(Color(tc, 0.22), Color(0, 0, 0, 0), 4, 0, 4)
	strip.add_child(k.lbl(TIER_UPPER[tier - 1], 24, TIER_TXT[tier - 1], HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(strip)
	v.add_child(k.sp(0, 6))
	v.add_child(k.center(k.tile(c["icon"], 112, tc)))
	v.add_child(k.sp(0, 4))
	v.add_child(k.wrap(str(c["title"]), 32, k.c("text"), 221, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.lbl(str(c["value"]), 64, VALUE_COL, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.wrap(str(c["cost"]), 24, COST_COL, 221, HORIZONTAL_ALIGNMENT_CENTER))
	var cat: String = str(c["cat"])
	if str(c["label"]) != "":
		cat += " · " + str(c["label"])
	v.add_child(k.wrap(cat, 24, k.c("dim"), 221, HORIZONTAL_ALIGNMENT_CENTER))
	if int(c["count"]) > 0:
		v.add_child(k.lbl("%dx alındı" % int(c["count"]), 24, k.c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.sp(0, 0, false, true))
	if sel:
		var r: HBoxContainer = k.h(8)
		r.add_child(k.glyph(DarkKit.G_CHECK, k.c("good"), 3))
		r.add_child(k.lbl("SEÇİLDİ", 32, k.c("good")))
		v.add_child(k.row_btn(r, "off", 56, 221))
	else:
		var b: Button = k.btn("SEÇ · ÜCRETSİZ", "primary" if not dim else "ghost", 24, 56, 221)
		b.disabled = dim
		v.add_child(b)
	if dim:
		card.modulate = Color(1, 1, 1, 0.45)
	return card


func _b_row(k, o: Dictionary, hover: bool) -> Control:
	var col: Color = o["tag_col"]
	var box: PanelContainer = k.box(k.c("panel3") if hover else k.c("panel2"), k.c("accent") if hover else k.c("line"), 8, 3, 6)
	box.custom_minimum_size.y = 100
	var r: HBoxContainer = k.h(16)
	box.add_child(r)
	var tile: PanelContainer = k.box(k.c("inset"), col, 4, 3, 4)
	tile.custom_minimum_size = Vector2(84, 84)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(k.center(_icon(k, o, 72)))
	r.add_child(tile)
	var mid: VBoxContainer = k.v(0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	var nr: HBoxContainer = k.h(12)
	nr.add_child(k.lbl(str(o["name"]), 32, k.c("text")))
	var pill: PanelContainer = k.box(k.c("inset"), Color(col, 0.8), 4, 2, 4)
	pill.add_child(k.lbl(str(o["tag"]), 24, col))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nr.add_child(pill)
	mid.add_child(nr)
	mid.add_child(k.clip(str(o["sub"]), 24, k.c("dim"), 480))
	var lines: Array = o["lines"]
	if not lines.is_empty():
		mid.add_child(k.clip(str(lines[0]), 24, k.c("good"), 480))
	r.add_child(mid)
	var pv: VBoxContainer = k.v(2)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.custom_minimum_size.x = 170
	var pr: HBoxContainer = _price(k, o, 32, k.c("price"), false)
	pr.alignment = BoxContainer.ALIGNMENT_END
	pv.add_child(pr)
	if str(o["reason"]) != "" and not bool(o["bought"]):
		pv.add_child(k.lbl(str(o["reason"]), 24, k.c("bad"), HORIZONTAL_ALIGNMENT_RIGHT))
	r.add_child(pv)
	var b: Button
	if bool(o["bought"]):
		var br: HBoxContainer = k.h(6)
		br.add_child(k.glyph(DarkKit.G_CHECK, k.c("good"), 3))
		br.add_child(k.lbl("ALINDI", 24, k.c("good")))
		b = k.row_btn(br, "off", 56, 140)
	else:
		b = k.btn("AL", "primary", 32, 56, 140)
		b.disabled = str(o["reason"]) != ""
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(b)
	if bool(o["bought"]):
		tile.modulate = Color(1, 1, 1, 0.4)
		mid.modulate = Color(1, 1, 1, 0.4)
		pv.modulate = Color(1, 1, 1, 0.4)
	return box


## ================================================================ C - ATEŞ IŞIĞI RAFLARI (kutusuz)
func _build_c(host: Control) -> void:
	var k = DarkKit.new(DarkKit.PAL_WOOD)
	host.theme = k.theme()
	_dim(host, 0.3)
	var shade: TextureRect = FMK.left_shade()
	host.add_child(shade)
	var rshade: TextureRect = FMK.left_shade()
	rshade.flip_h = true
	host.add_child(rshade)
	var mid_dim := ColorRect.new()
	mid_dim.color = Color(0.05, 0.035, 0.025, 0.55)
	mid_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(host, mid_dim, Vector2.ZERO, Vector2(1920, 1080))

	## sol: başlık + mumlu kart listesi
	var sub: Label = FMK.lbl("BİR KART SEÇ · ÜCRETSİZ" if int(D["pick"]) < 0 else "KART SEÇİLDİ · ücretsiz hak kullanıldı", 32,
		FMK.C_TAG)
	var tb: VBoxContainer = FMK.title_block("SEVİYE %d" % LEVEL, sub)
	_place(host, tb, Vector2(56, 40))
	var cards: Array = _card_list()
	var y: float = 300.0
	for i in cards.size():
		_place(host, _c_card(k, cards[i], i), Vector2(40, y), Vector2(700, 128))
		if i < cards.size() - 1:
			var ln := ColorRect.new()
			ln.color = Color(FMK.C_LINE, 0.9)
			_place(host, ln, Vector2(120, y + 134), Vector2(600, 2))
		y += 142.0
	var lh: HBoxContainer = FMK.hint([["BOŞLUK", "kartları karıştır"]])
	var lfree: int = int(D["lvl_free"]) if int(D["pick"]) < 0 else 0
	lh.add_child(k.sp(8))
	if int(D["pick"]) >= 0:
		lh.add_child(FMK.lbl("(seçildi)", 24, FMK.C_SUB))
	elif lfree > 0:
		lh.add_child(FMK.lbl("%d ücretsiz" % lfree, 24, k.c("good")))
	else:
		lh.add_child(k.amt(int(D["lvl_cost"]), 24, FMK.C_GOLD))
	_place(host, lh, Vector2(124, 740))

	## sağ: iki raf
	var rt: Label = FMK.lbl("TEZGÂH", 56, FMK.C_GOLD)
	rt.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 1))
	rt.add_theme_constant_override("outline_size", 10)
	_place(host, rt, Vector2(820, 56))
	_place(host, FMK.lbl("satıcının ve demircinin bugünkü malları", 32, FMK.C_TAG), Vector2(820, 124))
	var gr: HBoxContainer = k.h(24)
	gr.add_child(k.amt(int(D["gold"]), 40, FMK.C_GOLD))
	gr.add_child(k.amt(int(D["shards"]), 40, DarkKit.SHARD_TEXT, "shard"))
	_place_right(host, gr, 1872, 64)
	var cdl: Label = FMK.lbl("%d sn" % COUNTDOWN, 40, FMK.C_CREAM)
	_place_right(host, cdl, 1872, 118)
	var offers: Array = _offers()
	for s in 2:
		var sy: float = 196.0 + s * 372.0
		for j in 3:
			var i: int = s * 3 + j
			_c_offer(host, k, offers[i], i == int(D["hover"]), Vector2(830 + j * 350, sy))
		_c_plank(host, Vector2(812, sy + 140), 1068)

	var hint: HBoxContainer = FMK.hint([["SOL TIK", "seç / al"], ["BOŞLUK", "kart karıştır"], ["R", "tezgâhı karıştır"]])
	_place(host, hint, Vector2(56, 1000))
	var rr: HBoxContainer = FMK.hint([["R", "TEZGÂHI KARIŞTIR"]])
	rr.add_child(k.sp(8))
	rr.add_child(k.amt(int(D["shop_cost"]), 24, FMK.C_GOLD))
	rr.add_child(k.sp(40))
	var go: HBoxContainer = FMK.hint([["ENTER", "DEVAM ET" if bool(D["can_go"]) else "önce kart seç"]])
	if not bool(D["can_go"]):
		go.modulate = Color(1, 1, 1, 0.5)
	rr.add_child(go)
	_place_right(host, rr, 1872, 940)


func _c_card(k, c: Dictionary, i: int) -> Control:
	var tier: int = int(c["tier"])
	var sel: bool = int(D["pick"]) == i
	var dim: bool = int(D["pick"]) >= 0 and not sel
	var row: HBoxContainer = k.h(14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(64, 64)
	if sel:
		slot.add_child(FMK.Candle.new(load(FMK.CANDLES_PATH) as Texture2D))
	row.add_child(slot)
	row.add_child(k.icon(c["icon"], 80))
	var v: VBoxContainer = k.v(-2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl: Label = FMK.lbl(str(c["title"]), 48, FMK.C_GOLD if sel else FMK.C_CREAM)
	if sel:
		tl.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
		tl.add_theme_constant_override("outline_size", 6)
	v.add_child(tl)
	var s: String = "%s · %s" % [TS.NAMES[tier - 1], c["cat"]]
	if sel:
		s += " · SEÇİLDİ"
	v.add_child(FMK.lbl(s, 24, TIER_TXT[tier - 1]))
	row.add_child(v)
	var rv: VBoxContainer = k.v(-4)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_child(FMK.lbl(str(c["value"]), 56, VALUE_COL))
	var cl: Label = FMK.lbl(str(c["cost"]), 24, COST_COL)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(cl)
	(rv.get_child(0) as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(rv)
	if dim:
		row.modulate = Color(1, 1, 1, 0.4)
	return row


## Raf tahtası: haritanın/HUD'un ceviz tonları (HudTheme), iki konsol.
func _c_plank(host: Control, pos: Vector2, w: float) -> void:
	for spec: Array in [[Vector2(0, 0), Vector2(w, 30), HT.OUTLINE], [Vector2(3, 3), Vector2(w - 6, 24), HT.RIM],
			[Vector2(3, 3), Vector2(w - 6, 4), HT.RIM_HI], [Vector2(3, 21), Vector2(w - 6, 6), HT.RIM_LO],
			[Vector2(60, 30), Vector2(18, 26), HT.OUTLINE], [Vector2(63, 30), Vector2(12, 22), HT.RIM_LO],
			[Vector2(w - 78, 30), Vector2(18, 26), HT.OUTLINE], [Vector2(w - 75, 30), Vector2(12, 22), HT.RIM_LO]]:
		var r := ColorRect.new()
		r.color = spec[2]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(host, r, pos + spec[0], spec[1])


## Raftaki mal: ikon tahtanın üstünde durur, altında iple asılı fiyat levhası (HUD levhası), sonra ad + tür.
func _c_offer(host: Control, k, o: Dictionary, hover: bool, pos: Vector2) -> void:
	var w: float = 320.0
	var col: Color = o["tag_col"]
	var bought: bool = bool(o["bought"])
	if hover:
		var cand = FMK.Candle.new(load(FMK.CANDLES_PATH) as Texture2D)
		_place(host, cand, pos + Vector2(w - 70, 76))
	var ic: Control = _icon(k, o, 128, bought)
	var icc := CenterContainer.new()
	icc.add_child(ic)
	_place(host, icc, pos + Vector2(0, 8), Vector2(w, 132))
	for x: float in [w * 0.5 - 50, w * 0.5 + 48]:
		var s := ColorRect.new()
		s.color = Color("#2a1c10")
		_place(host, s, pos + Vector2(x, 168), Vector2(2, 20))
	var tag: PanelContainer = PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UIK.panel_style("hud_plaque"))
	var tr: HBoxContainer = _price(k, o, 32, FMK.C_GOLD)
	tag.add_child(tr)
	host.add_child(tag)
	tag.reset_size()
	var tw: float = maxf(k.est_w(tr) + 52.0, 150.0)
	tag.custom_minimum_size = Vector2(tw, 56)
	tag.size = tag.custom_minimum_size
	tag.position = pos + Vector2((w - tw) * 0.5, 186)
	if bought:
		tag.modulate = Color(1, 1, 1, 0.35)
	var nl: Label = FMK.lbl(str(o["name"]), 32, FMK.C_GOLD if hover else (FMK.C_SUB if bought else FMK.C_CREAM))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.clip_text = true
	_place(host, nl, pos + Vector2(0, 250), Vector2(w, 36))
	var tl_text: String = str(o["tag"])
	var tl_col: Color = col
	if bought:
		tl_text = "ALINDI"
		tl_col = k.c("good")
	elif str(o["reason"]) != "":
		tl_text = str(o["reason"])
		tl_col = FMK.C_RED
	var tl: Label = FMK.lbl(tl_text, 24, tl_col)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(host, tl, pos + Vector2(0, 286), Vector2(w, 28))
	if hover: ## üstünde durulan malın tek satırlık ayrıntısı (alt rafa taşmasın)
		var dl: Label = k.clip(str(o["sub"]), 24, FMK.C_GOLD_DIM, w, HORIZONTAL_ALIGNMENT_CENTER)
		_place(host, dl, pos + Vector2(0, 314), Vector2(w, 28))


## ================================================================ D - GECE SIVASI YUVALAR (+ ayrıntı kartı)
func _build_d(host: Control) -> void:
	var k = DarkKit.new(DarkKit.PAL_NIGHT)
	host.theme = k.theme()
	_dim(host, 0.5)
	var t: Label = k.lbl("SEVİYE %d" % LEVEL, 56, k.c("accent"))
	_place(host, t, Vector2(64, 36))
	_place(host, k.lbl("Level kartı ücretsiz, pazar altınla", 32, k.c("dim")), Vector2(64, 96))
	var tr: HBoxContainer = k.h(12)
	tr.add_child(_countdown(k))
	tr.add_child(_chips(k))
	_place_right(host, tr, 1856, 40)

	## sol: kart sütunu
	var lb: PanelContainer = k.box(k.c("panel"), k.c("line_hi"), 20, 3, 8)
	_place(host, lb, Vector2(64, 156), Vector2(612, 784))
	var lv: VBoxContainer = k.v(16)
	lb.add_child(lv)
	var lh: HBoxContainer = _sec_head(k, DarkKit.G_STAR, "LEVEL KARTI", 32)
	lh.add_child(k.sp(0, 0, true))
	lh.add_child(_free_badge(k))
	lv.add_child(lh)
	var cards: Array = _card_list()
	for i in cards.size():
		lv.add_child(_d_card(k, cards[i], i))
	lv.add_child(k.sp(0, 0, false, true))
	lv.add_child(_lvl_reroll(k, 32, "ghost", 60, 572))

	## sağ: yuvalar + ayrıntı
	var rb: PanelContainer = k.box(k.c("panel"), k.c("line_hi"), 20, 3, 8)
	_place(host, rb, Vector2(700, 156), Vector2(1156, 784))
	var rv: VBoxContainer = k.v(16)
	rb.add_child(rv)
	var rh: HBoxContainer = _sec_head(k, DarkKit.G_BAG, "PAZAR", 32)
	rh.add_child(k.lbl("6 rastgele: silah, geliştirme, mana kalkanı, eşya", 24, k.c("dim")))
	rv.add_child(rh)
	var body: HBoxContainer = k.h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(body)
	var gv: VBoxContainer = k.v(16)
	body.add_child(gv)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	var offers: Array = _offers()
	var focus: int = int(D["hover"])
	if focus < 0:
		focus = 0 ## "sonra": ayrıntıda kalkan geliştirmesi
	for i in offers.size():
		g.add_child(_d_slot(k, offers[i], i == focus))
	gv.add_child(g)
	gv.add_child(k.sp(0, 0, false, true))
	gv.add_child(_shop_reroll(k, 32, "ghost", 60, 576))
	body.add_child(_d_detail(k, offers[focus]))

	var go: Button = _go_btn(k)
	_place(host, go, Vector2(750, 966), Vector2(420, 72))


func _d_card(k, c: Dictionary, i: int) -> Control:
	var tier: int = int(c["tier"])
	var tc: Color = TIER_RIM[tier - 1]
	var sel: bool = int(D["pick"]) == i
	var dim: bool = int(D["pick"]) >= 0 and not sel
	var box: PanelContainer = k.box(k.c("panel3") if sel else k.c("panel2"), k.c("accent") if sel else Color(tc, 0.55), 14, 3, 6)
	box.custom_minimum_size.y = 176
	var r: HBoxContainer = k.h(18)
	box.add_child(r)
	var tile: Control = k.tile(c["icon"], 128, tc)
	r.add_child(tile)
	var v: VBoxContainer = k.v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top: HBoxContainer = k.h(8)
	top.add_child(k.lbl(TIER_UPPER[tier - 1], 24, TIER_TXT[tier - 1]))
	top.add_child(k.lbl("· " + str(c["cat"]), 24, k.c("dim")))
	if sel:
		top.add_child(k.sp(0, 0, true))
		top.add_child(k.glyph(DarkKit.G_CHECK, k.c("good"), 3))
		top.add_child(k.lbl("SEÇİLDİ", 24, k.c("good")))
	v.add_child(top)
	v.add_child(k.lbl(str(c["title"]), 40, k.c("text")))
	var vr: HBoxContainer = k.h(14)
	vr.add_child(k.lbl(str(c["value"]), 56, VALUE_COL))
	var cl: Label = k.lbl(str(c["cost"]), 24, COST_COL)
	cl.size_flags_vertical = Control.SIZE_SHRINK_END
	vr.add_child(cl)
	v.add_child(vr)
	r.add_child(v)
	if dim:
		box.modulate = Color(1, 1, 1, 0.42)
	return box


func _d_slot(k, o: Dictionary, focus: bool) -> Control:
	var col: Color = o["tag_col"]
	var bought: bool = bool(o["bought"])
	var box: PanelContainer = k.box(k.c("panel3") if focus else k.c("inset"), k.c("accent") if focus else Color(col, 0.75), 8, 3, 6)
	box.custom_minimum_size = Vector2(182, 256)
	var v: VBoxContainer = k.v(4)
	box.add_child(v)
	v.add_child(k.lbl(str(o["tag"]).split(" ")[0], 24, col, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.center(_icon(k, o, 112, bought)))
	v.add_child(k.clip(str(o["name"]), 24, k.c("text"), 162, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.sp(0, 0, false, true))
	v.add_child(_price(k, o, 24, k.c("price")))
	if bought:
		v.modulate = Color(1, 1, 1, 0.3)
		box.add_child(_bought_stamp(k, 24))
	return box


func _d_detail(k, o: Dictionary) -> Control:
	var col: Color = o["tag_col"]
	var box: PanelContainer = k.box(k.c("panel2"), k.c("line_hi"), 20, 3, 6)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = k.v(8)
	box.add_child(v)
	var pill: PanelContainer = k.box(k.c("inset"), col, 4, 2, 4)
	pill.add_child(k.lbl(str(o["tag"]), 24, col))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(pill)
	var well: PanelContainer = k.box(k.c("inset"), Color(col, 0.6), 8, 3, 6)
	well.custom_minimum_size = Vector2(176, 168)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.add_child(k.center(_icon(k, o, 144)))
	v.add_child(well)
	v.add_child(k.lbl(str(o["name"]), 40, k.c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.wrap(str(o["sub"]), 24, k.c("dim"), 400, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.hline())
	for ln in o["lines"]:
		var lr: HBoxContainer = k.h(10)
		lr.add_child(k.glyph(DarkKit.G_DIAMOND, k.c("good"), 3))
		lr.add_child(k.wrap(str(ln), 24, k.c("text"), 370))
		v.add_child(lr)
	v.add_child(k.sp(0, 0, false, true))
	v.add_child(_price(k, o, 40, k.c("price")))
	if bool(o["bought"]):
		var br: HBoxContainer = k.h(8)
		br.add_child(k.glyph(DarkKit.G_CHECK, k.c("good"), 3))
		br.add_child(k.lbl("ALINDI", 32, k.c("good")))
		v.add_child(k.row_btn(br, "off", 64))
	elif str(o["reason"]) != "":
		v.add_child(k.lbl(str(o["reason"]), 24, k.c("bad"), HORIZONTAL_ALIGNMENT_CENTER))
		var b: Button = k.btn("SATIN AL", "primary", 32, 64)
		b.disabled = true
		v.add_child(b)
	else:
		v.add_child(k.btn("SATIN AL", "primary", 32, 64))
	return box
