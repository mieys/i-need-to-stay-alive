extends "res://scripts/enchant_behavior.gd"

## Gölge Yankısı (Bıçak / Pençe) - bkz. EnchantDefs "golge_yankisi".
##  - Kombo = art arda ana hedef isabetleri (Bıçak 3, Pençe 2; 2 sn ara verince sıfırlanır). Tamamlanınca hedefin yerinde
##    sahibinin koyu gölgesi (evo_area.gd "assasin_clone" - karakterin kendi sprite'ı, diğer oyuncular da görür) belirir;
##    1,5 sn sonra komboyu aynı yerde tekrarlar (shade_slash sayfası, silah hasarının %35 / %55'i; Seviye 2 Derin Kanama 3 sn).
##  - Seviye 3: bir hareket tuşuna çift basınca en son gölgeyle yer değiştirir (network "teleport_snap") + 0,5 sn hasar almaz.
##  - Seviye 4: 2 gölge; iki gölgenin arasında duran sahip %20 saldırı hızı kazanır.
##  - Final: 2 gölge varken kombo tamamlanırsa sahip ve gölgeler 0,75 sn hedef alınamaz; 80 birim içindeki düşmanlara
##    8 ardışık darbe (toplam silah hasarının %500'ü).

const EvoAreaScript := preload("res://scripts/evo_area.gd")
const COMBO_RESET := 2.0
const STRIKE_DELAY := 1.5
const STRIKE_GAP := 0.12
const STRIKE_RADIUS := 50.0
const SHADE_TINT := Color(0.2, 0.08, 0.34, 0.75)
const SWAP_TAP := 0.3
const SWAP_INVULN := 0.5
const BETWEEN_DIST := 40.0
const DANCE_TIME := 0.75
const DANCE_HITS := 8
const DANCE_RADIUS := 80.0
const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]

var _shade_combo: int = 0
var _last_hit_msec: int = -100000
var _shades: Array = [] ## {node, pos, born}
var _invuln_until_msec: int = 0
var _last_tap: String = ""
var _last_tap_msec: int = -100000
var _dancing: bool = false


func _combo_len() -> int:
	return 2 if weapon_key() == "pence" else 3


func _alive_shades() -> Array:
	var now: int = Time.get_ticks_msec()
	var out: Array = []
	for s in _shades:
		if is_instance_valid(s["node"]) and now - int(s["born"]) < int(f("shade_life", 4.0) * 1000.0):
			out.append(s)
	_shades = out
	return out


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj != null or not is_enemy(t) or not can_act() or _dancing:
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_hit_msec > int(COMBO_RESET * 1000.0):
		_shade_combo = 0
	_last_hit_msec = now
	_shade_combo += 1
	if _shade_combo < _combo_len():
		return
	_shade_combo = 0
	if f("dance") > 0.0 and _alive_shades().size() >= 2:
		_dance()
		return
	_make_shade((t as Node2D).global_position)


func _make_shade(at: Vector2) -> void:
	var pl: Node = owner_player()
	if pl == null:
		return
	var shades: Array = _alive_shades()
	while shades.size() >= maxi(1, n("shade_max", 1)):
		_pop_shade(shades.pop_front())
	_shades = shades
	var node: Node2D = _spawn_shade_visual(at)
	var rec: Dictionary = {"node": node, "pos": at, "born": Time.get_ticks_msec()}
	_shades.append(rec)
	get_tree().create_timer(STRIKE_DELAY, false).timeout.connect(_shade_strike.bind(at, 0))


func _spawn_shade_visual(at: Vector2) -> Node2D:
	var pl: Node = owner_player()
	var spr: AnimatedSprite2D = pl.get("anim") if pl else null
	if spr == null or spr.sprite_frames == null or spr.sprite_frames.resource_path.is_empty():
		return null
	var facing: String = str(pl.get("facing")) if pl.get("facing") != null else "down"
	var clip: String = "idle_" + facing
	if not spr.sprite_frames.has_animation(clip):
		clip = String(spr.animation)
	var peer: int = my_peer()
	return EvoAreaScript.spawn(get_tree(), "assasin_clone", at, {"frames": spr.sprite_frames.resource_path, "anim": clip,
		"flip": spr.flip_h, "scale": spr.global_scale, "offset": spr.offset, "rel": spr.global_position - (pl as Node2D).global_position,
		"ground": Vector2(0.0, 15.0), "tint": SHADE_TINT, "duration": f("shade_life", 4.0), "peer": peer}, true)


func _pop_shade(rec: Dictionary) -> void:
	var node: Variant = rec.get("node")
	if node == null or not is_instance_valid(node):
		return
	var area_id: int = int(node.get("area_id"))
	if NetworkManager.is_multiplayer_active and area_id != 0:
		NetworkManager.broadcast_evo_area_end.rpc(area_id, (node as Node2D).global_position)
	node.call("_pop")


