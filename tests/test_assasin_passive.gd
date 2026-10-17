extends Node

## Assasin Çocuk pasifi "Bıçak Uzmanlığı" (kullanıcı bildirimi 2026-10-08: "assasin çocuğun pasifi çalışmıyor"): yetenek kullanımından sonraki
## 3 saniye boyunca garantili kritik. KÖK NEDEN: pasif hiç uygulanmamıştı (sadece characters.gd açıklama metni). + Q (Şahin Hamlesi) yük başı
## bekleme 8 sn. Gerçek Player + sahte yaratıklarla (bkz. test_assasin_evolutions.gd düzeni).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ASSASIN := 5


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var crits: Array = []

	func take_damage(_amount: float, is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		crits.append(is_crit)


var _spawned: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = ASSASIN
	GameManager.selected_character = int(Characters.DEFS[ASSASIN]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	p.item_shield_max = 1000.0
	p.item_shield_hp = 1000.0
	## Taban %5 yetenek kritiği de sıfırlansın: kritik SADECE pasiften gelsin.
	p.crit_chance_bonus = -p.ABILITY_BASE_CRIT_CHANCE
	return p


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene


func test_passive_is_off_until_a_skill_is_used_then_lasts_three_seconds() -> void:
	var p := _make_player()
	assert(not p.assasin_guaranteed_crit_active(), "yetenek kullanılmadan pasif kapalı")
	assert(not p._roll_ability_crit(), "kritik şansı sıfırken yetenek kritiği çıkmamalı (pasif kapalı)")
	p._assasin_passive_on_skill_used()
	assert(p.assasin_guaranteed_crit_active() and p._roll_ability_crit(), "yetenekten sonra kesin kritik")
	p._process_assasin_dash2_charges(2.9)
	assert(p.assasin_guaranteed_crit_active(), "2,9 sn sonra hâlâ aktif")
	p._process_assasin_dash2_charges(0.2)
	assert(not p.assasin_guaranteed_crit_active(), "3 sn dolunca biter")
	assert(not p._roll_ability_crit(), "bitince yetenek kritiği geri normale")
	_cleanup()


## Her yetenek kullanımı (Q hamle, E, R) sayacı kurar; yeni kullanım süreyi yeniler.
func test_every_skill_use_arms_the_passive_and_refreshes_it() -> void:
	var p := _make_player()
	assert(p.assasin_dash2_charges == 2)
	p._try_assasin_dash2()
	assert(p.assasin_guaranteed_crit_active(), "Q (Şahin Hamlesi) pasifi tetiklemeli")
	p._process_assasin_dash2_charges(2.5)
	p._try_assasin_dash2()
	p._process_assasin_dash2_charges(0.6)
	assert(p.assasin_guaranteed_crit_active(), "ikinci kullanım süreyi yenilemeli (2,5 + 0,6 > 3 olsa da aktif)")
	p._assasin_crit_timer = 0.0
	p._activate_skill2()
	assert(p.skill2_state == "active" and p.assasin_guaranteed_crit_active(), "E (Gölge Adımı) pasifi tetiklemeli")
	p._assasin_crit_timer = 0.0
	var target := FakeEnemy.new()
	target.add_to_group("enemies")
	add_child(target)
	_spawned.append(target)
	target.global_position = Vector2(1100.0, 1000.0)
	p._activate_skill3()
	assert(p.skill3_state == "active" and p.assasin_guaranteed_crit_active(),
		"R (Gölge Hücumu) pasifi tetiklemeli: durum=%s sayaç=%s kalkan=%s" % [p.skill3_state, p._assasin_crit_timer, p.item_shield_hp])
	_cleanup()


## Silah vuruşları da kesin kritik (weapon.gd _passive_guaranteed_crit) - gerçek silah, pasif açıkken %0 kritik şansıyla bile.
func test_weapon_hits_are_guaranteed_crits_while_the_passive_is_active() -> void:
	var p := _make_player()
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	GameManager.owned_weapons = [{"key": "dagger", "level": 1}]
	assert(p.buy_weapon_copy("dagger", 1), "silah verilemedi")
	var w: Node = p.owned_weapon_nodes[0]
	w.crit_chance = 0.0
	assert(not w._passive_guaranteed_crit(), "pasif kapalıyken silah kritik zorlamaz")
	p._assasin_passive_on_skill_used()
	assert(w._passive_guaranteed_crit(), "pasif açıkken silah vuruşu kesin kritik")
	p._process_assasin_dash2_charges(3.1)
	assert(not w._passive_guaranteed_crit(), "süre bitince kapanır")
	GameManager.owned_weapons = []
	_cleanup()


## UÇTAN UCA: Şimşek Asası'nın gerçek ışın tiki (weapon.gd _deal_beam_tick) %0 kritik şansıyla bile, pasif açıkken KRİTİK vurur; kapalıyken vurmaz.
func test_real_beam_tick_crits_only_while_the_passive_is_active() -> void:
	var p := _make_player()
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	GameManager.owned_weapons = [{"key": "lightning_staff", "level": 1}]
	assert(p.buy_weapon_copy("lightning_staff", 1), "silah verilemedi")
	var w: Node = p.owned_weapon_nodes[0]
	w.crit_chance = 0.0
	var target := FakeEnemy.new()
	target.add_to_group("enemies")
	add_child(target)
	_spawned.append(target)
	target.global_position = Vector2(1100.0, 1000.0)
	for i in range(20):
		w._deal_beam_tick(target)
	assert(target.crits.size() == 20 and not target.crits.has(true), "pasif kapalı + %0 şans: hiç kritik yok: %s" % str(target.crits))
	target.crits.clear()
	p._assasin_passive_on_skill_used()
	for i in range(20):
		w._deal_beam_tick(target)
	assert(target.crits.size() == 20 and not target.crits.has(false), "pasif açık: her tik kritik: %s" % str(target.crits))
	GameManager.owned_weapons = []
	_cleanup()


## Assasin olmayan karakterde pasif hiçbir şey yapmaz.
func test_non_assasin_never_gets_guaranteed_crits() -> void:
	var p := _make_player()
	GameManager.selected_character = 1 ## Oakley'nin yeteneği
	p._assasin_passive_on_skill_used()
	assert(not p.assasin_guaranteed_crit_active(), "Assasin olmayan oyuncuda pasif yok")
	_cleanup()


func test_q_hamle_recharge_is_eight_seconds_per_charge() -> void:
	var p := _make_player()
	assert(is_equal_approx(p.ASSASIN_DASH2_RECHARGE_TIME, 8.0), "yük başı 8 sn")
	p._try_assasin_dash2()
	assert(p.assasin_dash2_charges == 1 and is_equal_approx(p._assasin_dash2_recharge_timer, 8.0), "yük harcanınca 8 sn'lik dolum başlar")
	p._process_assasin_dash2_charges(7.9)
	assert(p.assasin_dash2_charges == 1, "7,9 sn'de yük gelmez")
	p._process_assasin_dash2_charges(0.2)
	assert(p.assasin_dash2_charges == 2, "8 sn'de yük geri gelir")
	assert(String(Characters.DEFS[ASSASIN]["skill_desc"]).contains("8sn"), "açıklama 8sn demeli")
	_cleanup()


## Pasif GÖRSELİ (kullanıcı isteği 2026-10-16: "pasifin varlığı hiç belli olmuyor"): tetiklenince gövdeye TEK "AssasinPassiveFx"
## düğümü (kırmızı dış hat kopyası + tetiklenme parlaması) eklenir, yeni kullanım ikinci düğüm açmadan süreyi yeniler, süre
## dolunca silinir; Assasin olmayan oyuncuda görsel de yok.
func test_passive_visual_follows_the_crit_window() -> void:
	const OutlineShader: Shader = preload("res://shaders/assasin_passive_outline.gdshader")
	var p := _make_player()
	assert(p.get_node_or_null("AssasinPassiveFx") == null, "yetenek kullanılmadan görsel yok")
	p._assasin_passive_on_skill_used()
	var fx: Node = p.get_node_or_null("AssasinPassiveFx")
	assert(fx != null, "pasif tetiklenince görsel düğümü eklenmeli")
	var has_outline: bool = false
	var procs: int = 0
	for c: Node in fx.get_children():
		if c is Sprite2D and (c as Sprite2D).material is ShaderMaterial and ((c as Sprite2D).material as ShaderMaterial).shader == OutlineShader:
			has_outline = (c as Sprite2D).texture != null
		elif c is AnimatedSprite2D:
			procs += 1
	assert(has_outline, "dış hat kopyası karakterin karesini almalı")
	assert(procs == 1, "tetiklenme parlaması oynamalı: %d" % procs)
	fx._process(2.5)
	p._assasin_passive_on_skill_used()
	var count: int = 0
	for c: Node in p.get_children():
		if String(c.name).begins_with("AssasinPassiveFx"):
			count += 1
	assert(count == 1 and is_equal_approx(float(fx.call("time_left")), p.ASSASIN_PASSIVE_CRIT_DURATION),
		"yeniden kullanım aynı düğümü yenilemeli: düğüm=%d kalan=%.2f" % [count, float(fx.call("time_left"))])
	fx._process(p.ASSASIN_PASSIVE_CRIT_DURATION + 0.05)
	assert(fx.is_queued_for_deletion(), "süre dolunca görsel silinmeli")
	_cleanup()
	var other := _make_player()
	GameManager.selected_character = 1
	other._assasin_passive_on_skill_used()
	assert(other.get_node_or_null("AssasinPassiveFx") == null, "Assasin olmayan oyuncuda pasif görseli yok")
	_cleanup()
