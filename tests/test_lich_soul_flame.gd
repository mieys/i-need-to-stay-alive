extends Node

## Madde 280: Lich büyülü atışı "Ruh Alevi" - mermi stili (küre yerine pişmiş alev sayfası, yön satırı, kare ilerlemesi), lich'e özel
## renk + asa ucundan çıkış + uçtan yeniden nişan, saldırı klibinin parlama karesinden başlaması (C++ hold kapalı), kendi isabet efekti,
## kor katmanı ve ağ kopyasının alanları add_child'dan ÖNCE alması (eski sıra kopyayı turuncu / sağa dönük kuruyordu).

const EnemyProjectileScene: PackedScene = preload("res://scenes/enemy_projectile.tscn")
const LichScene: PackedScene = preload("res://scenes/creatures/enemy_lich1.tscn")
const Lich3Scene: PackedScene = preload("res://scenes/creatures/enemy_lich3.tscn")
const DemonScene: PackedScene = preload("res://scenes/creatures/enemy_demon1.tscn")
const LichFlame := preload("res://scripts/lich_soul_flame.gd")
const LichImpactScript: GDScript = preload("res://scripts/fx_lich_flame_impact.gd")
const LichEmberLayerScript: GDScript = preload("res://scripts/lich_ember_layer.gd")


class FakeBody extends CharacterBody2D:
	var hits: int = 0

	func take_damage(_amount: float, _source: Node = null) -> void:
		hits += 1


var _spawned: Array = []


func _cleanup() -> void:
	for n in get_tree().get_nodes_in_group("enemy_projectiles"):
		n.queue_free()
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func _body(pos: Vector2, group: String) -> FakeBody:
	var b := FakeBody.new()
	b.collision_layer = 2
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	cs.shape = shape
	b.add_child(cs)
	b.add_to_group(group)
	add_child(b)
	b.global_position = pos
	_spawned.append(b)
	return b


func _proj(style: int, dir: Vector2, pos: Vector2) -> Node2D:
	var p: Node2D = EnemyProjectileScene.instantiate()
	p.direction = dir
	p.style = style
	p.damage = 3.0
	add_child(p)
	p.global_position = pos
	_spawned.append(p)
	return p


func _flame_of(p: Node) -> Sprite2D:
	for c in p.get_children():
		if c.get_script() == LichFlame:
			return c as Sprite2D
	return null


func _enemy(scene: PackedScene, pos: Vector2) -> Node2D:
	var e: Node2D = scene.instantiate()
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _newest_projectile() -> Node2D:
	var all: Array = get_tree().get_nodes_in_group("enemy_projectiles")
	return all[all.size() - 1] as Node2D if not all.is_empty() else null


func test_dir_row_maps_angles_to_32_rows() -> void:
	assert(LichFlame.dir_row(Vector2.RIGHT) == 0)
	assert(LichFlame.dir_row(Vector2.DOWN) == 8, "aşağı = 90 derece = satır 8")
	assert(LichFlame.dir_row(Vector2.LEFT) == 16)
	assert(LichFlame.dir_row(Vector2.UP) == 24)
	assert(LichFlame.dir_row(Vector2.from_angle(-0.05)) == 0, "sıfırın hemen altı 31'e değil 0'a yuvarlanmalı")
	assert(LichFlame.dir_row(Vector2.ZERO) == 0)


func test_only_lich_scenes_are_lich() -> void:
	var l1 := _enemy(LichScene, Vector2(300, 300))
	var l3 := _enemy(Lich3Scene, Vector2(360, 300))
	var d := _enemy(DemonScene, Vector2(420, 300))
	assert(l1.get("_is_lich") == true and l3.get("_is_lich") == true, "Lich 1/3 lich sayılmalı")
	assert(d.get("_is_lich") == false, "Demon lich DEĞİL (küre kalır)")
	_cleanup()


