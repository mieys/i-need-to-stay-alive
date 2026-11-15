extends Node

## Madde 608: 2v2 odasında seçim ekranında takım seçimi. Kurallar test_pvp_mode.gd'de (saf); burada ekran: iki takım başlığı, oyuncu kartları
## takımının altında, bu takımda değilsem GEÇ düğmesi (takım doluysa kapalı), kendi takımımda TAKIMIN etiketi, başlat bilgisi iki takım kuralını söyler.

const LobbyDesktopScript := preload("res://scripts/lobby_select_desktop.gd")
const GameModeScript := preload("res://scripts/pvp/game_mode.gd")
const TeamsScript := preload("res://scripts/pvp/teams.gd")

var _saved_players: Dictionary = {}
var _saved_max: int = 0


func _wait_previews_warm() -> void:
	for i in 900:
		var all_cached := true
		for id in Characters.DEFS.keys():
			var p: String = str(Characters.get_def(int(id)).get("frames", ""))
			if p != "" and not ResourceLoader.has_cached(p):
				all_cached = false
		if all_cached:
			break
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame


func _restore() -> void:
	GameModeScript.set_room_mode(GameModeScript.COOP)
	TeamsScript.reset()
	NetworkManager.is_multiplayer_active = false
	NetworkManager.lobby_players = _saved_players
	NetworkManager.room_max_players = _saved_max


func _info(n: String, char_id: int) -> Dictionary:
	return {"name": n, "char_id": char_id, "is_ready": false, "is_host": false}


func _header_texts(desk: Control, team: int) -> Array:
	var hdr: Control = desk.find_child("TeamHeader%d" % team, true, false)
	assert(hdr != null, "takım başlığı %d" % team)
	var out: Array = []
	for c in hdr.get_children():
		if c is Label:
			out.append((c as Label).text)
	return out


## Ben (ekranın kendi kimliği: ağ eşi varsa onun id'si, yoksa 0) + iki oyuncu. 4 kişilik oda: takım başı 2.
func test_team_headers_cards_and_join_buttons() -> void:
	_saved_players = NetworkManager.lobby_players
	_saved_max = NetworkManager.room_max_players
	NetworkManager.is_multiplayer_active = true
	NetworkManager.room_max_players = 4
	var desk: Control = LobbyDesktopScript.new()
	add_child(desk) ## _my_id() ağ düğümünü ağaçtayken okur
	var me: int = int(desk.call("_my_id"))
	NetworkManager.lobby_players = {me: _info("Ben", 1), 5: _info("Ali", 2), 6: _info("Veli", 4)}
	GameModeScript.set_room_mode(GameModeScript.PVP)
	TeamsScript.set_all({me: 0, 5: 1, 6: 1})
	desk.call("build")
	await get_tree().process_frame
	await _wait_previews_warm()
	desk.call("refresh")
	await get_tree().process_frame
	## iki takım başlığı, sayılar 1/2 ve 2/2
	assert("1/2" in _header_texts(desk, 0) and "2/2" in _header_texts(desk, 1), "kişi sayıları: %s %s" % [_header_texts(desk, 0), _header_texts(desk, 1)])
	assert(_header_texts(desk, 0).has(TeamsScript.TITLES[0]) and _header_texts(desk, 1).has(TeamsScript.TITLES[1]), "takım adları")
	## başlık satırı sütuna sığar (ad + sayı + düğme taşmaz): her çocuğun sağ kenarı satırın sağ kenarını geçmez
	for t in TeamsScript.TEAM_COUNT:
		var hdr: Control = desk.find_child("TeamHeader%d" % t, true, false)
		for c in hdr.get_children():
			assert((c as Control).get_global_rect().end.x <= hdr.get_global_rect().end.x + 0.5, "başlık %d taşıyor: %s" % [t, c.name])
		assert(hdr.get_global_rect().end.x <= LobbyDesktopScript.LEFT.end.x + 0.5, "başlık sol sütunu aşmıyor")
	## kendi takımımda (0) GEÇ düğmesi yok, 1. takımda var ama takım dolu -> kapalı
	assert(desk.find_child("TeamJoin0", true, false) == null, "kendi takımına geç düğmesi yok")
	var join1: Button = desk.find_child("TeamJoin1", true, false) as Button
	assert(join1 != null and join1.disabled and join1.text == "DOLU", "dolu takım: DOLU, kapalı")
	## oyuncu kartları takımının başlığından sonra: sıra = başlık0, Ben, başlık1, Ali, Veli
	var players: Control = desk.get("_players")
	var order: PackedStringArray = []
	for c in players.get_children():
		if str(c.name).begins_with("TeamHeader"):
			order.append(str(c.name))
		elif c is PanelContainer:
			order.append("kart")
	assert(order == PackedStringArray(["TeamHeader0", "kart", "TeamHeader1", "kart", "kart"]), "kartlar takım altında: %s" % str(order))
	## Veli ayrılınca kızıl takımda yer açılır: GEÇ düğmesi açılır
	NetworkManager.lobby_players = {me: _info("Ben", 1), 5: _info("Ali", 2)}
	TeamsScript.set_all({me: 0, 5: 1})
	desk.call("refresh")
	await get_tree().process_frame
	join1 = desk.find_child("TeamJoin1", true, false) as Button
	assert(join1 != null and not join1.disabled and join1.text == "BU TAKIMA GEÇ", "yer açılınca geçilebilir")
	## ben kızıla geçince (host yayını): başlıklar yer değiştirir, mavide GEÇ düğmesi çıkar
	TeamsScript.set_all({me: 1, 5: 1})
	desk.call("_on_teams_changed")
	await get_tree().process_frame
	assert(desk.find_child("TeamJoin1", true, false) == null, "ben kızıldayım: kızıla geç düğmesi yok (%s)" % str(TeamsScript.by_peer))
	assert(desk.find_child("TeamJoin0", true, false) != null, "mavi takıma geç düğmesi çıktı")
	## başlat bilgisi: herkes kızılda -> mavi takım boş
	assert(TeamsScript.lobby_start_block() != "", "mavi boş: başlatma engeli")
	desk.queue_free()
	await get_tree().process_frame
	_restore()


## Co-op odasında takım başlığı yok (bugünkü görünüm aynen).
func test_coop_room_has_no_team_headers() -> void:
	_saved_players = NetworkManager.lobby_players
	_saved_max = NetworkManager.room_max_players
	NetworkManager.is_multiplayer_active = true
	NetworkManager.lobby_players = {0: _info("Ben", 1), 5: _info("Ali", 2)}
	GameModeScript.set_room_mode(GameModeScript.COOP)
	var desk: Control = LobbyDesktopScript.new()
	add_child(desk)
	desk.call("build")
	await get_tree().process_frame
	await _wait_previews_warm()
	desk.call("refresh")
	await get_tree().process_frame
	assert(desk.find_child("TeamHeader0", true, false) == null and desk.find_child("TeamJoin1", true, false) == null, "co-op: takım başlığı yok")
	assert(TeamsScript.lobby_start_block() == "", "co-op: başlatma kuralı yok")
	desk.queue_free()
	await get_tree().process_frame
	_restore()
