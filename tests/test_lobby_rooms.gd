extends Node

## Lobi sistemi (2026-10-11): oda listesi / oda lobisi / karakter seçimi sahneleri, şifre kanıtı, oda ayarları, ret mesajları,
## oda listesindeki şifre sorusu ve yüz portreli karakter kartı. Gerçek ağ akışı (şifre/dolu/atma) iki-üç süreçli denetimde:
## tools/mp_audit/run_audit.ps1 -Mode lobby.

const CardScript: GDScript = preload("res://scripts/menu_character_card.gd")


func test_lobby_scenes_load() -> void:
	for path in ["res://scenes/room_browser.tscn", "res://scenes/room_lobby.tscn", "res://scenes/lobby_menu.tscn"]:
		var ps: PackedScene = load(path)
		assert(ps != null, "%s yüklenmeli" % path)
		var inst: Node = ps.instantiate()
		assert(inst != null, "%s örneklenmeli" % path)
		inst.free()
	var mm: String = FileAccess.get_file_as_string("res://scripts/main_menu.gd")
	assert(mm.contains("res://scenes/room_browser.tscn"), "ana menüdeki Çok Oyunculu önce oda listesini açmalı")


func test_password_proof_hides_password() -> void:
	assert(NetworkManager.password_proof("abc", "") == "", "şifresiz oda: boş kanıt")
	var p1: String = NetworkManager.password_proof("nonce1", "gizli")
	assert(p1 == NetworkManager.password_proof("nonce1", "gizli"), "aynı kod + şifre aynı kanıt")
	assert(p1 != NetworkManager.password_proof("nonce2", "gizli"), "farklı kodla farklı kanıt (tekrar oynatılamaz)")
	assert(not p1.contains("gizli") and p1.length() == 64, "kanıt sha256, şifrenin kendisi değil")


func test_configure_room_clamps() -> void:
	var old_name: String = NetworkManager.room_name
	var old_pw: String = NetworkManager.room_password
	var old_max: int = NetworkManager.room_max_players
	NetworkManager.configure_room("  Ali|nin odası  ", "x", 1)
	assert(NetworkManager.room_name == "Ali nin odası", "ad kırpılır, | atılır: %s" % NetworkManager.room_name)
	assert(NetworkManager.room_max_players == NetworkManager.ROOM_MIN_PLAYERS, "en az 2 oyuncu")
	NetworkManager.configure_room("a", "", 99)
	assert(NetworkManager.room_max_players == NetworkManager.MAX_PLAYERS, "en çok 8 oyuncu")
	NetworkManager.room_name = old_name
	NetworkManager.room_password = old_pw
	NetworkManager.room_max_players = old_max


func test_reject_messages() -> void:
	var seen: Dictionary = {}
	for code in [NetworkManager.REJECT_PASSWORD_NEEDED, NetworkManager.REJECT_PASSWORD_WRONG, NetworkManager.REJECT_FULL,
			NetworkManager.REJECT_KICKED, NetworkManager.REJECT_VERSION]:
		var m: String = NetworkManager.reject_message(code)
		assert(not m.is_empty() and not seen.has(m), "her ret sebebinin kendi mesajı: %d" % code)
		seen[m] = true


func test_room_browser_lists_rooms_and_asks_password() -> void:
	var rb: Control = load("res://scenes/room_browser.tscn").instantiate()
	add_child(rb)
	await get_tree().process_frame
	rb.set("_online_rooms", [
		{"host_id": "h1", "host_name": "Ali", "room_name": "Gece avı", "players": 2, "max_players": 4, "locked": true, "in_game": false},
		{"host_id": "h2", "host_name": "Veli", "room_name": "Dolu oda", "players": 3, "max_players": 3, "locked": false, "in_game": false},
	])
	rb.call("_rebuild_list")
	var list: VBoxContainer = rb.get("_list")
	assert(list.get_child_count() == 2, "iki oda satırı: %d" % list.get_child_count())
	var full_row: Button = null
	for c in list.get_children():
		if c is Button and str((c as Button).tooltip_text).begins_with("Dolu oda"):
			full_row = c
	assert(full_row != null and full_row.disabled, "dolu oda tıklanamaz")
	var rooms: Array = rb.call("_rooms")
	var locked: Dictionary = {}
	for r in rooms:
		if r["room_name"] == "Gece avı":
			locked = r
	rb.call("_on_room_pressed", locked)
	assert(list.get_child_count() == 3, "kilitli odaya basınca altına şifre satırı açılır")
	assert(rb.get("_pw_input") != null and (rb.get("_pw_input") as LineEdit).secret, "şifre gizli yazılır")
	assert(not bool(NetworkManager.is_multiplayer_active), "şifre girilmeden bağlanılmaz")
	rb.call("_submit_password", locked)
	assert(str(rb.get("_pw_error")) != "", "boş şifreyle Katıl: hata mesajı")
	rb.queue_free()
	await get_tree().process_frame


func test_face_card() -> void:
	var card: Control = CardScript.new()
	add_child(card)
	card.setup(7, Characters.get_def(7), 1.0, true)
	var faces: int = 0
	for c in card.get_children():
		if c is TextureRect:
			faces += 1
	assert(faces == 1 and card.get("_preview") == null, "yüz kartında tam boy sprite yok, tek yüz portresi var")
	card.queue_free()
	var plain: Control = CardScript.new()
	add_child(plain)
	plain.setup(7, Characters.get_def(7), 1.0)
	assert(plain.get("_preview") != null, "tek oyunculu kart eskisi gibi tam boy sprite")
	plain.queue_free()
