extends RefCounted

## BAĞLANTI KALİTESİ ÖLÇER (madde 419; madde 349 "KÖR NOKTA": oyun bağlantı kalitesini hiç ölçmüyordu, Epic'te ping hep -1'di).
## NetworkManager saniyede bir host<->istemci güvenilmez ping atar (_rpc_net_ping/_rpc_net_pong); karşı taraf aynı zaman damgasını geri
## yollar, gidiş-dönüş (RTT) kendi saatimizle ölçülür - ENet de Epic de aynı yoldan geçer (taşıma katmanından bağımsız).
## Peer başına: RTT (üstel ortalama), jitter (ardışık RTT farkının ortalaması), kayıp (son WINDOW pingten LOSS_GRACE_MS içinde dönmeyenler).
## Sonuçlar user://net_log.txt'ye özetlenir (NetworkManager) ve telefon şeridindeki ping yazısı buradan okur.
## (class_name YOK: başsız çalıştırmalarda yeni genel sınıflar görünmez - preload ile kullan.)

const WINDOW := 30 ## kayıp penceresi (ping sayısı = ~30 sn)
const LOSS_GRACE_MS := 2500 ## bu sürede dönmeyen ping kayıp sayılır
const RTT_ALPHA := 0.2

## peer -> {"rtt": float, "jitter": float, "last_rtt": float, "sent": {seq: ms}, "got": {seq: true}, "seq_log": Array[int], "samples": int}
var _peers: Dictionary = {}
var _seq: int = 0


func reset() -> void:
	_peers.clear()


func forget(pid: int) -> void:
	_peers.erase(pid)


func _rec(pid: int) -> Dictionary:
	if not _peers.has(pid):
		_peers[pid] = {"rtt": -1.0, "jitter": 0.0, "last_rtt": -1.0, "sent": {}, "got": {}, "seq_log": [], "samples": 0}
	return _peers[pid]


## Yeni ping için sıra numarası; gönderim anı kaydedilir.
func next_ping(pid: int, now_ms: int) -> int:
	_seq = (_seq + 1) & 0x7FFFFFFF
	var r: Dictionary = _rec(pid)
	(r["sent"] as Dictionary)[_seq] = now_ms
	var order: Array = r["seq_log"]
	order.append(_seq)
	while order.size() > WINDOW:
		var old: int = int(order.pop_front())
		(r["sent"] as Dictionary).erase(old)
		(r["got"] as Dictionary).erase(old)
	return _seq


## Pong geldi: t_sent = bizim gönderdiğimiz zaman damgası (karşı taraf aynen geri yollar).
func on_pong(pid: int, seq: int, t_sent: int, now_ms: int) -> void:
	if not _peers.has(pid):
		return
	var r: Dictionary = _peers[pid]
	var sent: Dictionary = r["sent"]
	if not sent.has(seq) or (r["got"] as Dictionary).has(seq) or int(sent[seq]) != t_sent:
		return ## bilinmeyen / tekrar / sahte
	(r["got"] as Dictionary)[seq] = true
	var rtt: float = float(maxi(0, now_ms - t_sent))
	if float(r["rtt"]) < 0.0:
		r["rtt"] = rtt
	else:
		r["rtt"] = lerpf(float(r["rtt"]), rtt, RTT_ALPHA)
	if float(r["last_rtt"]) >= 0.0:
		r["jitter"] = lerpf(float(r["jitter"]), absf(rtt - float(r["last_rtt"])), RTT_ALPHA)
	r["last_rtt"] = rtt
	r["samples"] = int(r["samples"]) + 1


## -> {"rtt": ms (-1 = henüz yok), "jitter": ms, "loss": 0..1, "samples": int}
func stats(pid: int, now_ms: int) -> Dictionary:
	if not _peers.has(pid):
		return {"rtt": -1.0, "jitter": 0.0, "loss": 0.0, "samples": 0}
	var r: Dictionary = _peers[pid]
	var sent: Dictionary = r["sent"]
	var got: Dictionary = r["got"]
	var due: int = 0
	var lost: int = 0
	for seq in sent.keys():
		if now_ms - int(sent[seq]) < LOSS_GRACE_MS:
			continue
		due += 1
		if not got.has(seq):
			lost += 1
	return {"rtt": float(r["rtt"]), "jitter": float(r["jitter"]), "loss": float(lost) / float(due) if due > 0 else 0.0, "samples": int(r["samples"])}


func peers() -> Array:
	return _peers.keys()
