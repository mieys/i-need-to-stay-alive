extends Node

## AĞ GECİKMESİ DÜZELTMESİ (madde 419; analiz madde 349): güvenilir RPC'lerin aktarım kanalları, oyuncu durum paketi deltası, yaratık
## senkronunda değişmeyen can/kalkanın atlanması (FLAG_NO_HP + bayta göre paket bölme), bağlantı kalitesi ölçer. Gerçek ağ davranışı
## (gecikme/kayıp altında ölçüm) iki süreçli `tools/mp_audit/net_probe/run_net_probe.ps1`.

const CodecScript := preload("res://scripts/enemy_sync_codec.gd")
const SpawnerScript := preload("res://scripts/enemy_spawner.gd")
const LinkQualityScript := preload("res://scripts/net/link_quality.gd")
const DeltaScript := preload("res://scripts/net/state_delta.gd")


## Betiğin @rpc tablosu (Script.get_rpc_config: yöntem -> {rpc_mode, transfer_mode, call_local, channel}).
func _cfg(script: Script) -> Dictionary:
	return script.get_rpc_config() as Dictionary


func _rpc_channel(script: Script, method: String) -> int:
	var cfg: Dictionary = _cfg(script)
	assert(cfg.has(method), "%s RPC olarak tanımlı" % method)
	return int((cfg[method] as Dictionary).get("channel", 0))


func _rpc_mode(script: Script, method: String) -> int:
	return int((_cfg(script)[method] as Dictionary).get("transfer_mode", -1))


# ------------------------------------------------------------------ kanallar

func test_combat_and_fx_rpcs_use_their_own_channels() -> void:
	var nm: Node = NetworkManager
	var sc: Script = nm.get_script()
	for m in ["request_enemy_damage", "request_enemy_effect", "request_enemy_element", "request_enemy_skill_push", "request_world_event_copy_damage",
			"forward_damage_to_peer", "forward_special_damage_to_peer", "forward_player_fling_to_peer", "sync_redirected_damage"]:
		assert(_rpc_channel(sc, m) == nm.CH_COMBAT, "%s hasar kanalında" % m)
		assert(_rpc_mode(sc, m) == MultiplayerPeer.TRANSFER_MODE_RELIABLE, "%s güvenilir kaldı" % m)
	for m in ["broadcast_enemy_vfx", "broadcast_enemy_ability_fx"]:
		assert(_rpc_channel(sc, m) == nm.CH_ENEMY_FX, "%s yaratık görsel kanalında" % m)
	## sıra bağımlı eşler varsayılan kanalda kalır (doğ/sil, ödül)
	for m in ["broadcast_drop", "remove_drop", "remove_drops_batch", "grant_kill_gold", "broadcast_player_vfx_reliable", "broadcast_player_fx_stop"]:
		assert(_rpc_channel(sc, m) == 0, "%s varsayılan kanalda" % m)
	assert(nm.CH_COMBAT != nm.CH_ENEMY_FX and nm.CH_ENEMY_FX != nm.CH_STATE and nm.CH_COMBAT != nm.CH_STATE, "kanallar ayrı")


func test_state_rpc_channel_matches_network_manager() -> void:
	var MainScript: GDScript = load("res://scripts/main.gd") ## preload değil: main.gd'nin bağımlılık zinciri diğer testleri bağlamasın
	assert(MainScript.STATE_CHANNEL == NetworkManager.CH_STATE, "main.gd STATE_CHANNEL = NetworkManager.CH_STATE")
	assert(_rpc_channel(MainScript, "_rpc_player_state") == NetworkManager.CH_STATE, "durum paketi kendi kanalında")
	assert(_rpc_mode(MainScript, "_rpc_player_state") == MultiplayerPeer.TRANSFER_MODE_RELIABLE, "durum paketi güvenilir (delta sırası)")
	assert(not _cfg(MainScript).has("_rpc_update_player_extra_state"), "eski tam paket RPC'si kalktı")
	var nm_sc: Script = NetworkManager.get_script()
	for m in ["_rpc_net_ping", "_rpc_net_pong"]:
		assert(_rpc_mode(nm_sc, m) == MultiplayerPeer.TRANSFER_MODE_UNRELIABLE, "%s güvenilmez (ölçüm akışı tıkamasın)" % m)


