extends Node

## Yeni evciller (madde 509, kullanıcı isteği 2026-11-09):
## Minik Cadı (iyi slime): +%5 saldırı gücü; ulti kullanınca (bekleme 90 sn; ilk sürüm 120) büyü -> 8 sn can/hasar(saldırı gücü)/boy/menzil +%15, menzil çizgisi.
## Hayalet (yarı opak): +%5 sıvışma; can %25 altına düşünce (bekleme 80 sn) 8 sn görünmez + dokunulmaz (yaratık hedeflemez, hasar/CC işlemez).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const PetCatalog := preload("res://scripts/pet_catalog.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const SlimeRangeRingScript := preload("res://scripts/slime_range_ring.gd")

var _nodes: Array = []
var _saved_pet: String = ""


## Menzil çarpanını kaydeden sahte silah (weapon.gd set_pet_range_mult / attack_range sözleşmesi).
class FakeWeapon extends Node2D:
	var attack_range: float = 200.0
	var pet_mult: float = 1.0

	func set_pet_range_mult(m: float) -> void:
		pet_mult = m
		attack_range = 200.0 * m


func _begin() -> void:
	_saved_pet = GameManager.selected_pet


func _end() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	GameManager.selected_pet = _saved_pet


func _player(pet: String) -> Node:
	GameManager.selected_pet = pet
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_nodes.append(p)
	return p


func _remote() -> Node:
	var rp: Node = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	add_child(rp)
	_nodes.append(rp)
	return rp


func test_catalog_has_new_pets_with_user_values() -> void:
	_begin()
	for k in ["slime", "hayalet"]:
		assert(PetCatalog.is_valid(k) and PetCatalog.icon(k) != null, "%s: katalogda + ikon" % k)
		assert(PetCatalog.description(k) != "" and PetCatalog.display_name(k) != "", "%s: ad + açıklama" % k)
		assert(MetaProgressScript.COSTS[MetaProgressScript.PET].has(k), "%s: Ruh Mağazası fiyatı (kilitli)" % k)
	assert(PetCatalog.display_name("slime") == "Minik Cadı")
	assert(PetCatalog.SLIME_AP_PERCENT == 0.05 and PetCatalog.SLIME_BUFF_PERCENT == 0.15 and PetCatalog.SLIME_BUFF_TIME == 8.0 \
		and PetCatalog.SLIME_COOLDOWN == 90.0, "kullanıcı değerleri: %5 saldırı gücü, 8 sn %15, 90 sn (madde 513)")
	assert(PetCatalog.HAYALET_DODGE == 0.05 and PetCatalog.HAYALET_HP_THRESHOLD == 0.25 and PetCatalog.HAYALET_COVER_TIME == 8.0 \
		and PetCatalog.HAYALET_COOLDOWN == 80.0, "kullanıcı değerleri: %5 sıvışma, %25 can, 8 sn, 80 sn (madde 513)")
	_end()


func test_slime_gives_five_percent_attack_power_and_attaches() -> void:
	_begin()
	var p: Node = _player("slime")
	var s: Node = p.get_node_or_null("Slime")
	assert(p._pet_kind == "slime" and s != null and not p.has_node("Hayalet"), "slime düğümü kurulmalı")
	assert(is_equal_approx(p.pet_ap_percent, 0.05), "+%5 saldırı gücü payı")
	p.damage_bonus = 100.0 + p._ap_pct_applied
	p._refresh_item_ap_percent()
	var base: float = p.damage_bonus - p._ap_pct_applied
	assert(is_equal_approx(p.damage_bonus, base * (1.0 + p.item_ap_percent + 0.05)), "saldırı gücü %%5 artar (%f)" % p.damage_bonus)
	var other: Node = _player("kirpi")
	assert(other.pet_ap_percent == 0.0, "diğer evciller saldırı gücü vermez")
	_end()


