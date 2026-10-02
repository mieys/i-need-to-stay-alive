extends MultiplayerPeerExtension

## Parçalayan çoklu oyuncu katmanı (kullanıcı isteği 2026-10-02: "hem androidden hem pcden crossplay sağlanması radmin
## olmadan" - Epic Online Services P2P).
##
## NEDEN VAR: Epic'in P2P bağlantısı (EOSGMultiplayerPeer) TEK paketi en fazla ~1170 bayt taşıyabiliyor ve daha büyüğünü
## "Packet size exceeds limits" hatasıyla HİÇ göndermiyor. ENet büyük paketleri kendisi bölüyordu; oyunun bazı RPC'leri
## (yaratık durum senkronu, oyun-içi katılım yakalaması, dükkan stoğu...) bu sınırı rahatça aşıyor. Bu sınıf asıl peer'i
## sarar: sınırı aşan her paketi parçalara böler, karşı tarafta birleştirir. Oyunun RPC kodu HİÇ değişmeden aynı kalır -
## SceneMultiplayer bu sarmalayıcıyı sıradan bir MultiplayerPeer gibi görür. (Peer id'leri, host = 1, sunucu aktarımı
## (relay) ve bağlantı sinyalleri olduğu gibi içteki peer'den geçer.)
##
## Paket biçimi (ilk bayt = tür):
##   0 = bütün paket:  [0][veri]
##   1 = parça:        [1][mesaj no u16][sıra u16][toplam u16][veri parçası]
## Güvenilir (reliable) parçalar sırayla gelir; güvenilmez olanlardan biri kaybolursa o mesajın tamamı düşer (zaten
## periyodik tekrar edilen veriler) ve yarım kalanlar PARTIAL_TIMEOUT_MS sonra temizlenir.

const TYPE_WHOLE := 0
const TYPE_FRAGMENT := 1
const FRAG_HEADER := 7
## Epic sınırı 1170 bayt; EOSG kendi 6 baytlık başlığını ekliyor. Pay bırakılarak 1100.
const DEFAULT_LIMIT := 1100
const PARTIAL_TIMEOUT_MS := 4000

var _inner: MultiplayerPeer
var _limit: int
var _next_msg_id: int = 0
var _target_peer: int = 0
var _transfer_mode: TransferMode = TRANSFER_MODE_RELIABLE
var _transfer_channel: int = 0

## Hazır (birleştirilmiş) gelen paketler: [gönderen, kanal, mod, veri]
var _ready_queue: Array = []
## Yarım mesajlar: anahtar (gönderen * 65536 + mesaj no) -> {count, got, parts, t}
var _partials: Dictionary = {}


## inner: asıl bağlantı (EOSGMultiplayerPeer; testte ENet). limit: tek pakete sığan en büyük boyut.
func _init(inner: MultiplayerPeer, limit: int = DEFAULT_LIMIT) -> void:
	_inner = inner
	_limit = maxi(limit, FRAG_HEADER + 16)
	_inner.peer_connected.connect(func(id: int) -> void: peer_connected.emit(id))
	_inner.peer_disconnected.connect(_on_inner_peer_disconnected)


func get_inner() -> MultiplayerPeer:
	return _inner


func _on_inner_peer_disconnected(id: int) -> void:
	for key in _partials.keys():
		if int(key) >> 16 == id:
			_partials.erase(key)
	peer_disconnected.emit(id)


func _inner_active() -> bool:
	return _inner != null and _inner.get_connection_status() != CONNECTION_DISCONNECTED


## ------------------------------------------------------------------ gönderme
func _put_packet_script(buffer: PackedByteArray) -> Error:
	if not _inner_active():
		return ERR_UNCONFIGURED
	var n: int = buffer.size()
	if n + 1 <= _limit:
		var whole := PackedByteArray([TYPE_WHOLE])
		whole.append_array(buffer)
		return _inner.put_packet(whole)
	var chunk: int = _limit - FRAG_HEADER
	var count: int = int(ceil(float(n) / float(chunk)))
	if count > 0xFFFF:
		return ERR_OUT_OF_MEMORY
	_next_msg_id = (_next_msg_id + 1) & 0xFFFF
	for i in range(count):
		var a: int = i * chunk
		var part := PackedByteArray()
		part.resize(FRAG_HEADER)
		part[0] = TYPE_FRAGMENT
		part.encode_u16(1, _next_msg_id)
		part.encode_u16(3, i)
		part.encode_u16(5, count)
		part.append_array(buffer.slice(a, mini(a + chunk, n)))
		var err: Error = _inner.put_packet(part)
		if err != OK:
			return err
	return OK


