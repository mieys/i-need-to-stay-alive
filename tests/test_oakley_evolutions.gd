extends Node

## Oakley yetenek evrimleri (madde 348, 2026-10-21): Q Arı Sürüsü 4+1, E Sarmaşıklar 4+1, R Hayat Ağacı 2+1.
## Kartlar skill_evolutions.gd DEFS[2]; etkiler player.gd EVO_OAKLEY_* + fx_oakley_bee_guard.gd / oakley_vine.gd / oakley_tree.gd / enemy.gd.
## Bu test sayıları ve zincirleri doğrular (kart şekli test_skill_evolutions.gd EVO_CHARS'ta).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const SkillEvolutions: GDScript = preload("res://scripts/skill_evolutions.gd")
const BeeGuardScene: PackedScene = preload("res://scenes/fx_oakley_bee_guard.tscn")
const VineScript: GDScript = preload("res://scripts/oakley_vine.gd")
const FlowerScript: GDScript = preload("res://scripts/oakley_flower.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")

var _prev_char_id: int = 1
var _prev_character: int = 1
var _prev_scene: Node = null


## Sahte yaratık: arı zehri / sarmaşık çağrılarını kaydeder.
class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var poisons: Array = [] ## [tick, plague]
	var pushes: int = 0
	var roots: Array = []
	var slows: Array = [] ## [yüzde, süre]
	var elements: Array = [] ## [tür, parametre]
	var damage: float = 0.0

	func apply_bee_poison(tick: float, plague: bool = false) -> void:
		poisons.append([tick, plague])

	func apply_knockback_distance(_dir: Vector2, _dist: float) -> void:
		pushes += 1

	func apply_root(duration: float, style: int = 0) -> void:
		roots.append([duration, style])

	func apply_slow(percent: float, duration: float, _boss: bool = false) -> void:
		slows.append([percent, duration])

	func apply_element(kind: String, p: Dictionary) -> void:
		elements.append([kind, p])

	func take_damage(amount: float, _c: bool = false, _s: float = 0.0, _a: bool = false) -> void:
		damage += amount


## Sahte uzak oyuncu (kukla): ağaç sadece bu alanlara bakar.
class FakeRemote extends Node2D:
	var is_downed: bool = false
	var is_dead: bool = false
	var peer_id: int = 0


## Sahte kaster: ağacın dirilişi sadece bu yönteme gider.
class FakeCaster extends Node2D:
	var revived: Array = []
	var damage_bonus: float = 50.0

	func oakley_tree_revive_ally(ally: Node2D) -> bool:
		revived.append(ally)
		return true


func _make_player() -> Node:
	if get_tree().current_scene == null or get_tree().current_scene != self:
		_prev_scene = get_tree().current_scene
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 2 ## Oakley
	GameManager.selected_character = int(Characters.DEFS[2]["skill"])
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector2(500.0, 500.0)
	return player


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for c in get_children():
		if is_instance_valid(c):
			c.free() ## anında: "oakley_vines" gibi grup sayımları sonraki testi etkilemesin
	if _prev_scene != null:
		get_tree().current_scene = _prev_scene
		_prev_scene = null


func _fake_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	e.set_meta(preload("res://scripts/vision_fog.gd").VIS_META, 1.0)
	return e


func _flower_count() -> int:
	return get_children().filter(func(c: Node) -> bool: return c.get_script() == FlowerScript).size()


# ------------------------------------------------------------------ veri

func test_cards_exist_with_expected_ids() -> void:
	assert(SkillEvolutions.has_evolutions(2), "Oakley evrimleri tanımlı olmalı")
	var q: Array = SkillEvolutions.slot_list(2, "skill")
	var e: Array = SkillEvolutions.slot_list(2, "skill2")
	var r: Array = SkillEvolutions.slot_list(2, "skill3")
	assert(q.size() == 5 and e.size() == 5 and r.size() == 3, "Q 5, E 5, R 3 evrim (bulunan %d/%d/%d)" % [q.size(), e.size(), r.size()])
	var ids: Array = []
	for list in [q, e, r]:
		for card in list:
			ids.append(str(card["id"]))
	assert(ids == ["oakley_q1", "oakley_q2", "oakley_q3", "oakley_q4", "oakley_qf",
		"oakley_e1", "oakley_e2", "oakley_e3", "oakley_e4", "oakley_ef",
		"oakley_r1", "oakley_r2", "oakley_rf"], "kimlik sırası: %s" % str(ids))
	assert(bool(q[4].get("final", false)) and bool(e[4].get("final", false)) and bool(r[2].get("final", false)), "finaller listenin sonunda")