func test_slime_ult_casts_and_buffs_owner_for_eight_seconds() -> void:
	_begin()
	var p: Node = _player("slime")
	var s: Node = p.get_node("Slime")
	var w := FakeWeapon.new()
	p.add_child(w)
	p.owned_weapon_nodes.append(w)
	p.max_health = 200.0
	p.health = 100.0
	var anim_scale0: Vector2 = p.anim.scale
	p._pet_on_ult_used()
	assert(s.is_casting() and String(s.current_clip()).begins_with("cast_"), "ulti -> kulak parlama klibi")
	assert(is_equal_approx(s.cooldown_left(), 90.0) and is_equal_approx(s.cooldown_fraction(), 1.0), "90 sn bekleme başlar")
	assert(not p.slime_buff_active(), "büyü kare 4'te çıkar (hemen değil)")
	for i in range(5): ## _process deltayı 0,1 sn ile sınırlar
		s._process(0.1)
	assert(p.slime_buff_active(), "büyü sahibine ulaştı")
	assert(p.has_node("SlimeSpellFx"), "sahibin üstünde pembe büyü efekti kurulur")
	assert(is_equal_approx(p.max_health, 230.0) and is_equal_approx(p.health, 130.0), "azami can +%%15, mevcut cana da eklenir (%f / %f)" % [p.health, p.max_health])
	assert(is_equal_approx(p.pet_ap_percent, 0.20), "saldırı gücü (hasar) +%15 (kalıcı %5'in üstüne)")
	assert(is_equal_approx(w.pet_mult, 1.15) and is_equal_approx(w.attack_range, 230.0), "menzil +%15")
	assert(p.anim.scale.is_equal_approx(anim_scale0 * 1.15) and is_equal_approx(p.get_pet_size_mult(), 1.15), "boy +%15")
	var ring: Node = p.get_node_or_null("SlimeRangeRing")
	assert(ring != null and not ring.is_ending(), "menzil ince çizgiyle görünür")
	assert(is_equal_approx(SlimeRangeRingScript.max_weapon_range(p), 230.0), "çizgi en geniş silah menzilinde")
	assert(p.get_status_effects().any(func(e: Dictionary) -> bool: return e["kind"] == "slime_buyu"), "buff rozeti")
	## bekleme dolmadan ikinci ulti: büyü yok
	s._casting = false
	assert(not s.on_owner_ult(), "90 sn dolmadan büyü yok")
	p._process_pet_buffs(7.9)
	assert(p.slime_buff_active(), "8 sn dolmadan sürer")
	p._process_pet_buffs(0.2)
	assert(not p.slime_buff_active() and is_equal_approx(p.max_health, 200.0) and is_equal_approx(p.health, 130.0), "bitince azami can geri, mevcut can tavanda")
	assert(is_equal_approx(p.pet_ap_percent, 0.05) and is_equal_approx(w.pet_mult, 1.0), "saldırı gücü/menzil geri")
	assert(p.anim.scale.is_equal_approx(anim_scale0) and ring.is_ending(), "boy geri, çizgi söner")
	s.process_cooldown(90.0)
	assert(s.on_owner_ult(), "bekleme dolunca yeniden")
	_end()


func test_slime_buff_survives_form_scale_reset() -> void:
	_begin()
	var p: Node = _player("slime")
	var base: Vector2 = p.char_base_anim_scale
	p.apply_slime_buff()
	p._end_skill_effects() ## her yetenek bitişinde anim.scale = taban yazılır
	assert(p.anim.scale.is_equal_approx(base * 1.15), "genel ölçek sıfırlaması boyu silmez")
	p._end_slime_buff()
	assert(p.anim.scale.is_equal_approx(base) and p.char_base_anim_scale.is_equal_approx(base), "taban hiç değişmedi")
	_end()


func test_slime_does_not_cast_when_frozen_or_down() -> void:
	_begin()
	var p: Node = _player("slime")
	var s: Node = p.get_node("Slime")
	p.is_downed = true
	assert(not s.on_owner_ult(), "sahip yerdeyken büyü yok")
	p.is_downed = false
	p.is_in_merchant_zone = true
	assert(not s.on_owner_ult(), "güvenli alanda evcil çalışmaz (madde 327)")
	s._cooldown = 50.0
	s.process_cooldown(10.0)
	assert(is_equal_approx(s.cooldown_left(), 50.0), "güvenli alanda bekleme donar")
	p.is_in_merchant_zone = false
	_end()


