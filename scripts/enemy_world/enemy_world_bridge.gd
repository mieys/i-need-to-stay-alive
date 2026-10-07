extends Node

## EnemyWorld köprüsü (yaratık yeniden yazımı, bkz. docs/yaratik_yeniden_yazim/PLAN.md §4.1). current_scene'in çocuğu
## ("EnemyWorldBridge"); eklenti yüklüyse host / tek oyunculuda VE istemcide (2026-10-03'ten beri) kurulur. İstemcide yaratıklar
## kukla (F_PUPPET): C++ sadece ağdan gelen konumu izler, AI/saldırı olayı üretmez; sorgular, sis, y-sıralaması, minimap aynı.
##
## Her fizik karesi:
##  1. orman ızgarası değiştiyse C++'a verir (enemy_pathing.gd'nin kurduğu AYNI ızgara),
##  2. aday (hedef) listesini doldurur: yerel oyuncu, uzak oyuncular, player_allies, "Ağacı Koru" ağacı - eleme
##     kuralları enemy.gd _find_closest_target_player / _paladin_zone_owners / _is_ghost_cached ile BİREBİR,
##  3. EnemyWorld.step (hareket + AI + konum yazma),
##  4. olay kuyruğunu ilgili yaratığın enemy.gd fonksiyonuna verir (_ew_on_event: yakın saldırı, kalkana saldırı,
##     hayalet, menzilli atış, tahrik bitişi),
##  5. SADECE uyanık yaratıkların kalan GDScript işini çağırır (_ew_tick: durum etkileri, yetenekler, saldırı
##     animasyonu, değişen durum bayraklarını C++'a yazma). Uyandırma enemy.gd _ew_wake ile; kaçırılan bir uyandırmaya
##     karşı her kare kayıtların 1/SWEEP_EVERY'si taranır (durum C++'a yazılır, iş varsa uyandırılır).
## Kayıtlı yaratığın kendi _physics_process'i KAPALI; die() kaydı siler ve eski yolu (ölüm animasyonu) geri açar.

const NODE_NAME := "EnemyWorldBridge"
const EnemyPathingScript := preload("res://scripts/enemy_pathing.gd")
const PLAYER_BODY_RADIUS := 11.4 ## enemy.gd PLAYER_BODY_RADIUS - TÜM adaylar için aynı (enemy.gd de öyle kullanıyor)

const T_PLAYER := 0
const T_REMOTE := 1
const T_ALLY := 2
const T_TREE := 3
const E_LOCO := 6 ## enemy_world.h EventType
const SWEEP_EVERY := 30 ## ~0,5 sn: kaçırılmış uyandırma / dışarıdan değişen hız için güvenlik ağı (8'de 1000 yaratıkta ~0,5 ms/kare)

static var _instance: Node = null

var world: Object = null
var _by_slot: Array = [] ## slot -> yaratık düğümü (boş slot = null)
var _target_nodes: Array = [] ## bu karenin adayları (olaylar aday indeksiyle gelir)
var _active: Array = [] ## uyanık yaratıklar (_ew_tick alacaklar)
var _dying: Array = [] ## kaydı silinmiş ama hâlâ sahnede (ölüm animasyonu) - görüş sisi bunları GDScript'te yönetir
var _sweep_phase: int = 0
var _step_counter: int = 0
var _grid_layer: Object = null
var _grid_ready: bool = false

# ölçüm (bench_current / testler okur)
var last_bridge_ms: float = 0.0
var last_step_ms: float = 0.0
var last_view_ms: float = 0.0 ## last_step_ms'nin konum/kare yazma kısmı
var event_counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0]) ## olay türü başına toplam (testler)
var last_tick_ms: float = 0.0


## Bu sahnenin köprüsü (yoksa kurar). Yaratığın _ready'sinden çağrılır: o an current_scene "çocuk ekliyor" kilidinde
## olduğu için düğüm ERTELENEREK eklenir; EnemyWorld nesnesi hemen hazırdır (kayıt ağaca girmeyi beklemez).
static func get_or_create(tree: SceneTree) -> Node:
	var scene: Node = tree.current_scene
	if scene == null:
		return null
	if _instance != null and is_instance_valid(_instance) and not _instance.is_queued_for_deletion() \
			and (_instance.get_parent() == scene or _instance.get_meta("pending_parent", null) == scene):
		return _instance
	var b: Node = (load("res://scripts/enemy_world/enemy_world_bridge.gd") as GDScript).new()
	b.name = NODE_NAME
	b.set_meta("pending_parent", scene)
	scene.add_child.call_deferred(b)
	_instance = b
	return b


