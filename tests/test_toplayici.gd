extends Node

## Toplayıcı ruhanisi (madde 625, scripts/toplayici.gd): yalnız XP kristali, çekilende XP bonusu yok, 2v2'de yalnız kendi takımının
## kristali, kesince kristal yerinde kalır, takımlar arası birleşme yok.

const S := preload("res://scripts/spiritual_skills.gd")
const T := preload("res://scripts/toplayici.gd")
const GM := preload("res://scripts/pvp/game_mode.gd")
const Teams := preload("res://scripts/pvp/teams.gd")
const DropMerge := preload("res://scripts/drop_merge.gd")
const MetaProgress := preload("res://scripts/meta_progress.gd")
const XpOrbScene: PackedScene = preload("res://scenes/xp_orb.tscn")

var _orbs: Array[Node] = []


class FakeCollector extends Node2D:
	var exp_gain_percent: float = 0.5


func _orb(pos: Vector2, team: int = -1, value: float = 5.0) -> Node2D:
	var o: Node2D = XpOrbScene.instantiate() as Node2D
	o.set("xp_value", value)
	o.global_position = pos
	if team >= 0:
		o.set_meta(T.KILL_TEAM_META, team)
	add_child(o)
	_orbs.append(o)
	return o


func _cleanup() -> void:
	for o in _orbs:
		if is_instance_valid(o):
			o.free()
	_orbs.clear()
	GM.set_room_mode(GM.COOP)
	Teams.by_peer = {}
	NetworkManager.is_multiplayer_active = false
	DropMerge.reset()


func test_definition_is_passive_and_numbers_match() -> void:
	assert(S.is_valid(S.TOPLAYICI) and S.ORDER.has(S.TOPLAYICI), "Toplayıcı tanımlı ve seçim listesinde")
	assert(S.is_active_skill(S.TOPLAYICI), "Toplayıcı F ile aktif (2026-11-15)")
	assert(ResourceLoader.exists(str(S.get_def(S.TOPLAYICI).get("icon", ""))), "ikon dosyası var")
	assert(is_equal_approx(S.toplayici_range_bonus(false), 0.40) and is_equal_approx(S.toplayici_range_bonus(true), 0.20), "menzil +%40 / 2v2 +%20")
	assert(S.toplayici_interval(false) == 60.0 and S.toplayici_interval(true) == 90.0, "aralık 60 / 2v2 90 sn")
	assert(int(MetaProgress.COSTS[MetaProgress.SPIRIT].get("toplayici", 0)) > 0, "Ruh Mağazası fiyatı (kilitli)")


func test_pulled_orb_ignores_collector_xp_bonus() -> void:
	var o: Node2D = _orb(Vector2(50, 0))
	var c := FakeCollector.new()
	add_child(c)
	assert(float(o.call("gain_mult_for", c)) > 1.0, "normal toplamada XP bonusu işler")
	T.apply([o], -1)
	assert(is_equal_approx(float(o.call("gain_mult_for", c)), 1.0), "çekilen kristalde XP bonusu işlemez")
	c.free()
	_cleanup()


func test_coop_pick_takes_only_visible_free_orbs_and_release_drops_them() -> void:
	var near: Node2D = _orb(Vector2(120, 0))
	var far: Node2D = _orb(Vector2(90000, 0))
	var claimed: Node2D = _orb(Vector2(60, 30))
	claimed.set_meta("claimed", true)
	var magnet: Node2D = _orb(Vector2(-60, 0))
	magnet.call("attract_to_player", 7)
	var picked: Array = T.pick(get_tree(), Vector2.ZERO, 0)
	assert(picked.size() == 2 and picked.has(near) and picked.has(far), "haritadaki boştaki TÜM kristaller (görüş sınırı yok): %s" % [picked])
	assert(not picked.has(claimed) and not picked.has(magnet))
	T.apply(picked, -1)
	assert(near.get("is_magnetized") == true and near.has_meta(T.PULLED_META), "çekilen kristal yola çıkar")
	assert(T.release(get_tree(), -1) == 2, "kesme yalnız bu oyuncunun çekişini bırakır")
	assert(near.get("is_magnetized") == false and not near.has_meta(T.PULLED_META), "kesilen kristal yerinde kalır")
	assert(magnet.get("is_magnetized") == true, "başkasının mıknatısı etkilenmez")
	_cleanup()


func test_pvp_pulls_only_own_team_orbs() -> void:
	NetworkManager.is_multiplayer_active = true
	GM.set_room_mode(GM.PVP)
	Teams.by_peer = {1: 0, 2: 1}
	assert(GM.is_pvp(), "test 2v2 kipinde")
	assert(T.kill_team_of(2) == 1 and T.kill_team_of(1) == 0, "öldürenin takımı")
	var mine: Node2D = _orb(Vector2(100, 0), 0)
	var theirs: Node2D = _orb(Vector2(-100, 0), 1)
	var untagged: Node2D = _orb(Vector2(0, 100))
	var picked: Array = T.pick(get_tree(), Vector2.ZERO, 0)
	assert(picked == [mine], "yalnız kendi takımının kristali: %s" % [picked])
	assert(not picked.has(theirs) and not picked.has(untagged))
	_cleanup()


func test_merge_never_mixes_kill_teams() -> void:
	DropMerge.reset()
	DropMerge.xp_cap = 300
	var a: Node2D = _orb(Vector2(0, 0), 0, 5.0)
	a.set("xp_tier", 1)
	assert(not DropMerge.absorb_xp(Vector2(10, 0), 1, 3.0, 1), "başka takımın kristaline karışmaz")
	assert(DropMerge.absorb_xp(Vector2(10, 0), 1, 3.0, 0), "aynı takımınkine karışır")
	assert(is_equal_approx(float(a.get("xp_value")), 8.0))
	_cleanup()
