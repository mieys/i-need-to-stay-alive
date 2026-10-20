extends Node

## UYKU (2026-10-19, FPS turu 4; madde 278): uyanık ama "sessiz" yaratık (tek işi yetenek bekleme sayacı + kalkan yenilenmesi) köprünün uyku listesine alınır, her fizik
## karesi tiklenmez (enemy.gd _ew_try_dormant, enemy_world_bridge.gd _wake_due). Atlanan sürenin etkisi uyanınca tek seferde işlenir. Bu dosya eski yolla (kare kare tik) AYNI
## sonucu verdiğini kanıtlar: sayaçlar (EnemyAbilities.fast_forward), kalkan yenilenmesi (_ew_dorm_sync) ve köprü düzeyinde A/B (uykulu / uykusuz, aynı tohum).

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const BridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const DT := 1.0 / 60.0

var _spawned: Array[Node] = []


class _FakeOwner extends Node2D:
	var is_ability_invisible: bool = false
	var is_dead: bool = false
	func set_ability_invisible(on: bool) -> void:
		is_ability_invisible = on


func _cleanup() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.free()
	_spawned.clear()
	EnemyScript._ew_dormancy_on = true


func _make(id: String) -> Node2D:
	var packed: PackedScene = load("res://scenes/creatures/enemy_%s.tscn" % id)
	var e: Node2D = packed.instantiate()
	e.set_meta("creature_id", id)
	add_child(e)
	e.global_position = Vector2(float(_spawned.size()) * 40.0, 0.0)
	e.speed = 0.0
	_spawned.append(e)
	return e


## Sayaçları DIŞARIDAN değiştirmek (yalnız testlerde olur; oyunda sayaçlara sadece yeteneğin kendi tiki dokunur): önce uyandır, yoksa uyuyanın eski bitiş saati geçerli kalır.
func _set_ability(c: Node2D, field: String, value: float) -> void:
	c._ew_wake()
	c._abilities.set(field, value)


func _step(b: Node, frames: int) -> void:
	b.set_physics_process(false)
	for i: int in range(frames):
		b._physics_process(DT)
	b.set_physics_process(true)


## --- 1) Yetenek sayaçları: fast_forward(k x DT) == k kez process_fast(DT) ---------------------------------------------------------------
func _make_ability(fam: String, variant: int) -> Array:
	seed(11) ## setup() rastgele bekleme çeker: iki kopya aynı başlasın
	var owner := _FakeOwner.new()
	var ab = AbilitiesScript.new()
	ab.setup(owner, fam)
	match fam:
		"hayalet":
			if variant == 1:
				owner.is_ability_invisible = true
				ab._timer = 2.5
			else:
				ab._cd = 4.0
		"vampire":
			ab._cd = 0.0
			if variant == 0:
				ab._cd = 5.0
			elif variant == 1:
				ab._pending = -1.0
				ab._vision_check = 0.2
			else:
				ab._pending = 1.5
		_:
			ab._cd = 3.0
	return [owner, ab]


func _ab_state(ab) -> Array:
	return [ab._cd, ab._timer, ab._pending, ab._vision_check]


func test_fast_forward_equals_repeated_process_fast() -> void:
	for fam in ["hayalet", "vampire", "rontgen", "iblis", "agac"]:
		for variant in range(3):
			if fam != "vampire" and fam != "hayalet" and variant > 0:
				continue
			if fam == "hayalet" and variant > 1:
				continue
			var a: Array = _make_ability(fam, variant)
			var rem: float = a[1].quiet_remaining()
			assert(rem > 0.0, "%s/%d: quiet_remaining > 0 olmalı (%f)" % [fam, variant, rem])
			var k: int = 0
			while a[1].process_fast(DT):
				k += 1
				assert(k < 100000, "process_fast sonsuza dek true döndü")
			var seq: Array = _ab_state(a[1])
			assert(k >= int(rem / DT) - 1 and k <= int(rem / DT) + 2, "%s/%d: hızlı kare sayısı sayaçla uyumlu olmalı (k=%d rem=%f)" % [fam, variant, k, rem])
			var b: Array = _make_ability(fam, variant)
			b[1].fast_forward(float(k) * DT)
			var jump: Array = _ab_state(b[1])
			for i in range(4):
				assert(absf(float(seq[i]) - float(jump[i])) < 1e-9, "%s/%d: sayaç %d kare kare %f / tek atlama %f" % [fam, variant, i, float(seq[i]), float(jump[i])])
			a[0].free()
			b[0].free()


func test_boss_families_have_no_fast_path_so_never_sleep() -> void:
	var owner := _FakeOwner.new()
	for fam in ["minotaur", "wendigo", "banshee"]:
		var ab = AbilitiesScript.new()
		ab.setup(owner, fam)
		assert(ab.quiet_remaining() < 0.0, "%s: hızlı yolu olmayan yetenek uyutulmamalı" % fam)
	owner.free()


