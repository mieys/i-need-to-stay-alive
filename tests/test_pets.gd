extends Node

## Evcil hayvanlar (kullanıcı isteği 2026-10-12): katalog, menü seçici, oyuncuya kurulum (köpek / papağan + 10 şans), uzak kukla papağan.
## Kelebek Ruhu: +%10 saldırı hızı, İLK silah isabetine lazer atışı (saldırı gücünün %20'si), 4 yön, uzak kukla.
## Peri: can eksikken 6 sn'de bir saldırı gücünün %10'u kadar can, 4 yön + büyü kareleri, uzak kukla.
## Kirpi: saldırgana azami kalkanın %5'i hasar, kalkan varken %5 az hasar, dikenler görüşte yaratık varsa açık, 4 yön x açık/kapalı, uzak kukla.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const PickerScript: GDScript = preload("res://scripts/menu_pet_picker.gd")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")

var _nodes: Array = []
var _saved_pet: String = ""


## Hasar sayan sahte yaratık (enemy.gd take_damage imzası).
class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var taken: Array = []

	func _ready() -> void:
		add_to_group("enemies")

	func take_damage(amount: float, _is_crit: bool = false, _shield_pen: float = 0.0, _is_area: bool = false) -> void:
		taken.append(amount)


func _begin() -> void:
	_saved_pet = GameManager.selected_pet


func _end() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			if n.is_in_group("enemies"):
				n.remove_from_group("enemies") ## queue_free kare sonunda işler; sonraki test eski sahte yaratığı görmesin
			n.queue_free()
	_nodes.clear()
	GameManager.selected_pet = _saved_pet


func _player(pet: String) -> Node:
	GameManager.selected_pet = pet
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_nodes.append(p)
	return p


func test_catalog() -> void:
	_begin()
	assert(PetCatalog.KEYS == ["kopek", "papagan", "kelebek", "peri", "kirpi"] and PetCatalog.DEFAULT_KEY == "kopek", "beş hayvan, varsayılan köpek")
	assert(PetCatalog.LUCK_BONUS == 10.0, "papağan 10 şans")
	GameManager.selected_pet = "bozuk"
	assert(PetCatalog.selected() == "kopek", "geçersiz seçim varsayılana düşmeli")
	GameManager.selected_pet = "papagan"
	assert(PetCatalog.selected() == "papagan")
	for k in PetCatalog.KEYS:
		var ic: Texture2D = PetCatalog.icon(k)
		assert(ic != null, "%s ikonu yüklenmeli" % k)
		assert(ic.get_width() > 4 and ic.get_width() <= 48 and ic.get_height() <= 48, "ikon kırpılmış kare olmalı: %s" % str(ic.get_size()))
		assert(PetCatalog.description(k) != "" and PetCatalog.display_name(k) != "")
	_end()


func test_picker_writes_selection_and_emits() -> void:
	_begin()
	GameManager.selected_pet = ""
	MetaProgressScript.set_unlock_all(true) ## Ruh Mağazası kilitleri bu testin konusu değil (bkz. test_meta_progress.gd)
	var picker: PanelContainer = PickerScript.new()
	add_child(picker)
	_nodes.append(picker)
	picker.setup(false)
	assert(GameManager.selected_pet == "kopek", "açılınca varsayılan köpek yazılmalı")
	var got: Array = []
	picker.picked.connect(func(k: String) -> void: got.append(k))
	picker.select("papagan")
	assert(GameManager.selected_pet == "papagan" and got == ["papagan"], "seçim yazılmalı + sinyal")
	picker.select("yok_boyle")
	assert(GameManager.selected_pet == "kopek", "geçersiz anahtar varsayılan olur")
	MetaProgressScript.set_unlock_all(false)
	_end()


func test_parrot_pet_gives_ten_luck_and_attaches() -> void:
	_begin()
	var base: Node = _player("")
	var base_luck: float = base.luck
	assert(not base.has_node("KorsanParrot") and base._pet_kind == "", "menüden geçilmediyse hayvan yok")
	var p: Node = _player("papagan")
	assert(is_equal_approx(p.luck, base_luck + 10.0), "papağan +10 şans: %f / %f" % [p.luck, base_luck])
	assert(p.has_node("KorsanParrot"), "papağan düğümü kurulmalı")
	p._setup_pet()
	assert(is_equal_approx(p.luck, base_luck + 10.0), "ikinci çağrı şansı tekrar eklememeli")
	_end()


