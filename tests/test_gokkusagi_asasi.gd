extends Node

## GÖKKUŞAĞI ASASI (2026-10-19, madde 306): kayıtlar, tik hasarı/aralığı (saniyede %150 SG, 0,5 sn), ışının ilk düşmanda durması ve finalde
## (beam_pierce) hattaki herkesi delmesi, Göz Kamaştıran Işık (3 sn tut -> 1,5 sn sersemletme; boss -> zayıflatma; hedef değişince sıfır),
## zayıflatılmış yaratığın verdiği hasar çarpanı. Gerçek oyuncu + gerçek asa (test_lightning_beam_sfx.gd düzeni).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const BeamScene: PackedScene = preload("res://scenes/fx_rainbow_beam.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const WeaponTraits := preload("res://scripts/weapon_traits/weapon_traits.gd")
const RemotePlayerScript := preload("res://scripts/remote_player.gd")
const VisionFog := preload("res://scripts/vision_fog.gd")
const MATTHEW := 3


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var is_elite: bool = false
	var hits: Array = []
	var elements: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)

	func apply_element(kind: String, p: Dictionary) -> void:
		elements.append([kind, p.duplicate()])


var _spawned: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1


func _track(n: Node) -> Node:
	add_child(n)
	_spawned.append(n)
	return n


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	_track(e)
	e.global_position = pos
	return e