# ------------------------------------------------------------------ durum deltası

func _state(hp: float, extra: Dictionary, weapons: Array = ["tufek"]) -> Dictionary:
	return {"hp": hp, "max_hp": 100.0, "s_hp": 5.0, "s_max": 10.0, "p_zone": false, "dead": false, "weapon_keys": weapons, "extra": extra}


func test_state_delta_rebuilds_the_full_state() -> void:
	var a: Dictionary = DeltaScript.flatten(_state(80.0, {"luck": 1.0, "hadime": {"fly": true}, "dmg_dealt": 10.0, "evo": [1, 2]}))
	var b: Dictionary = DeltaScript.flatten(_state(75.0, {"luck": 1.0, "dmg_dealt": 12.0, "evo": [1, 2, 3], "cride": 5}, ["tufek", "yay"]))
	var d: Dictionary = DeltaScript.diff(a, b)
	assert(not d.has("luck"), "değişmeyen anahtar gönderilmez")
	assert(d.has("_hp") and d.has("dmg_dealt") and d.has("evo") and d.has("cride") and d.has("_weapon_keys"), "değişen/eklenenler var: %s" % str(d.keys()))
	assert(d.has("hadime") and d["hadime"] == null, "silinen anahtar null")
	var cache: Dictionary = a.duplicate(true)
	DeltaScript.apply(cache, d)
	assert(cache == b, "tam paket + delta = yeni durum")
	assert(DeltaScript.diff(b, b).is_empty(), "değişmeyen durumda delta boş")
	## tür değişimi (0 -> 0.0) de değişim sayılır (yanlış eşitlik hatası olmasın)
	assert(DeltaScript.diff({"x": 0}, {"x": 0.0}).has("x"), "int -> float değişim")


func test_state_delta_is_much_smaller_than_full_packet() -> void:
	var extra: Dictionary = {}
	for i in 38:
		extra["anahtar_%d" % i] = float(i)
	var a: Dictionary = DeltaScript.flatten(_state(80.0, extra))
	extra["anahtar_3"] = 99.0
	var b: Dictionary = DeltaScript.flatten(_state(79.0, extra))
	var full_b: int = var_to_bytes(b).size()
	var delta_b: int = var_to_bytes(DeltaScript.diff(a, b)).size()
	assert(delta_b * 8 < full_b, "2 anahtarlık delta tam paketin 1/8'inden küçük: %d / %d" % [delta_b, full_b])


# ------------------------------------------------------------------ yaratık senkronu

func test_codec_no_hp_records_round_trip_and_are_smaller() -> void:
	var states: Array = [
		[7, Vector2(10.5, -3.25), false, 42.5, 10.25, false, 2, 0, true],
		[8, Vector2(1.0, 2.0), true, 0.0, 0.0, true, 0, 99, true],
		[9, Vector2(5.0, 6.0), false, 30.0, 1.0, false, 0, 0, false],
	]
	var data: PackedByteArray = CodecScript.encode(42, states)
	assert(data.size() == CodecScript.HEADER_BYTES + CodecScript.RECORD_BYTES_NO_HP + (CodecScript.RECORD_BYTES_NO_HP + 4) + CodecScript.RECORD_BYTES,
			"can/kalkansız kayıt 14 bayt: %d" % data.size())
	var dec: Array = CodecScript.decode(data)["states"]
	assert(dec.size() == 3)
	assert(int(dec[0][0]) == 7 and (dec[0][1] as Vector2).is_equal_approx(Vector2(10.5, -3.25)) and float(dec[0][3]) < 0.0 and float(dec[0][4]) < 0.0,
			"atlanan can/kalkan -1 (istemci dokunmaz)")
	assert(int(dec[0][6]) == 2, "chill korunur")
	assert(dec[1][2] == true and int(dec[1][7]) == 99 and float(dec[1][3]) < 0.0, "ölü + son vuran + can yok")
	assert(is_equal_approx(float(dec[2][3]), 30.0) and is_equal_approx(float(dec[2][4]), 1.0), "tam kayıt aynen")
	## 8 alanlı eski biçim hâlâ tam kayıt
	assert(CodecScript.encode(1, [[1, Vector2.ZERO, false, 1.0, 1.0, false, 0, 0]]).size() == CodecScript.HEADER_BYTES + CodecScript.RECORD_BYTES)