func test_dog_pet_spawns_with_owner_stats() -> void:
	_begin()
	var p: Node = _player("kopek")
	assert(p._pet_kind == "kopek" and not p.has_node("KorsanParrot"), "köpek seçili: papağan yok")
	var base: Node = _player("")
	assert(is_equal_approx(p.luck, base.luck), "köpek şans vermez")
	p._process_pet(0.016)
	assert(p._matthew_pet_alive and is_instance_valid(p._matthew_pet), "köpek ilk karede doğmalı")
	assert(p._matthew_pet.owner_player == p, "köpek sahibine bağlı (statlar sahibinden)")
	assert(p._matthew_pet.is_in_group("player_ally"))
	if is_instance_valid(p._matthew_pet):
		p._matthew_pet.queue_free()
	_end()


func test_remote_parrot_puppet_is_created_on_first_event() -> void:
	_begin()
	var rp: Node = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	add_child(rp)
	_nodes.append(rp)
	assert(not rp.has_node("KorsanParrot"), "başlangıçta kukla papağan yok")
	rp.korsan_parrot_event(0, Vector2.ZERO, 0, 200.0)
	assert(rp.has_node("KorsanParrot"), "ilk olayda kukla papağan kurulmalı")
	_end()


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	add_child(e)
	_nodes.append(e)
	e.global_position = pos
	return e


## İki sahte silah: [0] = ilk silah, [1] = ikinci.
func _fake_weapons(p: Node) -> Array:
	p.owned_weapon_nodes.clear()
	var out: Array = []
	for i in 2:
		var w := Node.new()
		add_child(w)
		_nodes.append(w)
		p.owned_weapon_nodes.append(w)
		out.append(w)
	return out


func test_kelebek_gives_attack_speed_and_attaches() -> void:
	_begin()
	assert(PetCatalog.KELEBEK_ATTACK_SPEED == 0.10 and PetCatalog.KELEBEK_DAMAGE_RATIO == 0.20, "kullanıcı değerleri: %10 hız, %20 hasar")
	var base: Node = _player("")
	var p: Node = _player("kelebek")
	assert(p._pet_kind == "kelebek" and p.has_node("KelebekRuhu") and not p.has_node("KorsanParrot"), "kelebek düğümü kurulmalı")
	assert(is_equal_approx(p.pet_attack_speed, 0.10) and is_equal_approx(base.pet_attack_speed, 0.0))
	assert(is_equal_approx(p._attack_interval_mult_uncapped(), base._attack_interval_mult_uncapped() / 1.1), "atış aralığı /1,1 (+%10 hız; eşyadaki +%10 ile aynı havuz)")
	assert(p.get_attack_speed_bonus_percent() > base.get_attack_speed_bonus_percent(), "stat ekranındaki saldırı hızı artmalı")
	assert(is_equal_approx(p.luck, base.luck), "kelebek şans vermez")
	p._setup_pet()
	assert(is_equal_approx(p.pet_attack_speed, 0.10), "ikinci çağrı tekrar eklememeli")
	_end()


func test_kelebek_shoots_only_for_first_weapon_hits() -> void:
	_begin()
	var p: Node = _player("kelebek")
	var k: Node = p.get_node("KelebekRuhu")
	var ws: Array = _fake_weapons(p)
	var e1: FakeEnemy = _enemy(Vector2(60, 0))
	var e2: FakeEnemy = _enemy(Vector2(0, 60))
	p.evo_weapon_hit(ws[1], e1, 5.0, Vector2.RIGHT)
	assert(k._bolts == 0, "ikinci silahın isabeti atış yaptırmaz")
	p.evo_weapon_hit(ws[0], e1, 5.0, Vector2.RIGHT)
	assert(k._bolts == 1, "ilk silah isabeti: bir atış")
	p.evo_weapon_hit(ws[0], e1, 5.0, Vector2.RIGHT)
	assert(k._bolts == 1, "aynı yaratığa KELEBEK_SHOT_INTERVAL dolmadan ikinci atış yok")
	p.evo_weapon_hit(ws[0], e2, 5.0, Vector2.DOWN)
	assert(k._bolts == 2, "başka yaratık: ayrı atış")
	e2.is_dead = true
	var e3: FakeEnemy = _enemy(Vector2(-60, 0))
	e3.is_dead = true
	p.evo_weapon_hit(ws[0], e3, 5.0, Vector2.LEFT)
	assert(k._bolts == 2, "ölü yaratığa atış yok")
	p.is_dead = true
	var e4: FakeEnemy = _enemy(Vector2(0, -60))
	p.evo_weapon_hit(ws[0], e4, 5.0, Vector2.UP)
	assert(k._bolts == 2, "sahip yerdeyken atış yok")
	assert(e1.taken.is_empty() and e2.taken.is_empty(), "hasar atış VARINCA verilir, isabet anında değil")
	_end()