func _setup(ench: Dictionary = {}) -> Array:
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = MATTHEW
	GameManager.selected_character = int(Characters.DEFS[MATTHEW]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = _track(PlayerScene.instantiate())
	p.global_position = Vector2(1000.0, 1000.0)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	GameManager.owned_weapons = [{"key": "gokkusagi", "level": 1}]
	assert(p.buy_weapon_copy("gokkusagi", 1), "silah verilemedi")
	var w: Node = p.owned_weapon_nodes[0]
	w.crit_chance = 0.0
	w.set_enchant(ench if not ench.is_empty() else {"id": "goz_kamastiran"})
	return [p, w]


func _open_beam(w: Node, target: Node2D) -> Node:
	var fx: Node = _track(BeamScene.instantiate())
	var origin: Node2D = w.muzzle if w.muzzle else w
	fx.setup(origin, target)
	w._beam_fx = fx
	w._beam_target = target
	w._update_beam_reach(target, origin)
	return fx


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.owned_weapons = []
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for c in get_children():
		c.free()
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene


func test_registered_everywhere() -> void:
	assert(WeaponCatalogScript.KEYS.has("gokkusagi"), "katalogda")
	assert(WeaponCatalogScript.DESCRIPTIONS.has("gokkusagi") and WeaponCatalogScript.NAMES["gokkusagi"] == "Gökkuşağı Asası", "ad + açıklama")
	assert(WeaponTraits.trait_of("gokkusagi") == "goz_kamastiran", "doğuştan özellik")
	assert(WeaponTierArt.has_art("gokkusagi") and WeaponTierArt.key_from_scene("res://scenes/weapon_gokkusagi.tscn") == "gokkusagi", "kademe sanatı anahtarı")
	for lv in range(1, 6):
		assert(WeaponTierArt.texture("gokkusagi", lv) != null, "L%d dokusu" % lv)
	assert(RemotePlayerScript.WEAPON_SCENES.has("gokkusagi"), "uzak kukla sahnesi")
	var d: Dictionary = EnchantDefs.get_def("goz_kamastiran")
	assert(not d.is_empty() and (d["upgrades"] as Array).size() == 4 and d.has("final"), "4 geliştirme + final")


func test_tick_is_110_percent_every_half_second() -> void:
	var s := _setup()
	var w: Node = s[1]
	assert(is_equal_approx(w.beam_tick_interval / GameManager.WEAPON_ATTACK_SPEED_MULT, 0.5), "taban tik aralığı 0,5 sn")
	assert(is_equal_approx(w.card_damage_bonus_ratio * w.beam_tick_ratio / 0.5, 1.4), "saniyede %140 SG (2026-11-14: %220 -> %140)")
	var e := _enemy(Vector2(1100.0, 1000.0))
	w.damage = 20.0
	w._deal_beam_tick(e)
	assert(e.hits.size() == 1, "tek vuruş")
	assert(absf(float(e.hits[0]) - 20.0 * w.beam_tick_ratio) < 0.5, "tik = silah hasarı x oran: %s" % str(e.hits))
	_cleanup()


func test_beam_stops_at_first_enemy_until_final_pierces_the_line() -> void:
	var s := _setup()
	var w: Node = s[1]
	var first := _enemy(Vector2(1060.0, 970.0))
	var origin: Node2D = w.muzzle if w.muzzle else w
	var dir: Vector2 = (first.global_position - origin.global_position).normalized()
	var behind := _enemy(origin.global_position + dir * 120.0)
	var off_line := _enemy(origin.global_position + dir * 90.0 + dir.orthogonal() * 40.0)
	_open_beam(w, first)
	assert(w._beam_extra_targets.is_empty(), "temelde ışın ilk düşmanda durur")
	assert(w.beam_targets() == [first], "yalnız birincil hedef")
	w.set_enchant({"id": "goz_kamastiran", "ups": [0, 1, 2, 3], "final": true})
	w._update_beam_reach(first, origin)
	assert(w._beam_extra_targets.has(behind), "final: arkadaki delinir")
	assert(not w._beam_extra_targets.has(off_line), "hattın dışındaki vurulmaz")
	assert(w._beam_fx.pierce, "efekt görüş kenarına uzanır")
	## madde 551: uç = sahibin görüş elipsinin kenarı (menzil 185'in ötesi)
	var p: Node2D = s[0]
	var n: float = VisionFog.normalized_distance(w._beam_end - p.global_position, VisionFog.current_radius(get_tree()), VisionFog.VISION_WIDTH_SCALE)
	assert(absf(n - 1.0) < 0.01, "uç görüş elipsinin kenarında: %.3f" % n)
	assert(origin.global_position.distance_to(w._beam_end) > w.attack_range + 50.0, "final menzilden uzun")
	_cleanup()


## madde 551 IŞIK SAÇILMASI: her tikte birincilin 60 px içindeki EN YAKIN 3 düşmana tik (2026-11-14: 4 -> 3) hasarının yarısı; uzaktakiler ve finalde delinenler almaz.
func test_light_scatter_hits_four_nearest_for_half() -> void:
	var s := _setup()
	var w: Node = s[1]
	w.damage = 20.0
	var primary := _enemy(Vector2(1100.0, 1000.0))
	var near: Array = []
	for off in [Vector2(20, 0), Vector2(0, 28), Vector2(-34, 0), Vector2(0, -40), Vector2(50, 10)]:
		near.append(_enemy(primary.global_position + off))
	var far := _enemy(primary.global_position + Vector2(75.0, 0.0))
	w._deal_beam_tick(primary)
	var tick: float = float(primary.hits[0])
	for i in range(3):
		assert((near[i] as FakeEnemy).hits.size() == 1, "yakın %d saçılma aldı" % i)
		assert(absf(float((near[i] as FakeEnemy).hits[0]) - tick * 0.5) < 0.01, "yarım hasar: %s / %s" % [str(near[i].hits), tick])
	assert((near[3] as FakeEnemy).hits.is_empty() and (near[4] as FakeEnemy).hits.is_empty(), "en çok 3 düşman (4. ve 5. en yakın almaz)")
	assert(far.hits.is_empty(), "60 px dışındaki almaz")
	## finalde ışının deldiği ek hedef saçılmadan ayrıca almaz (zaten tam hasar alıyor)
	for e in near:
		(e as FakeEnemy).hits.clear()
	w._beam_extra_targets = [near[0]]
	w._deal_beam_tick(primary)
	assert((near[0] as FakeEnemy).hits.is_empty(), "delinen saçılma almaz")
	assert((near[3] as FakeEnemy).hits.size() == 1 and (near[4] as FakeEnemy).hits.is_empty(), "yerine sıradaki en yakın alır (en çok 3)")
	_cleanup()


## madde 551 efekt: finalde halka takımı gönderilişte + her vuruşta; renkler farklı ve ardışık üçlü değil; bırakışta incelip kendini siler.
func test_final_rings_and_release() -> void:
	var fx: Node = _track(BeamScene.instantiate())
	var origin := _enemy(Vector2(0.0, 0.0))
	var target := _enemy(Vector2(100.0, 0.0))
	fx.setup(origin, target)
	fx.set_end(Vector2(330.0, 0.0), true)
	fx.set_launch(true)
	fx._process(0.016)
	assert(fx._ring_sets.size() == 1, "gönderilişte ilk halka takımı")
	fx.play_tick([target.global_position])
	assert(fx._ring_sets.size() == 2, "vuruşta yeni takım")
	for i in range(60):
		var cols: Array = fx._ring_colors()
		var idx: Array = []
		for c in cols:
			idx.append(fx.RING_RB.find(c))
		assert(idx.size() == 3 and not idx.has(-1) and idx[0] != idx[1] and idx[1] != idx[2] and idx[0] != idx[2], "3 farklı renk")
		for a in range(6):
			assert(not (idx.has(a) and idx.has((a + 1) % 6) and idx.has((a + 2) % 6)), "ardışık üçlü değil: %s" % str(idx))
	fx.release()
	assert(fx._releasing and is_instance_valid(fx), "final bırakışta hemen silinmez")
	for i in range(20):
		fx._process(0.02)
	assert(fx.is_queued_for_deletion(), "bırakış bitince silinir")
	## temel ışın bırakışta hemen gider
	var fx2: Node = _track(BeamScene.instantiate())
	fx2.setup(origin, target)
	fx2.release()
	assert(fx2.is_queued_for_deletion(), "temel ışın hemen silinir")
	_cleanup()


func test_three_second_hold_dazzles_and_switching_resets() -> void:
	var s := _setup()
	var w: Node = s[1]
	var a := _enemy(Vector2(1100.0, 990.0))
	var b := _enemy(Vector2(1100.0, 1040.0))
	_open_beam(w, a)
	var beh: Node = w.enchant_behavior
	assert(beh != null and beh.has_method("beam_glow"), "özellik davranışı kurulu")
	for i in range(5):
		beh.process_extra(0.5)
	assert(a.elements.is_empty(), "2,5 sn: henüz kamaşmadı")
	assert(absf(beh.beam_glow(a) - 2.5 / 3.0) < 0.01, "ışın tuttukça parlar")
	## hedef değişir -> a'nın sayacı sıfırlanır
	w._beam_hit = b ## ışın artık o an DEĞDİĞİ yaratığı sayar (_beam_hit; madde 549 ek 3)
	beh.process_extra(0.5)
	w._beam_hit = a
	for i in range(5):
		beh.process_extra(0.5)
	assert(a.elements.is_empty(), "hedef değişince süre sıfırdan başlar")
	beh.process_extra(0.5)
	assert(a.elements.size() == 1 and a.elements[0][0] == "stun" and is_equal_approx(float(a.elements[0][1]["dur"]), 1.5), "3 sn -> 1,5 sn kamaşma: %s" % str(a.elements))
	assert(beh.beam_glow(a) >= 2.0, "kamaşma sürerken ışın en parlak")
	beh.process_extra(1.0)
	assert(a.elements.size() == 1, "kamaşma bitene kadar sayılmaz")
	_cleanup()


func test_boss_is_weakened_not_stunned_and_upgrades_apply() -> void:
	var s := _setup({"id": "goz_kamastiran", "ups": [0, 2, 3]})
	var w: Node = s[1]
	var boss := _enemy(Vector2(1100.0, 990.0))
	boss.is_boss = true
	var near := _enemy(Vector2(1130.0, 990.0))
	_open_beam(w, boss)
	var beh: Node = w.enchant_behavior
	beh.process_extra(2.0) ## Hızlı Kamaşma: 2 sn yeter
	var kinds: Array = boss.elements.map(func(x): return x[0])
	assert(kinds == ["weaken"], "boss kamaşmaz, zayıflar: %s" % str(kinds))
	assert(is_equal_approx(float(boss.elements[0][1]["pct"]), 0.2), "%20 az hasar")
	var nk: Array = near.elements.map(func(x): return x[0])
	assert(nk.has("stun") and nk.has("vuln"), "Işık Saçılması + Kör Nokta yakındakine: %s" % str(nk))
	assert(near.hits.size() == 1, "Işık Saçılması hasarı")
	_cleanup()


func test_weakened_enemy_deals_less_damage() -> void:
	_prev_scene = get_tree().current_scene
	NetworkManager.is_multiplayer_active = false
	var e: Node = _track(EnemyScene.instantiate())
	assert(is_equal_approx(Enemy.damage_mult_of(e), 1.0), "normalde tam hasar")
	e.apply_element_host("weaken", {"pct": 0.2, "dur": 3.0}, 0)
	assert(is_equal_approx(Enemy.damage_mult_of(e), 0.8), "zayıflatılmış: %80")
	assert(is_equal_approx(Enemy.damage_mult_of(null), 1.0), "kaynaksız hasar etkilenmez")
	_cleanup()


## ---------- madde 549 ek 3: ışın NAMLUNUN yönünde (Yıldırım + Gökkuşağı) ----------
## Savurmada (ikon hedefe dönmemişken) ışın namlunun baktığı yönde uzanır: yolundaki ilk yaratığa değerse tik anında ona vurur, değmezse
## boşa gider; nişan oturunca (hedefe 6 dereceden yakın) ışın tam hedefe kilitli (eski davranış).
func _aim_barrel(w: Node, angle: float) -> void:
	w.set("_aim_angle", angle)
	w.set("_aim_angle_msec", Time.get_ticks_msec())


func test_beam_follows_the_barrel_while_the_icon_is_still_turning() -> void:
	var s := _setup()
	var w: Node = s[1]
	var origin: Node2D = w.muzzle if w.muzzle else w
	var a: Vector2 = origin.global_position
	var target := _enemy(a + Vector2(120.0, 0.0))
	_aim_barrel(w, PI / 2.0) ## ikon AŞAĞI bakıyor, hedef sağda -> savurma
	var tol: float = deg_to_rad(WeaponFollowMath.AIM_SHOT_TOLERANCE_DEG)
	var dir: Vector2 = Vector2.from_angle(PI / 2.0 - tol) ## namlu yönü hedefe en çok tolerans kadar yaklaşmış
	var blocker := _enemy(a + dir * 80.0)
	w._update_beam_reach(target, origin)
	assert(w._beam_hit == blocker, "savurmada ışın namlunun yönündeki ilk yaratığa vurur, hedefe değil")
	assert(w._beam_end.distance_to(a + dir * 80.0) < 2.0, "ışın o yaratıkta biter: %s" % str(w._beam_end))
	assert(w.beam_targets().is_empty() or w.beam_targets() == [blocker], "kamaşma sayacı ışının değdiğine bakar")
	## hiçbir yaratığa değmiyor: boşa gider, menzil sonunda biter
	blocker.is_dead = true
	w._update_beam_reach(target, origin)
	assert(w._beam_hit == null, "ışın boşta")
	assert(w._beam_end.distance_to(a + dir * w.attack_range) < 2.0, "boşa giden ışın menzil sonuna uzanır: %s" % str(w._beam_end))
	## nişan oturdu (ikon hedefe bakıyor): ışın tam hedefe kilitli, eski davranış
	_aim_barrel(w, 0.0)
	w._update_beam_reach(target, origin)
	assert(w._beam_hit == target and w._beam_end.is_equal_approx(target.global_position), "kilitli: tam hedef")
	## nişan bayatsa (bu karede _update_aim çalışmadı) eski kural: hedefe kilitli
	_aim_barrel(w, PI / 2.0)
	w.set("_aim_angle_msec", -100000)
	w._update_beam_reach(target, origin)
	assert(w._beam_hit == target, "bayat nişan -> hedefe kilitli")
	_cleanup()


func test_beam_tick_hits_whatever_the_ray_touches_and_misses_into_the_air() -> void:
	var s := _setup()
	var w: Node = s[1]
	var origin: Node2D = w.muzzle if w.muzzle else w
	var a: Vector2 = origin.global_position
	## hedef: asanın menzilinde (hedef seçimi karakterin merkezinden ölçer), namlunun baktığı yönün çok dışında -> savurma
	var target := _enemy(w._attack_origin() + Vector2(-60.0, -60.0)) ## menzilde, namluya yakın değil, namlunun (sağ) neredeyse tersinde
	var to_t: float = (target.global_position - a).angle()
	var dir: Vector2 = Vector2.from_angle(deg_to_rad(WeaponFollowMath.AIM_SHOT_TOLERANCE_DEG)) ## ikon sağa bakıyor: hedefe doğru en çok tolerans kadar (aşağı) dönmüş
	## ışının yolundaki "rastgele" yaratık: menzil dışı (hedef seçilmez) ama ışının yolunda
	var passer := _enemy(a + dir * 140.0)
	assert(w._attack_origin().distance_to(target.global_position) < w.attack_range, "test kurulumu: hedef menzilde")
	assert(w._attack_origin().distance_to(passer.global_position) > w.attack_range, "test kurulumu: geçen yaratık hedef seçimi dışı")
	for i in 6: ## savurma: ikon hâlâ sağa bakıyor, her karede nişan taze
		_aim_barrel(w, 0.0)
		w._process_continuous_beam(0.4)
	assert(w._beam_target == target, "nişan hedefi: menzildeki yaratık")
	assert(passer.hits.size() >= 1, "geçen ışın yolundaki yaratığa tik anında vurur: %d" % passer.hits.size())
	assert(target.hits.is_empty(), "hedef ışının dışında: hasar almaz (boşa lazer)")
	assert(w._beam_tip != null and is_instance_valid(w._beam_tip) and w._beam_tip.global_position.distance_to(w._beam_end) < 0.01,
			"ışın ucu taşıyıcısı ışının ucunda")
	## yaratık gidince (öldü) ışın boşa: hasar yok
	passer.is_dead = true
	var before: int = target.hits.size()
	for i in 6:
		_aim_barrel(w, 0.0)
		w._process_continuous_beam(0.4)
	assert(target.hits.size() == before, "boşa giden ışın kimseye vurmaz")
	## ikon hedefe döndü: ışın hedefe kilitlenir, tikler hedefe vurur
	for i in 6:
		_aim_barrel(w, to_t)
		w._process_continuous_beam(0.4)
	assert(target.hits.size() > before, "nişan oturunca ışın hedefe vurur")
	_cleanup()


## Namlu parıltısı + uçtaki saçılma yalnız ışın bir yaratığa değerken görünür (2026-11-12: "hedef değiştirirken boşa lazer atınca bile
## hep aktif görünüyor"); uzak kuklada aynı bilgi ağ alanı "ht" ile gelir (gelmezse eski görünüm: değiyor sayılır).
func test_tip_glow_and_scatter_only_while_the_beam_touches_a_creature() -> void:
	var s := _setup()
	var w: Node = s[1]
	var origin: Node2D = w.muzzle if w.muzzle else w
	var target := _enemy(w._attack_origin() + Vector2(-60.0, -60.0)) ## namlunun (sağ) neredeyse tersinde: ikon dönene kadar ışın boşa gider
	var to_t: float = (target.global_position - origin.global_position).angle()
	_aim_barrel(w, 0.0)
	w._process_continuous_beam(0.1)
	var fx: Node = w._beam_fx
	assert(fx != null and is_instance_valid(fx), "ışın açıldı")
	assert(w._beam_hit == null, "test kurulumu: ışın boşa gidiyor")
	fx._process(0.2)
	assert(not fx._tip.visible and not fx._scatter.visible, "boşa giden ışın: namlu parıltısı + saçılma yok")
	assert(w._beam_net_data(origin)["ht"] == false, "ağ bilgisi: değmiyor")
	## nişan oturdu: ışın hedefe değiyor -> parıltı + saçılma (saçılma yaratığın üstünde)
	_aim_barrel(w, to_t)
	w._process_continuous_beam(0.1)
	assert(w._beam_hit == target, "test kurulumu: ışın hedefe kilitli")
	fx._process(0.2)
	fx._process(0.2)
	assert(fx._tip.visible and fx._tip.modulate.a > 0.99, "değen ışın: namlu parıltısı tam")
	assert(fx._scatter.visible and fx._scatter.global_position.distance_to(target.global_position) < 1.01, "saçılma yaratığın üstünde")
	assert(w._beam_net_data(origin)["ht"] == true, "ağ bilgisi: değiyor")
	## hedef değişirken ikon yine savruldu: parıltı yumuşakça söner
	_aim_barrel(w, 0.0)
	w._process_continuous_beam(0.1)
	assert(w._beam_hit == null, "test kurulumu: ışın yine boşa")
	fx._process(0.04)
	assert(fx._tip.visible and fx._tip.modulate.a < 0.99, "geçiş yumuşak: bir karede tam sönmez")
	fx._process(0.2)
	assert(not fx._tip.visible and not fx._scatter.visible, "boşa giden ışın: parıltı söndü")
	## uzak kukla: "ht" yoksa eski görünüm, varsa uyar
	var old: Node = _track(BeamScene.instantiate())
	old.setup_network(Vector2(200.0, 0.0), {"from_pos": Vector2.ZERO})
	old._process(0.1)
	assert(old._tip.visible, "ağ alanı gelmezse parıltı görünür (eski istemci)")
	var rem: Node = _track(BeamScene.instantiate())
	rem.setup_network(Vector2(200.0, 0.0), {"from_pos": Vector2.ZERO, "ht": false})
	rem._process(0.1)
	assert(not rem._tip.visible and not rem._scatter.visible, "uzak ışın boşa: parıltı yok")
	rem.update_target(Vector2(200.0, 0.0), Vector2.ZERO, {"ht": true})
	rem._process(0.2)
	rem._process(0.2)
	assert(rem._tip.visible and rem._scatter.visible, "uzak ışın değince parıltı açılır")
	_cleanup()


func test_final_beam_pierces_the_line_it_sweeps_along_the_barrel() -> void:
	var s := _setup()
	var w: Node = s[1]
	var origin: Node2D = w.muzzle if w.muzzle else w
	var a: Vector2 = origin.global_position
	var target := _enemy(a + Vector2(120.0, 0.0))
	var dir: Vector2 = Vector2.from_angle(PI / 2.0 - deg_to_rad(WeaponFollowMath.AIM_SHOT_TOLERANCE_DEG))
	var near := _enemy(a + dir * 60.0)
	var far := _enemy(a + dir * 140.0)
	var off := _enemy(a + dir * 100.0 + dir.orthogonal() * 60.0)
	w.set_enchant({"id": "goz_kamastiran", "ups": [0, 1, 2, 3], "final": true})
	_aim_barrel(w, PI / 2.0)
	w._update_beam_reach(target, origin)
	assert(w._beam_hit == near, "final savurma: hattaki en yakın birincil")
	assert(w._beam_extra_targets.has(far) and not w._beam_extra_targets.has(off) and not w._beam_extra_targets.has(target),
			"hattaki diğerleri delinir, hattın dışındakiler (hedef dahil) vurulmaz: %s" % str(w._beam_extra_targets))
	_aim_barrel(w, 0.0)
	w._update_beam_reach(target, origin)
	assert(w._beam_hit == target, "final, nişan oturunca hedefe kilitli")
	_cleanup()