## Gölge komboyu tekrarlar: combo uzunluğu kadar darbe, STRIKE_GAP arayla.
func _shade_strike(at: Vector2, idx: int) -> void:
	if not is_inside_tree() or not can_act():
		return
	sprite("shade_slash", at + Vector2(0.0, -8.0), {"rot": randf() * TAU, "z": 9})
	var victims: Array = enemies_near(at, STRIKE_RADIUS)
	for e in victims:
		hit(e, wdmg() * f("shade_dmg", 0.35))
	if f("shade_bleed") > 0.0 and idx == 0:
		timed_dot(victims, wdmg() * f("shade_bleed"), 3.0)
	if idx + 1 < _combo_len():
		get_tree().create_timer(STRIKE_GAP, false).timeout.connect(_shade_strike.bind(at, idx + 1))


func process_extra(_delta: float) -> void:
	if not flag("shade_swap"):
		return
	for act in MOVE_ACTIONS:
		if Input.is_action_just_pressed(act):
			var now: int = Time.get_ticks_msec()
			if act == _last_tap and now - _last_tap_msec <= int(SWAP_TAP * 1000.0):
				_last_tap = ""
				_swap()
			else:
				_last_tap = act
				_last_tap_msec = now


func _swap() -> void:
	var pl: Node2D = owner_player() as Node2D
	var shades: Array = _alive_shades()
	if pl == null or shades.is_empty() or not can_act() or pl.get("is_chat_typing") == true:
		return
	var rec: Dictionary = shades.back()
	var target_pos: Vector2 = Vector2(rec["pos"])
	var old_pos: Vector2 = pl.global_position
	_pop_shade(rec)
	_shades.erase(rec)
	## Gölge oyuncunun eski yerine geçer (kalan ömrüyle).
	var node: Node2D = _spawn_shade_visual(old_pos)
	_shades.append({"node": node, "pos": old_pos, "born": int(rec["born"])})
	pl.global_position = target_pos
	pl.reset_physics_interpolation()
	if NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_player_vfx.rpc(multiplayer.get_unique_id(), "teleport_snap", target_pos, {})
	_invuln_until_msec = Time.get_ticks_msec() + int(SWAP_INVULN * 1000.0)


func on_owner_damaged(amount: float, _source: Node) -> float:
	if Time.get_ticks_msec() < _invuln_until_msec:
		return 0.0
	return amount


## Seviye 4: sahip iki gölgeyi birleştiren çizgiye yakınsa (aralarında) +%20 saldırı hızı.
func attack_speed_extra() -> float:
	if n("shade_max", 1) < 2:
		return 0.0
	var shades: Array = _alive_shades()
	var pl: Node2D = owner_player() as Node2D
	if shades.size() < 2 or pl == null:
		return 0.0
	var a: Vector2 = Vector2(shades[0]["pos"])
	var b: Vector2 = Vector2(shades[1]["pos"])
	var cp: Vector2 = Geometry2D.get_closest_point_to_segment(pl.global_position, a, b)
	if cp.distance_to(a) < 1.0 or cp.distance_to(b) < 1.0:
		return 0.0 ## uç noktadaysa "arasında" değil
	return 0.2 if pl.global_position.distance_to(cp) <= BETWEEN_DIST else 0.0


func _dance() -> void:
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	_dancing = true
	for s in _alive_shades():
		_pop_shade(s)
	_shades.clear()
	var was_invisible: bool = pl.get("is_invisible") == true
	pl.set("is_invisible", true)
	pl.modulate.a = 0.35
	_invuln_until_msec = Time.get_ticks_msec() + int(DANCE_TIME * 1000.0)
	var per_hit: float = wdmg() * f("dance") / float(DANCE_HITS)
	for i in range(DANCE_HITS):
		get_tree().create_timer(DANCE_TIME * float(i) / float(DANCE_HITS), false).timeout.connect(_dance_hit.bind(per_hit))
	get_tree().create_timer(DANCE_TIME, false).timeout.connect(_dance_end.bind(was_invisible))


func _dance_hit(amount: float) -> void:
	var pl: Node2D = owner_player() as Node2D
	if pl == null or not is_inside_tree():
		return
	var near: Array = enemies_near(pl.global_position, DANCE_RADIUS)
	if near.is_empty():
		return
	var e: Node2D = near[randi() % near.size()]
	sprite("shade_slash", e.global_position + Vector2(0.0, -8.0), {"rot": randf() * TAU, "z": 9})
	hit(e, amount)


func _dance_end(was_invisible: bool) -> void:
	_dancing = false
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	if not was_invisible:
		pl.set("is_invisible", false)
		pl.modulate.a = 1.0
