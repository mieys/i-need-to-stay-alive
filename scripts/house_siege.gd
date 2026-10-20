extends Node
class_name HouseSiege

## EV KUŞATMASI (kullanıcı isteği 2026-10-19, madde 313): "oyuncular evde 10 saniyeden çok beklediği müddetçe evin canı azalsın ...
## evin belli bir canı olsun (yaratıkların verdiği hasarla değil süreye göre hesaplanan) ... 5 dakika dayanabilecek ... oyuncu evde değilken
## ve dışarıda savaşınca evin canı otomatik olarak yavaşça artacak. ev yıkılırsa büyükanne ve oyuncular dışarı atılır, büyükanne
## savaşamaz canı 100'dür ve öldürülürse bir daha diriltilemez."
##  - KARAR HOST'TA (tekli oyunda yerel): içerideki canlı oyuncuların kesintisiz içeride kalma süresi izlenir; biri GRACE_SECONDS'i geçince
##    ev saniyede DRAIN_PER_SEC can kaybeder (oyuncu sayısından bağımsız -> MAX_HP / DRAIN = 5 dk). Kimse içeride değilken ve dışarıdaki
##    canlı bir oyuncunun COMBAT_RADIUS yakınında yaratık varken (savaşıyor) saniyede REGEN_PER_SEC onarılır.
##  - Can 0 -> YIKILIŞ: herkes (yerelde) içerideyse dışarı atılır, kapı kapanır, babaanne dışarı çıkar (house_interior.gd collapsed sinyali).
##    Ev REOPEN_RATIO'ya onarılınca kapı yeniden açılır, babaanne (yaşıyorsa) eve döner.
##  - Babaanne canı da burada (yaratıklar yalnız host'ta vurur -> granny_damage; ölüm kalıcı, GameManager.babaanne_dead).
##  - Eşitleme: host saniyede bir + her olayda güvenilir RPC (bu düğüm: Main/HouseInterior/HouseSiege, her peer'de aynı yol);
##    sonradan katılan/geri gelen oyuncuya NetworkManager.peer_needs_game_catchup ile tam durum.
##  - Görseller/ses (çatlak, dökülen parçalar, boğuk vuruşlar) house_damage_fx.gd - bu düğümün durumunu okur, ağ trafiği yok.
##  - KUŞATMACILAR (kullanıcı: "dışarı çıkınca yaratıklar evin etrafını sarmış gibi görünmüyor, uzakta spawn oluyorlar"): host saldırı
##    başlayınca ve ev saldırı altındayken evin çevresinde BESIEGE_BASE (+oyuncu başına) yaratık tutar (enemy_spawner.spawn_besieger,
##    evden 260-420 px uzakta doğar). Evin BESIEGE_WAKE_RADIUS yakınında dışarıda canlı oyuncu yokken C++ "uykuda" (oyuncu hedeflemez) ve
##    duvarların dibindeki noktalara yürüyüp orada dolanır (set_dormant + set_goal, guard_camps.gd ile aynı); oyuncu çıkınca uyanır, saldırır.

signal collapsed_changed(is_collapsed: bool)
signal granny_hp_changed(hp: float, dead: bool)
signal attack_started

