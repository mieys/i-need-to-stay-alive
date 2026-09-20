extends Node

## Kullanıcı bildirimi: "multiplayerda yeniden başlat butonuna basıp oyunculardan onay alınca oyun yeniden
## başlamıyor, ben zaten direkt aynı oyunu yeniden başlatsın istemiyorum; odaya atıp var olan oyuncularla tekrar
## karakter seçimi yaparak yeniden başlamasını istiyorum."
## Kök neden: oylama sırasında ağaç duraklatılıyor, onaydan sonra duraklatma hiç kaldırılmıyordu; doğrudan
## açılan yükleme ekranı duraklı ağaçta ilerlemeden sonsuza dek takılıyordu (iki gerçek süreçle yeniden üretildi).
## Yeni akış: onay -> herkes odaya (lobi) döner, "hazır" sıfırlanır, karakter yeniden seçilir, host başlatır.
## Gerçek iki süreçli (host + client, ENet) doğrulama ayrıca elle koşuldu; bu dosya hızlı regresyon koruması.


func _strip_comments(src: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		var idx: int = line.find("#")
		out.append(line.substr(0, idx) if idx != -1 else line)
	return "\n".join(out)


func _body(src: String, start_marker: String, end_marker: String) -> String:
	var start: int = src.find(start_marker)
	var end: int = src.find(end_marker, start + 1)
	assert(start != -1 and end > start, "fonksiyon bulunamadı: %s" % start_marker)
	return _strip_comments(src.substr(start, end - start))


## Onaylanan oylama artık doğrudan _rpc_start_game()'e DEĞİL odaya dönüşe gitmeli.
func test_approved_vote_returns_everyone_to_the_lobby() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	var result_fn: String = _body(src, "func _rpc_broadcast_restart_vote_result(", "## true iken lobby_menu.gd")
	assert(result_fn.contains("_return_to_lobby_for_restart()"), "Onaylanan oylama odaya dönüşü tetiklemeli")
	assert(not result_fn.contains("_rpc_start_game"), "Onaylanan oylama aynı oyunu doğrudan yeniden başlatmamalı")
	var return_fn: String = _body(src, "func _return_to_lobby_for_restart()", "func update_restart_vote_timer")
	assert(return_fn.contains("res://scenes/lobby_menu.tscn"), "Yeniden başlatma lobi ekranına dönmeli")
	assert(return_fn.contains("_reset_for_restart_lobby()"), "Dönüşten önce oyun durumu sıfırlanmalı")


## Asıl hata: duraklatma kaldırılmazsa lobi/yükleme ekranı ilerlemez.
func test_reset_lifts_the_pause_that_the_vote_set() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	var reset_fn: String = _body(src, "func _reset_for_restart_lobby()", "func _return_to_lobby_for_restart()")
	assert(reset_fn.contains("get_tree().paused = false"),
		"Oylamanın koyduğu duraklatma kaldırılmalı (aksi halde sonraki ekran takılı kalır)")

	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	NetworkManager._reset_for_restart_lobby()
	assert(not get_tree().paused, "Sıfırlamadan sonra ağaç duraklatılmış kalmamalı")
	get_tree().paused = was_paused
	_restore_network_state()


## Bağlantı/oyuncu listesi KORUNUR, "hazır" durumları sıfırlanır (sadece host hazır), oyun oturumu bayrakları temizlenir.
func test_reset_keeps_players_and_clears_ready_and_session_flags() -> void:
	NetworkManager.lobby_players = {
		1: {"name": "Host", "char_id": 10, "is_ready": true, "is_host": true},
		77: {"name": "Arkadas", "char_id": 5, "is_ready": true, "is_host": false},
	}
	NetworkManager._host_peer = 1
	NetworkManager._is_game_in_progress = true
	NetworkManager._is_rejoining_midgame = true
	NetworkManager.restart_vote_pending = true
	NetworkManager.restart_vote_responses = {1: true, 77: true}
	NetworkManager.chest_busy_peers = {77: true}
	NetworkManager.level_up_busy_peers = {77: true}
	NetworkManager.level_up_timer_active = true
	NetworkManager.mini_shop_timer_active = true

	NetworkManager._reset_for_restart_lobby()

	assert(NetworkManager.lobby_players.size() == 2, "Oyuncular odada kalmalı")
	assert(NetworkManager.lobby_players[77]["name"] == "Arkadas", "Oyuncu bilgisi korunmalı")
	assert(NetworkManager.lobby_players[1]["is_ready"] == true, "Host hazır sayılmalı (lobinin ilk hali)")
	assert(NetworkManager.lobby_players[77]["is_ready"] == false, "Katılımcı yeniden 'HAZIRIM'a basmalı")
	assert(not NetworkManager._is_game_in_progress, "'Oyun devam ediyor' bayrağı kalkmalı (yoksa hazır olan doğrudan eski oyuna girmeye çalışır)")
	assert(not NetworkManager._is_rejoining_midgame, "Yarıdan katılma bayrağı kalkmalı")
	assert(not NetworkManager.restart_vote_pending and NetworkManager.restart_vote_responses.is_empty(), "Oylama durumu temizlenmeli")
	assert(NetworkManager.chest_busy_peers.is_empty() and NetworkManager.level_up_busy_peers.is_empty(), "Eski sandık/level bekleme durumları temizlenmeli")
	assert(not NetworkManager.level_up_timer_active and not NetworkManager.mini_shop_timer_active, "Eski geri sayımlar durmalı")
	assert(NetworkManager.restart_returned_to_lobby, "Lobiye 'yeniden başlatma' bilgisi bırakılmalı")
	_restore_network_state()


## Lobi ekranı bağlıyken açılınca bilgi mesajını göstermeli ve bayrağı tüketmeli.
func test_lobby_shows_the_restart_notice_once() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/lobby_menu.gd")
	assert(src.contains("restart_returned_to_lobby"), "lobby_menu.gd yeniden başlatma bayrağını okumalı")
	assert(src.contains("NetworkManager.restart_returned_to_lobby = false"), "Bilgi bir kez gösterilip bayrak temizlenmeli")


func _restore_network_state() -> void:
	NetworkManager.lobby_players = {}
	NetworkManager._host_peer = 0
	NetworkManager.restart_returned_to_lobby = false
	NetworkManager._is_game_in_progress = false
	NetworkManager._is_rejoining_midgame = false
	NetworkManager.restart_vote_pending = false
	NetworkManager.restart_vote_responses = {}
	NetworkManager.chest_busy_peers = {}
	NetworkManager.level_up_busy_peers = {}
	NetworkManager.level_up_timer_active = false
	NetworkManager.mini_shop_timer_active = false
