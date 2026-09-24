extends Node

## XP orb'u / altın gibi yerdeki düşmelerin "hangi oyuncuya çekileyim" kararı - xp_orb.gd ve gold_drop.gd'nin
## TEK ORTAK kaynağı (eskiden iki dosyada birebir kopya _resolve_attraction_target vardı; davranış kuralları
## için bkz. o dosyalardaki DÜZELTME notları: #32 mıknatıs hedefi, "en yakın oyuncuya git" multiplayer düzeltmesi).
##
## PERF DÜZELTMESİ (kullanıcı bildirimi: "multiplayerda 200 civarı yaratık ... sürekli fps drop" - iki süreçli
## gerçek testte ölçüldü): toplu ölümlerden sonra yerde ~790 düşme birikince host 84 FPS'ten 31 FPS'e iniyordu;
## düşmelerin SADECE _physics_process'i kapatılınca 62 FPS'e çıkıyordu. Her düşme her fizik adımında
## get_nodes_in_group("remote_players") (yeni bir dizi kopyası), get_first_node_in_group("player"),
## has_method + get_pickup_range() çağırıyordu - sonuç o fizik karesindeki TÜM düşmeler için aynı. Host'un
## karesi 16.6 ms'yi aşınca kare başına 2-3 fizik adımı çalıştığı için bu maliyet kendini besliyordu. Artık
## oyuncu listesi, konumları ve toplama menzilleri fizik karesi başına BİR kez hesaplanıp paylaşılıyor
## (enemy.gd _paladin_zone_owners ile AYNI static-önbellek deseni).
##
## Önbellek tek başına yetmedi (ölçüm: 790 düşmede host 31 -> 36 FPS; düşmelerin fiziği tamamen kapalıyken 67):
## asıl maliyet 800 ayrı düğümün her fizik adımında ÇAĞRILMASININ kendisi, oysa neredeyse hepsi hiçbir oyuncuya
## yakın değil ve hiçbir şey yapmıyor. Bu yüzden UYKU: hiçbir oyuncunun toplama menzilinin WAKE_MARGIN yakınında
## olmayan, mıknatıslanmamış düşme kendi _physics_process'ini kapatıp _sleeping listesine girer; bu script'in
## TEK bir örneği (ticker, ilk uyuyan düşmede root'a eklenir) listeyi her fizik karesinde 1/WAKE_CHECK_SPREAD
## dilim halinde tarayıp oyuncu yaklaşınca uyandırır. Mıknatıs (attract_to_player) anında uyandırır (wake()).
## Menzile girme gecikmesi olmasın diye marj: oyuncu WAKE_CHECK_SPREAD karede WAKE_MARGIN'den fazla yol almaz
## (64 px / 3 kare = ~1280 px/sn). Uyuyan düşmenin Area2D çarpışması (üstüne basınca toplanma) DEĞİŞMEZ.

static var _cache_frame: int = -1
static var _nodes: Array[Node2D] = [] ## [0] = yerel oyuncu (varsa), sonra canlı RemotePlayer kuklaları
static var _positions: PackedVector2Array = PackedVector2Array()
static var _ranges: PackedFloat32Array = PackedFloat32Array()
static var _peer_ids: PackedInt32Array = PackedInt32Array()
static var _alive: Array[bool] = []
static var _local_index: int = -1
static var _local_peer_id: int = 0

const DEFAULT_PICKUP_RANGE := 60.0
const WAKE_MARGIN := 64.0
const WAKE_CHECK_SPREAD := 3

static var _sleeping: Array = [] ## tipsiz: silinmiş düşme okunurken tipli değişken ataması hata verirdi
static var _wake_cursor: int = 0
static var _ticker: Node = null
## attraction_target()'in son çağrısında düşme hiçbir oyuncunun (menzil + WAKE_MARGIN) yakınında değil miydi.
static var last_query_far: bool = false


static func _refresh(tree: SceneTree) -> void:
	var frame: int = Engine.get_physics_frames()
	if frame == _cache_frame:
		return
	_cache_frame = frame
	_nodes.clear()
	_positions.clear()
	_ranges.clear()
	_peer_ids.clear()
	_alive.clear()
	_local_index = -1
	var local_player: Node2D = tree.get_first_node_in_group("player") as Node2D
	var mp: bool = NetworkManager.is_multiplayer_active
	var mp_api: MultiplayerAPI = tree.root.multiplayer
	_local_peer_id = mp_api.get_unique_id() if (mp and mp_api.has_multiplayer_peer()) else 0
	if local_player and is_instance_valid(local_player):
		_local_index = 0
		_push(local_player, _local_peer_id)
	if not mp:
		return
	for rp: Node in tree.get_nodes_in_group("remote_players"):
		if is_instance_valid(rp) and rp is Node2D:
			_push(rp as Node2D, int(rp.get("peer_id")) if "peer_id" in rp else -1)


