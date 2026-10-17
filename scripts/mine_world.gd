extends Node

## MADEN DAYANIKLILIĞI + KIRILMA + YENİDEN DOĞMA (kullanıcı isteği 2026-10-14: "madenlerin belli bir dayanıklılığı olup bir süre sonra kırılsın, zaman geçince tekrar
## spawn olsun"). Maden verisi/hesabı mine_sites.gd, kazma + altın player.gd `_process_mining`; burası DURUM: her kazma vuruşu madenin dayanıklılığını (hp) düşürür,
## 0'da maden KIRILIR (karoları silinir, collision/yol ızgarası açılır, kazılamaz), RESPAWN_SECONDS sonra yeniden DOĞAR (hp dolu, karolar + collision geri).
## main.gd kurar (HideBrushManager gibi): KARAR host'ta (tekli oyunda yerel), görsel her peer'de.
##  - Vuruş: yerel oyuncu `MineWorld.report_hit(tree, indeks)` -> host/tekli `_apply_hit`; istemci `request_mine_hit` RPC'si ile host'a bildirir (altın istemcide anında verilir,
##    kırılma geç gelirse 1-2 fazladan vuruş sayılabilir - bilinçli, co-op).
##  - Durum: kırık maden indeks listesi değişince ve 5 sn'de bir host'tan herkese `sync_mine_state` (geç katılan/kaçırılan güncelleme düzelir).
##  - Yeniden doğma: sayaç host'ta (fizik karesi, duraklatmada durur); maden alanında (ayak izi + 24 px) canlı oyuncu varsa beklenir (içine doğup sıkışmasın).
## Görsel: asıl katman + DepthOccluders ön kopyası + derinlik kökleri (set_object_tiles), collision TerrainCollision.set_category_cells_blocked + EnemyPathing.sync_cells
## + C++ yaratık ızgarası (bridge.reload_grid). BİLİNEN: haritanın PİŞMİŞ gölge dokusu (harita_golgeleri.png) ve minimap görüntüsü maden gölgesini/rengini içerir - kırılınca
## onlar kalır (kozmetik).

const MineSites := preload("res://scripts/mine_sites.gd")
const TerrainCollisionScript := preload("res://scripts/terrain_collision.gd")
const EnemyPathingScript := preload("res://scripts/enemy_pathing.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")
const PixelDrawScript := preload("res://scripts/pixel_draw.gd")
const FloatingText := preload("res://scenes/floating_text.tscn")

const HEARTBEAT_SECONDS := 5.0
const RESPAWN_CLEAR_MARGIN := 24.0
const FX_NEAR_DISTANCE := 700.0
const BREAK_TEXT_COLOR := Color(0.9, 0.9, 0.9)

var _forest: TileMapLayer = null
var _since_sync: float = 0.0


func _ready() -> void:
	add_to_group("mine_world")
	_forest = GameManager.get_forest_layer()
	if _forest == null or MineSites.ensure(_forest).is_empty():
		set_physics_process(false)
		return
	NetworkManager.mine_state_received.connect(_apply_state)
	NetworkManager.mine_hit_requested.connect(_apply_hit)


func _exit_tree() -> void:
	if NetworkManager.mine_state_received.is_connected(_apply_state):
		NetworkManager.mine_state_received.disconnect(_apply_state)
	if NetworkManager.mine_hit_requested.is_connected(_apply_hit):
		NetworkManager.mine_hit_requested.disconnect(_apply_hit)


static func report_hit(tree: SceneTree, site_index: int) -> void:
	var w: Node = tree.get_first_node_in_group("mine_world")
	if w != null:
		w.call("register_hit", site_index)


func _is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func register_hit(site_index: int) -> void:
	if _is_authority():
		_apply_hit(site_index)
	elif NetworkManager.is_multiplayer_active:
		NetworkManager.request_mine_hit.rpc_id(NetworkManager._host_peer_id(), site_index)


## Yalnız karar veren taraf (host / tekli): bir kazma vuruşu madenin dayanıklılığını düşürür, 0'da kırar.
func _apply_hit(site_index: int) -> void:
	if not _is_authority() or site_index < 0 or site_index >= MineSites.sites.size():
		return
	var s: Dictionary = MineSites.sites[site_index]
	if bool(s["broken"]):
		return
	s["hp"] = int(s["hp"]) - 1
	if int(s["hp"]) <= 0:
		s["respawn_left"] = MineSites.RESPAWN_SECONDS
		_set_broken(site_index, true)
		_publish()