func test_spell_style_replaces_orb_with_flame_sheet() -> void:
	var p := _proj(LichFlame.STYLE_SPELL, Vector2.DOWN, Vector2(5000, 5000))
	assert(p.get_node_or_null("Visual") == null or p.get_node_or_null("Visual").get_script() != preload("res://scripts/fx_projectile_orb.gd"),
			"lich mermisinde eski küre görseli kalmamalı")
	var f := _flame_of(p)
	assert(f != null, "Ruh Alevi sprite'ı eklenmeli")
	assert(f.texture == LichFlame.SHEET, "büyü büyük sayfayı kullanmalı")
	assert(f.hframes == LichFlame.NF and f.vframes == LichFlame.NDIR)
	assert(int(f.frame / LichFlame.NF) == 8, "aşağı uçan alev 8. satırda: %d" % f.frame)
	var seen := {}
	for i in range(30):
		await get_tree().physics_frame
		if not is_instance_valid(f):
			break
		assert(int(f.frame / LichFlame.NF) == 8, "kare ilerlerken satır (yön) değişmemeli")
		seen[f.frame % LichFlame.NF] = true
	assert(seen.size() >= 3, "0,5 sn'de alev en az 3 farklı karede titremeli: %s" % str(seen.keys()))
	_cleanup()


func test_small_style_uses_small_sheet_and_orb_style_untouched() -> void:
	var p := _proj(LichFlame.STYLE_SMALL, Vector2.LEFT, Vector2(5000, 5200))
	var f := _flame_of(p)
	assert(f != null and f.texture == LichFlame.SHEET_SMALL, "normal atış küçük sayfa")
	assert(int(f.frame / LichFlame.NF) == 16)
	var o := _proj(LichFlame.STYLE_ORB, Vector2.LEFT, Vector2(5000, 5400))
	assert(_flame_of(o) == null and o.get_node_or_null("Visual") != null, "stil 0 = eski küre (Demon/İblis/Röntgen)")
	_cleanup()


func test_lich_spell_fires_from_staff_tip_with_teal_and_flash_frame() -> void:
	var lich := _enemy(LichScene, Vector2(1000, 1000))
	var target := _body(Vector2(1300, 1040), "player")
	await _physics_frames(2)
	lich.call("_fire_ranged_attack", (target.global_position - lich.global_position).normalized(), target)
	## Klip parlama karesinden: kare ilerlemesi GDScript'te (hold kapalı)
	assert(lich.call("_ew_hold_ok") == false, "lich saldırı karesini C++ (0'dan sayan hold) yazmamalı")
	var fs: Sprite2D = lich.get("frame_sprite")
	var col: int = fs.frame % fs.hframes
	assert(is_equal_approx(float(lich.get("_frame_time")), float(LichFlame.FLASH_FRAME)) or col >= LichFlame.FLASH_FRAME,
			"saldırı klibi parlama karesinden başlamalı")
	await get_tree().process_frame ## call_deferred add_child
	var p := _newest_projectile()
	assert(p != null, "mermi doğmalı")
	assert(int(p.get("style")) == LichFlame.STYLE_SPELL)
	assert(p.get("tint") == LichFlame.TINT, "lich mermisi turkuaz (gece ışığı/isabet rengi)")
	var off: Vector2 = p.global_position - lich.global_position
	assert(off.length() > 10.0 and off.length() < 40.0, "mermi asa ucundan çıkmalı (merkez değil): %s" % str(off))
	var aim: Vector2 = (target.global_position - p.global_position).normalized()
	assert((p.get("direction") as Vector2).dot(aim) > 0.999, "nişan asa ucundan yeniden alınmalı (paralel kayma yok)")
	await _physics_frames(120)
	assert(target.hits == 1, "uçtan atılan büyü hedefe isabet etmeli: %d" % target.hits)
	_cleanup()


