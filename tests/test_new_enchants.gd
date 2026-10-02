extends Node

## Kullanıcı isteği (2026-09-30): yeni 21 efsun (bkz. scripts/enchant_defs.gd dosya başı, hafıza project-new-enchants-2026-09-30).
## 1) Veri/havuz kuralları: kart yapısı (4 ya da 3 geliştirme + Final), geliştirmelerin RASTGELE sırayla gelmesi, Final'in
##    ancak hepsi alınınca + katalizörle gelmesi, Aşkın/nadirlik olmaması (mor / kırmızı kart), eklemeli adımların sıradan
##    bağımsız aynı sonuca varması.
## 2) Duman testi: her efsun x her uyduğu silah - GERÇEK oyuncu, GERÇEK silah ve GERÇEK yaratıklarla efsun tam dolu (tüm
##    geliştirmeler + Final) birkaç saniye savaşır; efsunun KENDİ izi (sprite sayfası / alan / gölge düğümü) sahnede
##    görülmeli ve yaratıklar hasar almalı (hata çıktısı runner'ın stderr taramasında).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const EnchantPool: GDScript = preload("res://scripts/enchant_pool.gd")
const RUN_TIME := 5.0
const ENEMY_HP := 60000.0
## Efsuna özgü iz sayılan script'ler (fx_enchant_sprite = sprite sayfası, enchant_area = alan, evo_area = gölge kopyası).
const TRACE_SCRIPTS := ["res://scripts/fx_enchant_sprite.gd", "res://scripts/enchant_area.gd", "res://scripts/evo_area.gd"]

var _spawned: Array[Node] = []
var _traces: int = 0
var _prev_weapons: Array = []
var _prev_items: Array = []


func _full(id: String) -> Dictionary:
	var ups: Array = []
	for i in range((EnchantDefs.get_def(id)["upgrades"] as Array).size()):
		ups.append(i)
	return {"id": id, "ups": ups, "final": true}


# ------------------------------------------------------------------ veri / havuz

func test_defs_shape() -> void:
	assert(EnchantDefs.DEFS.size() == 21, "kullanıcının 21 efsunu: %d" % EnchantDefs.DEFS.size())
	for id in EnchantDefs.DEFS:
		var d: Dictionary = EnchantDefs.DEFS[id]
		var ups: int = (d["upgrades"] as Array).size()
		var seviye: bool = id in ["tektonik_yarik", "golge_yankisi", "astral_yorunge"]
		assert(ups == (3 if seviye else 4), "%s: geliştirme sayısı %d" % [id, ups])
		for w in d["weapons"]:
			assert(EnchantDefs.WEAPON_NAMES.has(w), "%s: bilinmeyen silah %s" % [id, w])
		assert(str(d["base"]["text"]) != "" and str(d["final"]["text"]) != "", "%s: metin boş" % id)
	for w in EnchantDefs.WEAPON_NAMES:
		assert(not EnchantDefs.enchants_for(w).is_empty(), "efsunu olmayan silah: %s" % w)


func test_upgrade_order_does_not_matter() -> void:
	for id in EnchantDefs.DEFS:
		var n: int = (EnchantDefs.get_def(id)["upgrades"] as Array).size()
		var fwd: Array = range(n)
		var rev: Array = range(n)
		rev.reverse()
		var a: Dictionary = EnchantDefs.resolve({"id": id, "ups": fwd, "final": false})
		var b: Dictionary = EnchantDefs.resolve({"id": id, "ups": rev, "final": false})
		assert(a == b, "%s: geliştirme sırası sonucu değiştirdi" % id)
	## Kullanıcının yazdığı zincirler: iki bekleme kartı 60 -> 30, Final 20; sekme 4 -> 7; güçlü mermi her 5. atış.
	assert(is_equal_approx(float(EnchantDefs.resolve({"id": "beam_of_zeus", "ups": [3, 0]})["zeus_cd"]), 30.0), "Zeus 60 -> 30")
	assert(int(EnchantDefs.resolve({"id": "seken_mermiler", "ups": [3, 0]})["bounce"]) == 7, "sekme 4 -> 7")
	assert(int(EnchantDefs.resolve({"id": "loaded_chamber", "ups": [3, 1]})["charged_every"]) == 5, "her 5. atış")
	assert(int(EnchantDefs.resolve({"id": "hunters_eye", "ups": [3, 1]})["marks_per_ap"]) == 50, "50 işaret")
	assert(int(EnchantDefs.resolve({"id": "endless_void", "ups": [0]})["void_stacks"]) == 15, "karadelik 20 -> 15")


