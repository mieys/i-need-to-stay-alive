extends Node

## Şovalye R izometrik kubbe (2026-10-14, madde 160): elips alan (paladin_dome.gd), iki katmanlı kubbe görseli (fx_paladin_barrier.gd),
## kubbe boyunca kollar açık parlayan bariyer_<yön> klibi + havada süzülme/titreme (player.gd / remote_player.gd).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const DomeScript: GDScript = preload("res://scripts/paladin_dome.gd")
const BarrierScript: GDScript = preload("res://scripts/fx_paladin_barrier.gd")
const SOVALYE := 7
const TALON := 1


## Başka bir oyuncunun açtığı Şovalye kubbesi (uzak kukla taklidi).
class FakeKnight extends Node2D:
	var is_dead: bool = false
	var paladin_zone_active: bool = true
	var paladin_zone_radius: float = 126.0

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 0


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _make_knight() -> Node:
	return _make_char(SOVALYE)


func _make_char(char_id: int) -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = char_id
	GameManager.selected_character = int(Characters.DEFS[char_id]["skill"])
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(3000.0, 3000.0)
	player.item_shield_max = 1000.0
	player.item_shield_hp = 1000.0
	return player


func test_zone_is_a_2_to_1_ellipse_at_prototype_size() -> void:
	var r: float = 126.0
	var rr: Vector2 = DomeScript.radii(r)
	assert(rr.is_equal_approx(Vector2(126.0, 63.0)), "prototip boyutu: yatay 126, dikey 63: %s" % str(rr))
	assert(is_equal_approx(rr.y / rr.x, 0.5), "2:1 izometrik")
	assert(is_equal_approx(DomeScript.radius_along(r, Vector2.RIGHT), rr.x), "yatay kenar")
	assert(is_equal_approx(DomeScript.radius_along(r, Vector2(0.0, -3.0)), rr.y), "dikey kenar (birim olmayan yön)")
	var c := Vector2(50.0, -20.0)
	assert(DomeScript.contains(c, r, c), "merkez içeride")
	assert(DomeScript.contains(c, r, c + Vector2(120.0, 0.0)) and not DomeScript.contains(c, r, c + Vector2(132.0, 0.0)), "yatay sınır")
	assert(DomeScript.contains(c, r, c + Vector2(0.0, 58.0)) and not DomeScript.contains(c, r, c + Vector2(0.0, 68.0)), "dikey sınır")
	assert(DomeScript.contains(c, r, c + Vector2(0.0, 68.0), 10.0), "pay eklenince")
	var diag: Vector2 = DomeScript.edge_offset(r, 0.7)
	assert(is_equal_approx((diag.x / rr.x) * (diag.x / rr.x) + (diag.y / rr.y) * (diag.y / rr.y), 1.0), "kenar noktası elipste")


func test_levitate_offset_lifts_on_whole_pixels_and_trembles() -> void:
	var seen_x: Dictionary = {}
	for i in range(60):
		var o: Vector2 = DomeScript.levitate_offset(float(i) * 0.031)
		assert(o.x == roundf(o.x) and o.y == roundf(o.y), "tam piksel: %s" % str(o))
		assert(o.y <= -6.0 and o.y >= -14.0, "yerden 7-13 piksel yukarıda (uçuyormuş gibi): %s" % str(o))
		assert(absf(o.x) <= 1.0, "titreme 1 piksel")
		seen_x[o.x] = true
	assert(seen_x.size() >= 3, "titreme sağa-sola gider: %s" % str(seen_x.keys()))
	var lo: float = INF
	var hi: float = -INF
	for i in range(120):
		var y: float = DomeScript.levitate_offset(float(i) * 0.02).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	assert(hi - lo >= 5.0, "belirgin yukarı-aşağı süzülme: %f..%f" % [lo, hi])


func test_knight_frames_have_the_glowing_arms_open_clip() -> void:
	var frames: SpriteFrames = load(String(Characters.DEFS[SOVALYE]["frames"]))
	for d in ["down", "left", "right", "up"]:
		var a: String = DomeScript.ANIM_PREFIX + d
		assert(frames.has_animation(a), "%s klibi yok" % a)
		assert(frames.get_animation_loop(a), "%s döngüde" % a)
		assert(frames.get_frame_count(a) == 6, "%s 6 karelik nabız" % a)
		assert(frames.get_frame_texture(a, 0).get_size() == Vector2(48, 48), "48x48 kare")


