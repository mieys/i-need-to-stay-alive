extends Node

## Gecikme ölçer (madde 349, net_probe.gd): oyunun KENDİ güvenilir/güvenilmez RPC trafiğiyle aynı kanalda, her iki yönde zaman damgalı ping.
## Aynı makine (aynı saat) olduğu için tek yön gecikme doğrudan okunur.
var rel_lat: Array = []   # [alıcıda ms gecikme, seq]
var unr_lat: Array = []
var rel_seen: Dictionary = {}
var unr_seen: Dictionary = {}
var sent_rel: int = 0
var sent_unr: int = 0
var chan_lat: Array = []
var sent_chan: int = 0


@rpc("any_peer", "call_remote", "reliable")
func r_ping(seq: int, t_send: float) -> void:
	var now: float = Time.get_unix_time_from_system()
	rel_lat.append([snappedf((now - t_send) * 1000.0, 0.1), seq, snappedf(now, 0.001)])
	rel_seen[seq] = true


@rpc("any_peer", "call_remote", "unreliable")
func u_ping(seq: int, t_send: float) -> void:
	var now: float = Time.get_unix_time_from_system()
	unr_lat.append([snappedf((now - t_send) * 1000.0, 0.1), seq, snappedf(now, 0.001)])
	unr_seen[seq] = true


@rpc("any_peer", "call_remote", "reliable", 7)
func c_ping(seq: int, t_send: float) -> void:
	var now: float = Time.get_unix_time_from_system()
	chan_lat.append([snappedf((now - t_send) * 1000.0, 0.1), seq, snappedf(now, 0.001)])


func send_pair(peer_id: int) -> void:
	var t: float = Time.get_unix_time_from_system()
	sent_rel += 1
	sent_unr += 1
	r_ping.rpc_id(peer_id, sent_rel, t)
	u_ping.rpc_id(peer_id, sent_unr, t)
	sent_chan += 1
	c_ping.rpc_id(peer_id, sent_chan, t)