## Kart metinleri sayılarla tutarlı olmalı (iki yerde aynı sayı: metin + sabit).
func test_card_texts_match_constants() -> void:
	var d: Dictionary = {}
	for slot in SkillEvolutions.SLOTS:
		for card in SkillEvolutions.slot_list(2, slot):
			d[str(card["id"])] = str(card["desc"])
	var p: Node = _make_player()
	assert(d["oakley_q1"].contains("%%%d azalır" % int(round((1.0 - p.EVO_OAKLEY_Q_CD_MULT) * 100.0))), "q1 metni")
	assert(d["oakley_q2"].contains("0,7 saniye") and is_equal_approx(p.EVO_OAKLEY_Q_STING_INTERVAL, 0.7), "q2 metni")
	assert(d["oakley_q3"].contains("%%%d büyür" % int(round((p.EVO_OAKLEY_Q_RANGE_MULT - 1.0) * 100.0))) and d["oakley_q3"].contains("%d saniye daha" % int(p.EVO_OAKLEY_Q_EXTRA_DURATION)), "q3 metni")
	assert(d["oakley_q4"].contains("%%%d ihtimalle" % int(round(OakleyBeeGuard.FLOWER_DUST_CHANCE * 100.0))) and d["oakley_q4"].contains("en fazla %d çiçek" % OakleyBeeGuard.FLOWER_DUST_MAX), "q4 metni")
	assert(d["oakley_qf"].contains("%d birim" % int(Enemy.BEE_PLAGUE_RADIUS)), "qf metni")
	assert(d["oakley_e1"].contains("%%%d azalır" % int(round((1.0 - p.EVO_OAKLEY_E_CD_MULT) * 100.0))), "e1 metni")
	assert(d["oakley_e2"].contains("%%%d'ına" % int(round(p.EVO_OAKLEY_E_DAMAGE_RATIO * 100.0))) and is_equal_approx(VineScript.DAMAGE_RATIO, 0.60), "e2 metni")
	assert(d["oakley_e3"].contains("%d'ten %d'e" % [p.OAKLEY_VINES_COUNT, p.EVO_OAKLEY_E_VINE_COUNT]), "e3 metni")
	assert(d["oakley_e4"].contains("%d saniyeden %d saniyeye" % [int(VineScript.ROOT_DURATION), int(p.EVO_OAKLEY_E_ROOT_DURATION)]) and d["oakley_e4"].contains("%%%d'ye" % int(round(p.EVO_OAKLEY_E_BOSS_SLOW * 100.0))), "e4 metni")
	assert(d["oakley_ef"].contains("%%%d fazla" % int(round(p.EVO_OAKLEY_E_VULN * 100.0))), "ef metni")
	assert(d["oakley_r1"].contains("%d yerine %d saniye" % [int(OakleyTree.DURATION), int(OakleyTree.DURATION + p.EVO_OAKLEY_R_EXTRA_DURATION)]) and d["oakley_r1"].contains("%%%d büyür" % int(round((p.EVO_OAKLEY_R_ZONE_MULT - 1.0) * 100.0))), "r1 metni")
	assert(d["oakley_r2"].contains("%%%d artar" % int(round((p.EVO_OAKLEY_R_FRUIT_MULT - 1.0) * 100.0))) and d["oakley_r2"].contains("%d yerine %d çiçek" % [OakleyTree.FLOWER_OFFSETS.size(), p.EVO_OAKLEY_R_FLOWER_COUNT]), "r2 metni")
	assert(OakleyTree.FLOWER_OFFSETS.size() + OakleyTree.FLOWER_OFFSETS_EXTRA.size() >= p.EVO_OAKLEY_R_FLOWER_COUNT, "6 çiçek için yeterli yer")
	assert(d["oakley_rf"].contains("%%%d canla" % int(round(p.REVIVE_RESTORE_RATIO * 100.0))), "rf metni (diriltme oranı %50)")
	_cleanup()


# ------------------------------------------------------------------ süre / bekleme

