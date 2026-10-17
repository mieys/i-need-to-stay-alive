extends Node

## 2026-10-14 (kullanıcı): Şovalye E hasar emme anı "D - Yankı Darbesi" (fx_sovalye_echo.gd) + Melek E kalkan bağı artık
## Şovalye prototipi A'nın uçan kırıntıları (fx_shard_stream.gd). Çizim (_draw) doğrudan çağrılamaz - burada yaşam döngüsü,
## takip, kısma ve ağ dalları (iki-yer kuralı: alıcı istemci de aynı sahneyi kurar) test edilir.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _remote(peer: int, pos: Vector2) -> Node2D:
	var rp: Node2D = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(peer, 7, "P%d" % peer)
	rp.global_position = pos
	return rp


func _count(script_suffix: String) -> int:
	var n: int = 0
	for c in get_tree().current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str(sc.resource_path).ends_with(script_suffix) and not c.is_queued_for_deletion():
			n += 1
	return n


func _free_fx() -> void:
	for c in get_tree().current_scene.get_children():
		var sc: Variant = c.get_script()
		if sc != null and (str(sc.resource_path).ends_with("fx_sovalye_echo.gd") or str(sc.resource_path).ends_with("fx_shard_stream.gd") \
				or str(sc.resource_path).ends_with("fx_wave_beam.gd")):
			c.free()


func _cleanup() -> void:
	_free_fx()
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _ensure_scene() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self


func _run_until_freed(fx: Node, max_sec: float) -> float:
	var t: float = 0.0
	while is_instance_valid(fx) and not fx.is_queued_for_deletion() and t < max_sec:
		fx._process(0.016)
		t += 0.016
	return t


func test_echo_follows_both_ends_and_frees() -> void:
	_ensure_scene()
	var ally := _remote(91, Vector2(100, 100))
	var knight := _remote(92, Vector2(190, 80))
	var fx: Node2D = load("res://scripts/fx_sovalye_echo.gd").new()
	get_tree().current_scene.add_child(fx)
	fx.setup(ally, knight, PI, true)
	fx._process(0.05)
	knight.global_position = Vector2(220, 60)
	fx._process(0.05)
	var seg: Array = fx.get_glow_segment()
	assert(seg[0] == ally.global_position and seg[1] == knight.global_position, "yay iki ucu da takip etmeli")
	var t: float = _run_until_freed(fx, 2.0)
	assert(t < 0.5, "Yankı Darbesi kısa ömürlü (~0,33 sn) olmalı: %.2f" % t)
	_cleanup()


func test_shard_stream_starts_detached_and_homes_on_target() -> void:
	_ensure_scene()
	var target := _remote(93, Vector2(260, 140))
	var fx: Node2D = load("res://scripts/fx_shard_stream.gd").new()
	get_tree().current_scene.add_child(fx)
	fx.setup(Vector2(100, 100), target, "melek_shield")
	fx._process(0.05)
	target.global_position = Vector2(300, 180)
	fx._process(0.05)
	var seg: Array = fx.get_glow_segment()
	assert(seg[0] == Vector2(100, 100), "kalkış noktası sabit kalmalı (kırıntılar kaynaktan kopuk)")
	assert(seg[1] == target.global_position, "uç hedefi takip etmeli")
	var t: float = _run_until_freed(fx, 3.0)
	assert(t < 1.4, "kırıntılar uçuş + varıştan sonra silinmeli: %.2f" % t)
	_cleanup()


## İki-yer kuralı: dostun yayınladığı "sovalye_echo" alıcıda da kurulur - Şovalye bu istemcinin kendisi de olabilir.
func test_network_echo_branch_spawns_on_receivers() -> void:
	_ensure_scene()
	_remote(94, Vector2(100, 100))
	_remote(95, Vector2(190, 90))
	NetworkManager.broadcast_player_vfx(94, "sovalye_echo", Vector2(100, 100), {"k": 95, "a": PI, "b": false})
	assert(_count("fx_sovalye_echo.gd") == 1, "kuklalar arasında yankı kurulmalı")
	## Şovalye = bu istemcinin yerel oyuncusu ("player" grubu)
	var local := Node2D.new()
	local.add_to_group("player")
	add_child(local)
	_spawned.append(local)
	NetworkManager.broadcast_player_vfx(94, "sovalye_echo", Vector2(100, 100), {"k": multiplayer.get_unique_id(), "a": 0.0, "b": true})
	assert(_count("fx_sovalye_echo.gd") == 2, "Şovalye yerel oyuncuysa da kurulmalı")
	## bilinmeyen Şovalye -> sessizce yok
	NetworkManager.broadcast_player_vfx(94, "sovalye_echo", Vector2(100, 100), {"k": 4242, "a": 0.0, "b": false})
	assert(_count("fx_sovalye_echo.gd") == 2)
	_cleanup()


