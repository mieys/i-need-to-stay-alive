extends Node

## Kullanıcı isteği (2026-10-08): "bu efsunlar silahlarda kalıcı olacak tıpkı onlara göre bir özellik gibi" + "bu efsunlı özellik olarak
## kendine alan silahların geliştirmeleri blacksmithde 5 parçacık + bir miktar altın ile alınabilecek" (final: 10 parçacık + yüksek altın).
## Kapsam: EnchantDefs.TRAITS tablosu (kullanıcının seçimleri), 12 yeni tanımın şekli, her silah ekleme yolunun doğuştan efsun kaydı,
## demirci dükkanı geliştirme kuralları (weapon_shop_logic.gd), ve GERÇEK oyuncu + GERÇEK silah + GERÇEK yaratıklarla her silahın
## kendi özelliğiyle savaşması (özelliğe özgü gözlem: kanama yükü, zincir, zehir bulaşması, ek ok/bumerang sayısı, sersemleme, donma...).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const Logic: GDScript = preload("res://scripts/weapon_shop_logic.gd")
const WeaponCatalogScript: GDScript = preload("res://scripts/weapon_catalog.gd")
const WeaponTraitsScript: GDScript = preload("res://scripts/weapon_traits/weapon_traits.gd")

## Kullanıcının seçtiği silah -> efsun (artifact "Silah Efsunları", 2026-10-08).
const EXPECTED := {
	"dagger": "kanayan_kesikler", "pence": "kanli_pence", "topuz": "sismik_dalga", "uzunkilic": "wind_sword",
	"fire_staff": "ates_nefesi", "lightning_staff": "zincir_yildirim", "tabanca": "seri_parmak", "tuftuf": "bulasici_salgi",
	"tufek": "delici_mermi", "arcane": "yankilanan_buyu", "yay": "uclu_ok", "crossbow": "zincir_civata",
	"boomerang": "cifte_donus", "buz_asasi": "kirik_buz", "fisek": "kivilcim_yagmuru",
	"mizrak": "cirit", ## madde 305 (öneri kullanıcıya sunuldu, onaylandı)
	"gokkusagi": "goz_kamastiran", ## madde 306 (Gökkuşağı Asası, öneri onaylandı)
	"kalkan": "siper", ## madde 338 (Kalkan, öneri kişisel + sabit kalkanla onaylandı)
	"yinyang": "denge", ## madde 334 (Yin Yang Kitabı, öneri menzilsiz kalkanla onaylandı)
}
const NEW_IDS := ["kanayan_kesikler", "kanli_pence", "zincir_yildirim", "seri_parmak", "bulasici_salgi", "delici_mermi", "yankilanan_buyu",
	"uclu_ok", "zincir_civata", "cifte_donus", "kirik_buz", "kivilcim_yagmuru", "cirit", "siper", "denge"]
const RUN_TIME := 4.0
const ENEMY_HP := 60000.0

var _spawned: Array[Node] = []
var _node_counts: Dictionary = {} ## scene_file_path -> sahneye eklenen düğüm sayısı (çalışma boyunca)
var _trace_nodes: int = 0
var _saved_weapons: Array = []
var _saved_gold: int = 0
var _saved_shards: int = 0


# ------------------------------------------------------------------ veri

func test_trait_table_is_exactly_the_users_picks() -> void:
	var traits: Dictionary = WeaponTraitsScript.TRAITS
	assert(traits == EXPECTED, "TRAITS tablosu kullanıcının seçimleriyle birebir aynı olmalı: %s" % str(traits))
	## 2026-10-11: özellikler silah kodunun yanında - tablo + tanımlar weapon_traits.gd, davranışlar scripts/weapon_traits/.
	for key in traits:
		var tid: String = str(traits[key])
		assert(WeaponTraitsScript.DEFS.has(tid), "%s: tanımı weapon_traits.gd'de olmalı" % tid)
		assert(ResourceLoader.exists(WeaponTraitsScript.script_path(tid)) or tid == "delici_mermi", "%s: davranışı scripts/weapon_traits/'ta olmalı" % tid)
	for key in WeaponCatalogScript.KEYS:
		var id: String = EnchantDefs.trait_of(str(key))
		assert(id != "" and not EnchantDefs.get_def(id).is_empty(), "%s: özelliği (tanımı) olmalı" % key)
	var seen: Dictionary = {}
	for key in traits:
		assert(not seen.has(traits[key]), "iki silah aynı efsunu paylaşmamalı: %s" % traits[key])
		seen[traits[key]] = true


