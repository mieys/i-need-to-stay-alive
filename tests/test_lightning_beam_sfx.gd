extends Node

## Yıldırım Asası VURUŞ sesleri (2026-10-19, madde 294; kullanıcı: "hasar verdiğimizi hissettirsin" + "ilk yıldırım için de efekt"):
## ışın tikinde hedefte vuruş sesi (kritikte ağır), ortak ateş sesi (fire.mp3) ÇALMAZ, uğultu çöker; ilk çakış sahip başına 0,5 sn'de bir;
## sık tikte vuruş kısılır. Gerçek oyuncu + gerçek asa (test_assasin_passive.gd düzeni).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const BeamScene: PackedScene = preload("res://scenes/fx_lightning_beam.tscn")
const BeamFx := preload("res://scripts/fx_lightning_beam.gd")
const MATTHEW := 3


class FakeEnemy extends Node2D:
	var is_dead: bool = false

	func take_damage(_amount: float, _is_crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		pass


var _spawned: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1


func _setup() -> Array:
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = MATTHEW
	GameManager.selected_character = int(Characters.DEFS[MATTHEW]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
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
	var fx: Node = BeamScene.instantiate()
	add_child(fx)
	_spawned.append(fx)
	fx.setup(w, target)
	w._beam_fx = fx ## ışın açık (weapon.gd _process_continuous_beam'in kurduğu hâl)
	BeamFx._last_strike_ms.clear()
	return [p, w, target, fx]


func _one_shots() -> Array:
	var out: Array = []
	for c in get_children():
		if c is AudioStreamPlayer2D and not _spawned.has(c):
			out.append(c)
	return out


func _cleanup() -> void:
	for c in _one_shots():
		c.free()
	NetworkManager.is_multiplayer_active = false
	GameManager.owned_weapons = []
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene


func test_tick_plays_hit_sound_at_target_instead_of_shared_fire_sound() -> void:
	var s := _setup()
	var p: Node = s[0]
	var w: Node = s[1]
	var target: Node2D = s[2]
	var fx: Node = s[3]
	p.fire_sound.stop()
	w._deal_beam_tick(target)
	var shots := _one_shots()
	assert(shots.size() == 1, "tikte tek vuruş sesi: %d" % shots.size())
	var a: AudioStreamPlayer2D = shots[0]
	assert(BeamFx.HIT_STREAMS.has(a.stream), "normal tik = vuruş dosyalarından biri")
	assert(a.global_position == target.global_position, "ses hedefin konumunda")
	assert(a.is_playing(), "çalıyor")
	assert(not p.fire_sound.is_playing(), "ışın tikinde ortak ateş sesi (fire.mp3) ÇALMAZ")
	assert(fx._duck_left > 0.0, "uğultu tikte çöker")
	_cleanup()


func test_crit_tick_uses_heavy_sound_and_ticks_do_not_repeat_same_file() -> void:
	var s := _setup()
	var w: Node = s[1]
	var target: Node2D = s[2]
	w.crit_chance = 1.0
	w._deal_beam_tick(target)
	assert(_one_shots().size() == 1 and _one_shots()[0].stream == BeamFx.CRIT_STREAM, "kritik tik = ağır vuruş")
	w.crit_chance = 0.0
	var last: AudioStream = null
	for i in range(12):
		for c in _one_shots():
			c.free()
		w._deal_beam_tick(target)
		var st: AudioStream = _one_shots()[0].stream
		assert(st != last, "art arda aynı vuruş dosyası çalmaz")
		last = st
	_cleanup()


func test_strike_is_rate_limited_per_owner() -> void:
	var s := _setup()
	var fx: Node = s[3]
	fx.play_strike_sfx(Vector2(10, 10), 42)
	fx.play_strike_sfx(Vector2(20, 10), 42)
	assert(_one_shots().size() == 1, "aynı sahip 0,5 sn içinde ikinci ilk çakışı çalmaz")
	assert(_one_shots()[0].stream == BeamFx.STRIKE_STREAM and _one_shots()[0].global_position == Vector2(10, 10), "ilk çakış konumda")
	fx.play_strike_sfx(Vector2(30, 10), 43)
	assert(_one_shots().size() == 2, "başka sahip (uzak oyuncu) bağımsız")
	_cleanup()


func test_faster_ticks_are_quieter_and_remote_hit_fades_like_other_weapons() -> void:
	assert(is_equal_approx(BeamFx.rate_db(0.5), 0.0) and is_equal_approx(BeamFx.rate_db(0.9), 0.0), "taban ve yavaş tik kısılmaz")
	assert(absf(BeamFx.rate_db(0.25) + 3.0103) < 0.01, "yarı aralık = -3 dB (sn başına enerji sabit)")
	var prev: Node = get_tree().current_scene
	get_tree().current_scene = self
	BeamFx.play_hit_at(get_tree(), Vector2(5, 5), {"crit": false, "i": 2, "p": 1.03, "r": -2.0}, -1.4, true)
	var a: AudioStreamPlayer2D = _one_shots()[0]
	assert(a.stream == BeamFx.HIT_STREAMS[2] and is_equal_approx(a.pitch_scale, 1.03), "uzakta kasterin seçtiği dosya + perde")
	assert(is_equal_approx(a.volume_db, BeamFx.HIT_DB - 2.0 - 1.4), "uzak kısma + sıklık kısması")
	assert(is_equal_approx(a.max_distance, 900.0) and is_equal_approx(a.attenuation, 1.6), "başkasının silahı gibi erken söner")
	for c in _one_shots():
		c.free()
	get_tree().current_scene = prev