func test_kelebek_bolt_deals_twenty_percent_attack_power_on_arrival() -> void:
	_begin()
	var p: Node = _player("kelebek")
	var k: Node = p.get_node("KelebekRuhu")
	var ws: Array = _fake_weapons(p)
	p.damage_bonus = 40.0
	var e: FakeEnemy = _enemy(k.global_position + Vector2(80, 0))
	p.evo_weapon_hit(ws[0], e, 5.0, Vector2.RIGHT)
	var bolt: Node = null
	for c in k.get_children():
		if c.has_method("launch"):
			bolt = c
	assert(bolt != null, "atış düğümü kelebeğin çocuğu olmalı")
	bolt._process(0.05)
	assert(e.taken.is_empty(), "yoldayken hasar yok")
	bolt._process(1.0)
	assert(e.taken.size() == 1 and is_equal_approx(e.taken[0], 8.0), "saldırı gücü 40 -> 8 hasar: %s" % str(e.taken))
	bolt._process(1.0)
	assert(e.taken.size() == 1, "kıvılcım karesi tekrar hasar vermez")
	## Görsel sınırı doluyken: atış görseli yok ama hasar yine verilir.
	var e2: FakeEnemy = _enemy(k.global_position + Vector2(0, 80))
	k._bolts = k.MAX_BOLTS
	k.fire_at(e2)
	assert(e2.taken.size() == 1 and is_equal_approx(e2.taken[0], 8.0), "sınır doluyken anında hasar")
	## Yolda ölen yaratık hasar almaz.
	k._bolts = 0
	var e3: FakeEnemy = _enemy(k.global_position + Vector2(-80, 0))
	k.fire_at(e3)
	e3.is_dead = true
	for c in k.get_children():
		if c.has_method("launch"):
			c._process(1.0)
	assert(e3.taken.is_empty(), "varışta ölü olan yaratığa hasar yok")
	_end()


func test_kelebek_has_four_directions() -> void:
	_begin()
	var p: Node = _player("kelebek")
	var k: Node = p.get_node("KelebekRuhu")
	for a in [&"fly_down", &"fly_up", &"fly_side"]:
		assert(k.FRAMES.has_animation(a) and k.FRAMES.get_frame_count(a) == 4 and k.FRAMES.get_animation_loop(a), "%s: 4 karelik döngü" % a)
	k._face("up")
	assert(k._sprite.animation == &"fly_up" and not k._sprite.flip_h)
	k._face("right")
	assert(k._sprite.animation == &"fly_side" and not k._sprite.flip_h, "yan sayfa sağa bakar")
	k._face("left")
	assert(k._sprite.animation == &"fly_side" and k._sprite.flip_h, "sol = yanın aynası")
	k._face("down")
	assert(k._sprite.animation == &"fly_down" and not k._sprite.flip_h)
	_end()


