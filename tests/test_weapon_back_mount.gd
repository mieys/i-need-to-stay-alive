extends Node

## Silahlar SIRTTA (madde 451; prototip madde 450 A3): düşman yokken silah göğse girip kaybolmaz, sahibin çocuğu olan sırt sprite'ında
## görünür; önden/yandan bakışta karakterin arkasında, arkadan bakışta önünde; düşman görününce sırttan çıkar; ölüyken sırtta yok.
## Yerel weapon.gd ve kukla remote_player.gd aynı kural (weapon_back_mount.gd).

const TabancaScene: PackedScene = preload("res://scenes/weapon_tabanca.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const BackMount := preload("res://scripts/weapon_back_mount.gd")

var _spawned: Array[Node] = []


func _track(n: Node) -> Node:
	_spawned.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


class FakeOwner extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false


class FakeEnemy extends Node2D:
	var is_dead: bool = false


func _make_owner(pos: Vector2) -> FakeOwner:
	var o := FakeOwner.new()
	o.scale = Vector2(0.5, 0.5) ## main.tscn Player kökü
	var spr := AnimatedSprite2D.new()
	spr.name = "AnimatedSprite2D"
	var sf := SpriteFrames.new()
	for a in ["idle_down", "idle_up", "idle_left", "idle_right"]:
		sf.add_animation(a)
	spr.sprite_frames = sf
	spr.animation = &"idle_down"
	o.add_child(spr)
	add_child(o)
	o.global_position = pos
	_track(o)
	return o


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_track(e)
	return e


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _back_of(o: Node) -> Sprite2D:
	for c in o.get_children():
		if c is Sprite2D and str(c.name).begins_with("WeaponOnBack"):
			return c
	return null


func test_pose_depth_mirror_and_tip_by_view() -> void:
	var up: Dictionary = BackMount.pose(0, "up", Vector2.ZERO, 0.0, "fire_staff")
	var down: Dictionary = BackMount.pose(0, "down", Vector2.ZERO, 0.0, "fire_staff")
	assert(bool(up["front"]) and not bool(down["front"]), "arkadan bakışta önde, önden bakışta arkada")
	assert(is_equal_approx((up["pos"] as Vector2).x, -(down["pos"] as Vector2).x), "önden bakış aynalı")
	assert(is_equal_approx(rad_to_deg(float(up["tip"])), -42.0), "asada yukarı taşan uç = baş")
	var sw: Dictionary = BackMount.pose(0, "up", Vector2.ZERO, 0.0, "uzunkilic")
	assert(is_equal_approx(wrapf(rad_to_deg(float(sw["tip"])), -180.0, 180.0), 138.0), "kılıçta kabza yukarı, uç aşağı")
	var right: Dictionary = BackMount.pose(1, "right", Vector2.ZERO, 0.0, "yay")
	assert((right["pos"] as Vector2).x < 0.0 and not bool(right["front"]), "sağa bakarken sırt solda, gövdenin arkasında")
	var walk: Dictionary = BackMount.pose(0, "up", Vector2(82.0, 0.0), 0.15, "yay")
	assert((walk["pos"] as Vector2).y < (up["pos"] as Vector2).y, "yürürken adımda seker")
	assert(bool(BackMount.pose(2, "down", Vector2.ZERO, 0.0, "kalkan")["upright"]), "kalkan dik durur")


## madde 514: uçan silah sırta girerken sırttaki gölgeye kararır, çıkarken koyudan aydınlanır (devir anında sıçrama yok).
func test_flying_weapon_dims_toward_back_shade() -> void:
	var mount: Dictionary = BackMount.pose(0, "down", Vector2.ZERO, 0.0, "tabanca")
	var t0: float = 100.0
	var ret_end: float = t0 + WeaponFollowMath.retract_stagger(0) + WeaponFollowMath.RETRACT_T
	var ret_mid: float = t0 + WeaponFollowMath.retract_stagger(0) + WeaponFollowMath.RETRACT_T * 0.2
	assert(float(WeaponFollowMath.pose({"s": WeaponFollowMath.RETRACT, "t": t0}, ret_mid, 0, Vector2.ZERO, mount)["dim"]) < 0.01, "çekilmenin başında tam renk")
	assert(float(WeaponFollowMath.pose({"s": WeaponFollowMath.RETRACT, "t": t0}, ret_end, 0, Vector2.ZERO, mount)["dim"]) > 0.99, "çekilmenin sonunda sırt karartması")
	var rev0: float = t0 + WeaponFollowMath.reveal_stagger(0) + 0.001
	var rev1: float = t0 + WeaponFollowMath.reveal_stagger(0) + WeaponFollowMath.REVEAL_T * 0.5
	assert(float(WeaponFollowMath.pose({"s": WeaponFollowMath.REVEAL, "t": t0}, rev0, 0, Vector2.ZERO, mount)["dim"]) > 0.95, "çıkış koyu başlar")
	assert(float(WeaponFollowMath.pose({"s": WeaponFollowMath.REVEAL, "t": t0}, rev1, 0, Vector2.ZERO, mount)["dim"]) < 0.01, "çıkış yarısında tam renk")
	assert(float(WeaponFollowMath.pose({"s": WeaponFollowMath.SHOWN, "t": t0}, rev1, 0, Vector2.ZERO, {})["dim"]) == 0.0, "göğüs kuralında karartma yok")
	assert(BackMount.dim_color(1.0).is_equal_approx(BackMount.SHADE_TINT) and BackMount.dim_color(0.0) == Color.WHITE, "gölge katı")
	var t: Color = BackMount.SHADE_TINT
	assert(t.r < 0.8 and t.b >= t.r and t.b - t.r < 0.15, "ışık azalır, hafif serin, renk dengesi bozulmaz")


func test_local_weapon_rests_on_back_and_draws_out_on_sight() -> void:
	var o: FakeOwner = _make_owner(Vector2(7000.0, 7000.0))
	var w: Node2D = TabancaScene.instantiate()
	o.add_child(w)
	await _frames(4)
	assert(w.modulate.a < 0.01, "düşman yok -> süzülen silah görünmez")
	var back: Sprite2D = _back_of(o)
	assert(back != null and back.visible and back.texture != null, "silah sırtta görünür")
	var spr: Node = o.get_node("AnimatedSprite2D")
	assert(back.get_index() < spr.get_index(), "önden bakışta karakterin arkasında")
	(spr as AnimatedSprite2D).animation = &"idle_up"
	await _frames(2)
	assert(back.get_index() > spr.get_index(), "arkadan bakışta karakterin önünde")
	## madde 514: sırtta gölge düşmüş gibi (yalnız ışık azalır, doygunluk kısılmaz; uçuyor gibi durmasın)
	assert(back.modulate.is_equal_approx(BackMount.SHADE_TINT), "sırtta gölgede, opak")
	assert(back.material == null, "doygunluğu kısan shader yok (ikonun kendi materyali yoksa)")
	_make_enemy(o.global_position + Vector2(300.0, 0.0))
	await _wait(0.8)
	assert(not back.visible and w.modulate.a > 0.99, "düşman görününce sırttan çıktı")
	assert(w.modulate.r > 0.99, "çıktıktan sonra tam renk")
	o.is_dead = true
	await _wait(0.6)
	assert(not back.visible and w.modulate.a < 0.01, "ölüyken sırtta da görünmez (eski göğüs kuralı)")
	o.is_dead = false
	w.queue_free()
	await _frames(2)
	assert(not is_instance_valid(back), "silah silinince sırt görüntüsü de gider")
	_cleanup()


func test_puppet_weapon_rests_on_back() -> void:
	var puppet: Node2D = RemotePlayerScene.instantiate() as Node2D
	add_child(puppet)
	_track(puppet)
	puppet.setup(78, 5, "Dost")
	puppet.call("snap_to_network_position", Vector2(11000.0, 11000.0))
	puppet.call("update_weapon_visuals", ["tabanca", "uzunkilic"])
	await _frames(4)
	var backs: Array = puppet.get("_wf_backs")
	assert(backs.size() == 2 and backs[0] != null and (backs[0] as Sprite2D).visible, "kuklada da silah sırtta")
	assert((backs[1] as Sprite2D).visible, "ikinci silah da")
	var pivots: Array = puppet.get("_wf_pivots")
	assert((pivots[0] as CanvasItem).modulate.a < 0.01, "süzülen ikon gizli")
	puppet.set("is_dead", true)
	await _wait(0.7)
	assert(not (backs[0] as Sprite2D).visible, "ölüyken kuklada sırtta yok")
	var old_back: Sprite2D = backs[1] ## _wf_clear aynı diziyi boşaltır
	puppet.call("update_weapon_visuals", ["tabanca"])
	await _frames(2)
	assert(not is_instance_valid(old_back), "silah değişince eski sırt görüntüleri silinir")
	_cleanup()