const MAX_HP := 300.0
const DRAIN_PER_SEC := 1.0 ## 300 / 1 = 5 dk
const GRACE_SECONDS := 10.0
## 2026-10-19 (kullanıcı: "evin canı çok hızlı doluyor"; BALANCE_REV 82) 0,5 -> 0,25: dışarıda hemen her an yaratık olduğu için kimse
## içeride değilken ev neredeyse hep onarılıyordu. Artık evde geçen 1 dk'yı (60 can) geri kazanmak 4 dk savaş.
const REGEN_PER_SEC := 0.25 ## sıfırdan tam cana 20 dk savaş
const REOPEN_RATIO := 0.4 ## yıkılan ev %40'a onarılınca kapı açılır (sıfırdan 8 dk savaş)
const COMBAT_RADIUS := 480.0
const COMBAT_CHECK_SECONDS := 1.0
const SYNC_SECONDS := 1.0
const GRANNY_MAX_HP := 100.0
## Dışarıda kaçan babaannenin konumu (host'ta yürür, istemciler bu konuma yürür - babaanne_npc.gd _follow_net).
const GRANNY_POS_SECONDS := 0.12
const BESIEGE_BASE := 6
const BESIEGE_PER_PLAYER := 2
const BESIEGE_TOPUP_SECONDS := 6.0
const BESIEGE_SPAWN_PER_TICK := 4
const BESIEGE_WAKE_RADIUS := 600.0
const BESIEGE_SPAWN_RING := Vector2(260.0, 420.0) ## ev merkezinden doğma uzaklığı
const BESIEGE_WALL_GAP := Vector2(10.0, 36.0) ## duvar dibindeki hedef noktaların evin dikdörtgenine uzaklığı
const BESIEGE_GOAL_SPEED := 0.6
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const F_COLLAPSED := 1
const F_ATTACK := 2
const F_REGEN := 4

var hp: float = MAX_HP
var collapsed: bool = false
var under_attack: bool = false
var regenerating: bool = false
var granny_hp: float = GRANNY_MAX_HP
var granny_dead: bool = false

const SMITHY_INTERIOR_OFFSET: Vector2 = preload("res://scripts/weapon_shop.gd").INTERIOR_OFFSET ## demirci iç mekanı (ev DEĞİL)
const SMITHY_INTERIOR_RADIUS: float = 3000.0 ## weapon_shop.gd is_interior_position ile aynı

var _inside_time: Dictionary = {} ## örnek kimliği -> kesintisiz içeride geçen sn (host)
var _sync_acc: float = 0.0
var _combat_acc: float = 0.0
var _in_combat: bool = false
var test_combat: int = -1
var granny_net_pos: Vector2 = Vector2.INF ## istemci: host'tan gelen son babaanne ayak konumu (dünya)
var house_rect: Rect2 = Rect2() ## dışarıdaki evin dünya dikdörtgeni (house_interior.gd verir); boşsa kuşatmacı yok
var _besiegers: Array[Node2D] = []
var _besiege_tick: float = 0.0
var _besiege_topup: float = 0.0
var _besieged_once: bool = false
var _besiege_fill_tries: int = 0
var _besiege_awake: bool = true
var _gpos_acc: float = 0.0 ## testler: 1 = dışarıda savaş var, 0 = yok (EnemyQuery yerine)


func _ready() -> void:
	name = "HouseSiege"
	if not NetworkManager.peer_needs_game_catchup.is_connected(_send_catchup):
		NetworkManager.peer_needs_game_catchup.connect(_send_catchup)


func ratio() -> float:
	return clampf(hp / MAX_HP, 0.0, 1.0)


func is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func _process(delta: float) -> void:
	if not is_authority():
		return
	_sync_granny_pos(delta)
	if GameManager.is_game_over or GameManager.invasion_pending:
		if under_attack or regenerating:
			under_attack = false
			regenerating = false
			_broadcast_state()
		_inside_time.clear()
		return
	var outside: Array = _living_players(false)
	step(delta, _living_players(true), outside)
	_tick_besiegers(delta, outside)