func test_remote_kelebek_puppet_is_created_on_first_event_and_never_deals_damage() -> void:
	_begin()
	var rp: Node = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	add_child(rp)
	_nodes.append(rp)
	assert(not rp.has_node("KelebekRuhu"), "başlangıçta kukla yok")
	rp.kelebek_ruhu_event(Vector2.ZERO, false)
	var k: Node = rp.get_node_or_null("KelebekRuhu")
	assert(k != null and k.is_puppet and k._bolts == 0, "\"buradayım\" olayı kuklayı kurar, atış yok")
	rp.kelebek_ruhu_event(Vector2(90, 0), true)
	assert(k._bolts == 1 and rp.get_node("KelebekRuhu") == k, "atış olayı: görsel atış, ikinci kukla yok")
	var e: FakeEnemy = _enemy(Vector2(90, 0))
	k.fire_at(e)
	k._deal(e)
	assert(k._bolts == 1 and e.taken.is_empty(), "kukla hasar vermez / kendi atış kararı yok")
	_end()


func test_peri_heals_ten_percent_attack_power_every_six_seconds_when_hurt() -> void:
	_begin()
	assert(PetCatalog.PERI_HEAL_INTERVAL == 6.0 and PetCatalog.PERI_HEAL_RATIO == 0.10, "kullanıcı değerleri: 6 sn, %10")
	var p: Node = _player("peri")
	var k: Node = p.get_node_or_null("Peri")
	assert(p._pet_kind == "peri" and k != null and not p.has_node("KelebekRuhu") and not p.has_node("KorsanParrot"), "peri düğümü kurulmalı")
	p.damage_bonus = 50.0
	var want: float = 5.0 * p.heal_power_mult()
	p.health = p.max_health
	k.process_heal(1.0)
	assert(is_equal_approx(p.health, p.max_health) and not k._casting, "can doluyken büyü yok")
	k.process_heal(30.0)
	p.health = p.max_health - 30.0
	k.process_heal(0.016)
	assert(is_equal_approx(p.health, p.max_health - 30.0 + want), "can eksilir eksilmez: saldırı gücü 50 -> 5 can (%f / %f)" % [p.health, p.max_health])
	assert(k._casting and k._sprite.animation == &"cast_down", "büyü karesi oynamalı")
	k.process_heal(5.9)
	assert(is_equal_approx(p.health, p.max_health - 30.0 + want), "6 sn dolmadan ikinci büyü yok")
	k.process_heal(0.2)
	assert(is_equal_approx(p.health, p.max_health - 30.0 + want * 2.0), "6 sn sonra ikinci büyü")
	p.is_dead = true
	k.process_heal(10.0)
	assert(is_equal_approx(p.health, p.max_health - 30.0 + want * 2.0), "sahip yerdeyken/ölüyken can basmaz")
	p.is_dead = false
	p.health = p.max_health - 1.0
	k.process_heal(0.016)
	assert(is_equal_approx(p.health, p.max_health), "can üst sınırı aşmaz")
	_end()


func test_peri_has_four_directions_and_cast_frames() -> void:
	_begin()
	var p: Node = _player("peri")
	var k: Node = p.get_node("Peri")
	for d in ["down", "up", "side"]:
		assert(k.FRAMES.has_animation("fly_" + d) and k.FRAMES.get_frame_count("fly_" + d) == 4 and k.FRAMES.get_animation_loop("fly_" + d), "fly_%s: 4 karelik döngü" % d)
		assert(k.FRAMES.has_animation("cast_" + d) and k.FRAMES.get_frame_count("cast_" + d) == 8 and not k.FRAMES.get_animation_loop("cast_" + d), "cast_%s: 8 kare, tek sefer" % d)
	k._face("up")
	assert(k._sprite.animation == &"fly_up" and not k._sprite.flip_h)
	k._face("left")
	assert(k._sprite.animation == &"fly_side" and k._sprite.flip_h, "sol = yanın aynası")
	k._play_cast()
	k._face("right")
	assert(k._sprite.animation == &"cast_side" and not k._sprite.flip_h, "büyü sırasında yön değişince büyü karesi korunur")
	var fx: Node = p.get_node_or_null("PeriHealFx")
	assert(fx != null and fx._u > 0.0 and fx._head.y < fx._feet.y, "büyüde sahibin üstünde can efekti kurulur (ayaktan başa)")
	assert(fx._from.distance_to(p.to_local(k.global_position)) < 30.0, "efekt perinin asasından çıkar")
	var mid: Vector2 = k.cast_loop_offset(0.5, Vector2(-30, 2))
	assert(k._loop_t == 0.0 and mid.x < -8.0 and absf(mid.y) < 1.0, "büyüde oval tur: yarı yolda sahibe yaklaşır")
	assert(k.cast_loop_offset(0.25, Vector2(-30, 0)).y > 3.0 and k.cast_loop_offset(0.75, Vector2(-30, 0)).y < -3.0, "alttan gider, üstten döner")
	assert(k.cast_loop_offset(0.0, Vector2(-30, 0)) == Vector2.ZERO and k.cast_loop_offset(1.0, Vector2(-30, 0)) == Vector2.ZERO, "tur yerinde biter")
	k._on_animation_finished()
	assert(not k._casting and k._sprite.animation == &"fly_side", "büyü bitince uçuşa döner")
	_end()