func test_slime_frames_four_directions() -> void:
	_begin()
	var p: Node = _player("slime")
	var f: SpriteFrames = p.get_node("Slime").FRAMES
	for d in ["down", "left", "right", "up"]:
		assert(f.get_frame_count("idle_" + d) == 3 and f.get_animation_loop("idle_" + d), "idle_%s: kullanıcının 3 karesi" % d)
		assert(f.get_frame_count("hop_" + d) == 6 and f.get_animation_loop("hop_" + d), "hop_%s: kullanıcının 6 karesi" % d)
		assert(f.get_frame_count("cast_" + d) == 8 and not f.get_animation_loop("cast_" + d), "cast_%s: 8 kare, tek sefer" % d)
	_end()


func test_remote_slime_puppet_casts_visual_only() -> void:
	_begin()
	var rp: Node = _remote()
	assert(not rp.has_node("Slime"))
	rp.slime_event(false)
	var s: Node = rp.get_node_or_null("Slime")
	assert(s != null and s.is_puppet and not s.is_casting(), "\"buradayım\" kuklayı kurar")
	rp.slime_event(true)
	assert(s.is_casting() and rp.get_node("Slime") == s, "büyü olayı: görsel büyü, ikinci kukla yok")
	for i in range(5): ## _process deltayı 0,1 sn ile sınırlar
		s._process(0.1)
	assert(rp.has_node("SlimeSpellFx"), "kuklada da büyü efekti (MP iki-yer kuralı)")
	assert(s.cooldown_left() == 0.0, "kukla bekleme/buff kararı vermez")
	var sc0: Vector2 = rp.anim.scale
	rp._apply_pet_size(1.15)
	assert(rp.anim.scale.is_equal_approx(sc0 * 1.15), "boy ağdan (extra psz) uygulanır")
	rp._apply_pet_size(1.0)
	assert(rp.anim.scale.is_equal_approx(sc0), "boy geri")
	_end()


## Madde 523: buff süresince karakterde görünen pembe dış hat + yükselen oklar (slime_buff_fx.gd), iki ekranda, küre varınca başlar.
func test_slime_buff_look_on_owner_and_puppet() -> void:
	_begin()
	var p: Node = _player("slime")
	var s: Node = p.get_node("Slime")
	p._pet_on_ult_used()
	for i in range(5):
		s._process(0.1)
	assert(p.slime_buff_active())
	var spell: Node = p.get_node("SlimeSpellFx")
	spell._process(0.2)
	assert(not p.has_node("SlimeBuffFx"), "küre uçarken karakter henüz değişmez")
	spell._process(0.25)
	var aura: Node = p.get_node_or_null("SlimeBuffFx")
	assert(aura != null and not aura.is_ending(), "küre göğse varınca buff görünüşü başlar")
	aura._process(0.016)
	var want: Texture2D = p.anim.sprite_frames.get_frame_texture(p.anim.animation, p.anim.frame)
	assert(aura.outline_texture() == want, "dış hat karakterin o anki karesinden")
	assert(aura.motes_alive() > 0, "varışta yükselen ok demeti")
	assert(absf(aura.time_left() - p._slime_buff_timer) < 0.001, "sahibinde süre buffın kendisinden")
	p.set_pet_cover_fade(0.45)
	aura._process(0.016)
	assert(is_equal_approx(aura.modulate.a, 0.45), "karakterin saydamlığını izler (çalı / Hayalet örtüsü: yer belli olmasın)")
	p.set_pet_cover_fade(1.0)
	p._process_pet_buffs(8.0)
	assert(not p.slime_buff_active())
	aura._process(0.05)
	assert(aura.is_ending() and not p.has_node("SlimeBuffFx"), "buff bitince söner (yeni büyüye ad boşalır)")
	for i in range(4):
		aura._process(0.1)
	assert(aura.is_queued_for_deletion(), "sönme bitince silinir")
	## kukla: aynı görünüş, kendi sayacıyla
	var rp: Node = _remote()
	rp.slime_event(true)
	var rs: Node = rp.get_node("Slime")
	for i in range(5):
		rs._process(0.1)
	rp.get_node("SlimeSpellFx")._process(0.45)
	var ra: Node = rp.get_node_or_null("SlimeBuffFx")
	assert(ra != null and absf(ra.time_left() - (PetCatalog.SLIME_BUFF_TIME - 0.42)) < 0.01, "kuklada da (MP iki-yer kuralı), süre büyüden")
	for i in range(74): ## 7,4 sn < 7,58
		ra._process(0.1)
	assert(not ra.is_ending(), "süre dolmadan sürer")
	for i in range(3):
		ra._process(0.1)
	assert(ra.is_ending(), "kuklada süre dolunca söner")
	_end()