## enemy.gd get_enemies_near'ın EnemyWorld yolu (eski yol: her karede TÜM "enemies" grubunu GDScript'te tarayıp kurulan
## itilme ızgarası). Aynı küme: merkezi radius içinde, ölü olmayan yaratıklar + "enemies" grubundaki enemy.gd OLMAYAN
## tek üye türü olan görev kopyaları ("mission_copies"). Bu sahnede köprü yoksa null -> çağıran eski yola düşer.
static func enemies_near(tree: SceneTree, pos: Vector2, radius: float) -> Variant:
	var b: Node = _instance
	if b == null or not is_instance_valid(b) or not b.is_inside_tree() or b.get_tree() != tree:
		return null
	if radius <= 0.0:
		return []
	var res: Array = b.world.call("query_points", pos, radius)
	var r2: float = radius * radius
	for c: Node in tree.get_nodes_in_group("mission_copies"):
		if is_instance_valid(c) and c.is_in_group("enemies") and not (c.get("is_dead") == true) \
				and pos.distance_squared_to((c as Node2D).global_position) <= r2:
			res.append(c)
	return res


func _init() -> void:
	world = ClassDB.instantiate("EnemyWorld")
	world.call("set_body_block_scale", GameManager.BODY_BLOCK_SCALE)
	add_child(world)


func register(e: Node2D, sprite: Object, params: Dictionary) -> int:
	var slot: int = int(world.call("add_enemy", e, sprite, e.global_position, params))
	while _by_slot.size() <= slot:
		_by_slot.append(null)
	_by_slot[slot] = e
	return slot


func unregister(slot: int) -> void:
	if slot < 0 or slot >= _by_slot.size():
		return
	var e = _by_slot[slot]
	_by_slot[slot] = null
	world.call("remove_enemy", slot)
	if e != null and is_instance_valid(e) and e.is_inside_tree() and not e.is_queued_for_deletion():
		_dying.append(e)


## Görüş sisi (vision_fog.gd) yeni yolda: kayıtlı yaratıklar C++'ta (fog_update); bu fonksiyon sisin GDScript'te kendisinin
## yönetmesi gereken "enemies" üyelerini döner: ölüm animasyonundaki (kaydı silinmiş) yaratıklar + görev kopyaları.
## Bu sahnede köprü yoksa null -> sis eski yoldan tüm grubu tarar.
static func fog_world(tree: SceneTree) -> Object:
	var b: Node = _instance
	if b == null or not is_instance_valid(b) or not b.is_inside_tree() or b.get_tree() != tree:
		return null
	return b.world


static func fog_extra_enemies(tree: SceneTree) -> Array:
	var b: Node = _instance
	var out: Array = []
	if b != null and is_instance_valid(b):
		var keep: Array = []
		for e in b._dying:
			if e != null and is_instance_valid(e) and e.is_inside_tree():
				keep.append(e)
		b._dying = keep
		out.append_array(keep)
	for c in tree.get_nodes_in_group("mission_copies"):
		if is_instance_valid(c) and c.is_in_group("enemies"):
			out.append(c)
	return out


func wake(e: Node) -> void:
	_active.append(e)


func target_node(index: int) -> Node2D:
	if index < 0 or index >= _target_nodes.size():
		return null
	var n = _target_nodes[index]
	return n if is_instance_valid(n) else null