func test_remote_peri_puppet_is_created_on_first_event_and_never_heals() -> void:
	_begin()
	var rp: Node = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	add_child(rp)
	_nodes.append(rp)
	assert(not rp.has_node("Peri"), "başlangıçta kukla yok")
	rp.peri_event(false)
	var k: Node = rp.get_node_or_null("Peri")
	assert(k != null and k.is_puppet and not k._casting, "\"buradayım\" olayı kuklayı kurar, büyü yok")
	rp.peri_event(true)
	assert(k._casting and rp.get_node("Peri") == k, "büyü olayı: görsel büyü, ikinci kukla yok")
	assert(rp.has_node("PeriHealFx"), "kuklada da can efekti oynar (MP iki-yer kuralı)")
	k.process_heal(100.0)
	assert(k._cooldown == 0.0, "kukla can basma kararı vermez")
	_end()


func _hit(p: Node, amount: float, src: Node2D) -> float:
	p._last_damage_taken_at_msec = 0 ## temas kilidi sonraki vuruşu yutmasın
	p._shield_combat_timer = 0.0
	p.max_health = 100000.0
	p.health = 100000.0
	var before: float = p.health
	p.take_damage(amount, src)
	return before - p.health


func test_kirpi_reflects_five_percent_of_max_shield_and_cuts_damage_five_percent_while_shielded() -> void:
	_begin()
	assert(PetCatalog.KIRPI_REFLECT_RATIO == 0.05 and PetCatalog.KIRPI_SHIELD_REDUCTION == 0.05, "kullanıcı değerleri: %5 / %5")
	var p: Node = _player("kirpi")
	var k: Node = p.get_node_or_null("Kirpi")
	assert(p._pet_kind == "kirpi" and k != null and not p.has_node("Peri") and not p.has_node("KorsanParrot"), "kirpi düğümü kurulmalı")
	p.damage_taken_mult = 1.0
	p.shield_protection = 0.0 ## kalkan hasar emmesin: sadece %5 azaltma ölçülsün
	p.item_shield_max = 400.0
	p.item_shield_hp = 400.0
	var e: FakeEnemy = _enemy(Vector2(60, 0))
	var loss: float = _hit(p, 100.0, e)
	assert(is_equal_approx(loss, 95.0), "kalkan varken hasar %%5 az: 100 -> 95 (%f)" % loss)
	assert(e.taken.size() == 1 and is_equal_approx(e.taken[0], 20.0), "saldırgan azami kalkanın %%5'i = 20 hasar alır (%s)" % str(e.taken))
	p.item_shield_hp = 0.0
	loss = _hit(p, 100.0, e)
	assert(is_equal_approx(loss, 100.0), "kalkan yokken azalma yok (%f)" % loss)
	assert(e.taken.size() == 2 and is_equal_approx(e.taken[1], 20.0), "yansıma kalkan boşken de sürer (azami kalkan x %5)")
	p.item_shield_max = 0.0
	_hit(p, 50.0, e)
	assert(e.taken.size() == 2, "kalkan gücü yoksa yansıyacak hasar da yok")
	p.item_shield_max = 400.0
	p.item_shield_hp = 400.0
	var dead_e: FakeEnemy = _enemy(Vector2(70, 0))
	dead_e.is_dead = true
	_hit(p, 10.0, dead_e)
	_hit(p, 10.0, null)
	assert(dead_e.taken.is_empty(), "ölü yaratığa / kaynaksız hasarda yansıma yok")
	_end()