func test_timing_evolutions() -> void:
	var p: Node = _make_player()
	var q0: Dictionary = p._skill_timing_for(33)
	var e0: Dictionary = p._skill2_timing_for(10)
	var r0: Dictionary = p._skill3_timing_for(39)
	assert(is_equal_approx(float(q0["cooldown"]), 20.0) and is_equal_approx(float(q0["duration"]), 10.0), "Q temel 20 sn / 10 sn")
	assert(is_equal_approx(float(e0["cooldown"]), 16.0), "E temel bekleme 16 sn")
	assert(is_equal_approx(float(r0["duration"]), 12.0) and is_equal_approx(float(r0["cooldown"]), 60.0), "R temel 12 sn / 60 sn")
	p.apply_skill_evolution("oakley_q1", true)
	p.apply_skill_evolution("oakley_q3", true)
	p.apply_skill_evolution("oakley_e1", true)
	p.apply_skill_evolution("oakley_r1", true)
	var q1: Dictionary = p._skill_timing_for(33)
	assert(is_equal_approx(float(q1["cooldown"]), 15.0), "Çabuk Kovan: 20 -> 15 sn (bulunan %s)" % str(q1["cooldown"]))
	assert(is_equal_approx(float(q1["duration"]), 13.0), "Geniş Halka: süre +3 sn (bulunan %s)" % str(q1["duration"]))
	assert(is_equal_approx(float(p._skill2_timing_for(10)["cooldown"]), 12.0), "Çabuk Filiz: 16 -> 12 sn")
	var r1: Dictionary = p._skill3_timing_for(39)
	assert(is_equal_approx(float(r1["duration"]), 16.0) and is_equal_approx(float(r1["cooldown"]), 60.0), "Kadim Gövde: 16 sn, bekleme aynı")
	_cleanup()


func test_other_characters_untouched_by_oakley_ids() -> void:
	## Melek (10) Q=1/E=10/R=32 kullanır; Şovalye (7) de E=10. Oakley evrimleri onların zamanlamasına dokunmamalı.
	if get_tree().current_scene != self:
		_prev_scene = get_tree().current_scene
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 10
	GameManager.selected_character = int(Characters.DEFS[10]["skill"])
	var melek: Node = PlayerScene.instantiate()
	add_child(melek)
	var before: float = float(melek._skill2_timing_for(10)["cooldown"])
	melek.apply_skill_evolution("oakley_e1", true) ## (apply karakter denetlemez; kart havuzunda zaten çıkmaz) - zamanlamaya etkisi olmamalı
	assert(is_equal_approx(float(melek._skill2_timing_for(10)["cooldown"]), before), "Melek E bekleme değişmemeli")
	_cleanup()


# ------------------------------------------------------------------ Q: Arı Sürüsü

func test_bee_swarm_props_follow_evolutions() -> void:
	var p: Node = _make_player()
	p._skill_oakley_bee_swarm()
	var g0: OakleyBeeGuard = null
	for c in p.get_children():
		if c is OakleyBeeGuard:
			g0 = c
	assert(g0 != null, "sürü kurulmalı")
	assert(is_equal_approx(g0.duration, 10.0) and is_equal_approx(g0.range_mult, 1.0) and is_equal_approx(g0.sting_interval, 1.0), "evrimsiz: eski sabitler")
	assert(not g0.flower_dust and not g0.plague, "evrimsiz: çiçek tozu / salgın yok")
	g0.queue_free()
	for id in ["oakley_q2", "oakley_q3", "oakley_q4", "oakley_qf"]:
		p.apply_skill_evolution(id, true)
	p._skill_oakley_bee_swarm()
	var g: OakleyBeeGuard = null
	for c in p.get_children():
		if c is OakleyBeeGuard and not c.is_queued_for_deletion():
			g = c
	assert(g != null, "evrimli sürü kurulmalı")
	assert(is_equal_approx(g.duration, 13.0), "süre 13 sn")
	assert(is_equal_approx(g.range_mult, 1.3), "halka x1,3")
	assert(is_equal_approx(g.sting_interval, 0.7), "sokma aralığı 0,7 sn")
	assert(g.flower_dust and g.plague, "Çiçek Tozu + Salgın Zehir açık")
	_cleanup()


