extends Node

## Ortak 25 sn bekleme sayacı: kart ekranında başlar, sonraki kart ekranları / kart -> sandık geçişi / her sandık açışı
## SIFIRLAMAZ (kullanıcı bildirimi 2026-10-19). RPC gövdeleri düz fonksiyon olarak çağrılır (ağ gerekmez).

var _backup: Dictionary = {}


func _save() -> void:
	_backup = {
		"lb": NetworkManager.level_up_busy_peers.duplicate(),
		"cb": NetworkManager.chest_busy_peers.duplicate(),
		"lt": NetworkManager.level_up_timer_active,
		"lc": NetworkManager.level_up_countdown,
		"ct": NetworkManager.chest_countdown_active,
		"cc": NetworkManager.chest_countdown,
		"carry": NetworkManager._flow_clock_carry,
	}
	NetworkManager.level_up_busy_peers.clear()
	NetworkManager.chest_busy_peers.clear()
	NetworkManager.level_up_timer_active = false
	NetworkManager.chest_countdown_active = false
	NetworkManager._flow_clock_carry = false


func _restore() -> void:
	NetworkManager.level_up_busy_peers = _backup["lb"]
	NetworkManager.chest_busy_peers = _backup["cb"]
	NetworkManager.level_up_timer_active = _backup["lt"]
	NetworkManager.level_up_countdown = _backup["lc"]
	NetworkManager.chest_countdown_active = _backup["ct"]
	NetworkManager.chest_countdown = _backup["cc"]
	NetworkManager._flow_clock_carry = _backup["carry"]


func test_next_card_screen_does_not_reset() -> void:
	_save()
	NetworkManager._rpc_set_level_up_busy(1, true)
	NetworkManager._rpc_start_level_up_countdown()
	assert(is_equal_approx(NetworkManager.level_up_countdown, 25.0), "akış başında 25 sn")
	NetworkManager.update_level_up_timer(9.0)
	## ikinci oyuncu (ya da aynı oyuncunun sonraki kartı) ekranını açar
	NetworkManager._rpc_set_level_up_busy(2, true)
	NetworkManager._rpc_start_level_up_countdown()
	assert(is_equal_approx(NetworkManager.level_up_countdown, 16.0), "ikinci başlatma sayacı sıfırlamamalı: %s" % NetworkManager.level_up_countdown)
	_restore()


func test_chest_phase_takes_over_remaining_time() -> void:
	_save()
	NetworkManager._rpc_set_level_up_busy(1, true)
	NetworkManager._rpc_start_level_up_countdown()
	NetworkManager.update_level_up_timer(10.0)
	## kart akışı bitti, ilk sandık açılıyor
	NetworkManager._rpc_set_level_up_busy(1, false)
	NetworkManager._rpc_stop_level_up_countdown()
	NetworkManager._rpc_set_chest_busy(1, true)
	NetworkManager._rpc_start_chest_countdown()
	assert(NetworkManager.chest_countdown_active, "sandık sayacı açık")
	assert(is_equal_approx(NetworkManager.chest_countdown, 15.0), "kart ekranından kalan süre devralınmalı (25'e dönmemeli): %s" % NetworkManager.chest_countdown)
	_restore()


func test_next_chest_does_not_reset() -> void:
	_save()
	NetworkManager._rpc_set_level_up_busy(1, true)
	NetworkManager._rpc_start_level_up_countdown()
	NetworkManager.update_level_up_timer(4.0)
	NetworkManager._rpc_set_level_up_busy(1, false)
	NetworkManager._rpc_stop_level_up_countdown()
	NetworkManager._rpc_set_chest_busy(1, true)
	NetworkManager._rpc_start_chest_countdown()
	NetworkManager.update_chest_countdown(6.0)
	## aynı oyuncunun ikinci sandığı + ikinci oyuncunun ilk sandığı
	NetworkManager._rpc_set_chest_busy(1, true)
	NetworkManager._rpc_start_chest_countdown()
	NetworkManager._rpc_set_chest_busy(2, true)
	NetworkManager._rpc_start_chest_countdown()
	assert(is_equal_approx(NetworkManager.chest_countdown, 15.0), "yeni sandık sayacı sıfırlamamalı: %s" % NetworkManager.chest_countdown)
	_restore()


func test_expired_clock_stays_expired_and_new_flow_resets() -> void:
	_save()
	NetworkManager._rpc_set_level_up_busy(1, true)
	NetworkManager._rpc_start_level_up_countdown()
	NetworkManager.update_level_up_timer(30.0)
	assert(is_equal_approx(NetworkManager.level_up_countdown, 0.0), "süre dolar")
	NetworkManager._rpc_set_level_up_busy(1, false)
	NetworkManager._rpc_stop_level_up_countdown()
	NetworkManager._rpc_set_chest_busy(1, true)
	NetworkManager._rpc_start_chest_countdown()
	assert(is_equal_approx(NetworkManager.chest_countdown, 0.0), "dolmuş ortak süre sandıkta yeniden kurulmamalı")
	## herkes bitirdi -> akış kapanır
	NetworkManager._rpc_set_chest_busy(1, false)
	NetworkManager._rpc_stop_chest_countdown()
	assert(not NetworkManager.chest_countdown_active, "akış bitince sayaç kapanır")
	## yeni level atlama = yeni akış = taze 25 sn
	NetworkManager._rpc_set_level_up_busy(1, true)
	NetworkManager._rpc_start_level_up_countdown()
	assert(is_equal_approx(NetworkManager.level_up_countdown, 25.0), "yeni akış taze 25 sn almalı: %s" % NetworkManager.level_up_countdown)
	_restore()


func test_stale_timer_after_disconnect_does_not_poison_next_flow() -> void:
	_save()
	## önceki akışın sayacı açık kalmış (son meşgul oyuncu stop çağrılmadan kopmuş): küme boşalınca sayaç kapanmalı
	NetworkManager.level_up_busy_peers[7] = true
	NetworkManager.level_up_timer_active = true
	NetworkManager.level_up_countdown = 3.0
	NetworkManager._rpc_set_level_up_busy(7, false)
	assert(not NetworkManager.level_up_timer_active, "meşgul kümesi boşalınca sayaç kapanmalı")
	NetworkManager._rpc_set_level_up_busy(1, true)
	NetworkManager._rpc_start_level_up_countdown()
	assert(is_equal_approx(NetworkManager.level_up_countdown, 25.0), "temizlenen eski sayaç yeni akışı bozmamalı")
	_restore()