## --- 2) Kalkan: tek atlamayla işlenen gecikme + yenilenme == kare kare _process_item_shield --------------------------------------------
func test_shield_dormant_sync_matches_per_tick_regen() -> void:
	var e: Node2D = _make("iblis1")
	await get_tree().process_frame
	e._abilities = null ## sadece kalkan
	e.enable_item_shield(0.6, 1.0)
	var mx: float = float(e.item_shield_max)
	assert(mx > 0.0)
	for case in [[0.0, 0.4], [2.0, 0.4], [14.0, 0.1], [14.0, 0.9], [0.5, 0.99]]:
		var delay: float = case[0]
		var frac: float = case[1]
		var ticks: int = 60 * 20
		e.item_shield_regen_delay = delay
		e.item_shield_hp = mx * frac
		for i in range(ticks):
			e._process_item_shield(DT)
		var seq_hp: float = e.item_shield_hp
		e.item_shield_regen_delay = delay
		e.item_shield_hp = mx * frac
		e._ew_dorm_t0 = 0.0
		e._ew_dorm_sync(float(ticks) * DT)
		assert(absf(float(e.item_shield_hp) - seq_hp) <= mx * 0.001, "kalkan (gecikme %.1f, doluluk %.2f): kare kare %f / uyku %f" % [delay, frac, seq_hp, float(e.item_shield_hp)])
		## kısmi atlamalar art arda: aynı toplam
		e.item_shield_regen_delay = delay
		e.item_shield_hp = mx * frac
		e._ew_dorm_t0 = 0.0
		var t: float = 0.0
		for chunk in [1.3, 0.7, 6.0, 12.0]:
			t += float(chunk)
			e._ew_dorm_sync(t)
		assert(absf(float(e.item_shield_hp) - seq_hp) <= mx * 0.001, "kalkan parça parça atlama: kare kare %f / uyku %f" % [seq_hp, float(e.item_shield_hp)])
	_cleanup()


## --- 3) Köprü düzeyinde A/B: aynı tohum, uykulu ve uykusuz; sayaçlar + kalkan aynı, uykulu koşuda gerçekten uyuyan yaratık var -------------
func _scenario(dormant: bool) -> Dictionary:
	seed(4242)
	EnemyScript._ew_dormancy_on = dormant
	var ids: Array = ["vampire1", "iblis1", "hayalet1", "agac1", "rontgen1"] ## tek vampir: iki vampirin aynı karedeki rastgele çekimlerinin sırası uykuyla değişebilir
	var creatures: Array = []
	for id in ids:
		var e: Node2D = _make(id)
		creatures.append(e)
	await get_tree().process_frame
	var b: Node = BridgeScript._instance
	_step(b, 2) ## ilk tik: yetenek kurulumu
	var lengths := [5.5, 3.1, 4.2, 2.0, 9.0] ## bekleme sayaçlarını farklı bitiş saniyelerine koy
	for i in range(creatures.size()):
		var c: Node2D = creatures[i]
		c.enable_item_shield(0.6, 1.0)
		var ab = c._abilities
		assert(ab != null, "%s yeteneği kurulmalı" % ids[i])
		_set_ability(c, "_cd", float(lengths[i]))
		if i == 0:
			_set_ability(c, "_pending", -1.0)
			_set_ability(c, "_vision_check", 0.0)
	var rows: Array = []
	var max_dormant: int = 0
	for t in range(1, 1201): ## 20 sn
		_step(b, 1)
		max_dormant = maxi(max_dormant, int(b.dormant_count))
		if t == 150 or t == 700:
			for i in [0, 3, 4]: ## vuruş: eski yolun ilk işi _ew_wake, sonra kalkan düşer ve gecikme sıfırlanır
				var c: Node2D = creatures[i]
				c._ew_wake()
				c.item_shield_hp = maxf(0.0, float(c.item_shield_hp) - 15.0)
				c.item_shield_regen_delay = 14.0
		if t % 100 == 0 or t == 1200:
			var row: Array = []
			for c in creatures:
				c.shield_now() ## uyuyorsa sayaçları şu ana kadar işler
				var ab = c._abilities
				row.append([float(c.item_shield_hp), float(c.item_shield_regen_delay), float(ab._cd), float(ab._pending), float(ab._vision_check), float(ab._timer)])
			rows.append(row)
	var res: Dictionary = {"rows": rows, "max_dormant": max_dormant, "ids": ids}
	_cleanup()
	return res