func test_bee_guard_radius_interval_and_plague_flag() -> void:
	var p: Node = _make_player()
	for id in ["oakley_q2", "oakley_q3", "oakley_qf"]:
		p.apply_skill_evolution(id, true)
	p.damage_bonus = 40.0
	p._skill_oakley_bee_swarm()
	var g: OakleyBeeGuard = null
	for c in p.get_children():
		if c is OakleyBeeGuard:
			g = c
	var feet: Vector2 = g.global_position + OakleyBeeGuard.FEET
	var inside := _fake_enemy(feet + Vector2(150.0, 0.0)) ## 130'un dışında ama 169'un içinde
	var outside := _fake_enemy(feet + Vector2(175.0, 0.0))
	g._authority_area(0.0)
	assert(inside.poisons.size() == 1 and outside.poisons.is_empty(), "yarıçap x1,3: 150 içeride, 175 dışarıda")
	assert(bool(inside.poisons[0][1]), "zehir yüküne Salgın Zehir bayrağı eklenmeli")
	assert(is_equal_approx(float(inside.poisons[0][0]), 40.0 * 0.20 / 4.0), "yük hasarı değişmedi (SG x %20 / 4)")
	g._authority_area(0.5)
	assert(inside.poisons.size() == 1, "0,5 sn sonra henüz etkilenmez (aralık 0,7)")
	g._authority_area(0.3)
	assert(inside.poisons.size() == 2, "0,8 sn: ikinci etki")
	_cleanup()


func test_flower_dust_drops_flower_when_poisoned_enemy_dies_capped_at_three() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("oakley_q4", true)
	p._skill_oakley_bee_swarm()
	var g: OakleyBeeGuard = null
	for c in p.get_children():
		if c is OakleyBeeGuard:
			g = c
	g.dust_chance = 1.0
	var feet: Vector2 = g.global_position + OakleyBeeGuard.FEET
	var victims: Array = []
	for i in range(5):
		victims.append(_fake_enemy(feet + Vector2(20.0 + 10.0 * float(i), 0.0)))
	g._authority_area(0.0)
	assert(g._stung.size() == 5, "sokulan 5 yaratık izlenmeli (bulunan %d)" % g._stung.size())
	var before: int = _flower_count()
	for v in victims:
		v.is_dead = true
	g._poll_poisoned_deaths(1.0)
	assert(_flower_count() - before == 3, "sürü başına en fazla 3 çiçek (bulunan %d)" % (_flower_count() - before))
	assert(g._stung.is_empty(), "ölenler izlemeden çıkar")
	_cleanup()


func test_flower_dust_ignores_deaths_after_poison_expired_and_without_evo() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("oakley_q4", true)
	p._skill_oakley_bee_swarm()
	var g: OakleyBeeGuard = null
	for c in p.get_children():
		if c is OakleyBeeGuard:
			g = c
	g.dust_chance = 1.0
	var feet: Vector2 = g.global_position + OakleyBeeGuard.FEET
	var late := _fake_enemy(feet + Vector2(20.0, 0.0))
	g._authority_area(0.0)
	g._t += 5.0 ## zehir (4 sn) bitti
	late.is_dead = true
	var before: int = _flower_count()
	g._poll_poisoned_deaths(1.0)
	assert(_flower_count() == before, "zehri bitmiş yaratığın ölümü çiçek bırakmaz")
	## Evrimsiz sürü hiç izlemez.
	g.queue_free()
	var p2_guard: OakleyBeeGuard = BeeGuardScene.instantiate()
	p.add_child(p2_guard)
	var victim := _fake_enemy(p2_guard.global_position + OakleyBeeGuard.FEET + Vector2(20.0, 0.0))
	p2_guard._authority_area(0.0)
	assert(p2_guard._stung.is_empty() and victim.poisons.size() == 1 and not bool(victim.poisons[0][1]), "evrimsiz: izleme yok, salgın bayrağı yok")
	_cleanup()