func test_hayalet_gives_dodge_and_is_semi_opaque() -> void:
	_begin()
	var base: Node = _player("kirpi")
	var p: Node = _player("hayalet")
	var g: Node = p.get_node_or_null("Hayalet")
	assert(p._pet_kind == "hayalet" and g != null, "hayalet düğümü kurulmalı")
	assert(is_equal_approx(p.dodge_chance - base.dodge_chance, 0.05), "+%5 sıvışma")
	assert(g.sprite_alpha() > 0.4 and g.sprite_alpha() < 0.8, "yarı opak (%f)" % g.sprite_alpha())
	_end()


func test_hayalet_covers_owner_below_quarter_health() -> void:
	_begin()
	var p: Node = _player("hayalet")
	var g: Node = p.get_node("Hayalet")
	p.max_health = 200.0
	p.health = 60.0
	assert(not g.check_low_health() and not p.ghost_cover_active(), "%30 canda kaplamaz")
	p.health = 45.0
	assert(g.check_low_health(), "%25 altında kaplar")
	assert(p.ghost_cover_active() and p.is_invisible_now() and p.is_ghost_now(), "görünmez + yaratıkların içinden geçer")
	assert(g.is_covering() and is_equal_approx(g.cooldown_left(), 80.0), "kaplama görseli + 80 sn bekleme")
	assert(String(g.current_clip()) == "move_right", "önce sahibine uçar")
	g._process(0.2)
	assert(String(g.current_clip()) == "cover_in" and g.global_position.distance_to(g.cover_global()) < 1.0, "sahibin üstünde küçük bir noktadan açılır")
	g._on_animation_finished()
	assert(String(g.current_clip()) == "cover" and g.is_covering(), "büyük hayalet sahibini kaplar")
	## madde 513: sahip yürürken örtü doğal hâlindeki gibi gidiş yönüne eğilir, sola aynalanır, durunca öne döner
	for i in range(20):
		p.global_position += Vector2(3.0, 0.0) ## 0,016 sn'de 3 px = 187 px/sn sağa
		g._process(0.016)
	assert(g.cover_leaning() and String(g.current_clip()) == "cover_move_right" and not g._sprite.flip_h, "sağa giderken sağa eğilir")
	for i in range(20):
		p.global_position += Vector2(-3.0, 0.0)
		g._process(0.016)
	assert(String(g.current_clip()) == "cover_move_right" and g._sprite.flip_h, "sola dönünce aynalanır")
	var fr: int = g._sprite.frame
	for i in range(40):
		g._process(0.016)
	assert(not g.cover_leaning() and String(g.current_clip()) == "cover" and not g._sprite.flip_h, "durunca öne döner (%d)" % fr)
	## madde 515: örtü boyunca karakterin kendisi de soluklaşır, çalı saydamlığıyla çarpılır
	assert(is_equal_approx(p.get_pet_cover_fade(), g.CHAR_FADE) and is_equal_approx(p.anim.self_modulate.a, g.CHAR_FADE), 		"örtüde karakter soluk (%f)" % p.anim.self_modulate.a)
	p.set_brush_state(1) ## saklı (0,7)
	assert(is_equal_approx(p.anim.self_modulate.a, 0.7 * g.CHAR_FADE), "çalıda: 0,7 x örtü solukluğu (%f)" % p.anim.self_modulate.a)
	p.set_brush_state(0)
	assert(is_equal_approx(p.anim.self_modulate.a, g.CHAR_FADE), "çalıdan çıkınca örtü solukluğu kalır")
	assert(g.sprite_alpha() < 1.0, "kaplarken de yarı opak")
	p._last_damage_taken_at_msec = 0
	p.take_damage(30.0, null)
	assert(is_equal_approx(p.health, 45.0), "dokunulmaz: hasar işlemez")
	p.apply_stun(2.0)
	assert(not p.is_stunned, "dokunulmaz: sersemlemez")
	p.apply_knockback_force(Vector2.RIGHT, 300.0)
	assert(p._knockback_velocity == Vector2.ZERO, "dokunulmaz: itilmez")
	assert(p.get_status_effects().any(func(e: Dictionary) -> bool: return e["kind"] == "hayalet_ortu"), "buff rozeti")
	p._process_pet_buffs(7.9)
	assert(p.ghost_cover_active(), "8 sn dolmadan sürer")
	p._process_pet_buffs(0.2)
	assert(not p.ghost_cover_active() and not p.is_invisible_now(), "8 sn sonra biter")
	g.process_guard(0.016)
	assert(not g.is_covering() and String(g.current_clip()).begins_with("cover_out"), "örtü kıvrılıp küçülerek kaybolur")
	for i in range(30):
		g._process(0.016)
	assert(is_equal_approx(p.anim.self_modulate.a, 1.0) and is_equal_approx(p.get_pet_cover_fade(), 1.0), "örtü kalkınca karakter yine tam görünür")
	assert(not g.check_low_health(), "80 sn dolmadan yeniden kaplamaz")
	g.process_guard(80.0)
	assert(p.ghost_cover_active(), "bekleme dolunca (can hâlâ düşük) yeniden kaplar")
	_end()