func test_bridge_dormancy_gives_same_counters_as_per_tick_path() -> void:
	var off: Dictionary = await _scenario(false)
	var on: Dictionary = await _scenario(true)
	assert(int(off["max_dormant"]) == 0, "uykusuz koşuda uyuyan olmamalı")
	assert(int(on["max_dormant"]) >= 3, "uykulu koşuda yaratıklar uyumalı (en çok uyuyan: %d)" % int(on["max_dormant"]))
	var a_rows: Array = off["rows"]
	var b_rows: Array = on["rows"]
	assert(a_rows.size() == b_rows.size() and a_rows.size() >= 10)
	for r in range(a_rows.size()):
		for c in range(a_rows[r].size()):
			var x: Array = a_rows[r][c]
			var y: Array = b_rows[r][c]
			assert(absf(float(x[0]) - float(y[0])) <= 0.06, "%s kalkan @%d: %f / %f" % [on["ids"][c], (r + 1) * 100, float(x[0]), float(y[0])])
			assert(absf(float(x[1]) - float(y[1])) <= 0.06, "%s kalkan gecikmesi @%d: %f / %f" % [on["ids"][c], (r + 1) * 100, float(x[1]), float(y[1])])
			for k in range(2, 6):
				assert(absf(float(x[k]) - float(y[k])) <= 1e-6, "%s sayaç %d @%d: kare kare %f / uyku %f" % [on["ids"][c], k, (r + 1) * 100, float(x[k]), float(y[k])])


## --- 4) Dışarıdan uyandırma ve ölüm uyku listesini bozmaz ---------------------------------------------------------------------------------
func test_external_wake_and_free_keep_the_sleep_list_consistent() -> void:
	EnemyScript._ew_dormancy_on = true
	var cs: Array = []
	for i in range(5):
		cs.append(_make("iblis1"))
	await get_tree().process_frame
	var b: Node = BridgeScript._instance
	_step(b, 2)
	for c in cs:
		_set_ability(c, "_cd", 9.0)
	_step(b, 3)
	assert(int(b.dormant_count) == 5, "bekleme uzunken 5 yaratık da uyumalı (uyuyan: %d)" % int(b.dormant_count))
	for c in cs:
		assert(c._ew_dormant and not c._ew_awake)
	## ortadaki dışarıdan uyandırılır, sonuncusu silinir: kalan indeksler tutarlı kalmalı
	cs[1]._ew_wake()
	assert(not cs[1]._ew_dormant and cs[1]._ew_awake and int(b.dormant_count) == 4)
	cs[4].free()
	assert(int(b.dormant_count) == 3, "silinen uyuyan listeden çıkmalı")
	for i in [0, 2, 3]:
		var idx: int = int(cs[i]._ew_dorm_idx)
		assert(idx >= 0 and idx < int(b.dormant_count) and b._dorm_nodes[idx] == cs[i], "uyuyanın indeksi listedeki yerini göstermeli")
	_step(b, 600) ## 10 sn: hepsi bekleme süresini doldurup uyanır (hedefsiz, sayaç negatife iner)
	for i in [0, 2, 3]:
		assert(float(cs[i]._abilities._cd) < 0.0, "bekleme dolmalı (_cd=%f)" % float(cs[i]._abilities._cd))
	assert(float(cs[1]._abilities._cd) < 0.0)
	_cleanup()


## EW_DORMANT=0 anahtarı (süreç düzeyi A/B): kapalıyken hiçbir yaratık uyutulmaz.
func test_switch_off_never_sleeps() -> void:
	EnemyScript._ew_dormancy_on = false
	var c: Node2D = _make("iblis1")
	await get_tree().process_frame
	var b: Node = BridgeScript._instance
	_step(b, 2)
	_set_ability(c, "_cd", 9.0)
	_step(b, 30)
	assert(not c._ew_dormant and int(b.dormant_count) == 0)
	_cleanup()


## --- 5) Bekleme biter bitmez asıl iş: hedefi olan hayalet eski yolla AYNI karede görünmez olmalı (uyku süreyi kaydırmamalı) ---------------------
func _ghost_first_vanish_tick(dormant: bool, rng_seed: int) -> int:
	seed(rng_seed)
	EnemyScript._ew_dormancy_on = dormant
	var target := Node2D.new()
	target.add_to_group("player")
	add_child(target)
	_spawned.append(target)
	target.global_position = Vector2(120.0, 0.0)
	var g: Node2D = _make("hayalet1")
	g.global_position = Vector2.ZERO
	await get_tree().process_frame
	var b: Node = BridgeScript._instance
	_step(b, 2)
	_set_ability(g, "_cd", 2.0 + float(rng_seed % 3) * 0.37)
	var found: int = -1
	var slept: bool = false
	for t in range(1, 2400):
		_step(b, 1)
		slept = slept or bool(g._ew_dormant)
		if g.is_ability_invisible:
			found = t
			break
	if dormant:
		assert(slept, "hedefi olan hayalet de bekleme sırasında uyumalı (tohum %d)" % rng_seed)
	_cleanup()
	return found


func test_dormant_ghost_vanishes_on_the_same_tick_as_per_tick_path() -> void:
	for rng_seed in [1, 2, 3, 4, 5, 6]:
		var off: int = await _ghost_first_vanish_tick(false, rng_seed)
		var on: int = await _ghost_first_vanish_tick(true, rng_seed)
		assert(off > 0, "hayalet görünmez olmalı (tohum %d)" % rng_seed)
		assert(on == off, "tohum %d: uykusuz %d. karede, uykulu %d. karede görünmez oldu" % [rng_seed, off, on])