func test_barrier_builds_floor_back_front_layers_and_gold_stays_flat() -> void:
	var holder := Node2D.new()
	holder.scale = Vector2(0.5, 0.5)
	add_child(holder)
	_spawned.append(holder)
	var b: Node2D = BarrierScript.new()
	b.set("muffle_outside_sound", false)
	holder.add_child(b)
	var iso: Node2D = b.get_node_or_null("IsoDome") as Node2D
	assert(iso != null, "Şovalye kubbesi izometrik katmanlarla kurulmalı")
	var floor_spr := iso.get_child(0) as Sprite2D
	var back := iso.get_child(1) as AnimatedSprite2D
	var front := iso.get_child(2) as AnimatedSprite2D
	assert(floor_spr != null and not floor_spr.z_as_relative and floor_spr.z_index == 0, "zemin karakterlerin altında (mutlak z 0)")
	assert(back != null and not back.z_as_relative and back.z_index == 0 and back.is_playing(), "arka kabuk karakterlerin altında, döngüde")
	assert(front != null and front.z_as_relative and b.z_index == 20 and front.is_playing(), "ön kabuk karakterlerin üstünde (z 20)")
	assert(back.frame == front.frame, "arka/ön aynı karede başlar")
	assert(b.scale.is_equal_approx(Vector2(2.0, 2.0)), "1 yerel birim = 1 dünya px")
	b.call("flash_from_angle", PI * 0.5)
	assert(b.get("_flash").visible, "isabette parlama")
	var gold: Node2D = BarrierScript.new()
	gold.set("variant", "gold")
	gold.set("muffle_outside_sound", false)
	holder.add_child(gold)
	assert(gold.get_node_or_null("IsoDome") == null, "satıcının altın kubbesi düz daire kalır")
	_cleanup()


func test_knight_r_holds_the_glowing_pose_floats_and_lands() -> void:
	var p: Node = _make_knight()
	var anim: AnimatedSprite2D = p.get("anim")
	var base: Vector2 = p.get("cadi_base_offset")
	p.call("_skill_paladin_ulti")
	assert(bool(p.get("paladin_zone_active")), "R açıldı")
	p.call("_update_animation", false)
	assert(String(anim.animation) == DomeScript.ANIM_PREFIX + String(p.get("facing")), "kollar açık parlayan klip: %s" % anim.animation)
	p.call("_process_paladin_levitate", 0.2)
	assert(anim.offset.y < base.y - 2.0, "havaya süzüldü: %s" % str(anim.offset))
	## yürürken de (Yürüyen Kale) ve yetenek klibinden sonra da poz bozulmaz
	anim.play("shrug_down")
	p.call("_update_animation", true)
	assert(DomeScript.is_anim(String(anim.animation)), "poz her şeyin önünde: %s" % anim.animation)
	var barrier: Node = p.get("_paladin_barrier_instance")
	assert(barrier != null and barrier.get_node_or_null("IsoDome") != null, "izometrik kubbe kuruldu")
	p.call("_end_paladin_ulti")
	p.call("_update_animation", false)
	assert(not DomeScript.is_anim(String(anim.animation)), "R bitince normal klip: %s" % anim.animation)
	p.call("_process_paladin_levitate", 0.016)
	assert(anim.offset.is_equal_approx(base), "yere indi: %s" % str(anim.offset))
	_cleanup()


func test_remote_copy_floats_from_the_clip_name() -> void:
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.set_physics_process(false)
	rp.call("setup", 77, SOVALYE, "uzak")
	var anim: AnimatedSprite2D = rp.get("anim")
	var base: Vector2 = rp.get("cadi_base_offset")
	rp.call("update_position_and_anim_from_net", Vector2(100.0, 100.0), "bariyer_left")
	assert(String(anim.animation) == "bariyer_left", "uzak kopya klibi adıyla oynar: %s" % anim.animation)
	rp.call("_process_paladin_levitate_remote", 0.2)
	assert(anim.offset.y < base.y - 2.0, "uzak kopya da süzülür: %s" % str(anim.offset))
	rp.call("update_position_and_anim_from_net", Vector2(100.0, 100.0), "idle_left")
	rp.call("_process_paladin_levitate_remote", 0.016)
	assert(anim.offset.is_equal_approx(base), "klip bitince yere iner: %s" % str(anim.offset))
	_cleanup()


