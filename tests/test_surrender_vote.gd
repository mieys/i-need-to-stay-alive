extends Node

## TESLİM OYLAMASI (madde 540, kullanıcı: "oyuna esc de teslim olma seçeneği ekle oylama ile loldeki gibi"; kurallar: OYBİRLİĞİ, hemen açık).
## Host tarafı oylama kuralları NetworkManager üzerinde doğrudan sınanır (OfflineMultiplayerPeer: call_local RPC'ler yerelde çalışır, kimlik 1);
## ESC öğesinin tek oyunculu iki basış akışı ve oylama paneli gerçek düğümlerle. İki süreçli gerçek doğrulama ayrı (tools/mp_audit).

const PanelScript := preload("res://scripts/surrender_vote_panel.gd")
const PauseMenuScene := preload("res://scenes/pause_menu.tscn")
const BalanceLogScript := preload("res://scripts/balance_log.gd")

var _passed_count: int = 0
var _started_count: int = 0
var _ended: Array = []


func _host_room(peers: Array) -> void:
	_cleanup()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	NetworkManager._host_peer = 1
	var lp: Dictionary = {}
	for p in peers:
		lp[p] = {"name": "Oyuncu%d" % p, "char_id": 1, "is_ready": true, "is_host": p == 1}
	NetworkManager.lobby_players = lp
	_passed_count = 0
	_started_count = 0
	_ended.clear()
	if not NetworkManager.surrender_vote_started.is_connected(_on_started):
		NetworkManager.surrender_vote_started.connect(_on_started)
	if not NetworkManager.surrender_passed.is_connected(_on_passed):
		NetworkManager.surrender_passed.connect(_on_passed)
	if not NetworkManager.surrender_vote_ended.is_connected(_on_ended):
		NetworkManager.surrender_vote_ended.connect(_on_ended)


func _on_started(_init: int) -> void:
	_started_count += 1


func _on_passed() -> void:
	_passed_count += 1


func _on_ended(passed: bool, yes_n: int, total: int) -> void:
	_ended.append([passed, yes_n, total])


func _cleanup() -> void:
	NetworkManager.reset_surrender_vote()
	NetworkManager.lobby_players = {}
	NetworkManager.is_multiplayer_active = false
	NetworkManager.is_host = false
	NetworkManager._host_peer = 0
	GameManager.is_game_over = false
	GameManager.run_surrendered = false
	get_tree().paused = false


func test_unanimous_yes_ends_the_run_for_everyone() -> void:
	_host_room([1, 77, 88])
	NetworkManager.request_surrender_vote() ## host başlatır = evet
	assert(NetworkManager.surrender_vote_active, "oylama açılmalı")
	assert(NetworkManager.surrender_voters == PackedInt32Array([1, 77, 88]), "oy verenler yayınlanmalı: %s" % NetworkManager.surrender_voters)
	assert(NetworkManager.my_surrender_vote() == 1, "başlatan evet sayılmalı")
	assert(_started_count == 1, "host da 'oylama başladı' duyurusunu bir kez almalı (sohbet satırı): %d" % _started_count)
	NetworkManager._host_record_surrender_vote(77, true)
	assert(NetworkManager.surrender_vote_active and not GameManager.is_game_over, "oybirliği olmadan bitmemeli")
	assert(_started_count == 1, "ara oy yeni duyuru yapmamalı")
	NetworkManager._host_record_surrender_vote(77, false) ## aynı kişinin ikinci oyu sayılmaz
	assert(NetworkManager.surrender_vote_active, "tekrar oy oylamayı değiştirmemeli")
	NetworkManager._host_record_surrender_vote(555, false) ## odada olmayan eş sayılmaz
	assert(NetworkManager.surrender_vote_active, "odada olmayanın oyu sayılmamalı")
	NetworkManager._host_record_surrender_vote(88, true)
	assert(not NetworkManager.surrender_vote_active, "herkes evet deyince oylama kapanmalı")
	assert(GameManager.is_game_over and GameManager.run_surrendered, "koşu teslimle bitmeli")
	assert(_passed_count == 1, "surrender_passed bir kez: %d" % _passed_count)
	assert(_ended.size() == 1 and _ended[0] == [true, 3, 3], "sonuç 3/3 evet: %s" % str(_ended))
	_cleanup()


func test_single_no_fails_and_starts_cooldown() -> void:
	_host_room([1, 77, 88])
	NetworkManager.request_surrender_vote()
	NetworkManager._host_record_surrender_vote(77, false)
	assert(not NetworkManager.surrender_vote_active, "tek hayır oylamayı düşürmeli")
	assert(not GameManager.is_game_over and _passed_count == 0, "koşu sürmeli")
	assert(_ended.size() == 1 and _ended[0] == [false, 1, 3], "sonuç 1/3: %s" % str(_ended))
	assert(NetworkManager.surrender_cooldown_left() > NetworkManager.SURRENDER_VOTE_COOLDOWN - 2.0, "bekleme başlamalı")
	assert(NetworkManager.surrender_block_reason() != "", "beklemede düğme kapalı olmalı")
	NetworkManager._host_start_surrender_vote(88)
	assert(not NetworkManager.surrender_vote_active, "beklemede yeni oylama açılmamalı")
	_cleanup()


