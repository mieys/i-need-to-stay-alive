extends Node

## Kullanıcı bildirimi (2026-10-05): "Kopyanı Öldür" görevinde kopya benim silahlarıma sahip ama onlarla ateş etmiyor, başka (mor)
## ateşler ediyor. Kopya artık silahın KENDİ mermi sahnesinin görselini/hızını kullanır (mission_player_copy.gd attack_info),
## Şimşek Asası anlık ışın çizer; hasar mantığı (yolu boyunca ilk oyuncuya vurur) aynı kalır.

const CopyScript: GDScript = preload("res://scripts/mission_player_copy.gd")
const BoltScript: GDScript = preload("res://scripts/mission_copy_bolt.gd")
const RemotePlayerScript: GDScript = preload("res://scripts/remote_player.gd")


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var hits: Array = []

	func take_damage(amount: float, _source: Variant = null) -> void:
		hits.append(amount)


var _made: Array[Node] = []


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if c is Node2D and c.get_script() == BoltScript:
			c.free()


func _fake_player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_made.append(p)
	return p


func _bolts() -> Array[Node]:
	var out: Array[Node] = []
	for c: Node in get_children():
		if c.get_script() == BoltScript:
			out.append(c)
	return out


func _has_class(n: Node, cls: String) -> bool:
	if n.is_class(cls):
		return true
	for c: Node in n.get_children():
		if _has_class(c, cls):
			return true
	return false


func _spawn(key: String, from: Vector2, to: Vector2, cosmetic: bool) -> Node:
	CopyScript.spawn_bolt(from, to, 5.0, null, cosmetic, key)
	var b: Array[Node] = _bolts()
	assert(b.size() == 1, "tek mermi olmalı: %d" % b.size())
	_made.append(b[0])
	return b[0]


# ---------------------------------------------------------------- saldırı bilgisi
func test_attack_info_reads_projectile_speed_scale_and_rotation_from_the_weapon_scene() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var info: Dictionary = CopyScript.attack_info("yay")
	assert(info.get("proj") is PackedScene, "yayın mermi sahnesi (ok) olmalı")
	assert(info.get("beam") == null, "yay ışın silahı değil")
	var p: Node = (info["proj"] as PackedScene).instantiate()
	var want_speed: float = float(p.get("speed"))
	p.free()
	assert(want_speed > 0.0 and is_equal_approx(float(info["speed"]), want_speed), "hız merminin kendi hızı olmalı: %s" % str(info["speed"]))
	assert(float(info["speed"]) != CopyScript.BOLT_SPEED, "yay oku artık eski mor merminin hızında uçmamalı")
	var tab: Dictionary = CopyScript.attack_info("tabanca")
	assert(is_equal_approx(float(tab["rot"]), -0.005471964169398338), "silahın mermi dönüş ofseti okunmalı: %s" % str(tab["rot"]))


func test_lightning_staff_is_a_beam_and_melee_has_no_projectile() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var l: Dictionary = CopyScript.attack_info("lightning_staff")
	assert(l.get("beam") is PackedScene, "Şimşek Asası ışın sahnesi taşımalı")
	assert(l.get("proj") == null, "Şimşek Asası'nın mermi sahnesi yok")
	var d: Dictionary = CopyScript.attack_info("dagger")
	assert(d.get("proj") == null and d.get("beam") == null, "yakın dövüşün mermisi/ışını yok")
	assert(CopyScript.attack_info("yok_boyle_silah").is_empty(), "bilinmeyen anahtar boş sözlük (eski mor mermi) döner")


func test_every_ranged_weapon_has_its_own_projectile_or_beam() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	## Regresyon: yeni bir menzilli silah eklenip mermisi okunamazsa kopya sessizce yine mor mermi atardı.
	for key: String in RemotePlayerScript.WEAPON_SCENES.keys():
		if key in CopyScript.MELEE_KEYS:
			continue
		var info: Dictionary = CopyScript.attack_info(key)
		assert(info.get("proj") != null or info.get("beam") != null, "%s kendi mermisi/ışını olmadan mor mermiye düşüyor" % key)


# ---------------------------------------------------------------- mermi görseli
func test_bolt_with_a_weapon_key_shows_the_weapons_projectile_not_the_purple_rects() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var b: Node = _spawn("yay", Vector2.ZERO, Vector2(400, 0), true)
	assert(not _has_class(b, "ColorRect"), "silah mermisi varken mor dikdörtgen çizilmemeli")
	assert(_has_class(b, "Sprite2D") or _has_class(b, "AnimatedSprite2D"), "okun sprite'ı görünmeli")
	assert(not _has_class(b, "CollisionShape2D"), "görsel kopyada çarpışma şekli kalmamalı")
	assert(not _has_class(b, "AudioStreamPlayer2D") and not _has_class(b, "AudioStreamPlayer"), "görsel kopyada ses kalmamalı")
	for c: Node in b.get_children():
		assert(c.get_script() == null, "görsel kopyanın mermi betiği (hasar/çarpışma mantığı) sökülmüş olmalı: %s" % c.name)
	_cleanup()


func test_bolt_without_a_key_or_with_an_unknown_key_keeps_the_old_purple_look() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var b: Node = _spawn("", Vector2.ZERO, Vector2(400, 0), true)
	assert(_has_class(b, "ColorRect"), "anahtarsız mermi eski mor görünümde kalmalı")
	_cleanup()
	var b2: Node = _spawn("yok_boyle_silah", Vector2.ZERO, Vector2(400, 0), true)
	assert(_has_class(b2, "ColorRect"), "bilinmeyen silah anahtarı da eski mor görünüme düşer")
	_cleanup()


