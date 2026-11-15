extends Node

## DÜNYA HARİTASI seçim ekranı ("B - Atlas Defteri", madde 606): her seçilebilir haritanın önizlemesi + küçük resmi var, ekran listeden
## seçer / yukarı-aşağı satır değiştirir / YOLA ÇIK sinyali / çok oyunculu OYLAMA kipi (madde 620); host->istemci RPC'sinin gövdesi.

const MapProfiles := preload("res://scripts/map_profiles.gd")
const Screen := preload("res://scripts/world_map_screen.gd")


func test_every_selectable_map_has_preview() -> void:
	## Yeni harita seçilebilir yapıldıysa: tools/dunya_haritasi/uret.py REGIONS'a ekle, uret.ps1 + uret.py ile yeniden üret.
	for id: String in MapProfiles.selectable_ids():
		var pv: Texture2D = load(Screen.ART_DIR + "onizleme_%s.png" % id)
		var th: Texture2D = load(Screen.ART_DIR + "kucuk_%s.png" % id)
		assert(pv != null and th != null, "dünya haritası dokusu yok: " + id)
		assert(Vector2(pv.get_size()) == Screen.PREVIEW_SIZE, id + " önizleme boyu")
		assert(th.get_width() == int(Screen.THUMB) and th.get_height() == int(Screen.THUMB), id + " küçük resim boyu")
	assert(Screen.map_ids() == MapProfiles.selectable_ids())


func test_screen_selects_and_confirms() -> void:
	var s: Control = Screen.new()
	s.initial_map = "bataklik"
	add_child(s)
	await get_tree().process_frame
	assert(s.call("get_pick") == "bataklik")
	assert(s.find_child("Back", true, false) != null and s.find_child("Go", true, false) != null)
	var pv: TextureRect = s.find_child("Preview", true, false)
	assert(pv.texture.resource_path.ends_with("onizleme_bataklik.png"))
	## satır tıklaması
	(s.find_child("Row_col", true, false) as Button).pressed.emit()
	assert(s.call("get_pick") == "col")
	assert(pv.texture.resource_path.ends_with("onizleme_col.png"))
	## klavye: aşağı bir sonraki satır, en üstte yukarı yerinde kalır
	var ids: Array[String] = Screen.map_ids()
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	s.call("_input", down)
	assert(s.call("get_pick") == ids[ids.find("col") + 1])
	s.call("_select", ids[0], false)
	var up := InputEventAction.new()
	up.action = "ui_up"
	up.pressed = true
	s.call("_input", up)
	assert(s.call("get_pick") == ids[0])
	var got: Array = []
	s.connect("chosen", func(id: String) -> void: got.append(id))
	s.call("_select", ids.back(), true)
	s.call("_confirm")
	assert(got == [ids.back()])
	s.queue_free()
	await get_tree().process_frame


## Hata defteri 2026-11-14: satır içeriği ortalandığı için küçük görseller ad uzunluğuna göre farklı x'teydi -> hepsi aynı sütunda olmalı.
func test_list_rows_left_aligned() -> void:
	var s: Control = Screen.new()
	add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	var xs: Array[float] = []
	for id: String in Screen.map_ids():
		var b: Button = s.find_child("Row_" + id, true, false)
		var row: HBoxContainer = b.get_meta("row")
		var thumb: Control = row.get_child(0)
		xs.append(thumb.global_position.x - b.global_position.x)
	assert(xs.size() >= 2)
	for x: float in xs:
		assert(absf(x - xs[0]) < 1.0, "küçük görsel x kayması: " + str(xs))
	assert(xs[0] <= Screen.ROW_PAD + 1.0, "görsel sola yaslı değil: " + str(xs[0]))
	s.queue_free()
	await get_tree().process_frame


