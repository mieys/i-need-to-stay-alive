extends RefCounted
## RUH HÂLİ (madde 438, 2026-11-07; kullanıcı: "level atlama aralarında oyuncuların birbirlerini beklemelerini istemiyorum").
## Level kartı + pazar + sandık akışındaki oyuncu "ruh hâlinde": dünya onu beklemez, ama O oyuncunun her şeyi donar (seyyar satıcıdaki
## gibi, üstüne AKTİF süreler de) ve menüden dönünce kaldığı yerden devam eder. Kurallar (kullanıcı kararları):
##   - Ruh hâlindeki oyuncu tamamen dokunulmaz: hasar/CC/itme almaz, yaratıklar hedef almaz, içinden geçer (enemy_world_bridge targetable/ghost).
##   - Dünyaya bıraktığı yetenekler (kubbe/iskelet/totem/ağaç/duman/iksir/bağ/evcil ...) SON HÂLLERİYLE donar, işlemez (bu dosya).
##   - Herkes menüdeyken dünya durur (get_tree().paused); en az biri oyuna dönünce akar (main.gd _refresh_limbo). Tek oyunculu = eskisi gibi durur.
##   - Ortak 25 sn bekleme sayacı + "oyuncular bekleniyor" ekranı bu akışta YOK (kimse kimseyi beklemez).
## Ağ: ek RPC YOK - ruh hâlindeki eşler NetworkManager.level_up_busy_peers (akışın tamamı boyunca true; sandık dahil). Her makine aynı
## kümeden kendi kopyalarını (yerel Player, RemotePlayer kuklası, dünyadaki düğümler) dondurur.
##
## DONDURMA: sahnenin (current_scene) doğrudan çocukları arasında SAHİBİ ruh hâlinde olan düğüm PROCESS_MODE_DISABLED olur (fizikten de çıkar),
## önceki mod meta'da saklanır. Sahip şu sırayla bulunur: açık etiket (`own()` -> meta), int alan (`owner_peer`...), düğüm alanı (`caster`,
## `owner_player`...) -> yerel Player / RemotePlayer. YENİ bir kalıcı yetenek düğümü (alan, çağrılan, bırakılan nesne) eklerken ya bu alanlardan
## birini taşı ya da doğduğu yerde `Limbo.own(node, peer)` çağır (kaster: Limbo.local_peer(); kukla: peer_id) - yoksa sahibi menüdeyken çalışır.

const META_PEER := &"limbo_peer"
const META_PREV := &"limbo_prev_pm"
const PEER_FIELDS: Array[StringName] = [&"owner_peer", &"caster_peer"]
const OWNER_FIELDS: Array[StringName] = [&"caster", &"owner_player", &"owner_body", &"owner_node", &"summoner", &"_caster"]

## Ruh hâlindeki eşler (peer_id -> true). Tek oyunculuda yerel oyuncu = 1.
static var peers: Dictionary = {}


static func local_peer() -> int:
	if NetworkManager.is_multiplayer_active and NetworkManager.multiplayer.has_multiplayer_peer():
		return NetworkManager.multiplayer.get_unique_id()
	return 1


static func is_peer(peer_id: int) -> bool:
	return peer_id != 0 and peers.has(peer_id)


static func any() -> bool:
	return not peers.is_empty()


## Oyuncu düğümünün eşi: yerel Player -> local_peer(), kukla -> peer_id, değilse 0.
static func peer_of_player(n: Object) -> int:
	if n == null or not is_instance_valid(n) or not (n is Node):
		return 0
	var node := n as Node
	if node.is_in_group("player"):
		return local_peer()
	if node.is_in_group("remote_players"):
		return int(node.get("peer_id"))
	return 0


static func owner_peer(node: Node) -> int:
	if node.has_meta(META_PEER):
		return int(node.get_meta(META_PEER))
	for f in PEER_FIELDS:
		var v: Variant = node.get(f)
		if v is int and int(v) > 0:
			return int(v)
	for f in OWNER_FIELDS:
		var o: Variant = node.get(f)
		if o is Object:
			var p: int = peer_of_player(o)
			if p != 0:
				return p
	return 0


## Doğduğu yerde sahibini açıkça yazar (alanı olmayan kalıcı düğümler). Sahip zaten ruh hâlindeyse hemen donar.
static func own(node: Node, peer_id: int) -> void:
	if node == null or peer_id == 0:
		return
	node.set_meta(META_PEER, peer_id)
	if is_peer(peer_id) and node.is_inside_tree():
		freeze(node)


static func is_frozen(node: Object) -> bool:
	return node != null and is_instance_valid(node) and (node as Node).has_meta(META_PREV)


static func freeze(node: Node) -> void:
	if node.has_meta(META_PREV):
		return
	node.set_meta(META_PREV, int(node.process_mode))
	node.process_mode = Node.PROCESS_MODE_DISABLED


static func thaw(node: Node) -> void:
	if not node.has_meta(META_PREV):
		return
	node.process_mode = int(node.get_meta(META_PREV)) as Node.ProcessMode
	node.remove_meta(META_PREV)


static func _skip(node: Node) -> bool:
	return node.is_in_group("player") or node.is_in_group("remote_players") or node.is_in_group("enemies")


static func sync_node(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or _skip(node):
		return
	if is_peer(owner_peer(node)):
		freeze(node)
	else:
		thaw(node)


## Küme değişince (main.gd _refresh_limbo): sahnedeki doğrudan çocuklar yeniden taranır (seyrek olay - level akışı başı/sonu).
static func apply(tree: SceneTree, new_peers: Dictionary) -> void:
	peers = new_peers.duplicate()
	var root: Node = tree.current_scene if tree != null else null
	if root == null:
		return
	for c in root.get_children():
		sync_node(c)


## Sahneye yeni eklenen çocuk (main.gd child_entered_tree): alanlar add_child'dan SONRA da yazılabildiği için bir kare ertelenir.
## Kimse ruh hâlinde değilken hiçbir iş yapmaz.
static func on_child_added(node: Node) -> void:
	if peers.is_empty() or _skip(node):
		return
	(func() -> void:
		if is_instance_valid(node):
			sync_node(node)).call_deferred()


static func reset() -> void:
	peers.clear()