## 2026-10-17 (madde 212): Melek Q/E tikleri artık dostun SİHİRLİ BAĞINA dalga paketi (melek_bond_fx.gd pulse, ayrıntı
## tests/test_melek_bond_fx.gd) - ne kırıntı ne dalga ışını kurulur.
func test_wave_fx_heal_and_shield_no_longer_spawn_streams_or_beams() -> void:
	_ensure_scene()
	var caster := _remote(96, Vector2(100, 100))
	var target := _remote(97, Vector2(200, 100))
	NetworkManager.broadcast_wave_fx(caster.global_position, String(target.get_path()), "shield", 96, 97)
	NetworkManager.broadcast_wave_fx(caster.global_position, String(target.get_path()), "heal", 96, 97)
	assert(_count("fx_shard_stream.gd") == 0, "kalkan bağı artık kırıntı DEĞİL")
	assert(_count("fx_wave_beam.gd") == 0, "can bağı artık dalga ışını DEĞİL")
	_cleanup()


## Dost tarafı: aktarımda yerel yankı kurulur, sık tikler SOVALYE_ECHO_MIN_INTERVAL ile kısılır.
func test_player_echo_is_throttled() -> void:
	_ensure_scene()
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 4
	NetworkManager.is_multiplayer_active = false
	var player: Node2D = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(2000, 2000)
	_remote(98, Vector2(2080, 1990))
	player.damage_redirect_peer_id = 98
	player.damage_redirect_percent = 0.3
	player._sovalye_echo_fx(null, 10.0)
	player._sovalye_echo_fx(null, 10.0)
	assert(_count("fx_sovalye_echo.gd") == 1, "aynı anda gelen ikinci aktarım görseli kısılmalı")
	player._sovalye_echo_next_msec = 0
	player._sovalye_echo_fx(null, 10.0)
	assert(_count("fx_sovalye_echo.gd") == 2, "aralık geçince yine kurulmalı")
	player.damage_redirect_peer_id = 4343
	player._sovalye_echo_next_msec = 0
	player._sovalye_echo_fx(null, 10.0)
	assert(_count("fx_sovalye_echo.gd") == 2, "Şovalye kuklası yoksa görsel yok")
	_cleanup()


## 2026-10-15 (kullanıcı): Şovalye E koruması menzil dışına çıkınca düşer, menzile dönünce geri gelir; E açıkken sonradan yaklaşan
## dost da faydalanır (_process_paladin_barrier_roster).
func test_barrier_roster_drops_and_regrants_by_range() -> void:
	_ensure_scene()
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 4
	NetworkManager.is_multiplayer_active = false
	var player: Node2D = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(2000, 2000)
	var near := _remote(81, Vector2(2100, 2000))
	var far := _remote(82, Vector2(2900, 2000))
	player.paladin_guard_active = true
	player._barrier_end_msec = Time.get_ticks_msec() + 10000
	player._barrier_buffed_allies.clear()
	player._process_paladin_barrier_roster(1.0)
	assert(player._barrier_buffed_allies.has(near), "yakın dost korunmalı")
	assert(not player._barrier_buffed_allies.has(far), "uzak dost başta korunmaz")
	far.global_position = Vector2(2150, 2000)
	player._process_paladin_barrier_roster(1.0)
	assert(player._barrier_buffed_allies.has(far), "E açıkken yaklaşan dost da korunmalı")
	far.global_position = Vector2(2900, 2000)
	player._process_paladin_barrier_roster(1.0)
	assert(not player._barrier_buffed_allies.has(far), "uzaklaşan dostun koruması düşmeli")
	far.global_position = Vector2(2100, 2050)
	player._process_paladin_barrier_roster(1.0)
	assert(player._barrier_buffed_allies.has(far), "yeniden yaklaşan dost tekrar korunmalı")
	_cleanup()