func test_other_pets_do_not_reflect_or_reduce() -> void:
	_begin()
	var p: Node = _player("peri")
	p.damage_taken_mult = 1.0
	p.shield_protection = 0.0
	p.item_shield_max = 400.0
	p.item_shield_hp = 400.0
	var e: FakeEnemy = _enemy(Vector2(60, 0))
	var loss: float = _hit(p, 100.0, e)
	assert(is_equal_approx(loss, 100.0) and e.taken.is_empty(), "kirpi seçili değilken etki yok")
	_end()


func test_kirpi_spikes_open_when_owner_sees_enemy_and_close_after_delay() -> void:
	_begin()
	var p: Node = _player("kirpi")
	var k: Node = p.get_node("Kirpi")
	p.global_position = Vector2.ZERO
	assert(not k.is_open() and k.current_clip() == &"kapali_down", "başlangıç: dikenler kapalı")
	k.process_spikes(0.3)
	assert(not k.is_open(), "yaratık yokken kapalı kalır")
	var e: FakeEnemy = _enemy(Vector2(120, 0))
	k.process_spikes(0.3)
	assert(k.is_open(), "sahibin görüşünde yaratık var: hemen açılır")
	k._update_animation()
	assert(String(k.current_clip()).begins_with("acik_"), "açık klip: %s" % k.current_clip())
	e.global_position = Vector2(2000, 0) ## görüş dışı
	k.process_spikes(0.3)
	assert(k.is_open(), "yaratık görüşten çıkınca hemen kapanmaz (titreme koruması)")
	k.process_spikes(0.3)
	k.process_spikes(0.3)
	k.process_spikes(0.3)
	assert(not k.is_open(), "CLOSE_DELAY sonra kapanır")
	var e2: FakeEnemy = _enemy(Vector2(80, 0))
	e2.is_dead = true
	k.process_spikes(0.3)
	assert(not k.is_open(), "ölü yaratık sayılmaz")
	_end()


func test_kirpi_has_four_directions_open_and_closed_and_keeps_frame() -> void:
	_begin()
	var p: Node = _player("kirpi")
	var k: Node = p.get_node("Kirpi")
	for pre in ["acik_", "kapali_"]:
		for d in ["down", "up", "left", "right"]:
			## Duruş: 15 kare (nefes + göz kırpma + burun çekme, kare süreleriyle 4,5 sn); yürüyüş: 4 kare.
			assert(k.FRAMES.has_animation(pre + d) and k.FRAMES.get_frame_count(pre + d) == 15 and k.FRAMES.get_animation_loop(pre + d), "%s%s: 15 karelik duruş döngüsü" % [pre, d])
			var walk: String = pre + "walk_" + d
			assert(k.FRAMES.has_animation(walk) and k.FRAMES.get_frame_count(walk) == 4 and k.FRAMES.get_animation_loop(walk), "%s: 4 karelik döngü" % walk)
	k._dir = "up"
	k._apply_clip()
	k._sprite.set_frame_and_progress(9, 0.3)
	k.set_open(true)
	assert(k._sprite.animation == &"acik_up" and k._sprite.frame == 9, "diken açılırken kare korunur")
	k._moving = true
	k._apply_clip()
	assert(k._sprite.animation == &"acik_walk_up" and k._sprite.frame == 0, "yürürken walk_ klibi baştan başlar (kare sayısı farklı)")
	k._sprite.set_frame_and_progress(2, 0.3)
	k.set_open(false)
	assert(k._sprite.animation == &"kapali_walk_up" and k._sprite.frame == 2, "yürürken diken kapanınca adım korunur")
	k._moving = false
	k._apply_clip()
	assert(k._sprite.animation == &"kapali_up" and k._sprite.frame == 0, "durunca nefes klibine baştan döner")
	assert(k._dir_of(Vector2(5, -2)) == "right" and k._dir_of(Vector2(-5, 2)) == "left" and k._dir_of(Vector2(1, 9)) == "down" and k._dir_of(Vector2(1, -9)) == "up")
	_end()


func test_kirpi_follows_owner_and_warps_when_far() -> void:
	_begin()
	var p: Node = _player("kirpi")
	var k: Node = p.get_node("Kirpi")
	p.global_position = Vector2(1000, 1000)
	k._process_movement(0.016)
	assert(k.global_position.distance_to(p.global_position) < 80.0, "uzaktaki kirpi sahibin yanına atlar (%s)" % str(k.global_position))
	_end()