## Salgın Zehir (enemy.gd): gerçek yaratıklarla yük yayılımı.
func test_plague_spreads_stacks_to_nearby_on_death() -> void:
	if get_tree().current_scene != self:
		_prev_scene = get_tree().current_scene
		get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var a: Node = EnemyScene.instantiate()
	var b: Node = EnemyScene.instantiate()
	var far: Node = EnemyScene.instantiate()
	for e in [a, b, far]:
		add_child(e)
		e.add_to_group("enemies")
	a.global_position = Vector2(1000.0, 1000.0)
	b.global_position = Vector2(1100.0, 1000.0) ## 150 içinde
	far.global_position = Vector2(1300.0, 1000.0) ## dışında
	for i in range(3):
		a.apply_bee_poison(6.0, true)
	assert(a._bee_poison_stacks.size() == 3 and a._bee_plague, "taşıyıcıda 3 yük + salgın bayrağı")
	a._spread_bee_plague()
	assert(b._bee_poison_stacks.size() == 3, "yakındaki 3 yük alır (bulunan %d)" % b._bee_poison_stacks.size())
	assert(b._bee_plague, "geçen yükler de salgın taşır (zincirleme)")
	assert(is_equal_approx(b._bee_poison_per_tick_damage, 6.0), "tik hasarı taşınır")
	assert(far._bee_poison_stacks.is_empty(), "150 dışındaki etkilenmez")
	## Yük tavanı: komşunun zaten 9 yükü varsa en fazla 10'a çıkar.
	var c: Node = EnemyScene.instantiate()
	add_child(c)
	c.add_to_group("enemies")
	c.global_position = Vector2(1050.0, 1000.0)
	for i in range(9):
		c.apply_bee_poison(2.0)
	a._spread_bee_plague()
	assert(c._bee_poison_stacks.size() == 10, "tavan 10 (bulunan %d)" % c._bee_poison_stacks.size())
	## Bayraksız zehir die()'da yayılmaz.
	var plain: Node = EnemyScene.instantiate()
	add_child(plain)
	plain.add_to_group("enemies")
	plain.global_position = Vector2(1000.0, 1040.0)
	plain.apply_bee_poison(6.0)
	assert(not plain._bee_plague, "evrimsiz zehir salgın bayrağı taşımaz")
	_cleanup()


## die() zinciri: salgın taşıyıcı ölünce yükler gerçekten komşuya geçer (host / tek oyunculu yolu).
func test_plague_spreads_through_real_die() -> void:
	if get_tree().current_scene != self:
		_prev_scene = get_tree().current_scene
		get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var a: Node = EnemyScene.instantiate()
	var b: Node = EnemyScene.instantiate()
	for e in [a, b]:
		add_child(e)
		e.add_to_group("enemies")
	a.global_position = Vector2(1000.0, 1000.0)
	b.global_position = Vector2(1060.0, 1000.0)
	a.apply_bee_poison(4.0, true)
	a.apply_bee_poison(4.0, true)
	a.die()
	assert(b._bee_poison_stacks.size() == 2 and b._bee_plague, "ölümde 2 yük komşuya geçmeli (bulunan %d)" % b._bee_poison_stacks.size())
	var c: Node = EnemyScene.instantiate()
	var d: Node = EnemyScene.instantiate()
	for e in [c, d]:
		add_child(e)
		e.add_to_group("enemies")
	c.global_position = Vector2(2000.0, 2000.0)
	d.global_position = Vector2(2040.0, 2000.0)
	c.apply_bee_poison(4.0) ## salgın bayraksız
	c.die()
	assert(d._bee_poison_stacks.is_empty(), "bayraksız zehir ölümde yayılmaz")
	_cleanup()


# ------------------------------------------------------------------ E: Sarmaşıklar

func _make_vine(evo: Dictionary) -> Node2D:
	var vine := Node2D.new()
	vine.set_script(VineScript)
	vine.position = Vector2(300.0, 300.0)
	add_child(vine)
	vine.call("setup", 50.0, evo)
	return vine


func test_vine_defaults_without_evolutions() -> void:
	get_tree().current_scene = self
	var e := _fake_enemy(Vector2(300.0, 300.0))
	var vine: Node2D = _make_vine({})
	vine._target = e
	vine._on_hit()
	assert(is_equal_approx(e.damage, 50.0 * 0.60), "temel hasar SG x %60")
	assert(e.roots.size() == 1 and is_equal_approx(float(e.roots[0][0]), 4.0), "temel sabitleme 4 sn")
	assert(e.elements.is_empty(), "evrimsiz: zayıflık yok")
	_cleanup()