## Kubbe girdabı (2026-10-15): Talon kubbede E -> halkanın tamamını döndürür (avantajlar yarı), silahlarını halkadan çekmez;
## R (Ayna Formu) yalnız KENDİ silahlarını kopyalar ve kopyalar da halkada durur.
func test_talon_in_a_dome_spins_the_rim_and_mirrors_only_own_weapons() -> void:
	assert(is_equal_approx(TalonFormationMath.salvo_fire_mult(false), 1.0 / 5.0), "normal salvo +%400")
	assert(is_equal_approx(TalonFormationMath.salvo_fire_mult(true), 1.0 / 6.0), "Ateş Seli +%500")
	assert(is_equal_approx(TalonFormationMath.salvo_fire_mult(false, TalonFormationMath.DOME_SPIN_ADVANTAGE), 1.0 / 3.0), "girdap +%200")
	assert(is_equal_approx(TalonFormationMath.salvo_fire_mult(true, TalonFormationMath.DOME_SPIN_ADVANTAGE), 1.0 / 3.5), "girdap + Ateş Seli +%250")
	var talon: Node = _make_char(TALON)
	assert(not talon.call("is_talon_salvo"), "başta salvo yok")
	var knight := FakeKnight.new()
	knight.add_to_group("remote_players")
	add_child(knight)
	_spawned.append(knight)
	knight.global_position = (talon as Node2D).global_position + Vector2(20.0, 0.0)
	talon.call("_skill_talon_weapon_salvo")
	assert(talon.call("is_talon_salvo"), "E açıldı")
	assert(bool(talon.get("talon_dome_spin")), "kubbenin içinde basılan E girdaba döner")
	assert(not talon.call("dome_rim_blocked"), "E silahları halkadan çekmez")
	assert(is_equal_approx(float(talon.call("_talon_salvo_fire_mult")), 1.0 / 3.0), "girdapta Talon'un kendi silahları da yarı bonus")
	talon.call("_end_talon_weapon_salvo")
	assert(not bool(talon.get("talon_dome_spin")) and is_equal_approx(float(talon.call("_talon_salvo_fire_mult")), 1.0 / 5.0), "E bitince normal")
	var own: int = (talon.get("owned_weapon_nodes") as Array).size()
	talon.call("_skill_talon_mirror_form")
	assert((talon.get("owned_weapon_nodes") as Array).size() == own * 2, "R yalnız kendi silahlarını kopyalar: %d -> %d" % [own, (talon.get("owned_weapon_nodes") as Array).size()])
	assert(not talon.call("dome_rim_blocked"), "R kopyaları da halkada durur")
	talon.call("_end_talon_mirror_form")
	assert((talon.get("owned_weapon_nodes") as Array).size() == own, "R bitince kopyalar gider")
	## kubbe dışında E eski davranış: kendi çemberi
	knight.paladin_zone_active = false
	talon.call("_skill_talon_weapon_salvo")
	assert(not bool(talon.get("talon_dome_spin")), "kubbe dışında normal salvo")
	talon.call("_end_talon_weapon_salvo")
	_cleanup()


## DÜZELTME (2026-10-17, kullanıcı: "talonun E yeteneği şovalye adamın içine girip çıktıktan sonra dönme becerisini kaybediyor"): kuklanın ikon sayısı
## kubbedeyken azalınca (Ayna Formu kopyaları bitince) fazla indekslerin halka geçişi 1'de takılı kalıyordu -> kubbeden çıkınca _dome_rim_owns_icons
## sonsuza dek true, kuklanın Talon dizilimi (_update_talon_formation) bir daha hiç çalışmıyordu (diğer oyuncular E'de silahları dönerken görmüyordu).
func test_remote_talon_formation_comes_back_after_icons_shrink_inside_the_dome() -> void:
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.set_physics_process(false)
	rp.call("setup", 78, TALON, "uzak")
	(rp as Node2D).global_position = Vector2(100.0, 100.0)
	rp.call("update_weapon_visuals", ["dagger", "fire_staff", "dagger", "fire_staff"]) ## R açık: 2 silah + 2 kopya
	var icons: int = (rp.get("_weapon_icons") as Array).size()
	assert(icons == 4, "4 ikon: %d" % icons)
	rp.call("set_dome_rim_targets", [Vector2(0, 0), Vector2(50, 0), Vector2(100, 0), Vector2(150, 0)])
	for i in range(30):
		rp.call("_update_dome_rim", 0.05)
	assert(rp.call("_dome_rim_owns_icons"), "halkada")
	rp.call("update_weapon_visuals", ["dagger", "fire_staff"]) ## R bitti (kubbenin içinde): kopyalar gitti
	rp.call("set_dome_rim_targets", [Vector2(0, 0), Vector2(50, 0)])
	rp.call("_update_dome_rim", 0.05)
	rp.call("set_dome_rim_targets", []) ## kubbeden çıktı
	for i in range(30):
		rp.call("_update_dome_rim", 0.05)
	assert(not rp.call("_dome_rim_owns_icons"), "kubbeden çıkıp geçiş bitince halka ikonları bırakmalı (yoksa E dizilimi hiç çalışmaz)")
	_cleanup()