func test_remote_kirpi_puppet_is_created_on_first_event_and_applies_state_only() -> void:
	_begin()
	var rp: Node = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	add_child(rp)
	_nodes.append(rp)
	assert(not rp.has_node("Kirpi"), "başlangıçta kukla yok")
	rp.kirpi_event(false)
	var k: Node = rp.get_node_or_null("Kirpi")
	assert(k != null and k.is_puppet and not k.is_open(), "\"buradayım\" olayı kuklayı kurar, dikenler kapalı")
	rp.kirpi_event(true)
	assert(k.is_open() and rp.get_node("Kirpi") == k, "açık olayı: dikenler açılır, ikinci kukla yok")
	var e: FakeEnemy = _enemy(Vector2(10, 0))
	k.process_spikes(1.0)
	assert(k.is_open() and e.taken.is_empty(), "kukla kendi diken kararı vermez")
	rp.kirpi_event(false)
	assert(not k.is_open(), "kapalı olayı")
	_end()


## Doğal takip (kullanıcı 2026-10-13): hayvan sahibin hızını kopyalamaz; yakınken durur, uzaklaşınca uzaklığa göre koşar, sahip sabit hızla giderken geride kalır.
func test_pet_follow_ground_is_not_locked_to_owner_speed() -> void:
	var f = load("res://scripts/pet_follow.gd").new()
	var pos := Vector2.ZERO
	var owner_pos := Vector2(20, 0)
	assert(f.ground_velocity(pos, owner_pos, 0.016, 300.0) == Vector2.ZERO, "rahat bölgede durur")
	owner_pos = Vector2(50, 0)
	assert(f.ground_velocity(pos, owner_pos, 0.016, 300.0) == Vector2.ZERO, "başlama yarıçapının içinde (histerezis) hâlâ durur")
	owner_pos = Vector2(200, 0)
	var v: Vector2 = f.ground_velocity(pos, owner_pos, 0.016, 300.0)
	assert(v.x > 100.0 and absf(v.y) < 0.001, "uzaktaki sahibe doğru koşar: %s" % str(v))
	var near: Vector2 = Vector2(45, 0)
	var slow: Vector2 = f.ground_velocity(Vector2.ZERO, near, 0.016, 300.0)
	assert(slow.length() < v.length(), "yaklaştıkça yavaşlar")
	## Sahip sabit 240 px/sn ile gider: hayvan dur-kalk geride kalır, hızı sahibinkine eşit olmaz.
	pos = Vector2.ZERO
	owner_pos = Vector2(100, 0)
	var vel := Vector2.ZERO
	var speeds: Array = []
	for i in 300:
		owner_pos.x += 240.0 * 0.016
		vel = vel.move_toward(f.ground_velocity(pos, owner_pos, 0.016, 400.0), 1100.0 * 0.016)
		pos += vel * 0.016
		if i > 150:
			speeds.append(vel.x)
	var mn: float = speeds.min()
	var mx: float = speeds.max()
	assert(mx - mn > 5.0, "hız sabit değil, dalgalanır (%f..%f)" % [mn, mx])
	var gap: float = owner_pos.x - pos.x
	assert(gap > 60.0 and gap < 160.0, "koşan sahibin geride kalır ama kopmaz (%f)" % gap)


func test_pet_follow_air_spring_lags_then_settles() -> void:
	var f = load("res://scripts/pet_follow.gd").new()
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var dest := Vector2.ZERO
	var last_gap: float = 0.0
	for i in 200:
		dest.x += 240.0 * 0.016
		var st: Array = f.spring_step(pos, vel, dest, 0.016)
		pos = st[0]
		vel = st[1]
		last_gap = dest.x - pos.x
	assert(last_gap > 20.0 and last_gap < 120.0, "koşan sahibin gerisinde süzülür (%f)" % last_gap)
	for i in 300:
		var st2: Array = f.spring_step(pos, vel, dest, 0.016)
		pos = st2[0]
		vel = st2[1]
	assert(pos.distance_to(dest) < 0.5 and vel.length() < 0.5, "sahip durunca hedefe oturur")