func test_vine_evolution_values() -> void:
	get_tree().current_scene = self
	var evo := {"damage_ratio": 0.9, "root_duration": 6.0, "boss_slow": 0.5, "vuln": 0.25}
	var e := _fake_enemy(Vector2(300.0, 300.0))
	var vine: Node2D = _make_vine(evo)
	vine._target = e
	vine._on_hit()
	assert(is_equal_approx(e.damage, 50.0 * 0.9), "Dikenli Sarmaşık: SG x %90")
	assert(is_equal_approx(float(e.roots[0][0]), 6.0), "Sıkı Dolanma: 6 sn")
	assert(e.elements.size() == 1 and e.elements[0][0] == "vuln" and is_equal_approx(float(e.elements[0][1]["pct"]), 0.25) and is_equal_approx(float(e.elements[0][1]["dur"]), 6.0), "Kök Hapishanesi: +%25 hasar, sabitleme süresi kadar")
	var boss := _fake_enemy(Vector2(300.0, 300.0))
	boss.is_boss = true
	var vine2: Node2D = _make_vine(evo)
	vine2._target = boss
	vine2._on_hit()
	assert(boss.roots.is_empty() and boss.slows.size() == 1, "boss sabitlenmez, yavaşlar")
	assert(is_equal_approx(float(boss.slows[0][0]), 0.5) and is_equal_approx(float(boss.slows[0][1]), 6.0), "boss yavaşlatması %50 / 6 sn")
	assert(boss.elements.size() == 1, "yavaşlatılan boss da zayıflar")
	_cleanup()


func test_cast_spawns_five_vines_with_evolutions() -> void:
	var p: Node = _make_player()
	p._skill_oakley_vines()
	assert(get_tree().get_nodes_in_group("oakley_vines").size() == 3, "temel: 3 sarmaşık")
	for v in get_tree().get_nodes_in_group("oakley_vines"):
		v.free()
	p.apply_skill_evolution("oakley_e3", true)
	p.apply_skill_evolution("oakley_e2", true)
	p.apply_skill_evolution("oakley_ef", true)
	p._skill_oakley_vines()
	var vines: Array = get_tree().get_nodes_in_group("oakley_vines")
	assert(vines.size() == 5, "Çok Filiz: 5 sarmaşık (bulunan %d)" % vines.size())
	for v in vines:
		assert(is_equal_approx(float(v.get("_damage_ratio")), 0.9) and is_equal_approx(float(v.get("_vuln")), 0.25), "evrim değerleri sarmaşığa gitmeli")
		assert(is_equal_approx(float(v.get("_root_duration")), 4.0), "e4 alınmadı: sabitleme 4 sn")
	_cleanup()


# ------------------------------------------------------------------ R: Hayat Ağacı

func test_tree_evolution_params() -> void:
	get_tree().current_scene = self
	var caster := FakeCaster.new()
	add_child(caster)
	var tree: OakleyTree = OakleyTree.spawn(self, Vector2(300.0, 300.0), caster, {"dur": 16.0, "zone": 1.25, "fruit": 1.4, "flowers": 6, "revive": true})
	assert(is_equal_approx(tree._duration, 16.0) and is_equal_approx(tree._zone_mult, 1.25) and tree._flower_count == 6 and tree._revive_enabled, "parametreler okunmalı")
	var rx: float = OakleyTree.ZONE_RX * 1.25
	assert(tree.in_zone(Vector2(300.0 + rx - 2.0, 300.0)) and not tree.in_zone(Vector2(300.0 + rx + 3.0, 300.0)), "alan x1,25 (yatay %s)" % str(rx))
	assert(int(OakleyTree.tree_state(12.2, 16.0)[0]) == 2 and int(OakleyTree.tree_state(12.2)[0]) == 1, "16 sn'de ağaç 12. sn'de hâlâ tam boy")
	assert(OakleyTree.zone_alpha(12.5, 16.0) > 0.99 and OakleyTree.zone_alpha(12.5) < 1.0, "alan 16 sn'ye kadar açık")
	assert(is_equal_approx(tree._zone.scale.x, 1.25) and is_equal_approx(tree._rays_back.scale.x, 1.25), "görsel alan da büyür")
	var plain: OakleyTree = OakleyTree.spawn(self, Vector2(300.0, 300.0), caster)
	assert(is_equal_approx(plain._duration, 12.0) and is_equal_approx(plain._zone_mult, 1.0) and plain._flower_count == 3 and not plain._revive_enabled, "parametresiz: eski değerler")
	var cosmetic: OakleyTree = OakleyTree.spawn(self, Vector2(300.0, 300.0), null, {"dur": 16.0, "zone": 1.25, "revive": true})
	assert(cosmetic.is_cosmetic() and not cosmetic._revive_enabled, "kozmetik kopya diriltemez")
	_cleanup()