## Host adımı (testler doğrudan çağırır): inside/outside = içerideki / dışarıdaki canlı oyuncu düğümleri.
func step(delta: float, inside: Array, outside: Array) -> void:
	var live: Dictionary = {}
	var longest: float = 0.0
	for p: Node in inside:
		var id: int = p.get_instance_id()
		live[id] = true
		_inside_time[id] = float(_inside_time.get(id, 0.0)) + delta
		longest = maxf(longest, float(_inside_time[id]))
	for id in _inside_time.keys():
		if not live.has(id):
			_inside_time.erase(id)
	var was_attack: bool = under_attack
	var was_regen: bool = regenerating
	under_attack = not collapsed and longest >= GRACE_SECONDS
	regenerating = false
	if under_attack:
		hp = maxf(0.0, hp - DRAIN_PER_SEC * delta)
		if hp <= 0.0:
			_collapse_host()
			return
	elif inside.is_empty() and hp < MAX_HP:
		_combat_acc -= delta
		if _combat_acc <= 0.0:
			_combat_acc = COMBAT_CHECK_SECONDS
			_in_combat = _anyone_fighting(outside)
		if _in_combat:
			hp = minf(MAX_HP, hp + REGEN_PER_SEC * delta)
			regenerating = true
			if collapsed and hp >= MAX_HP * REOPEN_RATIO:
				_reopen_host()
				return
	if under_attack and not was_attack:
		attack_started.emit()
	_sync_acc += delta
	if was_attack != under_attack or was_regen != regenerating or _sync_acc >= SYNC_SECONDS:
		_broadcast_state()


func _living_players(want_inside: bool) -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	for p: Node2D in NpcActor.live_players(get_tree()):
		if p.get("is_downed") == true:
			continue
		## Demirci iç mekanı da is_indoors yapar ama EV DEĞİL: orada durmak evin canını yemez, "dışarıda savaşıyor" da sayılmaz.
		if in_smithy(p):
			continue
		var inside: bool = bool(p.call("is_indoors_now")) if p.has_method("is_indoors_now") else p.get("is_indoors") == true
		if inside == want_inside:
			out.append(p)
	return out


## Oyuncu demirci iç mekanında mı (is_indoors orada da true; evin iç mekanı değil).
static func in_smithy(p: Node) -> bool:
	return p is Node2D and (p as Node2D).global_position.distance_to(SMITHY_INTERIOR_OFFSET) < SMITHY_INTERIOR_RADIUS


## Oyuncu EVİN içinde mi (demirci hariç) - ev canı çubuğu/sarsıntı/drenaj bunu kullanır.
static func in_house(p: Node) -> bool:
	if p == null or in_smithy(p):
		return false
	return bool(p.call("is_indoors_now")) if p.has_method("is_indoors_now") else p.get("is_indoors") == true


## Dışarıdaki canlı bir oyuncunun yakınında yaratık var mı (saniyede bir; "enemies" taraması yerine EnemyQuery).
func _anyone_fighting(outside: Array) -> bool:
	if test_combat >= 0:
		return test_combat == 1
	if not is_inside_tree():
		return false
	for p: Node in outside:
		if not (p is Node2D):
			continue
		for e: Node in EnemyQueryScript.candidates(get_tree(), (p as Node2D).global_position, COMBAT_RADIUS):
			if is_instance_valid(e) and e.get("is_dead") != true:
				return true
	return false


const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")


# ------------------------------------------------------------------ kuşatmacılar (host)

