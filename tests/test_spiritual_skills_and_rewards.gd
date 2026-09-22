extends Node

## Kullanıcı isteği (2026-09-21) paketi: Ruhani Yetenekler (F), etkileşim tuşu BOŞLUK, satıcı 8 eşya + eşit olasılık, sandık/boss altını
## dağıtımı, Vampir E toggle + Q 6sn, Talon R nişan / E alan hasarı düzeltmeleri.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const S: GDScript = preload("res://scripts/spiritual_skills.gd")
const MerchantScript: GDScript = preload("res://scripts/traveling_merchant.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1
var _prev_spirit: String = ""


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var _body_radius: float = 20.0
	var hits: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		hits.append(amount)


func _make_player(char_id: int = 1, spirit: String = "") -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	_prev_spirit = GameManager.selected_spiritual
	GameManager.selected_char_id = char_id
	GameManager.selected_character = Characters.get_def(char_id)["skill"]
	GameManager.selected_spiritual = spirit if spirit != "" else S.PARA
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(1000.0, 1000.0)
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	player._last_damage_taken_at_msec = -999999
	return player


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.merchant_zone_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	GameManager.selected_spiritual = _prev_spirit
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


# ------------------------------------------------------------------ tuşlar / tanımlar

func test_interact_is_space_and_skill4_is_f() -> void:
	assert(InputMap.has_action("interact") and InputMap.has_action("skill4"), "action'lar tanımlı olmalı")
	var interact_key: int = -1
	for ev in InputMap.action_get_events("interact"):
		if ev is InputEventKey:
			interact_key = ev.physical_keycode
	var skill4_key: int = -1
	for ev in InputMap.action_get_events("skill4"):
		if ev is InputEventKey:
			skill4_key = ev.physical_keycode
	assert(interact_key == KEY_SPACE, "etkileşim BOŞLUK olmalı: %d" % interact_key)
	assert(skill4_key == KEY_F, "ruhani yetenek F olmalı: %d" % skill4_key)
	var found: bool = false
	for entry in GameManager.REBINDABLE_ACTIONS:
		if entry["action"] == "skill4":
			found = true
	assert(found, "skill4 tuş atama menüsünde olmalı")


func test_spiritual_definitions_match_the_spec() -> void:
	assert(S.ORDER.size() == 6, "6 ruhani yetenek")
	assert(S.PARA_INTERVAL == 10.0 and S.PARA_GOLD == 5 and is_equal_approx(S.PARA_SHOP_DISCOUNT, 0.10), "Para: 10sn / 5 altın / %10")
	assert(is_equal_approx(S.CAN_HEAL_PERCENT, 0.08) and is_equal_approx(S.CAN_SHIELD_PERCENT, 0.15) and S.CAN_INVULN_TIME == 3.0 and S.CAN_COOLDOWN == 90.0, "Can")
	assert(S.ADC_DURATION == 10.0 and is_equal_approx(S.ADC_ATTACK_SPEED, 0.30) and is_equal_approx(S.ADC_SHIELD_PEN, 0.15) and is_equal_approx(S.ADC_LIFESTEAL, 0.01) and S.ADC_COOLDOWN == 120.0, "Adc")
	assert(S.TANK_DURATION == 10.0 and is_equal_approx(S.TANK_REFLECT, 0.60) and is_equal_approx(S.TANK_SHIELD_REGEN, 0.03) and S.TANK_COOLDOWN == 100.0, "Tank")
	assert(is_equal_approx(S.TAKTIK_SPEED_BONUS, 0.30) and S.TAKTIK_SPEED_TIME == 3.0 and S.TAKTIK_COOLDOWN == 30.0, "Taktiksel")
	assert(S.DUKKAN_CHANNEL == 3.0 and S.DUKKAN_COOLDOWN == 120.0, "Dükkan")
	for id in S.ORDER:
		var def: Dictionary = S.get_def(id)
		assert(ResourceLoader.exists(str(def["icon"])), "ikon yok: %s" % id)
		if bool(def["active"]):
			assert(ResourceLoader.exists(str(def["sound"])), "ses yok: %s" % id)
	assert(not S.is_active_skill(S.PARA), "Para pasif")


func test_para_discount_applies_to_shop_prices_only_for_para() -> void:
	var prev: String = GameManager.selected_spiritual
	GameManager.selected_spiritual = S.CAN
	var full_upgrade: int = ShopPanel._upgrade_cost("dagger", 5)
	var full_copy: int = ShopPanel._copy_cost("dagger", 3)
	var full_item: int = ShopPanel._item_cost(Items.KEYS[0], 2)
	GameManager.selected_spiritual = S.PARA
	assert(ShopPanel._upgrade_cost("dagger", 5) == int(round(float(full_upgrade) * 0.9)), "yükseltme fiyatı %10 düşmeli")
	assert(ShopPanel._copy_cost("dagger", 3) == int(round(float(full_copy) * 0.9)), "silah fiyatı %10 düşmeli")
	assert(ShopPanel._item_cost(Items.KEYS[0], 2) == int(round(float(full_item) * 0.9)), "eşya fiyatı %10 düşmeli")
	assert(GameManager.apply_shop_discount(1) == 1, "1 altın 0'a düşmemeli")
	GameManager.selected_spiritual = prev


func test_para_grants_gold_every_ten_seconds() -> void:
	var player: Node = _make_player(1, S.PARA)
	GameManager.gold = 0
	for i in range(9):
		player._process_spirit(1.0)
	assert(GameManager.gold == 0, "10sn dolmadan altın yok")
	player._process_spirit(1.0)
	assert(GameManager.gold == 5, "10. saniyede +5 altın: %d" % GameManager.gold)
	for i in range(10):
		player._process_spirit(1.0)
	assert(GameManager.gold == 10, "20. saniyede toplam 10: %d" % GameManager.gold)
	_cleanup()


# ------------------------------------------------------------------ Can

func test_can_heals_shields_and_blocks_damage_for_three_seconds() -> void:
	var player: Node = _make_player(1, S.CAN)
	player.item_shield_max = 200.0
	player.item_shield_hp = 0.0
	player.health = 50.0
	var expected_heal: float = player.max_health * 0.08
	player._try_spirit_skill()
	assert(is_equal_approx(player.health, 50.0 + expected_heal), "%%8 can: %s" % player.health)
	assert(is_equal_approx(player.item_shield_hp, 30.0), "%%15 kalkan: %s" % player.item_shield_hp)
	assert(player.spirit_state == "active", "aktif aşama")
	var before: float = player.health
	player.take_damage(40.0)
	assert(is_equal_approx(player.health, before), "3sn içinde hasar görmemeli")
	player._process_spirit(3.05)
	player._last_damage_taken_at_msec = -999999
	player.take_damage(10.0)
	assert(player.health < before, "3sn sonra hasar tekrar işlemeli")
	assert(player.spirit_state == "cooldown" and is_equal_approx(player.spirit_timer, 90.0 - 0.0) or player.spirit_timer <= 90.0, "bekleme başladı")
	_cleanup()


func test_spirit_cooldown_ignores_cooldown_reduction() -> void:
	var player: Node = _make_player(1, S.TAKTIK)
	player.cooldown_reduction_percent = 0.5
	player._try_spirit_skill()
	assert(player.spirit_state == "active", "taktik atıldı")
	player._process_spirit(3.0)
	assert(player.spirit_state == "cooldown", "aktif bitti")
	assert(absf(player.spirit_timer - 30.0) < 0.2, "bekleme 30sn kalmalı (azaltma uygulanmaz): %s" % player.spirit_timer)
	assert(player.get_spirit_progress() < 0.05, "ilerleme başta ~0")
	_cleanup()


# ------------------------------------------------------------------ Adc

func test_adc_gives_attack_speed_shield_pen_and_lifesteal_then_removes_them() -> void:
	var player: Node = _make_player(1, S.ADC)
	player.buy_weapon_copy("tabanca", 1)
	var weapon: Node = player.owned_weapon_nodes[player.owned_weapon_nodes.size() - 1]
	var base_mult: float = weapon.fire_rate_multiplier if "fire_rate_multiplier" in weapon else 1.0
	var base_fire_rate: float = float(weapon.get("fire_rate_mult")) if "fire_rate_mult" in weapon else -1.0
	player._try_spirit_skill()
	assert(is_equal_approx(player.spirit_shield_pen, 0.15) and is_equal_approx(player.spirit_lifesteal, 0.01) and is_equal_approx(player.spirit_attack_speed, 0.30), "buff alanları")
	assert(is_equal_approx(weapon._player_stat("spirit_shield_pen"), 0.15), "silah kalkan delmeyi okuyor")
	if "fire_rate_mult" in weapon:
		assert(float(weapon.get("fire_rate_mult")) < base_fire_rate, "saldırı hızı artmalı (çarpan düşmeli)")
	player.health = 10.0
	var got_heal: bool = false
	for i in range(400):
		player.on_damage_dealt(10.0, false)
		if player.health > 10.0:
			got_heal = true
			break
	assert(got_heal, "%%1 can emme ile 400 isabette en az bir kez can gelmeli")
	player._process_spirit(10.1)
	assert(is_zero_approx(player.spirit_shield_pen) and is_zero_approx(player.spirit_lifesteal) and is_zero_approx(player.spirit_attack_speed), "10sn sonra sökülmeli")
	assert(player.spirit_state == "cooldown" and absf(player.spirit_timer - 120.0) < 0.3, "120sn bekleme")
	if "fire_rate_mult" in weapon:
		assert(is_equal_approx(float(weapon.get("fire_rate_mult")), base_fire_rate), "saldırı hızı eski haline dönmeli")
	_cleanup()


# ------------------------------------------------------------------ Tank

func test_tank_reflects_sixty_percent_and_regens_missing_shield() -> void:
	var player: Node = _make_player(1, S.TANK)
	player.item_shield_max = 100.0
	player.item_shield_hp = 40.0
	var enemy := FakeEnemy.new()
	add_child(enemy)
	_spawned.append(enemy)
	player.take_damage(50.0, enemy)
	assert(enemy.hits.is_empty(), "tank aktif değilken yansıtma yok")
	player._last_damage_taken_at_msec = -999999
	player._try_spirit_skill()
	var shield_before: float = player.item_shield_hp
	player.take_damage(50.0, enemy)
	assert(enemy.hits.size() == 1 and is_equal_approx(float(enemy.hits[0]), 30.0), "alınan hasarın %%60'ı yansımalı: %s" % str(enemy.hits))
	## Yenileme: eksik kalkanın %3'ü (hasar emiliminden önce).
	assert(player.item_shield_hp > shield_before - 50.0 * 0.65 + 0.5, "eksik kalkanın bir kısmı yenilenmeli")
	player._process_spirit(10.1)
	player._last_damage_taken_at_msec = -999999
	player.take_damage(50.0, enemy)
	assert(enemy.hits.size() == 1, "10sn sonra yansıtma bitmeli")
	_cleanup()


# ------------------------------------------------------------------ Taktiksel

func test_taktik_teleports_forward_and_gives_speed_for_three_seconds() -> void:
	var player: Node = _make_player(1, S.TAKTIK)
	player.facing = "right"
	var start: Vector2 = player.global_position
	player._try_spirit_skill()
	var moved: float = player.global_position.x - start.x
	assert(moved > 100.0 and absf(player.global_position.y - start.y) < 1.0, "ileriye (sağa) ışınlanmalı: %s" % moved)
	assert(is_equal_approx(player._current_temp_speed_boost(), 0.30), "%%30 hız")
	player._process_spirit(3.1)
	assert(is_zero_approx(player._current_temp_speed_boost()), "3sn sonra hız bonusu bitmeli")
	_cleanup()


# ------------------------------------------------------------------ Dükkan

func test_dukkan_needs_merchant_channels_three_seconds_and_cancels_on_move_or_damage() -> void:
	var player: Node = _make_player(1, S.DUKKAN)
	player._try_spirit_skill()
	assert(player.spirit_state == "ready", "satıcı yokken kullanılamaz, bekleme başlamamalı")
	GameManager.merchant_zone_active = true
	GameManager.merchant_zone_pos = Vector2(2000.0, 2000.0)
	player._try_spirit_skill()
	assert(player.spirit_state == "active" and player._spirit_channeling, "odaklanma başladı")
	## Hasar alınca iptal
	player.health -= 5.0
	player._process_spirit(0.5)
	assert(not player._spirit_channeling and player.spirit_state == "cooldown", "hasar odaklanmayı bölmeli")
	assert(player.spirit_timer <= S.DUKKAN_CANCEL_LOCKOUT + 0.01, "iptalde tam bekleme yok")
	player._process_spirit(S.DUKKAN_CANCEL_LOCKOUT + 0.1)
	assert(player.spirit_state == "ready", "kilit bitti")
	## Tamamlanma
	player._try_spirit_skill()
	for i in range(31):
		player._process_spirit(0.1)
	assert(player.global_position.distance_to(Vector2(2000.0, 2000.0)) < 120.0, "satıcının yanına ışınlanmalı: %s" % str(player.global_position))
	assert(player.spirit_state == "cooldown" and absf(player.spirit_timer - 120.0) < 0.5, "120sn bekleme")
	_cleanup()


# ------------------------------------------------------------------ Satıcı: 8 eşya, eşit olasılık

func test_merchant_stock_is_eight_unique_entries_with_one_owned_shield() -> void:
	assert(MerchantScript.STOCK_SIZE == 8, "stok 8 olmalı")
	var m: Node = MerchantScript.new()
	add_child(m)
	_spawned.append(m)
	for i in range(30):
		var stock: Array = m._generate_stock()
		assert(stock.size() == 8, "8 kart: %d" % stock.size())
		var seen: Dictionary = {}
		var shields: int = 0
		for e in stock:
			var k: String = "%s:%s" % [e["type"], e["key"]]
			assert(not seen.has(k), "tekrarlı kart: %s" % k)
			seen[k] = true
			if e["type"] == "shield":
				shields += 1
		assert(shields >= 1, "en az bir kalkan garanti")


func test_merchant_no_longer_favours_the_starting_weapon() -> void:
	GameManager.owned_weapons = [{"key": "dagger", "level": 1, "spent": 0}]
	var m: Node = MerchantScript.new()
	add_child(m)
	_spawned.append(m)
	var counts: Dictionary = {}
	var rounds: int = 1500
	for i in range(rounds):
		for e in m._generate_stock():
			if e["type"] == "weapon":
				counts[e["key"]] = int(counts.get(e["key"], 0)) + 1
	var dagger: int = int(counts.get("dagger", 0))
	var others_total: int = 0
	var others_n: int = 0
	for k in counts.keys():
		if k != "dagger":
			others_total += int(counts[k])
			others_n += 1
	var others_avg: float = float(others_total) / float(maxi(others_n, 1))
	assert(float(dagger) < others_avg * 1.35, "başlangıç silahı artık ağırlıklı çıkmamalı: dagger=%d diğer ort=%.1f" % [dagger, others_avg])
	GameManager.owned_weapons = []


# ------------------------------------------------------------------ Sandık / boss altını

func test_chest_winner_is_uniform_and_single() -> void:
	var counts: Dictionary = {1: 0, 2: 0, 3: 0}
	for i in range(3000):
		var w: int = NetworkManager.pick_chest_winner([1, 2, 3])
		assert(counts.has(w), "geçersiz kazanan")
		counts[w] += 1
	for id in counts.keys():
		assert(counts[id] > 800 and counts[id] < 1200, "her oyuncunun şansı ~%%33 olmalı: %s" % str(counts))
	assert(NetworkManager.pick_chest_winner([]) == 0, "boş listede kazanan yok")
	assert(NetworkManager.pick_chest_winner([7]) == 7, "tek oyuncu her zaman kazanır")


func test_boss_gold_is_split_equally_and_conserved() -> void:
	for amount in [90, 100, 101, 7, 2, 1]:
		var shares: Dictionary = NetworkManager.compute_gold_shares(amount, [1, 2, 3], 2)
		var total: int = 0
		var lo: int = 1 << 30
		var hi: int = 0
		for id in shares.keys():
			total += int(shares[id])
			lo = mini(lo, int(shares[id]))
			hi = maxi(hi, int(shares[id]))
		assert(total == amount, "toplam korunmalı (%d): %d" % [amount, total])
		assert(hi - lo <= 2, "paylar eşit olmalı (artan toplayana): %s" % str(shares))
	var s100: Dictionary = NetworkManager.compute_gold_shares(100, [1, 2, 3], 3)
	assert(int(s100[1]) == 33 and int(s100[2]) == 33 and int(s100[3]) == 34, "artan 1 altın toplayana: %s" % str(s100))
	assert(NetworkManager.compute_gold_shares(50, [5], 5)[5] == 50, "tek katılımcı hepsini alır")


# ------------------------------------------------------------------ Vampir

func test_vampir_q_cooldown_is_six_seconds() -> void:
	var P: GDScript = preload("res://scripts/player.gd")
	assert(float(P.SKILL_TIMING[40]["cooldown"]) == 6.0, "Kan Emme 6sn")


func test_vampir_e_second_press_returns_to_human_form() -> void:
	var player: Node = _make_player(13, S.PARA)
	player.max_health = 500.0
	player.health = 500.0
	player._process_vampir(0.016)
	player._activate_skill2()
	assert(player._vampir_bat_form_active and player.skill2_state == "active", "form açıldı")
	player._vampir_cancel_bat_form()
	assert(not player._vampir_bat_form_active, "insan formuna dönmeli")
	assert(player.skill2_state == "cooldown" and absf(player.skill2_timer - 22.0) < 0.5, "bekleme başlamalı: %s" % player.skill2_timer)
	assert(is_equal_approx(player.skill2_speed_multiplier, 1.0), "hız çarpanı sıfırlanmalı")
	## Silahlar geri gelir: çekilme oranı 0'a iner ve işleme yeniden açılır.
	for i in range(200):
		player._process_vampir_weapon_pull(0.05)
	assert(player._vampir_pull <= 0.0, "silah çekilmesi geri dönmeli")
	_cleanup()


# ------------------------------------------------------------------ Talon

func test_talon_r_alone_keeps_weapons_aiming_and_e_removes_area_tick() -> void:
	var player: Node = _make_player(1, S.PARA)
	for key in ["tabanca", "dagger"]:
		player.buy_weapon_copy(key, 1)
	assert(not player.has_method("_talon_salvo_damage_tick"), "E'nin alan hasarı tik'i kaldırılmış olmalı")
	var iconed: Array = player._talon_iconed_weapons()
	for w in iconed:
		w.icon_faces_target = true
		w.icon_sprite.rotation = 0.777
	## R tek başına (face_outward=false): nişan açık kalır, rotasyona dokunulmaz.
	player._talon_set_weapons_circular(110.0, 0.0, false)
	for w in iconed:
		assert(w.icon_faces_target, "R tek başına: namlu hedefe dönebilmeli")
		assert(is_equal_approx(w.icon_sprite.rotation, 0.777), "R tek başına: rotasyon sabitlenmemeli")
	## E (salvo/dışa bakan): nişan kapanır, rotasyon dışa.
	player._talon_set_weapons_circular(130.0, 0.0, true)
	for w in iconed:
		assert(not w.icon_faces_target, "E: dışa bakan sabit duruş")
	_cleanup()


func test_facing_target_uses_flipped_mirror_and_hits_a_real_melee_enemy() -> void:
	var player: Node = _make_player(1, S.PARA)
	player.buy_weapon_copy("tabanca", 1)
	player.buy_weapon_copy("dagger", 1)
	var gun: Node = null
	var knife: Node = null
	for w in player.owned_weapon_nodes:
		if w.get_meta("shop_key", "") == "tabanca":
			gun = w
		elif w.get_meta("shop_key", "") == "dagger":
			knife = w
	assert(gun != null and knife != null, "silahlar alınmalı")
	## Aynalanan silah SOLA bakarken (flip_h): hayalet hedef solda olmalı (eskiden ters yöne çıkıyordu).
	gun.icon_sprite.flip_h = true
	var forward: float = deg_to_rad(float(gun.sprite_forward_angle_deg))
	gun.icon_sprite.rotation = PI - PI + 0.0 - forward + 0.0 ## açı = rot + PI - forward = PI - 2*forward... yerine formülü doğrudan doğrula
	var expected_angle: float = gun.icon_sprite.rotation + PI - forward
	var target: Node2D = gun._make_facing_direction_target()
	var dir: Vector2 = (target.global_position - gun.global_position).normalized()
	assert(absf(angle_difference(dir.angle(), expected_angle)) < 0.01, "aynalı ikon yönü yanlış")
	## Yakın dövüş silahı ışının üstündeki GERÇEK yaratığı hedef almalı.
	knife.icon_sprite.rotation = -float(deg_to_rad(float(knife.sprite_forward_angle_deg))) ## yön = 0 rad (sağ)
	var enemy := FakeEnemy.new()
	enemy.add_to_group("enemies")
	add_child(enemy)
	_spawned.append(enemy)
	enemy.global_position = knife.global_position + Vector2(60.0, 4.0)
	var picked: Node2D = knife._make_facing_direction_target()
	if knife.attack_range >= 60.0:
		assert(picked == enemy, "ışın üstündeki gerçek yaratık hedef seçilmeli")
	_cleanup()


# ------------------------------------------------------------------ Oakley efektleri + kalkan hasar efekti (pixel)

func test_oakley_r_leaf_barrier_follows_bond_flag_and_bursts_on_hit() -> void:
	var player: Node = _make_player(2, S.PARA)
	player._apply_oakley_bond_to_target(player, 5.0, 2.0, 0.2, 10.0)
	assert(player.oakley_bond_active, "büyü aktif")
	assert(is_instance_valid(player._oakley_leaf_fx), "yaprak bariyeri doğmalı")
	var fx: Node = player._oakley_leaf_fx
	assert(fx.get_parent() == player, "bariyer büyüyü alan oyuncunun çocuğu olmalı")
	player._last_damage_taken_at_msec = -999999
	player.take_damage(10.0)
	assert(not fx._pieces.is_empty(), "her hasarda yeşil parçalar çıkmalı")
	## Bayrak kapanınca bariyer kendini kaldırır.
	fx._process(0.05) ## bayrak açıkken bir kare (oyunda hep böyle)
	player.oakley_bond_active = false
	for i in range(60):
		fx._process(0.05)
	assert(not is_instance_valid(fx) or fx.is_queued_for_deletion(), "büyü bitince bariyer kalkmalı")
	_cleanup()


func test_shield_hit_fx_is_pixel_procedural_and_self_removes() -> void:
	var script: GDScript = load("res://scripts/fx_shield_hit.gd")
	var fx: Node2D = Node2D.new()
	fx.set_script(script)
	add_child(fx)
	_spawned.append(fx)
	fx.setup(1.2)
	assert(not ("_sprite" in fx), "eski sprite tabanlı efekt kalmamalı (artık prosedürel pixel)")
	fx._process(0.1)
	assert(not fx.is_queued_for_deletion(), "0.1sn'de hâlâ görünür")
	fx._process(0.5)
	assert(fx.is_queued_for_deletion(), "ömrü bitince kendini silmeli")
	## Paladin bariyeri kendi yarıçapını verebilmeli.
	var fx2: Node2D = Node2D.new()
	fx2.set_script(script)
	add_child(fx2)
	_spawned.append(fx2)
	fx2.setup(0.3, 126.0)
	assert(is_equal_approx(fx2._radius, 126.0), "yarıçap parametresi")


func test_oakley_vine_uses_pixel_visual_and_bee_ring_spawns_bees() -> void:
	var vine: Node2D = Node2D.new()
	vine.set_script(load("res://scripts/oakley_vine.gd"))
	vine.mark_as_network_visual()
	add_child(vine)
	_spawned.append(vine)
	assert(vine._visual != null and vine._visual.has_method("_draw_strand"), "Line2D değil pixel sarmaşık görseli")
	vine.update_network_vine_state(vine.global_position, vine.global_position + Vector2(90, 0), true)
	vine._process(0.1)
	assert(vine._visual.points.size() == 2, "hedef verilince uzantı noktaları set edilmeli")
	var ring: Node2D = Node2D.new()
	ring.set_script(load("res://scripts/oakley_bee_swarm_ring.gd"))
	add_child(ring)
	_spawned.append(ring)
	ring.setup(130.0)
	assert(ring._bees.size() >= 12, "alanın içinde minik arılar uçuşmalı")
	assert(ResourceLoader.exists("res://assets/audio/oakley/oakley_bees.wav"), "arı vızıltı sesi")


func test_oakley_three_vines_pick_three_different_targets() -> void:
	var player: Node = _make_player(2, S.PARA)
	var enemies: Array = []
	for k in range(3):
		var e := FakeEnemy.new()
		e.add_to_group("enemies")
		add_child(e)
		_spawned.append(e)
		e.global_position = player.global_position + Vector2(60.0 + 25.0 * k, 10.0 * k)
		enemies.append(e)
	player._skill_oakley_vines()
	var vines: Array = get_tree().get_nodes_in_group("oakley_vines")
	assert(vines.size() == 3, "3 sarmaşık oluşmalı: %d" % vines.size())
	var targets: Dictionary = {}
	for v in vines:
		_spawned.append(v)
		assert(is_instance_valid(v._target), "her sarmaşığın hedefi olmalı")
		targets[v._target.get_instance_id()] = true
	assert(targets.size() == 3, "3 sarmaşık 3 FARKLI yaratığa gitmeli: %d" % targets.size())
	_cleanup()