func test_timeout_fails_vote() -> void:
	_host_room([1, 77])
	NetworkManager.request_surrender_vote()
	NetworkManager.update_surrender_vote_timer(NetworkManager.SURRENDER_VOTE_TIMEOUT * 0.5)
	assert(NetworkManager.surrender_vote_active, "süre dolmadan açık kalmalı")
	NetworkManager.update_surrender_vote_timer(NetworkManager.SURRENDER_VOTE_TIMEOUT)
	assert(not NetworkManager.surrender_vote_active and not GameManager.is_game_over, "zaman aşımında geçmemeli")
	assert(_ended.size() == 1 and _ended[0][0] == false, "geçmedi sonucu: %s" % str(_ended))
	_cleanup()


func test_leaving_holdout_lets_the_rest_surrender() -> void:
	_host_room([1, 77])
	NetworkManager.request_surrender_vote()
	assert(NetworkManager.surrender_vote_active, "açık olmalı")
	NetworkManager.lobby_players.erase(77) ## _on_peer_disconnected ile aynı sıra: önce lobiden düşer
	NetworkManager._on_surrender_voter_left()
	assert(GameManager.run_surrendered, "oy vermeyen ayrılınca kalanların oybirliği yeterli")
	_cleanup()


func test_client_vote_during_active_vote_from_menu_counts_as_yes() -> void:
	_host_room([1, 77])
	NetworkManager._host_start_surrender_vote(77) ## istemci başlattı
	assert(NetworkManager.surrender_vote_active and NetworkManager.my_surrender_vote() == -1, "host henüz oy vermedi")
	NetworkManager.request_surrender_vote() ## ESC > EVET OYU VER
	assert(GameManager.run_surrendered, "sürmekte olan oylamada TESLİM OL = evet")
	_cleanup()


func test_solo_surrender_needs_two_presses() -> void:
	_cleanup()
	var menu: CanvasLayer = PauseMenuScene.instantiate()
	add_child(menu)
	var btn: Button = menu.find_child("SurrenderButton", true, false) as Button
	assert(btn != null and btn.visible and not btn.disabled, "ESC menüsünde TESLİM OL olmalı")
	btn.pressed.emit()
	assert(not GameManager.is_game_over, "ilk basış yalnız onay ister")
	assert(menu.get("_surrender_confirm") == true, "onay durumuna geçmeli")
	btn.pressed.emit()
	assert(GameManager.is_game_over and GameManager.run_surrendered, "ikinci basış koşuyu bitirmeli")
	menu.queue_free()
	_cleanup()


func test_surrender_button_hidden_after_game_over() -> void:
	_cleanup()
	GameManager.is_game_over = true
	var menu: CanvasLayer = PauseMenuScene.instantiate()
	add_child(menu)
	var btn: Button = menu.find_child("SurrenderButton", true, false) as Button
	assert(btn != null and not btn.visible, "oyun bittiyse TESLİM OL gizli olmalı")
	menu.queue_free()
	_cleanup()


func test_panel_shows_vote_and_hides_on_result() -> void:
	_host_room([1, 77, 88])
	var panel: CanvasLayer = PanelScript.new()
	add_child(panel)
	var box: Control = panel.get_node("Panel") as Control
	assert(not box.visible, "oylama yokken gizli")
	NetworkManager._host_start_surrender_vote(77)
	assert(box.visible, "oylama başlayınca görünmeli")
	var pips: Control = panel.find_child("Pips", true, false) as Control
	assert(pips.get("voters").size() == 3, "her oyuncuya bir kutu")
	var yes_btn: Button = panel.find_child("YesButton", true, false) as Button
	assert(yes_btn.is_visible_in_tree(), "oy vermeyene düğmeler görünmeli")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_F2
	ev.physical_keycode = KEY_F2
	panel._input(ev) ## F2 = hayır
	assert(not NetworkManager.surrender_vote_active and not GameManager.is_game_over, "F2 oylamayı düşürmeli")
	assert(box.visible and str((panel.find_child("Title", true, false) as Label).text) == "TESLİM GEÇMEDİ", "sonuç kısa süre görünmeli")
	panel._process(PanelScript.RESULT_HOLD + 0.1)
	assert(not box.visible, "sonuçtan sonra kapanmalı")
	panel.queue_free()
	_cleanup()


func test_game_over_title_and_balance_reason() -> void:
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.contains("\"TESLİM OLUNDU\" if GameManager.run_surrendered"), "oyun bitti başlığı teslimi söylemeli")
	assert(main_src.contains("NetworkManager.surrender_passed.connect(_on_surrender_passed)"), "main teslimi dinlemeli")
	GameManager.run_surrendered = true
	GameManager.is_game_over = true
	assert(BalanceLogScript._end_reason({}) == "surrender", "balans kaydı teslimi ayırmalı")
	_cleanup()