func test_new_definitions_have_four_upgrades_and_a_final() -> void:
	for id in NEW_IDS:
		var d: Dictionary = EnchantDefs.get_def(id)
		assert(not d.is_empty(), "%s: tanım yok" % id)
		assert((d["upgrades"] as Array).size() == 4, "%s: 4 geliştirme olmalı" % id)
		assert(str(d["base"]["text"]) != "" and str(d["final"]["text"]) != "" and str(d["desc"]) != "", "%s: metin boş" % id)
		for u in d["upgrades"]:
			assert(str(u["name"]) != "" and str(u["text"]) != "" and (u.has("add") or u.has("set")), "%s: geliştirme eksik" % id)
		var rows: Array = EnchantDefs.upgrade_rows(id)
		assert(rows.size() == 5 and bool(rows[4]["final"]) and not bool(rows[0]["final"]), "%s: 4 normal + final satırı" % id)
		## Tam dolu çözüm: sıradan bağımsız ve final'in kendi anahtarları var.
		var full: Dictionary = EnchantDefs.resolve({"id": id, "ups": [0, 1, 2, 3], "final": true}, str(d["weapons"][0]))
		var rev: Dictionary = EnchantDefs.resolve({"id": id, "ups": [3, 2, 1, 0], "final": true}, str(d["weapons"][0]))
		assert(full == rev, "%s: geliştirme sırası sonucu değiştirmemeli" % id)
		assert(bool(full["is_final"]) and int(full["up_count"]) == 4, "%s: çözüm durumu" % id)
		assert(ResourceLoader.exists(WeaponTraitsScript.script_path(id)) or id == "delici_mermi", "%s: davranış scripti yerinde olmalı (delici_mermi tamamen ortak anahtarlarla)" % id)


func test_new_weapon_entry_and_ensure_trait() -> void:
	for key in EXPECTED:
		var e: Dictionary = EnchantDefs.new_weapon_entry(str(key), 1, 30)
		assert(str((e["enchant"] as Dictionary)["id"]) == EXPECTED[key] and (e["enchant"]["ups"] as Array).is_empty() and not bool(e["enchant"]["final"]),
				"%s: doğuştan kayıt" % key)
		assert(int(e["spent"]) == 30 and int(e["level"]) == 1 and str(e["key"]) == key, "girdi alanları")
	var bare: Dictionary = {"key": "tabanca", "level": 1, "spent": 0}
	assert(EnchantDefs.ensure_trait(bare) and str(bare["enchant"]["id"]) == "seri_parmak", "eksik kayıt tamamlanır")
	bare["enchant"]["ups"] = [1]
	assert(not EnchantDefs.ensure_trait(bare) and (bare["enchant"]["ups"] as Array) == [1], "var olan kayıt EZİLMEZ")
	var unknown: Dictionary = {"key": "yok_silah"}
	assert(not EnchantDefs.ensure_trait(unknown) and not unknown.has("enchant"), "özelliği olmayan anahtar sessizce geçilir")


# ------------------------------------------------------------------ demirci dükkanı geliştirme kuralları

func _begin_shop() -> void:
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	_saved_gold = GameManager.gold
	_saved_shards = GameManager.weapon_shards


func _end_shop() -> void:
	GameManager.owned_weapons = _saved_weapons
	GameManager.gold = _saved_gold
	GameManager.weapon_shards = _saved_shards