## ------------------------------------------------------------------ alma
func _poll() -> void:
	if not _inner_active():
		return
	_inner.poll()
	while _inner_active() and _inner.get_available_packet_count() > 0:
		## SceneMultiplayer ile aynı sıra: gönderen/kanal/mod SIRADAKİ paket için, sonra paketi al.
		var from: int = _inner.get_packet_peer()
		var ch: int = _inner.get_packet_channel()
		var mode: TransferMode = _inner.get_packet_mode()
		var data: PackedByteArray = _inner.get_packet()
		if data.is_empty():
			continue
		if data[0] == TYPE_WHOLE:
			_ready_queue.append([from, ch, mode, data.slice(1)])
		elif data[0] == TYPE_FRAGMENT and data.size() > FRAG_HEADER:
			_add_fragment(from, ch, mode, data)
	if not _partials.is_empty():
		var now: int = Time.get_ticks_msec()
		for key in _partials.keys():
			if now - int(_partials[key]["t"]) > PARTIAL_TIMEOUT_MS:
				_partials.erase(key)


func _add_fragment(from: int, ch: int, mode: TransferMode, data: PackedByteArray) -> void:
	var msg_id: int = data.decode_u16(1)
	var idx: int = data.decode_u16(3)
	var count: int = data.decode_u16(5)
	if count == 0 or idx >= count:
		return
	var key: int = from * 65536 + msg_id
	var entry: Dictionary = _partials.get(key, {})
	if entry.is_empty() or int(entry["count"]) != count:
		var parts: Array = []
		parts.resize(count)
		entry = {"count": count, "got": 0, "parts": parts, "t": Time.get_ticks_msec()}
		_partials[key] = entry
	var parts_ref: Array = entry["parts"]
	if parts_ref[idx] != null:
		return
	parts_ref[idx] = data.slice(FRAG_HEADER)
	entry["got"] = int(entry["got"]) + 1
	if int(entry["got"]) < count:
		return
	_partials.erase(key)
	var full := PackedByteArray()
	for p in parts_ref:
		full.append_array(p)
	_ready_queue.append([from, ch, mode, full])


func _get_available_packet_count() -> int:
	return _ready_queue.size()


func _get_packet_script() -> PackedByteArray:
	if _ready_queue.is_empty():
		return PackedByteArray()
	return _ready_queue.pop_front()[3]


func _get_packet_peer() -> int:
	return int(_ready_queue[0][0]) if not _ready_queue.is_empty() else 0


func _get_packet_channel() -> int:
	return int(_ready_queue[0][1]) if not _ready_queue.is_empty() else 0


func _get_packet_mode() -> TransferMode:
	return _ready_queue[0][2] if not _ready_queue.is_empty() else TRANSFER_MODE_RELIABLE


func _get_max_packet_size() -> int:
	return 1 << 24


## ------------------------------------------------------------------ ayarlar (içteki peer'e aynen geçer)
func _set_target_peer(peer: int) -> void:
	_target_peer = peer
	if _inner_active():
		_inner.set_target_peer(peer)


func _set_transfer_mode(mode: TransferMode) -> void:
	## Epic'te "güvenilmez ama sıralı" mod yok (EOSG her seferinde uyarı basıp güvenilire çeviriyor) - oyunun hiçbir
	## RPC'si bunu kullanmıyor; gelirse güvenilmeze eşlenir.
	_transfer_mode = TRANSFER_MODE_UNRELIABLE if mode == TRANSFER_MODE_UNRELIABLE_ORDERED else mode
	_inner.transfer_mode = _transfer_mode


func _get_transfer_mode() -> TransferMode:
	return _transfer_mode


func _set_transfer_channel(channel: int) -> void:
	_transfer_channel = channel
	_inner.transfer_channel = channel


func _get_transfer_channel() -> int:
	return _transfer_channel


func _set_refuse_new_connections(enable: bool) -> void:
	_inner.refuse_new_connections = enable


func _is_refusing_new_connections() -> bool:
	return _inner.refuse_new_connections


func _get_unique_id() -> int:
	return _inner.get_unique_id()


func _is_server() -> bool:
	return _inner.get_unique_id() == 1


func _is_server_relay_supported() -> bool:
	return _inner.is_server_relay_supported()


func _get_connection_status() -> ConnectionStatus:
	return _inner.get_connection_status() if _inner != null else CONNECTION_DISCONNECTED


func _disconnect_peer(peer: int, force: bool) -> void:
	if _inner_active():
		_inner.disconnect_peer(peer, force)


func _close() -> void:
	if _inner_active():
		_inner.close()
	_ready_queue.clear()
	_partials.clear()