func _tick_besiegers(delta: float, outside: Array) -> void:
	if house_rect.size == Vector2.ZERO or not is_inside_tree():
		return
	_besiege_tick -= delta
	_besiege_topup -= delta
	if _besiege_tick > 0.0:
		return
	_besiege_tick = 0.5
	var alive: Array[Node2D] = []
	for e: Node2D in _besiegers:
		if is_instance_valid(e) and e.get("is_dead") != true and not e.is_queued_for_deletion():
			alive.append(e)
	_besiegers = alive
	var center: Vector2 = house_rect.get_center()
	var awake: bool = false
	for p: Node in outside:
		if p is Node2D and (p as Node2D).global_position.distance_to(center) <= BESIEGE_WAKE_RADIUS:
			awake = true
			break
	## doldurma: saldırı başlar başlamaz bir kez, sonra ev saldırı altındayken (oyuncular içeride oyalanırken kuşatma kalabalıklaşır)
	if (not _besieged_once or under_attack) and _besiege_topup <= 0.0:
		var want: int = BESIEGE_BASE + BESIEGE_PER_PLAYER * maxi(0, _player_count() - 1)
		var spawner: Node = get_tree().current_scene.get_node_or_null("EnemySpawner") if get_tree().current_scene != null else null
		if spawner != null and spawner.has_method("spawn_besieger"):
			var n: int = mini(want - _besiegers.size(), BESIEGE_SPAWN_PER_TICK)
			for i in n:
				var pos: Vector2 = besiege_spawn_point(center)
				if not pos.is_finite():
					continue
				var e: Node = spawner.call("spawn_besieger", pos)
				if e is Node2D:
					_besiegers.append(e)
			_besiege_fill_tries += 1
			## ilk dalga hedefe kadar dolar (tur başına BESIEGE_SPAWN_PER_TICK); doğurucu dolmazsa birkaç denemeden sonra bırakır
			_besieged_once = _besiegers.size() >= want or _besiege_fill_tries >= 6
			_besiege_topup = 0.5 if _besiegers.size() < want else BESIEGE_TOPUP_SECONDS
	var world: Object = EnemyWorldBridgeScript.fog_world(get_tree())
	if world == null:
		return
	for e: Node2D in _besiegers:
		var v: Variant = e.get("_ew_slot")
		var slot: int = int(v) if v != null else -1
		if slot < 0:
			continue
		var was_set: bool = e.has_meta("besiege_dormant")
		if awake:
			if not was_set or bool(e.get_meta("besiege_dormant")):
				world.call("set_goal", slot, 0.0, 0.0, 0.0)
				world.call("set_dormant", slot, false)
				e.set_meta("besiege_dormant", false)
			continue
		var t: float = float(e.get_meta("besiege_goal_t", 0.0)) - 0.5
		if not was_set or not bool(e.get_meta("besiege_dormant")) or t <= 0.0:
			world.call("set_dormant", slot, true)
			var g: Vector2 = wall_point()
			if g.is_finite():
				world.call("set_goal", slot, g.x, g.y, BESIEGE_GOAL_SPEED)
			e.set_meta("besiege_dormant", true)
			t = randf_range(3.0, 6.0) ## duvar dibinde bir sonraki noktaya (dolanır)
		e.set_meta("besiege_goal_t", t)
	_besiege_awake = awake


func _player_count() -> int:
	return maxi(1, NetworkManager.lobby_players.size()) if NetworkManager.is_multiplayer_active else 1


## Evin merkezinden BESIEGE_SPAWN_RING uzaklıkta, duvar/su/bina olmayan nokta.
func besiege_spawn_point(center: Vector2) -> Vector2:
	for i in 16:
		var p: Vector2 = center + Vector2.from_angle(randf() * TAU) * randf_range(BESIEGE_SPAWN_RING.x, BESIEGE_SPAWN_RING.y)
		if not GameManager.is_position_blocked_by_walls(p):
			return p
	return Vector2.INF


## Evin duvarlarının dibinde (dikdörtgenin BESIEGE_WALL_GAP dışında) rastgele açık nokta.
func wall_point() -> Vector2:
	var r: Rect2 = house_rect
	for i in 16:
		var gap: float = randf_range(BESIEGE_WALL_GAP.x, BESIEGE_WALL_GAP.y)
		var side: int = randi() % 4
		var p: Vector2
		match side:
			0: p = Vector2(randf_range(r.position.x, r.end.x), r.position.y - gap)
			1: p = Vector2(randf_range(r.position.x, r.end.x), r.end.y + gap)
			2: p = Vector2(r.position.x - gap, randf_range(r.position.y, r.end.y))
			_: p = Vector2(r.end.x + gap, randf_range(r.position.y, r.end.y))
		if not GameManager.is_position_blocked_by_walls(p):
			return p
	return Vector2.INF


func besieger_count() -> int:
	return _besiegers.size()


# ------------------------------------------------------------------ olaylar (host)