func test_split_by_bytes_stays_under_the_epic_packet_limit() -> void:
	var states: Array = []
	for i in 300:
		states.append([i + 1, Vector2(i, i), false, 10.0, 0.0, false, 0, (5 if i % 3 == 0 else 0), i % 2 == 0])
	var chunks: Array = CodecScript.split_by_bytes(states)
	var total: int = 0
	for c: Array in chunks:
		var n: int = CodecScript.encode(1, c).size()
		assert(n <= CodecScript.MAX_PACKET_BYTES, "paket %d bayt <= sınır" % n)
		total += c.size()
	assert(total == 300, "kayıt kaybı yok")
	assert(chunks.size() < int(ceil(300.0 / CodecScript.BATCH)), "bayta göre bölme eski 40'lık dilimden az paket: %d" % chunks.size())


func test_hp_is_resent_after_change_and_refreshed_periodically() -> void:
	var sent: Dictionary = {}
	assert(SpawnerScript.hp_must_send(sent, 5, 10.0, 2.0), "ilk kez her zaman")
	for i in SpawnerScript.HP_REPEAT_TICKS:
		assert(SpawnerScript.hp_must_send(sent, 5, 10.0, 2.0), "değişimden sonra %d. tekrar" % (i + 1))
	var skipped: int = 0
	var refreshed: bool = false
	for i in SpawnerScript.HP_REFRESH_TICKS:
		if SpawnerScript.hp_must_send(sent, 5, 10.0, 2.0):
			refreshed = true
			break
		skipped += 1
	assert(refreshed and skipped == SpawnerScript.HP_REFRESH_TICKS - 1, "değişmeyen can %d tur atlanır, sonra yenilenir" % skipped)
	assert(not SpawnerScript.hp_must_send(sent, 5, 10.0, 2.0), "yenilemeden sonra yine atlanır")
	assert(SpawnerScript.hp_must_send(sent, 5, 9.0, 2.0), "can değişince hemen")
	assert(SpawnerScript.hp_must_send(sent, 5, 9.0, 2.0), "ve ardından tekrar")
	assert(SpawnerScript.hp_must_send(sent, 6, 9.0, 2.0), "başka yaratık kendi kaydıyla")
	for i in SpawnerScript.HP_REPEAT_TICKS + 1:
		SpawnerScript.hp_must_send(sent, 5, 9.0, 2.0)
	assert(SpawnerScript.hp_must_send(sent, 5, 9.0, 1.5), "kalkan değişimi de sayılır")


# ------------------------------------------------------------------ bağlantı kalitesi

func test_link_quality_rtt_jitter_and_loss() -> void:
	var lq = LinkQualityScript.new()
	assert(float(lq.stats(2, 0)["rtt"]) < 0.0, "ölçüm yokken -1")
	var t: int = 10000
	for i in 10:
		var seq: int = lq.next_ping(2, t)
		if i % 5 != 4: ## her 5 pingten biri kayıp
			lq.on_pong(2, seq, t, t + 100 + (i % 2) * 20)
		t += 1000
	var s: Dictionary = lq.stats(2, t + 5000)
	assert(absf(float(s["rtt"]) - 110.0) < 15.0, "rtt ~110 ms: %s" % str(s["rtt"]))
	assert(float(s["jitter"]) > 5.0, "jitter ölçülür: %s" % str(s["jitter"]))
	assert(absf(float(s["loss"]) - 0.2) < 0.01, "kayıp %%20: %s" % str(s["loss"]))
	## sahte / tekrar pong sayılmaz
	var seq2: int = lq.next_ping(2, t)
	lq.on_pong(2, seq2, t - 50, t + 10) ## yanlış zaman damgası
	lq.on_pong(2, seq2 + 99, t, t + 10) ## bilinmeyen sıra
	assert(int(lq.stats(2, t)["samples"]) == 8, "sahte pong örnek eklemez")
	lq.forget(2)
	assert(float(lq.stats(2, t)["rtt"]) < 0.0, "ayrılan peer unutulur")