func test_bolt_flies_at_the_weapons_projectile_speed() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var info: Dictionary = CopyScript.attack_info("yay")
	var b: Node = _spawn("yay", Vector2.ZERO, Vector2(2000, 0), true)
	await get_tree().process_frame
	var x0: float = (b as Node2D).position.x
	b.call("_physics_process", 0.1)
	var dx: float = (b as Node2D).position.x - x0
	assert(is_equal_approx(dx, float(info["speed"]) * 0.1), "0.1 sn'de silah hızı kadar ilerlemeli: %s" % str(dx))
	_cleanup()
	var b2: Node = _spawn("", Vector2.ZERO, Vector2(2000, 0), true)
	b2.call("_physics_process", 0.1)
	assert(is_equal_approx((b2 as Node2D).position.x, CopyScript.BOLT_SPEED * 0.1), "anahtarsız mermi eski hızda")
	_cleanup()


# ---------------------------------------------------------------- hasar mantığı değişmedi
func test_weapon_bolt_still_damages_the_first_player_on_its_path() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var victim: FakePlayer = _fake_player(Vector2(100, 0))
	var b: Node = _spawn("yay", Vector2.ZERO, Vector2(400, 0), false)
	await get_tree().process_frame
	for i in range(40):
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			break
		b.call("_physics_process", 0.02)
	assert(victim.hits.size() == 1 and is_equal_approx(float(victim.hits[0]), 5.0), "yoldaki oyuncuya tam bir kez vurmalı: %s" % str(victim.hits))
	_cleanup()


func test_cosmetic_weapon_bolt_never_damages() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var victim: FakePlayer = _fake_player(Vector2(100, 0))
	var b: Node = _spawn("yay", Vector2.ZERO, Vector2(400, 0), true)
	await get_tree().process_frame
	for i in range(40):
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			break
		b.call("_physics_process", 0.02)
	assert(victim.hits.is_empty(), "istemcideki kozmetik mermi hasar vermemeli")
	_cleanup()


# ---------------------------------------------------------------- kopyanın kendisi
func _make_copy(keys: Array) -> Node:
	var c: Node = CopyScript.new()
	add_child(c)
	c.call("setup", 1, 0, 0, 100.0, 0.0, 200.0, 10.0, true)
	c.call("set_weapon_keys", keys)
	_made.append(c)
	return c


func test_copy_fires_the_weapons_projectile_not_the_generic_bolt() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var target: FakePlayer = _fake_player(Vector2(300, 0))
	var copy: Node = _make_copy(["yay"])
	var ws: Array = copy.get("_weapons")
	assert(ws.size() == 1 and not ws[0]["melee"], "yay menzilli silah olarak yüklenmeli")
	assert((ws[0]["info"] as Dictionary).get("proj") != null, "silah verisi mermi bilgisini taşımalı")
	copy.call("_fire_at", target, Vector2.ZERO, 5.0, ws[0])
	var b: Array[Node] = _bolts()
	assert(b.size() == 1, "tek mermi atılmalı: %d" % b.size())
	await get_tree().process_frame
	assert(not _has_class(b[0], "ColorRect"), "kopyanın atışı mor mermi olmamalı, okun kendisi olmalı")
	assert(_has_class(b[0], "Sprite2D") or _has_class(b[0], "AnimatedSprite2D"), "okun sprite'ı görünmeli")
	_cleanup()


func test_copy_lead_aim_uses_the_weapons_projectile_speed() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	## Hızlı ok (620) yavaş mor mermiden (340) daha az "önden nişan" ister: aynı hareketli hedefe ateşte uçuş noktası farklı olmalı.
	var target: FakePlayer = _fake_player(Vector2(400, 0))
	var copy: Node = _make_copy(["yay"])
	copy.set("_target_vel", Vector2(0, 200))
	var ws: Array = copy.get("_weapons")
	copy.call("_fire_at", target, Vector2.ZERO, 5.0, ws[0])
	var fast: Node = _bolts()[0]
	var fast_y: float = ((fast.get("_dir") as Vector2).y)
	_cleanup()
	var generic: Dictionary = {"key": "", "info": {}}
	var target2: FakePlayer = _fake_player(Vector2(400, 0))
	var copy2: Node = _make_copy([])
	copy2.set("_target_vel", Vector2(0, 200))
	copy2.call("_fire_at", target2, Vector2.ZERO, 5.0, generic)
	var slow: Node = _bolts()[0]
	var slow_y: float = ((slow.get("_dir") as Vector2).y)
	assert(fast_y > 0.0 and slow_y > fast_y, "yavaş mermi daha çok önden nişan almalı (hızlı ok: %s, mor: %s)" % [str(fast_y), str(slow_y)])
	_cleanup()


func test_copy_with_lightning_staff_hits_instantly_and_draws_a_beam_instead_of_a_bolt() -> void:
	_cleanup() ## önceki testin (başarısız olsa bile) artıklarını temizle
	var target: FakePlayer = _fake_player(Vector2(250, 0))
	var copy: Node = _make_copy(["lightning_staff"])
	var ws: Array = copy.get("_weapons")
	assert(ws.size() == 1 and (ws[0]["info"] as Dictionary).get("beam") != null, "Şimşek Asası ışın bilgisi taşımalı")
	copy.call("_fire_at", target, Vector2.ZERO, 7.0, ws[0])
	assert(target.hits.size() == 1 and is_equal_approx(float(target.hits[0]), 7.0), "ışın ANINDA vurmalı: %s" % str(target.hits))
	assert(_bolts().is_empty(), "ışın silahı mermi (bolt) atmamalı")
	var beam: Node = null
	for c: Node in get_children():
		if c.scene_file_path.ends_with("fx_lightning_beam.tscn"):
			beam = c
			_made.append(c)
	assert(beam != null, "ışın görseli sahneye eklenmeli")
	_cleanup()