func _collapse_host() -> void:
	hp = 0.0
	under_attack = false
	regenerating = false
	_inside_time.clear()
	_apply_collapsed(true)


func _reopen_host() -> void:
	under_attack = false
	_apply_collapsed(false)


func _flags() -> int:
	return (F_COLLAPSED if collapsed else 0) | (F_ATTACK if under_attack else 0) | (F_REGEN if regenerating else 0)


func _broadcast_state() -> void:
	_sync_acc = 0.0
	if not NetworkManager.is_multiplayer_active or not NetworkManager.is_host:
		return
	var f: int = _flags()
	for pid in NetworkManager.game_ready_peers():
		_rpc_state.rpc_id(int(pid), hp, f)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_state(new_hp: float, flags: int) -> void:
	if not NetworkManager._from_host():
		return
	apply_state(new_hp, flags)


## İstemci (ve testler): host'tan gelen durum.
func apply_state(new_hp: float, flags: int) -> void:
	hp = clampf(new_hp, 0.0, MAX_HP)
	var was_attack: bool = under_attack
	under_attack = (flags & F_ATTACK) != 0
	regenerating = (flags & F_REGEN) != 0
	if under_attack and not was_attack:
		attack_started.emit()
	var c: bool = (flags & F_COLLAPSED) != 0
	if c != collapsed:
		_apply_collapsed(c)


func _apply_collapsed(c: bool) -> void:
	if c == collapsed:
		return
	collapsed = c
	if c:
		hp = 0.0
	if is_authority():
		_broadcast_state() ## yıkılış/açılış olayı hemen (saniyelik paketi beklemeden)
	collapsed_changed.emit(c)


# ------------------------------------------------------------------ babaanne canı

## Host: yaratık babaanneye vurdu (babaanne_npc.gd take_damage). Ölüm kalıcı.
func granny_damage(amount: float) -> void:
	if not is_authority() or granny_dead or amount <= 0.0:
		return
	_set_granny(maxf(0.0, granny_hp - amount), granny_hp - amount <= 0.0)
	if NetworkManager.is_multiplayer_active:
		for pid in NetworkManager.game_ready_peers():
			_rpc_granny.rpc_id(int(pid), granny_hp, granny_dead)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_granny(new_hp: float, dead: bool) -> void:
	if not NetworkManager._from_host():
		return
	_set_granny(new_hp, dead)


func _set_granny(new_hp: float, dead: bool) -> void:
	if granny_dead:
		return
	granny_hp = clampf(new_hp, 0.0, GRANNY_MAX_HP)
	if dead:
		granny_dead = true
		granny_hp = 0.0
		GameManager.babaanne_dead = true
	granny_hp_changed.emit(granny_hp, granny_dead)


## Host: dışarıdaki (canlı, eve yönelmemiş) babaannenin ayak konumu saniyede ~8 kez, sırasız-kaybolabilir kanaldan.
func _sync_granny_pos(delta: float) -> void:
	if not NetworkManager.is_multiplayer_active or not NetworkManager.is_host:
		return
	var g: Node2D = GameManager.babaanne_target
	if not is_instance_valid(g) or not g.has_method("feet_world"):
		return
	_gpos_acc += delta
	if _gpos_acc < GRANNY_POS_SECONDS:
		return
	_gpos_acc = 0.0
	var p: Vector2 = g.call("feet_world")
	for pid in NetworkManager.game_ready_peers():
		_rpc_granny_pos.rpc_id(int(pid), p)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rpc_granny_pos(p: Vector2) -> void:
	if not NetworkManager._from_host():
		return
	granny_net_pos = p


# ------------------------------------------------------------------ yakalama

func _send_catchup(peer_id: int) -> void:
	if not is_inside_tree() or not NetworkManager.is_host:
		return
	_rpc_state.rpc_id(peer_id, hp, _flags())
	_rpc_granny.rpc_id(peer_id, granny_hp, granny_dead)