func test_blacksmith_upgrade_rules_prices_and_final_gate() -> void:
	_begin_shop()
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("dagger", 1, 0)]
	GameManager.gold = 5000
	GameManager.weapon_shards = 100
	assert(Logic.slot_trait_id(0) == "kanayan_kesikler", "satırlar silahın özelliğinden")
	var rows: Array = Logic.slot_upgrade_rows(0)
	assert(rows.size() == 5, "4 geliştirme + final")
	assert(Logic.wupgrade_shard_cost(0, 0) == 5 and Logic.wupgrade_shard_cost(0, 4) == 10, "geliştirme 5, final 10 parçacık")
	assert(Logic.wupgrade_price(0, 0) == 100 and Logic.wupgrade_price(0, 4) == 400, "ilk geliştirme 100, final 400 altın")
	assert(Logic.wupgrade_block_reason(0, 4).begins_with("Önce"), "final 4 geliştirme bitmeden satılmaz: %s" % Logic.wupgrade_block_reason(0, 4))
	## Satın alma: altın + parçacık düşer, kayda işlenir, fiyat artar.
	assert(Logic.buy_wupgrade(null, 0, 2), "geliştirme alınır")
	assert(GameManager.gold == 4900 and GameManager.weapon_shards == 95, "100 altın + 5 parçacık düştü: %d / %d" % [GameManager.gold, GameManager.weapon_shards])
	assert(Logic.wupgrade_taken(0, 2) and not Logic.wupgrade_taken(0, 0), "yalnız alınan geliştirme işaretli")
	assert(Logic.wupgrade_price(0, 0) == 130, "sonraki geliştirme 130 (100 + 30 x alınan)")
	assert(Logic.wupgrade_block_reason(0, 2) != "" and not Logic.buy_wupgrade(null, 0, 2), "aynı geliştirme ikinci kez alınamaz")
	for i in [0, 1, 3]:
		assert(Logic.buy_wupgrade(null, 0, i), "geliştirme %d alınır" % i)
	assert(Logic.wupgrade_price(0, 4) == 400, "final fiyatı alınan sayıdan bağımsız")
	assert(Logic.wupgrade_block_reason(0, 4) == "", "4 geliştirme tamam -> final açılır")
	assert(Logic.buy_wupgrade(null, 0, 4) and EnchantDefs.is_complete(Logic.slot_enchant(0)), "final alınır")
	assert(GameManager.gold == 5000 - 100 - 130 - 160 - 190 - 400 and GameManager.weapon_shards == 100 - 5 * 4 - 10, "toplam maliyet: %d / %d" % [GameManager.gold, GameManager.weapon_shards])
	assert(not Logic.buy_wupgrade(null, 0, 4), "final bir kez")
	## Final sonrası güçlendirme (madde 297): sınırsız, fiyat 150 + 50 x alınan, 3 parçacık, parçacık defterine yazılır.
	var g0: int = GameManager.gold
	var s0: int = GameManager.weapon_shards
	var spent0: int = int(GameManager.owned_weapons[0].get("shards_spent", 0))
	for i in range(6):
		assert(Logic.wplus_price(0) == 150 + 50 * i, "güçlendirme %d fiyatı %d" % [i, Logic.wplus_price(0)])
		assert(Logic.buy_wplus(null, 0), "güçlendirme %d alınır (sınır yok)" % i)
	assert(Logic.wplus_count(0) == 6 and EnchantDefs.plus_count(Logic.slot_enchant(0)) == 6, "6 güçlendirme kayıtta")
	assert(GameManager.gold == g0 - (150 + 200 + 250 + 300 + 350 + 400) and GameManager.weapon_shards == s0 - 18, "güçlendirme maliyeti: %d / %d" % [GameManager.gold, GameManager.weapon_shards])
	assert(int(GameManager.owned_weapons[0]["shards_spent"]) == spent0 + 18, "parçacık defteri (satış iadesi)")
	GameManager.owned_weapons.append(EnchantDefs.new_weapon_entry("tabanca", 1, 0))
	assert(Logic.wplus_block_reason(1).begins_with("Önce") and not Logic.buy_wplus(null, 1), "final alınmadan güçlendirme yok")
	## Çözülen istatistikler gerçekten yükseldi (dört geliştirme + final).
	var st: Dictionary = EnchantDefs.resolve(Logic.slot_enchant(0), "dagger")
	assert(is_equal_approx(float(st["kb_ap"]), 0.08) and int(st["kb_cap"]) == 8 and int(st["kb_combo"]) == 2 and bool(st["kb_spread"]), "geliştirmeler + final uygulandı: %s" % str(st))
	_end_shop()


func test_blacksmith_upgrades_need_shards_and_gold_and_are_per_copy() -> void:
	_begin_shop()
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("tabanca", 1, 0), EnchantDefs.new_weapon_entry("tabanca", 1, 0)]
	GameManager.gold = 99
	GameManager.weapon_shards = 5
	assert(not Logic.can_buy_wupgrade(0, 0), "99 altın yetmez (100 gerekli)")
	GameManager.gold = 500
	GameManager.weapon_shards = 4
	assert(Logic.wupgrade_block_reason(0, 0).begins_with("Silah parçacığı yetersiz") and not Logic.buy_wupgrade(null, 0, 0), "4 parçacık yetmez")
	GameManager.weapon_shards = 5
	assert(Logic.buy_wupgrade(null, 0, 1) and GameManager.weapon_shards == 0, "5 parçacıkla alınır, parçacık biter")
	assert(Logic.wupgrade_taken(0, 1) and not Logic.wupgrade_taken(1, 1), "geliştirme o kopyaya özel (ikinci Tabanca etkilenmez)")
	assert(Logic.wupgrade_price(1, 1) == 100, "ikinci kopyanın fiyatı sıfırdan başlar")
	assert(Logic.wupgrade_block_reason(7, 0) != "", "olmayan yuva reddedilir")
	_end_shop()


# ------------------------------------------------------------------ gerçek silah / gerçek yaratık

const COUNT_SCENES := ["arrow_projectile.tscn", "boomerang_projectile.tscn", "firework_projectile.tscn"]


func _on_node_added(n: Node) -> void:
	var sf: String = n.scene_file_path
	if sf != "":
		_node_counts[sf] = int(_node_counts.get(sf, 0)) + 1
	var s: Variant = n.get_script()
	if s is Script and ["res://scripts/fx_enchant_sprite.gd", "res://scripts/enchant_area.gd", "res://scripts/fx_korsan_explosion.gd"].has((s as Script).resource_path):
		_trace_nodes += 1


func test_every_weapon_fights_with_its_own_trait() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	get_tree().node_added.connect(_on_node_added)
	var failures: Array = []
	for key in EXPECTED:
		var res: Dictionary = await _run_trait(str(key))
		print("TRAIT %-16s %-18s hasar=%d izler=%d %s" % [key, EXPECTED[key], int(res["damage"]), int(res["traces"]), str(res["notes"])])
		for f in res["fails"]:
			failures.append("%s/%s: %s" % [key, EXPECTED[key], f])
	get_tree().node_added.disconnect(_on_node_added)
	GameManager.owned_weapons = _saved_weapons
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene
	assert(failures.is_empty(), "özellik gözlemleri tutmadı: %s" % str(failures))