func test_fruit_bonus_and_six_flowers() -> void:
	var p: Node = _make_player()
	p.apply_skill_evolution("oakley_r1", true)
	p.apply_skill_evolution("oakley_r2", true)
	p.max_health = 200.0
	p.health = 50.0
	p.item_shield_max = 1000.0
	p.item_shield_hp = 1000.0
	p.damage_bonus = 50.0
	p.facing = "right"
	p._activate_skill3()
	assert(is_equal_approx(p.skill3_timer, 16.0), "R 16 sn aktif (bulunan %s)" % str(p.skill3_timer))
	var tree: OakleyTree = null
	for n in get_tree().get_nodes_in_group("oakley_trees"):
		if n.get("caster") == p:
			tree = n
	assert(tree != null and is_equal_approx(tree._duration, 16.0) and is_equal_approx(tree._zone_mult, 1.25), "ağaç evrim parametreleriyle kurulmalı")
	var hp0: float = p.health
	tree._heal_target(p)
	var expected: float = (50.0 * OakleyTree.HEAL_AP_RATIO + 200.0 * OakleyTree.HEAL_MAX_HP_PERCENT) * 1.4
	assert(absf((p.health - hp0) - expected) < 0.01, "meyve can x1,4 (beklenen %s, bulunan %s)" % [str(expected), str(p.health - hp0)])
	var before: int = _flower_count()
	tree._t = 16.0 + OakleyTree.FLOWER_DELAY
	tree._process(0.01)
	assert(_flower_count() - before == 6, "ağaç solarken 6 çiçek (bulunan %d)" % (_flower_count() - before))
	_cleanup()


func test_tree_revives_downed_ally_once_in_zone() -> void:
	get_tree().current_scene = self
	var caster := FakeCaster.new()
	add_child(caster)
	var tree: OakleyTree = OakleyTree.spawn(self, Vector2(300.0, 300.0), caster, {"revive": true})
	tree._opened = true
	var inside := FakeRemote.new()
	inside.add_to_group("remote_players")
	inside.peer_id = 11
	add_child(inside)
	inside.global_position = Vector2(340.0, 290.0)
	var outside := FakeRemote.new()
	outside.add_to_group("remote_players")
	outside.peer_id = 12
	add_child(outside)
	outside.global_position = Vector2(900.0, 300.0)
	var standing := FakeRemote.new()
	standing.add_to_group("remote_players")
	standing.peer_id = 13
	add_child(standing)
	standing.global_position = Vector2(310.0, 300.0)
	inside.is_downed = true
	outside.is_downed = true
	tree._try_revive()
	assert(caster.revived == [inside] and tree._revive_used, "gölgedeki yerde yatan dost kaldırılır, dışarıdaki ve ayaktaki değil")
	## ağaç başına bir kez
	var second := FakeRemote.new()
	second.add_to_group("remote_players")
	second.peer_id = 14
	second.is_downed = true
	add_child(second)
	second.global_position = Vector2(320.0, 300.0)
	tree._process(0.016)
	assert(caster.revived.size() == 1, "her ağaçta bir kez")
	_cleanup()


func test_receive_revive_brings_downed_player_up() -> void:
	var p: Node = _make_player()
	p.max_health = 100.0
	p.health = 0.0
	p.is_downed = true
	p.is_dead = true
	p.receive_oakley_revive()
	assert(not p.is_downed and not p.is_dead, "yerdeki oyuncu kalkmalı")
	assert(is_equal_approx(p.health, 50.0), "%50 canla (bulunan %s)" % str(p.health))
	p.health = 80.0
	p.receive_oakley_revive() ## ayaktakine etki etmez
	assert(is_equal_approx(p.health, 80.0), "ayaktaki oyuncuya dokunmaz")
	_cleanup()


func test_revive_ally_requires_multiplayer_and_downed() -> void:
	var p: Node = _make_player()
	var remote := FakeRemote.new()
	remote.peer_id = 21
	remote.is_downed = true
	add_child(remote)
	assert(not p.oakley_tree_revive_ally(remote), "tek oyunculuda dost yok -> gönderilmez")
	NetworkManager.is_multiplayer_active = true
	remote.is_downed = false
	assert(not p.oakley_tree_revive_ally(remote), "ayaktaki dost kaldırılmaz")
	NetworkManager.is_multiplayer_active = false
	_cleanup()