func _physics_process(delta: float) -> void:
	if int(world.call("get_count")) == 0:
		return
	var t0: int = Time.get_ticks_usec()
	_refresh_grid()
	_build_targets()
	_build_extra_bodies()
	## Kareler arasında (mermi isabeti, yetenek, test...) uygulanan donma/kök/korku/yavaşlatma bu adımda geçerli olsun -
	## eski yol durumu _physics_process'in başında okuyordu (yoksa yaratık bir kare daha kayıyordu).
	for e in _active:
		if e != null and is_instance_valid(e) and e._ew_slot >= 0:
			e._ew_push_state()
	world.call("step", delta)
	var t1: int = Time.get_ticks_usec()
	var ev: PackedInt32Array = world.call("pop_events")
	var j: int = 0
	while j < ev.size():
		var slot: int = ev[j + 1]
		event_counts[ev[j]] += 1
		var e = _by_slot[slot] if slot < _by_slot.size() else null
		if e != null and is_instance_valid(e):
			if ev[j] == E_LOCO:
				e._ew_on_loco(ev[j + 2])
			else:
				e._ew_on_event(ev[j], target_node(ev[j + 2]))
		j += 3
	## seyrek tarama: uyanması kaçırılmış (ya da dışarıdan hızı/yarıçapı değiştirilmiş) yaratıklar
	var n: int = _by_slot.size()
	var s: int = _sweep_phase
	while s < n:
		var e = _by_slot[s]
		if e != null and is_instance_valid(e) and not e._ew_awake:
			e._ew_push_state()
			if e._ew_still_active():
				e._ew_wake()
		s += SWEEP_EVERY
	_sweep_phase = (_sweep_phase + 1) % SWEEP_EVERY
	## uyanık yaratıkların tiki (tik sırasında uyanan da aynı karede işlenir)
	var i: int = 0
	var keep: Array = []
	## Köprünün KENDİ adım sayacı (oyunda fizik karesi başına bir adım = Engine.get_physics_frames() ile aynı anlam): testler köprüyü
	## aynı motor karesinde art arda elle adımladığında motor sayacı ilerlemiyor, yaratıklar ilk adımdan sonra hiç tiklenmiyordu
	## (saldırı durumu bitmiyor, yaratık donup kalıyordu).
	_step_counter += 1
	var frame: int = _step_counter
	while i < _active.size():
		var e = _active[i]
		i += 1
		if e == null or not is_instance_valid(e) or e._ew_slot < 0:
			continue
		if e._ew_tick_stamp == frame:
			if e._ew_awake and not keep.has(e):
				keep.append(e)
			continue
		e._ew_tick_stamp = frame
		e._ew_tick(delta)
		if e._ew_awake and e._ew_slot >= 0:
			keep.append(e)
	_active = keep
	var t2: int = Time.get_ticks_usec()
	last_step_ms = float(world.call("get_last_step_ms"))
	last_view_ms = float(world.call("get_last_view_ms"))
	last_tick_ms = float(t2 - t1) / 1000.0
	last_bridge_ms = float(t2 - t0) / 1000.0


## Orman ızgarası: enemy_pathing.gd'nin kurduğu bayt dizisi (aynı katman, aynı kenar payı). EnemyPathing kapalı olsa
## bile (testler) duvarlar geçerli kalmalı - enemy.gd _block_movement_into_terrain da yol bulmadan bağımsız.
func _refresh_grid() -> void:
	var layer: TileMapLayer = GameManager.get_forest_layer()
	if layer == _grid_layer and _grid_ready:
		return
	_grid_layer = layer
	_grid_ready = true
	if layer == null:
		world.call("set_grid", PackedByteArray(), Vector2i.ZERO, Vector2i.ZERO, 16.0, Vector2.ZERO)
		return
	if EnemyPathingScript._layer != layer or EnemyPathingScript._astar == null:
		EnemyPathingScript._build(layer)
	var blocked: PackedByteArray = EnemyPathingScript._blocked
	var size: Vector2i = EnemyPathingScript._size
	if blocked.size() != size.x * size.y:
		world.call("set_grid", PackedByteArray(), Vector2i.ZERO, Vector2i.ZERO, 16.0, Vector2.ZERO)
		return
	var cw: float = float(layer.tile_set.tile_size.x) * layer.global_scale.x
	## Görüş (sis) ızgarası SADECE orman duvarı: su/bina/ağaç/maden hareketi engeller ama görüşü kesmez (bkz. terrain_collision.gd).
	world.call("set_grid", blocked, EnemyPathingScript._origin, size, cw, layer.global_position, EnemyPathingScript._fog_blocked)


