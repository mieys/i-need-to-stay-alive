extends Node

## SAKLANMA ÇALILIĞI kuralları (2026-10-09, kullanıcı: "çalıya girince saklanabilelim ancak yaratıklar görürken girersek onlar da çalıya girip bizi görebilmeli;
## görmedikleri anda girersek istediğimiz kadar saklanabiliriz"). Alan: hide_brush.gd. main.gd her peer'e bir tane ekler.
##
## KARAR SADECE HOST'TA (tek oyunculuda yerel): host hem kendi oyuncusunun hem uzak oyuncuların (kukla konumu) çalıda olup olmadığını 0,1 sn'de bir bakar.
##  - ÇALIYA GİRİŞ anında oyuncuyu GÖREN yaratıklar (SPOT_RADIUS içindeki canlı yaratıklar; hepsi en yakın oyuncuyu kovaladığı için "görme" = yakınlık) "görenler"
##    listesine yazılır: onlar çalının içinde de oyuncuyu hedeflemeye devam eder (çalıya girip kovalar). Listedekiler çalı içinde oyuncudan kopmaz.
##  - Girişte kimse görmüyorsa oyuncu SAKLI: hiçbir yaratık onu hedeflemez, çalıda kaldığı sürece sınırsız saklanır. Yanından geçen (BUMP_RADIUS içine giren) yaratık
##    ona çarpar ve o da "görenler"e eklenir (benim seçimim: yoksa yaratık oyuncunun üstünden hedefsiz geçerdi).
##  - Çalıdan çıkınca / ölünce / içeri girince kayıt silinir; yeniden girişte yeniden hesaplanır.
## Hedefleme C++ EnemyWorld'de (set_stealth: oyuncu düğüm kimliği -> görebilen yaratık düğüm kimlikleri); durum her peer'in kendi ekranında karakterin saydamlığına yazılır
## (NetworkManager.sync_brush_state, yalnız değişince + 2 sn'de bir yeniden). BİLİNÇLİ KAPSAM DIŞI: oyuncunun çalıdan saldırınca açığa çıkması, alan hasarı/mermi (hedeflemeyi
## değil isabeti etkiler), Yeraltı Canavarı uzuv yönetmeni (oyuncu konumlarına bakar, saklı oyuncuyu da avlar).

const HideBrushScript := preload("res://scripts/hide_brush.gd")
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const EnemyWorldBridgeScript := preload("res://scripts/enemy_world/enemy_world_bridge.gd")

const TICK := 0.1
const RESYNC := 2.0
## Girişte "oyuncuyu gören" yaratık mesafesi (oyuncunun görüş elipsi 250 x 1,4 = 350; guard_camps.gd SIGHT ile aynı) VE görüş hattı açık olmalı.
## 2026-10-10 (kullanıcı: "yaratıkların bizi görmediği vaziyette girdiysek bizi aramayı bırakmalarını istedim"): eskiden 420 px içindeki HER yaratık (duvar/ağaç
## arkasındakiler, görüş dışındakiler dahil) "gören" sayılıp çalıda da kovalıyordu; artık yalnız gerçekten görenler.
const SPOT_RADIUS := 340.0
const BUMP_RADIUS := 56.0

var _acc: float = 0.0
var _resync: float = 0.0
## anahtar (peer id; tekli oyunda 0) -> {"inside": bool, "spotters": Dictionary(düğüm kimliği -> true), "state": int, "node": Node2D}
var _entries: Dictionary = {}
var _stealth_active: bool = false


func _ready() -> void:
	NetworkManager.brush_state_received.connect(_apply_state)


func _exit_tree() -> void:
	if NetworkManager.brush_state_received.is_connected(_apply_state):
		NetworkManager.brush_state_received.disconnect(_apply_state)


func _is_authority() -> bool:
	return not NetworkManager.is_multiplayer_active or NetworkManager.is_host


func _local_key() -> int:
	return multiplayer.get_unique_id() if NetworkManager.is_multiplayer_active else 0


func _physics_process(delta: float) -> void:
	if not _is_authority():
		return
	_acc += delta
	if _acc < TICK:
		return
	var dt: float = _acc
	_acc = 0.0
	_resync += dt
	tick()