## OYLAMA kipi (madde 620): satır tıklaması = oy (`voted`), YOLA ÇIK yok, oy yüzleri + sayaç, kazanan gösterimi sonrası oy kapanır.
func test_voting_screen_votes_and_shows_winner() -> void:
	NetworkManager.lobby_players = {1: {"char_id": 4}, 2: {"char_id": 1}, 3: {"char_id": 7}}
	var s: Control = Screen.new()
	s.voting = true
	s.can_cancel = false
	s.initial_map = "ana"
	add_child(s)
	await get_tree().process_frame
	assert(s.find_child("Back", true, false) == null and s.find_child("Go", true, false) == null, "oylamada YOLA ÇIK / istemcide GERİ yok")
	assert(s.find_child("VoteHead", true, false) != null and s.find_child("VoteSub", true, false) != null)
	var votes: Array = []
	var chosen: Array = []
	var cancelled: Array = []
	s.connect("voted", func(id: String) -> void: votes.append(id))
	s.connect("chosen", func(id: String) -> void: chosen.append(id))
	s.connect("cancelled", func() -> void: cancelled.append(true))
	(s.find_child("Row_col", true, false) as Button).pressed.emit()
	assert(votes == ["col"] and s.call("get_pick") == "col", "satır tıklaması oy verir ve önizlemeyi o haritaya geçirir")
	s.call("_confirm")
	assert(chosen.is_empty(), "oylamada YOLA ÇIK yok")
	## klavye: yukarı/aşağı yalnız odağı değiştirir (yanlışlıkla son oy olmasın), ui_accept odaktaki haritaya oy verir
	var ids: Array[String] = Screen.map_ids()
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	s.call("_input", down)
	assert(votes == ["col"] and s.call("get_pick") == ids[ids.find("col") + 1], "ok tuşu oy vermez")
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	s.call("_input", accept)
	assert(votes.size() == 2 and votes[1] == ids[ids.find("col") + 1], "ui_accept odaktaki haritaya oy verir")
	## ESC: istemcide (can_cancel false) yutulur, GERİ yok
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	s.call("_input", esc)
	assert(cancelled.is_empty())
	## oy listesi: yüzler doğru satırda, sayaç "3 / 3"
	s.call("set_votes", {1: "col", 2: "col", 3: "bataklik"}, 1, 3)
	assert((s.find_child("Votes_col", true, false) as Control).get_child_count() == 2)
	assert((s.find_child("Votes_bataklik", true, false) as Control).get_child_count() == 1)
	assert((s.find_child("Votes_ana", true, false) as Control).get_child_count() == 0)
	assert(str((s.find_child("VoteSub", true, false) as Label).text).contains("3 / 3"), "sayaç: " + str((s.find_child("VoteSub", true, false) as Label).text))
	## süre sayacı
	s.call("set_time_left", 17.2)
	assert(str((s.find_child("VoteHead", true, false) as Label).text).contains("18"), "kalan süre yukarı yuvarlanır")
	## kazanan: önizleme kazananda, oy kapanır
	s.call("show_winner", "bataklik", true)
	assert(s.call("get_winner") == "bataklik" and s.call("get_pick") == "bataklik")
	votes.clear()
	(s.find_child("Row_col", true, false) as Button).pressed.emit()
	assert(votes.is_empty(), "kazanan belli olunca oy verilemez")
	s.queue_free()
	NetworkManager.lobby_players = {}
	await get_tree().process_frame


func test_voting_screen_host_can_cancel() -> void:
	var s: Control = Screen.new()
	s.voting = true
	s.can_cancel = true
	s.initial_map = "ana"
	add_child(s)
	await get_tree().process_frame
	assert(s.find_child("Back", true, false) != null, "host oylamayı iptal edebilir")
	var cancelled: Array = []
	s.connect("cancelled", func() -> void: cancelled.append(true))
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	s.call("_input", esc)
	assert(cancelled.size() == 1)
	s.queue_free()
	await get_tree().process_frame


func test_world_map_rpc_updates_state_and_signal() -> void:
	## Tekli oyunda _from_host() true: istemcinin alacağı RPC'nin gövdesi doğrudan sınanır.
	var got: Array = []
	var cb := func(open: bool, id: String) -> void: got.append([open, id])
	NetworkManager.world_map_changed.connect(cb)
	NetworkManager.call("_rpc_world_map", true, "col")
	assert(NetworkManager.world_map_open and NetworkManager.world_map_pick == "col")
	NetworkManager.call("_rpc_world_map", true, "yok_boyle")
	assert(NetworkManager.world_map_pick == MapProfiles.DEFAULT_ID, "bilinmeyen harita ana haritaya düşer")
	NetworkManager.call("_rpc_world_map", false, "")
	assert(not NetworkManager.world_map_open)
	assert(got.size() == 3 and got[0] == [true, "col"] and got[2][0] == false)
	NetworkManager.world_map_changed.disconnect(cb)
	## host olmayan tekli oyunda yayın hiçbir şey göndermez
	NetworkManager.broadcast_world_map(true, "ana")
	assert(not NetworkManager.world_map_open)