func test_pool_random_upgrades_final_and_no_askin() -> void:
	_prev_weapons = GameManager.owned_weapons.duplicate(true)
	_prev_items = GameManager.owned_items.duplicate(true)
	GameManager.owned_items = []
	GameManager.owned_weapons = [{"key": "topuz", "enchant": {"id": "earthquake", "ups": [2], "final": false}}]
	var seen: Dictionary = {}
	for _i in range(60):
		for c in EnchantPool.build(null):
			if str(c["type"]) == "step":
				seen[int(c["up"])] = true
				assert(int(c["tier"]) == EnchantDefs.CARD_TIER, "geliştirme kartı mor olmalı")
			assert(str(c["type"]) != "askin", "Aşkın kartı çıkmamalı")
			assert(str(c["type"]) != "final", "geliştirmeler bitmeden Final çıkmamalı")
	assert(seen.size() == 3 and not seen.has(2), "alınmamış 3 geliştirme rastgele gelmeli, alınan gelmemeli: %s" % str(seen))
	GameManager.owned_weapons[0]["enchant"]["ups"] = [0, 1, 2, 3]
	## 2026-10-02: katalizör eşya şartı kaldırıldı (ekstralar silindi) - tüm geliştirmeler alınınca Final doğrudan gelir.
	GameManager.owned_items = []
	var got_final: bool = false
	for _i in range(20):
		for c in EnchantPool.build(null):
			if str(c["type"]) == "final":
				got_final = true
				assert(int(c["tier"]) == EnchantDefs.FINAL_CARD_TIER, "Final kırmızı olmalı")
	assert(got_final, "tüm geliştirmeler -> Final havuzda (katalizörsüz)")
	GameManager.owned_weapons[0]["enchant"]["final"] = true
	for _i in range(20):
		for c in EnchantPool.build(null):
			assert(not (str(c["type"]) in ["step", "final", "temel"] and int(c.get("slot", -1)) == 0), "biten efsun kart vermemeli")
	GameManager.owned_weapons = [{"key": "fisek"}]
	var ids: Dictionary = {}
	for _i in range(40):
		for c in EnchantPool.build(null):
			if str(c["type"]) == "temel":
				ids[str(c["id"])] = true
	assert(ids.has("nuukler") and ids.has("matryoshka") and ids.size() == 2, "Fişek'in 2 efsunu Temel kartı olarak gelmeli: %s" % str(ids))
	GameManager.owned_weapons = _prev_weapons
	GameManager.owned_items = _prev_items


# ------------------------------------------------------------------ duman testi

func _on_node_added(n: Node) -> void:
	var s: Variant = n.get_script()
	if s is Script and TRACE_SCRIPTS.has((s as Script).resource_path):
		_traces += 1


func test_every_enchant_fights_with_real_weapon() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	_prev_weapons = GameManager.owned_weapons.duplicate(true)
	_prev_items = GameManager.owned_items.duplicate(true)
	get_tree().node_added.connect(_on_node_added)
	var failures: Array = []
	for id in EnchantDefs.DEFS:
		for key in EnchantDefs.DEFS[id]["weapons"]:
			var res: Array = await _run_one(str(id), str(key))
			print("ENCH %-20s %-16s iz=%d hasar=%d" % [id, key, int(res[0]), int(res[1])])
			if int(res[0]) <= 0 or float(res[1]) <= 0.0:
				failures.append("%s/%s (iz %d, hasar %d)" % [id, key, int(res[0]), int(res[1])])
	get_tree().node_added.disconnect(_on_node_added)
	GameManager.owned_weapons = _prev_weapons
	GameManager.owned_items = _prev_items
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene
	assert(failures.is_empty(), "efsun izi ya da hasarı yok: %s" % str(failures))