static func _push(n: Node2D, peer_id: int) -> void:
	_nodes.append(n)
	_positions.append(n.global_position)
	_ranges.append(float(n.call("get_pickup_range")) if n.has_method("get_pickup_range") else DEFAULT_PICKUP_RANGE)
	_peer_ids.append(peer_id)
	_alive.append(n.get("is_dead") != true)


## Bu fizik adımında düşmenin çekileceği hedef oyuncunun _nodes indeksi; hedef yoksa -1. Kurallar eski
## _resolve_attraction_target ile birebir: tek oyunculuda hep yerel oyuncu; multiplayer'da önce geçerli
## mıknatıs sahibi (canlıysa), yoksa en yakın oyuncu (yerel oyuncu ölü olsa bile başlangıç adayı - eski
## davranış; RemotePlayer'lar ölüyse atlanır).
static func _target_index(pos: Vector2, is_magnetized: bool, magnet_target_peer_id: int) -> int:
	if not NetworkManager.is_multiplayer_active:
		return _local_index
	if is_magnetized and magnet_target_peer_id >= 0:
		if magnet_target_peer_id == _local_peer_id:
			if _local_index >= 0 and _alive[_local_index]:
				return _local_index
		else:
			for i in range(_nodes.size()):
				if i != _local_index and _alive[i] and _peer_ids[i] == magnet_target_peer_id:
					return i
	var best: int = _local_index
	var best_d: float = INF
	if _local_index >= 0:
		best_d = pos.distance_squared_to(_positions[_local_index])
	for i in range(_nodes.size()):
		if i == _local_index or not _alive[i]:
			continue
		var d: float = pos.distance_squared_to(_positions[i])
		if d < best_d:
			best_d = d
			best = i
	return best


## Düşmenin bu adımda hareket etmesi gereken hedef oyuncu (mıknatıslı ya da toplama menzilinde) - yoksa null.
## Çağıran taraf (xp_orb.gd/gold_drop.gd _physics_process) sadece hızlanıp o oyuncuya doğru ilerler.
static func attraction_target(drop: Node2D, is_magnetized: bool, magnet_target_peer_id: int) -> Node2D:
	_refresh(drop.get_tree())
	last_query_far = false
	var pos: Vector2 = drop.global_position
	var idx: int = _target_index(pos, is_magnetized, magnet_target_peer_id)
	if idx < 0:
		last_query_far = not is_magnetized
		return null
	var n: Node2D = _nodes[idx]
	if not is_instance_valid(n):
		return null
	if is_magnetized:
		return n
	var r: float = _ranges[idx]
	var d2: float = pos.distance_squared_to(_positions[idx])
	if d2 <= r * r:
		return n
	last_query_far = not _near_any_player(pos)
	return null


## Herhangi bir oyuncunun (ölü dahil - hedef kuralı yerel oyuncuyu ölüyken de aday sayıyor) toplama menzili +
## WAKE_MARGIN içinde mi. En yakın hedef kuralından bağımsız, kasıtlı olarak geniş: uyumak için HERKESTEN uzak olmalı.
static func _near_any_player(pos: Vector2) -> bool:
	for i in range(_nodes.size()):
		var r: float = _ranges[i] + WAKE_MARGIN
		if pos.distance_squared_to(_positions[i]) <= r * r:
			return true
	return false


## Düşmenin _physics_process'i attraction_target() null döndürüp last_query_far true ise bunu çağırır.
static func put_to_sleep(drop: Node2D) -> void:
	drop.set_physics_process(false)
	_sleeping.append(drop)
	if _ticker == null or not is_instance_valid(_ticker):
		var script: GDScript = load("res://scripts/drop_attraction.gd")
		_ticker = script.new()
		_ticker.name = "DropSleepTicker"
		drop.get_tree().root.add_child.call_deferred(_ticker)


## Mıknatıs (attract_to_player) - listeden çıkarma tembel: ticker geçersiz/uyanık girdileri kendisi atar.
static func wake(drop: Node2D) -> void:
	drop.set_physics_process(true)


func _physics_process(_delta: float) -> void:
	var n: int = _sleeping.size()
	if n == 0:
		return
	_refresh(get_tree())
	var budget: int = int(ceil(float(n) / float(WAKE_CHECK_SPREAD)))
	if _wake_cursor >= n:
		_wake_cursor = 0
	var i: int = _wake_cursor
	while budget > 0 and not _sleeping.is_empty():
		if i >= _sleeping.size():
			i = 0
		budget -= 1
		var d: Variant = _sleeping[i]
		var drop_out: bool = not is_instance_valid(d) or (d as Node2D).is_queued_for_deletion() or (d as Node2D).is_physics_processing()
		if not drop_out and ((d as Node2D).get("is_magnetized") == true or _near_any_player((d as Node2D).global_position)):
			(d as Node2D).set_physics_process(true)
			drop_out = true
		if drop_out:
			## Sırasız hızlı silme: son elemanı bu yuvaya taşı, aynı i'yi tekrar incele.
			_sleeping[i] = _sleeping[_sleeping.size() - 1]
			_sleeping.pop_back()
		else:
			i += 1
	_wake_cursor = i