func _build_targets() -> void:
	_target_nodes.clear()
	var pos := PackedVector2Array()
	var kind := PackedInt32Array()
	var targetable := PackedByteArray()
	var ghost := PackedByteArray()
	var body := PackedFloat32Array()
	var zone := PackedFloat32Array()
	var ids := PackedInt64Array()
	var tree := get_tree()
	## 1. yerel oyuncu - enemy.gd _find_closest_target_player ile aynı eleme (görünmez / ev içi / satıcı bölgesi / ölü)
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p != null and is_instance_valid(local_p):
		var ok: bool = not (local_p.has_method("is_invisible_now") and local_p.is_invisible_now()) \
				and not (local_p.has_method("is_indoors_now") and local_p.is_indoors_now()) \
				and not (local_p.has_method("is_in_merchant_zone_now") and local_p.is_in_merchant_zone_now()) \
				and not (local_p.get("is_dead") == true)
		_add_target(local_p, T_PLAYER, ok, pos, kind, targetable, ghost, body, zone, ids)
	## HitArea eşleniği (C++ hit_radius): yerel oyuncunun FİZİK çemberi - Area2D (mask 2) sadece katman 2'deki "player"ı
	## görüyordu; Hadime hayaleti gibi collision_layer 0 iken görmezdi.
	var probe_r: float = -1.0
	var probe_c: Vector2 = Vector2.ZERO
	if local_p != null and is_instance_valid(local_p) and local_p is CollisionObject2D and ((local_p as CollisionObject2D).collision_layer & 2) != 0:
		var cs: CollisionShape2D = local_p.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs != null and not cs.disabled and cs.shape is CircleShape2D:
			probe_r = (cs.shape as CircleShape2D).radius * absf(cs.global_scale.x)
			probe_c = cs.global_position
	world.call("set_hit_probe", probe_c, probe_r)
	## 2. uzak oyuncular (sadece çok oyunculuda) - is_downed da elenir (bkz. enemy.gd notu)
	if NetworkManager.is_multiplayer_active:
		for rp: Node in tree.get_nodes_in_group("remote_players"):
			if not is_instance_valid(rp):
				continue
			var ok2: bool = not (rp.get("is_invisible") == true) and not (rp.get("is_dead") == true) \
					and not (rp.get("is_downed") == true) and not (rp.get("is_indoors") == true) \
					and not (rp.get("is_in_merchant_zone") == true)
			_add_target(rp, T_REMOTE, ok2, pos, kind, targetable, ghost, body, zone, ids)
	## 3. Necromancer yaratıkları
	for ally: Node in tree.get_nodes_in_group("player_allies"):
		if not is_instance_valid(ally):
			continue
		_add_target(ally, T_ALLY, not (ally.get("is_dead") == true), pos, kind, targetable, ghost, body, zone, ids)
	## 4. "Ağacı Koru" - doluysa her şeyin önünde (C++ geçersiz kılma)
	## İstemcide defend_tree_active hep false (sadece host); kuklaların yönü için kozmetik ağaç referansı yeterli (enemy.gd
	## eski istemci dalı da GameManager.defend_tree_ref geçerliyse ağaca baktırıyordu).
	var is_client: bool = NetworkManager.is_multiplayer_active and not NetworkManager.is_host
	if (GameManager.defend_tree_active or is_client) and is_instance_valid(GameManager.defend_tree_ref):
		_add_target(GameManager.defend_tree_ref, T_TREE, true, pos, kind, targetable, ghost, body, zone, ids)
	world.call("set_targets", pos, kind, targetable, ghost, body, zone, ids)
	world.call("set_merchant_zone", GameManager.merchant_zone_active, GameManager.merchant_zone_pos,
			GameManager.MERCHANT_ZONE_RADIUS)


## Görev kopyaları ("enemies" grubunda ama C++'a kayıtlı değil): enemy.gd itilme ızgarası onları da içeriyordu (yarıçap
## _body_radius, yoksa 20) - yaratıklar kopyanın içine girmesin diye C++'a "dış gövde" olarak verilir.
func _build_extra_bodies() -> void:
	var pos := PackedVector2Array()
	var rad := PackedFloat32Array()
	for c: Node in get_tree().get_nodes_in_group("mission_copies"):
		if not is_instance_valid(c) or not c.is_in_group("enemies") or c.get("is_dead") == true or not (c is Node2D):
			continue
		pos.append((c as Node2D).global_position)
		var r: Variant = c.get("_body_radius")
		rad.append(float(r) if r != null else 20.0)
	world.call("set_extra_bodies", pos, rad)


func _add_target(n: Node, k: int, ok: bool, pos: PackedVector2Array, kind: PackedInt32Array, targetable: PackedByteArray,
		ghost: PackedByteArray, body: PackedFloat32Array, zone: PackedFloat32Array, ids: PackedInt64Array) -> void:
	_target_nodes.append(n)
	pos.append((n as Node2D).global_position)
	kind.append(k)
	targetable.append(1 if ok else 0)
	ghost.append(1 if (k != T_TREE and n.has_method("is_ghost_now") and n.is_ghost_now()) else 0)
	body.append(PLAYER_BODY_RADIUS)
	## Şovalye baloncuğu: enemy.gd _paladin_zone_owners (yerel + uzak oyuncular; ölü sahibin baloncuğu odak dışı)
	var z: float = 0.0
	if (k == T_PLAYER or k == T_REMOTE) and n.get("paladin_zone_active") == true and not (n.get("is_dead") == true):
		z = float(n.get("paladin_zone_radius"))
	zone.append(z)
	ids.append(n.get_instance_id())