func test_lich_attack_state_holds_after_flash_and_keeps_duration() -> void:
	var lich := _enemy(LichScene, Vector2(1600, 1000))
	await _physics_frames(2)
	var dur: float = float(lich.call("_anim_length_for", 2)) ## State.ATTACK
	lich.call("_enter_state", 2, dur)
	assert(is_equal_approx(float(lich.get("_state_duration")), dur), "saldırı süresi (hareket kilidi) değişmemeli")
	await _physics_frames(20)
	var fs: Sprite2D = lich.get("frame_sprite")
	assert(fs.frame % fs.hframes >= LichFlame.FLASH_FRAME, "parlamadan sonra klip son karelerde kalmalı: %d" % (fs.frame % fs.hframes))
	_cleanup()


func test_demon_keeps_orb_center_origin_and_own_tint() -> void:
	var d := _enemy(DemonScene, Vector2(2000, 1000))
	var target := _body(Vector2(2300, 1000), "player")
	await _physics_frames(2)
	d.call("_fire_ranged_attack", Vector2.RIGHT, target)
	await get_tree().process_frame
	var p := _newest_projectile()
	assert(int(p.get("style")) == LichFlame.STYLE_ORB)
	assert(p.global_position.distance_to(d.global_position) < 0.01, "Demon mermisi eskisi gibi merkezden")
	assert(p.get("tint") == d.get("projectile_tint"))
	assert(d.get("_is_lich") == false, "Demon'da C++ saldırı karesi yolu (hold) lich kuralıyla kapanmamalı")
	_cleanup()


func test_lich_hit_spawns_lich_impact_not_bolt() -> void:
	var target := _body(Vector2(3000, 1000), "player")
	_proj(LichFlame.STYLE_SPELL, Vector2.RIGHT, Vector2(2950, 1000))
	await _physics_frames(30)
	assert(target.hits == 1)
	var found := false
	for c in get_children():
		if c.get_script() == LichImpactScript:
			found = true
			assert(c.get("small") == false)
	assert(found, "lich isabeti fx_lich_flame_impact olmalı")
	_cleanup()


func test_embers_go_to_one_shared_layer() -> void:
	_proj(LichFlame.STYLE_SPELL, Vector2.RIGHT, Vector2(4000, 2000))
	_proj(LichFlame.STYLE_SPELL, Vector2.LEFT, Vector2(4400, 2100))
	await _physics_frames(40)
	var layers: Array = []
	for c in get_children():
		if c.get_script() == LichEmberLayerScript:
			layers.append(c)
	assert(layers.size() == 1, "tüm korlar TEK katmanda: %d" % layers.size())
	assert(int(layers[0].call("count")) > 0, "uçan alev kor bırakmalı")
	_cleanup()


func test_network_copy_gets_fields_before_ready() -> void:
	NetworkManager.broadcast_enemy_projectile(Vector2(6000, 6000), Vector2.UP, false, LichFlame.TINT, 0, LichFlame.STYLE_SPELL)
	var p := _newest_projectile()
	assert(p != null and p.get_meta("network_spawned", false), "kozmetik kopya doğmalı")
	var f := _flame_of(p)
	assert(f != null and int(f.frame / LichFlame.NF) == 24, "kopya stili ve yönü _ready'de görmeli (yukarı = satır 24)")
	assert(p.global_position.distance_to(Vector2(6000, 6000)) < 0.01)
	## Eski hata: küre kopyası varsayılan turuncu + sağa dönük kuruluyordu
	var red := Color(1.0, 0.3, 0.15)
	NetworkManager.broadcast_enemy_projectile(Vector2(6100, 6000), Vector2.DOWN, false, red, 0)
	var o := _newest_projectile()
	var vis: Node = o.get_node_or_null("Visual")
	assert(vis != null and vis.get("glow_color") == red, "küre kopyası gönderilen rengi almalı")
	assert(vis.get("direction") == Vector2.DOWN, "küre kopyasının izi uçuş yönünün tersinde olmalı")
	_cleanup()