func _physics_process(delta: float) -> void:
	if not _is_authority():
		return
	var changed: bool = false
	for s: Dictionary in MineSites.sites:
		if not bool(s["broken"]):
			continue
		s["respawn_left"] = float(s["respawn_left"]) - delta
		if float(s["respawn_left"]) <= 0.0 and not _player_inside(s):
			_set_broken(int(s["index"]), false)
			changed = true
	if changed:
		_publish()
	elif NetworkManager.is_multiplayer_active:
		_since_sync += delta
		if _since_sync >= HEARTBEAT_SECONDS:
			_publish()


func _publish() -> void:
	_since_sync = 0.0
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		NetworkManager.sync_mine_state.rpc(broken_indices())


func broken_indices() -> Array:
	var out: Array = []
	for s: Dictionary in MineSites.sites:
		if bool(s["broken"]):
			out.append(int(s["index"]))
	return out


## İstemci: host'tan gelen kırık maden listesini uygular (fark neyse onu kırar/doğurur).
func _apply_state(broken: Array) -> void:
	var want: Dictionary = {}
	for v: Variant in broken:
		want[int(v)] = true
	for s: Dictionary in MineSites.sites:
		_set_broken(int(s["index"]), want.has(int(s["index"])))


func _player_inside(s: Dictionary) -> bool:
	var zone: Rect2 = (s["bounds"] as Rect2).grow(RESPAWN_CLEAR_MARGIN)
	for n: Node in _all_players():
		var p: Node2D = n as Node2D
		if p == null or not is_instance_valid(p) or p.get("is_dead") == true:
			continue
		if zone.has_point(p.global_position + Vector2(0.0, 12.0)):
			return true
	return false


func _all_players() -> Array:
	var out: Array = get_tree().get_nodes_in_group("player")
	if NetworkManager.is_multiplayer_active:
		out.append_array(get_tree().get_nodes_in_group("remote_players"))
	return out


func _near_local_player(pos: Vector2) -> bool:
	for n: Node in get_tree().get_nodes_in_group("player"):
		if n is Node2D and (n as Node2D).global_position.distance_to(pos) < FX_NEAR_DISTANCE:
			return true
	return false


## Madeni kırar (broken=true) ya da yeniden doğurur (false): karolar, derinlik kökleri, collision, yol ızgarası, C++ yaratık ızgarası, efekt. Aynıysa hiçbir şey yapmaz.
func _set_broken(site_index: int, broken: bool) -> void:
	if site_index < 0 or site_index >= MineSites.sites.size():
		return
	var s: Dictionary = MineSites.sites[site_index]
	if bool(s["broken"]) == broken:
		return
	s["broken"] = broken
	s["hp"] = 0 if broken else int(s["max_hits"])
	var saved: Dictionary = s.get("saved_bases", {})
	s["saved_bases"] = saved
	var by_layer: Dictionary = {} ## TileMapLayer -> [karo sözlükleri]
	for t: Dictionary in s["tiles"]:
		var layer: TileMapLayer = t["layer"]
		if not is_instance_valid(layer):
			continue
		if not by_layer.has(layer):
			by_layer[layer] = []
		(by_layer[layer] as Array).append(t)
		if broken:
			layer.erase_cell(t["cell"])
		else:
			layer.set_cell(t["cell"], int(t["sid"]), t["atlas"], int(t["alt"]))
	for occ: Node in get_tree().get_nodes_in_group("depth_occluders"):
		if occ.has_method("set_object_tiles"):
			for layer: TileMapLayer in by_layer:
				occ.call("set_object_tiles", layer, by_layer[layer], not broken, saved)
	var gcs: Array = s["gcs"]
	TerrainCollisionScript.set_category_cells_blocked("mines", gcs, not broken)
	EnemyPathingScript.sync_cells(gcs)
	var bridge: Object = EnemyWorldBridgeScript._instance
	if bridge != null and is_instance_valid(bridge) and bridge.has_method("reload_grid"):
		bridge.call("reload_grid")
	var center: Vector2 = (s["bounds"] as Rect2).get_center()
	if _near_local_player(center):
		_spawn_fx(s, center, broken)


func _spawn_fx(s: Dictionary, center: Vector2, broken: bool) -> void:
	var root: Node = get_tree().current_scene
	if root == null:
		return
	if broken:
		PixelDrawScript.spawn_burst(root, center, "ore_gray" if bool(s["gray"]) else "ore_copper", 26, 130.0, 0.7)
		PixelDrawScript.spawn_burst(root, center, "dust", 12, 90.0, 0.6)
		var ft: Node = FloatingText.instantiate()
		root.add_child(ft)
		ft.global_position = center + Vector2(0.0, -24.0)
		ft.call("setup", "Maden tükendi", BREAK_TEXT_COLOR)
	else:
		PixelDrawScript.spawn_burst(root, center, "spark", 14, 80.0, 0.5)