func _make_enemy(pos: Vector2, hp: float) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	_spawned.append(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = hp
	e.health = hp
	return e


func _run_trait(key: String) -> Dictionary:
	var id: String = str(EXPECTED[key])
	seed(hash("trait" + key)) ## şansa bağlı tetikleyiciler sabit tohumla
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	GameManager.owned_items = []
	GameManager.owned_weapons = []
	_node_counts.clear()
	_trace_nodes = 0
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(2000.0, 2000.0)
	p.max_health = 100000.0
	p.health = 100000.0
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry(key, 1, 0)] ## kayıt YOK değil: doğuştan özellikle
	assert(p.buy_weapon_copy(key, 1), "silah verilemedi: %s" % key)
	var w: Node = p.owned_weapon_nodes[0]
	var beh: Node = w.get("enchant_behavior")
	var fails: Array = []
	if beh == null:
		return {"damage": 0.0, "traces": 0, "notes": "davranış yok", "fails": ["özellik davranışı kurulmadı"]}
	var st: Dictionary = beh.get("stats")
	if str(st.get("id", "")) != id:
		fails.append("yanlış efsun: %s" % str(st.get("id", "")))
	var script_path: String = str(beh.get_script().resource_path)
	if ResourceLoader.exists(WeaponTraitsScript.script_path(id)) and script_path != WeaponTraitsScript.script_path(id):
		fails.append("davranış scripti %s olmalı: %s" % [id, script_path])
	## Şansa bağlı ek tetikleyiciler kesin olsun (kod yolu doğrulanır, oranlar veri testinde).
	for k in ["wave_chance", "echo_chance", "seis_chance"]:
		if st.has(k):
			st[k] = 1.0
	if st.has("echo_pity"):
		st["echo_pity"] = 1
	if st.has("cirit_every"):
		st["cirit_every"] = 1 ## her saplama cirit (4 sn içinde ~3 saldırı)
	var hp_each: float = 1.0 if id == "seri_parmak" else ENEMY_HP
	var enemies: Array = []
	var line_mode: bool = key in ["crossbow", "tufek", "tabanca", "yay"]
	for i in range(8):
		var ang: float = TAU * float(i) / 8.0
		var pos: Vector2 = p.global_position + Vector2(cos(ang), sin(ang)) * (55.0 + 20.0 * float(i % 3))
		if line_mode:
			pos = p.global_position + Vector2(70.0 + 22.0 * float(i % 4), 0.0) + Vector2(0.0, 18.0 * float(i / 4))
		enemies.append(_make_enemy(pos, hp_each if id != "seri_parmak" or i < 6 else ENEMY_HP))
	var hp0: float = 0.0
	for e in enemies:
		hp0 += float(e.health)
	var max_dots: int = 0
	var any_stun: bool = false
	var any_frozen: bool = false
	var any_poison: bool = false
	var any_plague: bool = false
	var max_stacks: int = 0
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(RUN_TIME * 1000.0):
		await get_tree().physics_frame
		get_tree().paused = false
		max_dots = maxi(max_dots, (beh.get("_dots") as Dictionary).size())
		if id == "seri_parmak":
			max_stacks = maxi(max_stacks, int(beh.call("current_stacks")))
		for e in enemies:
			if is_instance_valid(e) and e.get("is_dead") != true:
				any_stun = any_stun or bool(e.get("is_stunned"))
				any_frozen = any_frozen or bool(e.get("is_frozen"))
				any_poison = any_poison or bool(e.call("is_poisoned"))
				any_plague = any_plague or not (e.get("_plague") as Dictionary).is_empty()
	var hp1: float = 0.0
	for e in enemies:
		if is_instance_valid(e) and e.get("is_dead") != true:
			hp1 += float(e.health)
	var damage: float = hp0 - hp1
	var attacks: int = int(beh.get("attacks"))
	var notes: String = "saldırı=%d" % attacks
	if damage <= 0.0:
		fails.append("hiç hasar yok")
	match id:
		"kanayan_kesikler", "kanli_pence":
			if max_dots <= 0:
				fails.append("kanama yükü hiç birikmedi")
		"zincir_yildirim":
			if int(beh.call("chain_bonus")) != 2 or not is_equal_approx(float(beh.call("chain_pct", 0.5)), 0.35) or not is_equal_approx(float(beh.call("chain_range_mult")), 0.75):
				fails.append("zincir: 2 atlama / %35 / menzil x0,75 olmalı (2026-10-10 denge)")
		"seri_parmak":
			notes += " yığın=%d" % max_stacks
			if max_stacks < 1:
				fails.append("öldürme saldırı hızı yığını vermedi (yığın %d)" % max_stacks)
		"bulasici_salgi":
			if not any_poison or not any_plague:
				fails.append("zehir ya da bulaşma kaydı yok (zehir %s, bulaşma %s)" % [str(any_poison), str(any_plague)])
		"delici_mermi":
			if int(beh.call("n", "pierce")) != 2 or not is_equal_approx(float(beh.call("f", "pierce_ramp")), 0.0):
				fails.append("delme 2 / tabanda artış YOK olmalı (2026-10-10 denge; artış Kinetik Enerji geliştirmesinde)")
		"yankilanan_buyu":
			notes += " patlama=%d" % int(_node_counts.get("res://scenes/fx_korsan_explosion.tscn", 0))
			if _trace_nodes <= 0:
				fails.append("yankı patlaması görülmedi")
		"uclu_ok":
			var arrows: int = int(_node_counts.get("res://scenes/arrow_projectile.tscn", 0))
			notes += " ok=%d" % arrows
			if attacks >= 3 and arrows < attacks + 2:
				fails.append("yelpaze okları yok: %d ok / %d saldırı" % [arrows, attacks])
		"zincir_civata":
			if not any_stun:
				fails.append("delinen düşman sersemlemedi")
		"cifte_donus":
			var booms: int = int(_node_counts.get("res://scenes/boomerang_projectile.tscn", 0))
			notes += " bumerang=%d" % booms
			if attacks >= 4 and booms < attacks + 1:
				fails.append("ikiz bumerang yok: %d bumerang / %d saldırı" % [booms, attacks])
		"kirik_buz":
			if not any_frozen:
				fails.append("hiçbir düşman donmadı")
		"kivilcim_yagmuru":
			if _trace_nodes <= 0:
				fails.append("kıvılcım yağmuru izi yok")
		"cirit":
			notes += " cirit=%d" % int(beh.get("throws"))
			if attacks >= 1 and int(beh.get("throws")) < 1:
				fails.append("cirit hiç fırlatılmadı (%d saldırı)" % attacks)
		"siper":
			notes += " darbe=%d kalkan=%.0f" % [int(beh.get("bashes")), float(beh.get("gained"))]
			if attacks >= 1 and int(beh.get("bashes")) < 1:
				fails.append("kalkan darbesi Siper'e hiç ulaşmadı (%d saldırı)" % attacks)
		"denge":
			notes += " isabet=%d" % int(beh.get("_hits"))
			if attacks >= 1 and int(beh.get("_hits")) < 1:
				fails.append("kara küre isabeti Denge'ye hiç ulaşmadı (%d saldırı)" % attacks)
		"ates_nefesi", "sismik_dalga", "wind_sword":
			pass ## kart döneminden kalan davranışlar (test_new_enchants duman testi ayrıntılı)
	## Temizlik.
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for c in get_children():
		if c is Node2D and c.get_script() == null:
			c.queue_free()
	await get_tree().process_frame
	return {"damage": damage, "traces": _trace_nodes, "notes": notes, "fails": fails}