## Bir kural adımı (testler doğrudan çağırır).
func tick() -> void:
	var tree: SceneTree = get_tree()
	if HideBrushScript.layer(tree) == null:
		if not _entries.is_empty() or _stealth_active:
			_clear_all()
		return
	var seen: Dictionary = {}
	var resend: bool = _resync >= RESYNC
	if resend:
		_resync = 0.0
	for pair: Array in _players(tree):
		var node: Node2D = pair[0]
		var key: int = pair[1]
		seen[key] = true
		var e: Dictionary = _entries.get(key, {"inside": false, "spotters": {}, "state": 0, "node": node})
		e["node"] = node
		var inside: bool = _eligible(node) and HideBrushScript.contains(tree, node.global_position + Vector2(0.0, HideBrushScript.FEET_OFFSET))
		var spotters: Dictionary = e["spotters"]
		if inside:
			if not e["inside"]:
				spotters = _spot(tree, node.global_position)
			else:
				for id: int in _spot(tree, node.global_position, BUMP_RADIUS, false):
					spotters[id] = true
			_prune(spotters)
		else:
			spotters = {}
		e["inside"] = inside
		e["spotters"] = spotters
		var state: int = HideBrushScript.STATE_NONE
		if inside:
			state = HideBrushScript.STATE_SPOTTED if not spotters.is_empty() else HideBrushScript.STATE_HIDDEN
		if state != int(e["state"]) or (resend and state != 0):
			e["state"] = state
			_publish(key, state)
		_entries[key] = e
	for key: int in _entries.keys():
		if not seen.has(key):
			if int(_entries[key]["state"]) != 0:
				_publish(key, 0)
			_entries.erase(key)
	_push_stealth()


## [[düğüm, anahtar], ...]: yerel oyuncu + (çok oyunculuda) uzak oyuncu kukları.
func _players(tree: SceneTree) -> Array:
	var out: Array = []
	var local_p: Node = tree.get_first_node_in_group("player")
	if local_p is Node2D and is_instance_valid(local_p):
		out.append([local_p, _local_key()])
	if NetworkManager.is_multiplayer_active:
		for rp: Node in tree.get_nodes_in_group("remote_players"):
			if rp is Node2D and is_instance_valid(rp) and int(rp.get("peer_id")) != 0:
				out.append([rp, int(rp.get("peer_id"))])
	return out


func _eligible(n: Node) -> bool:
	if n.get("is_dead") == true or n.get("is_downed") == true:
		return false
	if n.has_method("is_indoors_now") and n.is_indoors_now():
		return false
	if n.get("is_indoors") == true:
		return false
	return true


## `center` çevresindeki canlı yaratıkların düğüm kimlikleri (anahtar listesi).
func _spot(tree: SceneTree, center: Vector2, radius: float = SPOT_RADIUS, need_los: bool = true) -> Dictionary:
	var out: Dictionary = {}
	var r2: float = radius * radius
	var world: Object = EnemyWorldBridgeScript.fog_world(tree) if need_los else null
	for e: Variant in EnemyQueryScript.candidates(tree, center, radius):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true or not (e as Node).is_in_group("enemies"):
			continue
		if center.distance_squared_to((e as Node2D).global_position) <= r2:
			if world != null and world.has_method("is_los_clear") and not world.is_los_clear((e as Node2D).global_position, center):
				continue
			out[(e as Node).get_instance_id()] = true
	return out


func _prune(spotters: Dictionary) -> void:
	for id: int in spotters.keys():
		var o: Object = instance_from_id(id)
		if o == null or not is_instance_valid(o) or o.get("is_dead") == true:
			spotters.erase(id)


func _publish(key: int, state: int) -> void:
	_apply_state(key, state)
	if NetworkManager.is_multiplayer_active and NetworkManager.is_host:
		NetworkManager.sync_brush_state.rpc(key, state)


## C++ hedefleme kaydı: saklı/görülmüş oyuncu -> görebilen yaratıklar. Çalıda kimse yoksa bir kez boşaltılır.
func _push_stealth() -> void:
	var world: Object = EnemyWorldBridgeScript.fog_world(get_tree())
	if world == null or not world.has_method("set_stealth"):
		return
	var ids := PackedInt64Array()
	var reveals: Array = []
	for key: int in _entries.keys():
		var e: Dictionary = _entries[key]
		if int(e["state"]) == HideBrushScript.STATE_NONE or not is_instance_valid(e["node"]):
			continue
		ids.append((e["node"] as Node).get_instance_id())
		var arr := PackedInt64Array()
		for id: int in (e["spotters"] as Dictionary).keys():
			arr.append(id)
		reveals.append(arr)
	if ids.is_empty() and not _stealth_active:
		return
	world.call("set_stealth", ids, reveals)
	_stealth_active = not ids.is_empty()


func _clear_all() -> void:
	for key: int in _entries.keys():
		if int(_entries[key]["state"]) != 0:
			_publish(key, 0)
	_entries.clear()
	_push_stealth()


## Durumu karaktere yaz (host kendisi + herkesin ağdan aldığı); anahtar yerel oyuncununsa Player, değilse o peer'in kuklası.
func _apply_state(key: int, state: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	if key == _local_key():
		var p: Node = tree.get_first_node_in_group("player")
		if p != null and p.has_method("set_brush_state"):
			p.set_brush_state(state)
		return
	for rp: Node in tree.get_nodes_in_group("remote_players"):
		if int(rp.get("peer_id")) == key and rp.has_method("set_brush_state"):
			rp.set_brush_state(state)