func test_hayalet_triggers_in_the_same_hit_that_drops_health() -> void:
	_begin()
	var p: Node = _player("hayalet")
	p.max_health = 200.0
	p.health = 60.0
	p.dodge_chance = 0.0
	p.item_shield_hp = 0.0
	p.item_shield_max = 0.0
	p._last_damage_taken_at_msec = 0
	p.take_damage(20.0, null)
	assert(p.health < 50.0 and p.ghost_cover_active(), "canı %%25 altına düşüren vuruşla hemen kaplar (%f)" % p.health)
	var hp: float = p.health
	p._last_damage_taken_at_msec = 0
	p.take_damage(20.0, null)
	assert(is_equal_approx(p.health, hp), "aynı karedeki sonraki vuruş engellenir")
	_end()


func test_hayalet_frames() -> void:
	_begin()
	var p: Node = _player("hayalet")
	var f: SpriteFrames = p.get_node("Hayalet").FRAMES
	for a in ["idle", "move_right", "cry", "cover", "cover_move_right"]:
		assert(f.has_animation(a) and f.get_animation_loop(a), "%s döngü" % a)
	for a in ["vanish", "appear", "cover_in", "cover_out"]:
		assert(f.has_animation(a) and not f.get_animation_loop(a), "%s tek sefer" % a)
	var small: Vector2 = f.get_frame_texture("idle", 0).get_size()
	var big: Vector2 = f.get_frame_texture("cover", 0).get_size()
	assert(big == small * 2.0, "kaplayan hayalet 2 kat (aynı piksel boyu, Scale2x)")
	_end()


func test_remote_hayalet_puppet_cover_visual_only() -> void:
	_begin()
	var rp: Node = _remote()
	rp.hayalet_event(false)
	var g: Node = rp.get_node_or_null("Hayalet")
	assert(g != null and g.is_puppet and not g.is_covering(), "\"buradayım\" kuklayı kurar")
	rp.hayalet_event(true)
	assert(g.is_covering() and rp.get_node("Hayalet") == g, "kaplama olayı: görsel, ikinci kukla yok")
	for i in range(30):
		g._process(0.016)
	assert(rp.get_pet_cover_fade() < 0.5 and rp.anim.self_modulate.a < 0.5, "kuklada da karakter soluklaşır (%f)" % rp.anim.self_modulate.a)
	rp.hayalet_event(false)
	assert(not g.is_covering(), "bitti olayı: örtü dağılır")
	assert(g.cooldown_left() == 0.0, "kukla tetik kararı vermez")
	_end()