# ------------------------------------------------------------------ Kırık Buz parçalanması (birim)

func test_kirik_buz_shatter_hits_neighbours_and_slows_them() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("buz_asasi", 1, 0)]
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(3000.0, 3000.0)
	assert(p.buy_weapon_copy("buz_asasi", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	var victim: Node2D = _make_enemy(Vector2(3060.0, 3000.0), ENEMY_HP)
	var near: Node2D = _make_enemy(Vector2(3100.0, 3000.0), ENEMY_HP)
	var far: Node2D = _make_enemy(Vector2(3400.0, 3000.0), ENEMY_HP)
	beh.call("_shatter", victim.global_position, victim)
	await get_tree().physics_frame
	var ap: float = float(beh.call("ap"))
	assert(float(near.health) <= ENEMY_HP - ap * 0.99, "yakındaki düşman parçalanma hasarı almalı: %.1f / %.1f" % [float(near.health), ENEMY_HP - ap])
	assert(is_equal_approx(float(far.health), ENEMY_HP), "uzaktaki düşman etkilenmemeli")
	assert(is_equal_approx(float(victim.health), ENEMY_HP), "parçalanan düşmanın kendisi vurulmaz (zaten ölü)")
	for n in [p, victim, near, far]:
		if is_instance_valid(n):
			n.free()
	GameManager.owned_weapons = _saved_weapons
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene


## 2026-10-10 (kullanıcı: "buz asası hiç dondurmuyor"): asa hedeflerini bilerek FARKLI donmamış düşmanlara dağıtıyor; dondurma sayacı düşman başına olunca aynı düşman
## 2-3 kez neredeyse hiç vurulmuyordu. Sayaç artık asaya bağlı: her biri FARKLI düşmana giden isabetlerin her 2.'si dondurur.
func test_kirik_buz_freezes_every_second_hit_even_when_every_hit_is_a_different_enemy() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("buz_asasi", 1, 0)]
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(3000.0, 3000.0)
	assert(p.buy_weapon_copy("buz_asasi", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	assert(beh != null, "Buz Asası doğuştan Kırık Buz özelliğiyle gelir")
	var foes: Array = []
	for i in range(6):
		foes.append(_make_enemy(Vector2(3060.0 + 40.0 * i, 3000.0), ENEMY_HP))
	await get_tree().physics_frame
	for e in foes:
		beh.call("on_hit", e, 10.0, true, null)
	var frozen: Array = []
	for i in range(foes.size()):
		frozen.append(bool(foes[i].get("is_frozen")))
	assert(frozen == [false, true, false, true, false, true], "her 2. isabet (farklı düşmanlara) dondurmalı: %s" % str(frozen))
	for n in [p] + foes:
		if is_instance_valid(n):
			n.free()
	GameManager.owned_weapons = _saved_weapons
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene


## 2026-10-17 (kullanıcı: "pençe çok güçsüz ve az can basıyor" -> "kanama %20 sg olsun kanama birikmesin"): Kanlı Pençe yeni hedefe İLK vuruşta da
## can basar (%6; eskiden can kontrolü kanamadan önceydi -> 0), alan payında %33; kanama saldırı gücünün %20'si/sn, tek yük (birikmez).
func test_kanli_pence_heals_on_first_hit_and_bleed_does_not_stack() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("pence", 1, 0)]
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(3000.0, 3000.0)
	assert(p.buy_weapon_copy("pence", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	assert(beh != null and str(beh.get_script().resource_path).ends_with("kanli_pence.gd"), "Pençe doğuştan Kanlı Pençe ile gelir")
	var e: Node2D = _make_enemy(Vector2(3060.0, 3000.0), ENEMY_HP)
	var other: Node2D = _make_enemy(Vector2(3100.0, 3000.0), ENEMY_HP)
	await get_tree().physics_frame
	var mult: float = float(p.call("heal_power_mult"))
	p.max_health = 5000.0
	p.health = 1000.0
	beh.call("on_hit", e, 100.0, true, null)
	assert(absf(float(p.health) - 1000.0 - 1.0 * mult) < 0.01, "yeni hedefe ilk vuruşta %%1 can (2026-10-19): %.2f" % (float(p.health) - 1000.0))
	beh.call("on_hit", e, 100.0, true, null)
	assert(int(beh.call("dot_stacks", e)) == 1, "kanama birikmez (tek yük)")
	var rec: Dictionary = (beh.get("_dots") as Dictionary)[e.get_instance_id()]
	assert(is_equal_approx(float(rec["dps"]), float(beh.call("ap")) * 0.30), "kanama saldırı gücünün %%30'u/sn: %.2f" % float(rec["dps"]))
	var h0: float = float(p.health)
	beh.call("on_hit", other, 100.0, false, null)
	assert(absf(float(p.health) - h0) < 0.01, "alan payı vuruşunda Kanlı Pençe can emmesi yok (2026-10-19)")
	for n in [p, e, other]:
		if is_instance_valid(n):
			n.free()
	GameManager.owned_weapons = _saved_weapons
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene


## 2026-10-19 (kullanıcı: "pençe hala çok can çalıyor" -> "sınırları kaldırıp oranları düşür"): can emme %3 -> %1, saniyelik sınır YOK (art arda
## vuruşlar hep can basar). Kanama tikleri genel can çalma zarı atmaz (kanayan her yaratık 0,5 sn'de bir zar atıyordu). Final: azami canın %0,5'i, sınırsız
## ama kurban başına tek ödül (kp_kill olayı + kanama tikinin ölü kurbanı bulması aynı ölümdür).
func test_kanli_pence_leech_has_no_cap_and_bleed_ticks_roll_no_lifesteal() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	_saved_weapons = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("pence", 1, 0)]
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(3000.0, 3000.0)
	assert(p.buy_weapon_copy("pence", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	var e: Node2D = _make_enemy(Vector2(3060.0, 3000.0), ENEMY_HP)
	await get_tree().physics_frame
	var mult: float = float(p.call("heal_power_mult"))
	p.max_health = 1000.0
	p.health = 100.0
	beh.call("on_hit", e, 100000.0, true, null) ## %1 = 1000 can: sınır yok, azami canı (1000) aşmayana dek tamamı basılır
	var gained: float = float(p.health) - 100.0
	assert(gained > 15.0 * mult * 10.0, "saniyelik sınır yok: %.2f" % gained)
	p.health = 100.0
	beh.call("on_hit", e, 2000.0, true, null)
	beh.call("on_hit", e, 2000.0, true, null)
	assert(absf(float(p.health) - 100.0 - 2.0 * 20.0 * mult) < 0.01, "art arda iki vuruş da %%1 can basar: %.2f" % (float(p.health) - 100.0))
	## Final: azami canın %0,5'i. Aynı ölüm olay + tik yolundan gelse de tek ödül; işaretsiz ölü kurban ayrı ödül; art arda ölümler sınırsız.
	var stats: Dictionary = beh.get("stats")
	stats["kp_kill_heal"] = 0.005
	stats["kp_kill_haste"] = 0.0
	p.health = 100.0
	beh.call("dot_add", e, 50.0, 3.0, 1)
	beh.call("damage_extra", 100.0, e) ## kanayan kurban işaretlenir (kp_kill olayı beklenir)
	beh.call("on_event", "kp_kill", {})
	assert(absf(float(p.health) - 100.0 - 5.0 * mult) < 0.01, "olayla final ödülü azami canın %%0,5'i: %.2f" % (float(p.health) - 100.0))
	beh.call("on_dot_victim_died", {"node": e, "left": [1.0], "pos": e.global_position})
	assert(absf(float(p.health) - 100.0 - 5.0 * mult) < 0.01, "aynı ölümün tik yolu ikinci ödül vermez: %.2f" % (float(p.health) - 100.0))
	beh.call("on_dot_victim_died", {"node": e, "left": [1.0], "pos": e.global_position})
	assert(absf(float(p.health) - 100.0 - 10.0 * mult) < 0.01, "başka (işaretsiz) kanayan kurban ayrıca ödül verir, sınır yok: %.2f" % (float(p.health) - 100.0))
	stats["kp_kill_heal"] = 0.0
	## Kanama tiki: genel can çalma (isabet başına zar) atılmaz; aynı çağrı hit() ile yapılınca zar atılır (yüzde 500 = kesin).
	p.lifesteal_percent = 5.0
	p.health = 100.0
	beh.call("hit", e, 1.0)
	assert(float(p.health) > 100.0, "kontrol: normal isabet can çalma zarı atar (alan %33 x %500 = kesin)")
	p.health = 100.0
	beh.call("dot_add", e, 50.0, 3.0, 1)
	var rec: Dictionary = (beh.get("_dots") as Dictionary)[e.get_instance_id()]
	rec["next"] = 0
	var e_hp: float = float(e.health)
	beh.call("_tick_dots")
	assert(float(e.health) < e_hp, "kanama tiki hasar verir")
	assert(absf(float(p.health) - 100.0) < 0.01, "kanama tiki genel can çalma zarı atmaz: %.2f" % (float(p.health) - 100.0))
	assert(p.lifesteal_blocked == false, "bayrak tik sonrası kapanır")
	for n in [p, e]:
		if is_instance_valid(n):
			n.free()
	GameManager.owned_weapons = _saved_weapons
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene


# ------------------------------------------------------------------ demirci ekranı: EFSUNLAR sekmesi

const ScreenScript: GDScript = preload("res://scripts/weapon_shop_screen.gd")
const MobileUIPath := "res://scripts/mobile_ui.gd"


class FakePlayer extends Node2D:
	func get_max_owned_weapons() -> int:
		return 5

	func buy_weapon_copy(_key: String, _level: int) -> bool:
		return true


func _frames(n: int) -> void:
	for _i in range(n):
		await get_tree().process_frame


func test_screen_enchants_tab_lists_rows_and_buys_per_copy() -> void:
	_begin_shop()
	(load(MobileUIPath) as GDScript).set(&"enabled", false)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("dagger", 1, 0), EnchantDefs.new_weapon_entry("tabanca", 1, 0)]
	GameManager.gold = 3000
	GameManager.weapon_shards = 50
	var p := FakePlayer.new()
	add_child(p)
	var screen: CanvasLayer = ScreenScript.new()
	add_child(screen)
	screen.setup(p)
	await _frames(6)
	screen._show_tab(screen.Tab.ENCHANTS)
	await _frames(2)
	assert(screen._rows.size() == 6, "4 geliştirme + final + güçlendirme plakası: %d" % screen._rows.size())
	assert(str(screen._rows[0]["entry"]["type"]) == "wupgrade" and str(screen._rows[0]["entry"]["key"]) == "dagger", "ilk silah (Bıçak) satırları")
	assert(str(screen._rows[0]["price"].text) == "100" and str(screen._rows[0]["shard_cost"].text) == "5", "geliştirme: 100 altın + 5 parçacık")
	assert(str(screen._rows[4]["price"].text) == "400" and str(screen._rows[4]["shard_cost"].text) == "10", "final: 400 altın + 10 parçacık")
	assert(not screen._entry_can_buy(screen._rows[4]["entry"]), "final 4 geliştirme bitmeden kapalı")
	assert(str(screen._rows[5]["entry"]["type"]) == "wplus" and str(screen._rows[5]["price"].text) == "150" and str(screen._rows[5]["shard_cost"].text) == "3", "güçlendirme: 150 altın + 3 parçacık")
	assert(not screen._entry_can_buy(screen._rows[5]["entry"]), "güçlendirme final alınmadan kapalı")
	screen._select(screen._rows[4]["entry"])
	assert(str(screen._details_block.text).begins_with("Önce"), "final ayrıntısında sebep: %s" % screen._details_block.text)
	assert("Kanayan Kesikler" in screen._details_trait.text and screen._details_desc.text != "", "vitrinde efsunun adı + temel metni: %s / %s" % [screen._details_trait.text, screen._details_desc.text])
	screen._on_buy_pressed(screen._rows[0]["entry"])
	assert((GameManager.owned_weapons[0]["enchant"]["ups"] as Array) == [0], "AL geliştirmeyi o kopyanın kaydına işler")
	assert(GameManager.gold == 2900 and GameManager.weapon_shards == 45, "100 altın + 5 parçacık düştü")
	assert(str(screen._rows[0]["price"].text) == "ALINDI" and not screen._entry_can_buy(screen._rows[0]["entry"]), "alınan plaka ALINDI + kapalı")
	assert(str(screen._rows[1]["price"].text) == "130", "sonraki geliştirme 130: %s" % screen._rows[1]["price"].text)
	## Final sonrası güçlendirme (madde 297): sınırsız, satır seçili kalır, ad sayıyla güncellenir.
	GameManager.owned_weapons[0]["enchant"]["ups"] = [0, 1, 2, 3]
	GameManager.owned_weapons[0]["enchant"]["final"] = true
	screen._show_tab(screen.Tab.ENCHANTS)
	await _frames(2)
	var plus_entry: Dictionary = screen._rows[5]["entry"]
	screen._select(plus_entry)
	assert(screen._entry_can_buy(plus_entry), "final sonrası güçlendirme açık: %s" % screen._details_block.text)
	screen._on_buy_pressed(plus_entry)
	screen._on_buy_pressed(plus_entry)
	assert(int(GameManager.owned_weapons[0]["enchant"]["plus"]) == 2, "iki güçlendirme kayıtta")
	assert(GameManager.gold == 2900 - 150 - 200 and GameManager.weapon_shards == 45 - 6, "150 + 200 altın, 6 parçacık: %d / %d" % [GameManager.gold, GameManager.weapon_shards])
	assert(screen._selected == plus_entry and screen._entry_can_buy(plus_entry), "seçim güçlendirmede kalır, hâlâ alınabilir")
	assert(str(screen._rows[5]["name"].text) == "Güçlendirme +3" and str(screen._rows[5]["price"].text) == "250", "sıradaki: +3, 250 altın: %s / %s" % [screen._rows[5]["name"].text, screen._rows[5]["price"].text])
	assert(screen._list_sub.text == "TAMAM · güçlendirme +2", "liste alt yazısı: %s" % screen._list_sub.text)
	assert(screen._tier_row.get_child_count() > 0, "ayrıntıda stat artışı satırı")
	## İkinci silaha geç: onun satırları sıfırdan (kopya başına).
	screen._trait_slot = 1
	screen._show_tab(screen.Tab.ENCHANTS)
	await _frames(2)
	assert(screen._rows.size() == 6 and str(screen._rows[0]["entry"]["key"]) == "tabanca" and int(screen._rows[0]["entry"]["slot"]) == 1, "Tabanca'nın satırları")
	assert(str(screen._rows[0]["price"].text) == "100" and str(screen._rows[0]["price"].text) != "ALINDI", "ikinci kopya sıfırdan başlar")
	assert(screen._status_label.text == "Silah yuvası 2/5", "durum: %s" % screen._status_label.text)
	screen._on_close_pressed()
	p.free()
	_end_shop()


## 2026-10-10 Ateş Asası buff (kullanıcı: "ateş asası aşırı güçsüz"): asanın TEK hasar kaynağı Destiny püskürtmesi - saniyede %108 saldırı gücü, menzil 140, yanma %14/sn.
func test_fire_staff_spray_buff_numbers_and_catalog_text_agree() -> void:
	var base: Dictionary = (EnchantDefs.get_def("ates_nefesi") as Dictionary)["base"]["set"]
	var per_sec: float = float(base["spray_ap"]) / float(base["spray_tick"])
	assert(absf(per_sec - 1.08) < 0.001, "püskürtme tabanı 0,27 / 0,25 sn = 1,08: %.3f" % per_sec)
	## 2026-10-20: tik aralığı `_effective_fire_wait` ile ölçeklenir (ates_nefesi.gd _interval), o da WEAPON_ATTACK_SPEED_MULT'a (0,7) bölünür -> gerçek saniyelik oran 1,08 x 0,7 = %76.
	assert(absf(per_sec * GameManager.WEAPON_ATTACK_SPEED_MULT - 0.756) < 0.001, "gerçek püskürtme saniyede %%76")
	assert(float(base["spray_range"]) == 140.0 and float(base["elem_ap"]) == 0.14, "menzil 140, yanma %14")
	var text: String = str(WeaponCatalogScript.DESCRIPTIONS["fire_staff"])
	assert(text.contains("%76") and text.contains("140"), "katalog metni sayılarla aynı (%76 = 1,08 x 0,7; 2026-10-20'de %108 bayattı): " + text)