func _run_one(id: String, key: String) -> Array:
	## Şansa bağlı tetikleyiciler (infaz, dalga, yağmur...) testi rastgele düşürmesin: her çalıştırma sabit tohumla.
	seed(hash(id + key))
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	GameManager.owned_items = []
	GameManager.owned_weapons = []
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
	GameManager.owned_weapons = [{"key": key, "level": 1, "enchant": _full(id)}]
	assert(p.buy_weapon_copy(key, 1), "silah verilemedi: %s" % key)
	var w: Node = p.owned_weapon_nodes[0]
	var beh: Node = w.get("enchant_behavior")
	assert(beh != null and str(beh.get_script().resource_path).ends_with("/%s.gd" % id), "%s: davranış script'i kurulmadı" % id)
	## Şansa bağlı tetikleyiciler kesin olsun (kod yolu doğrulanır; oranları test_upgrade_order / veri testi kontrol eder).
	var st: Dictionary = beh.get("stats")
	for k in ["wave_chance_final", "rain_chance_final", "exec_chance", "exec_elite", "crystal_chance", "seis_chance_final"]:
		if st.has(k):
			st[k] = 1.0
	## Yavaş tetiklenenler 5 sn'de eşiğe varamaz - sayaçları eşiğin bir altından başlat (davranış aynı yoldan tetiklenir).
	match id:
		"endless_void":
			w.set_meta("ench_void_stacks", int(beh.call("n", "void_stacks", 20)) - 1)
		"loaded_chamber":
			beh.set("_shots", int(beh.call("n", "charged_every", 7)) - 1)
	var enemies: Array = []
	for i in range(8):
		var ang: float = TAU * float(i) / 8.0
		var e: Node2D = EnemyScene.instantiate()
		add_child(e)
		_spawned.append(e)
		e.global_position = p.global_position + Vector2(cos(ang), sin(ang)) * (55.0 + 20.0 * float(i % 3))
		e.set("speed", 0.0)
		e.max_health = ENEMY_HP
		## Hunter's Eye infazı için hepsi %30 canın altında.
		e.health = ENEMY_HP * (0.2 if id == "hunters_eye" else 1.0)
		enemies.append(e)
	var hp0: float = 0.0
	for e in enemies:
		hp0 += float(e.health)
	_traces = 0
	var t0: int = Time.get_ticks_msec()
	var max_grow: float = 1.0
	while Time.get_ticks_msec() - t0 < int(RUN_TIME * 1000.0):
		await get_tree().physics_frame
		get_tree().paused = false
		## BIGerang'ın izi büyüyen bumerangın kendisi (girdap sadece en büyük boyutta).
		if id == "bigerang":
			for c in get_children():
				if "_grow_factor" in c:
					max_grow = maxf(max_grow, float(c.get("_grow_factor")))
	var hp1: float = 0.0
	for e in enemies:
		if is_instance_valid(e) and e.get("is_dead") != true:
			hp1 += float(e.health)
	var traces: int = _traces
	if id == "bigerang" and max_grow > 1.0:
		traces += 1
	## Temizlik: oyuncu, yaratıklar, sahnede kalan efsun izleri.
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for c in get_children():
		var s: Variant = c.get_script()
		if s is Script and (TRACE_SCRIPTS.has((s as Script).resource_path) or c.is_in_group("enemies")):
			c.free()
	for c in get_children():
		if c is Node2D and c.get_script() == null:
			c.queue_free()
	await get_tree().process_frame
	return [traces, hp0 - hp1]
