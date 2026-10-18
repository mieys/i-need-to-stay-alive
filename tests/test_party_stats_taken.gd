extends Node

## Grup paneli Hasar Sıralaması: verilen + ALINAN hasar (2026-10-18, kullanıcı: "grup istatistiklerinde alınan hasar da olmalı
## hem pc hem mobilde"). Alınan hasar kuklaya durum kanalının "dmg_taken" alanıyla gider (main.gd -> remote_player.gd).

const PartyPanelScript = preload("res://scripts/party_panel.gd")


func _fake(dealt: float, taken: float, pname: String) -> Node2D:
	var s := GDScript.new()
	## Grup satırının okuduğu alanlar da (bkz. party_panel.gd _rebuild_rows / satır güncellemesi), yoksa int(null) patlar.
	s.source_code = "extends Node2D\nvar match_damage_dealt: float = 0.0\nvar match_damage_taken: float = 0.0\nvar player_name: String = \"\"\n" \
			+ "var peer_id: int = 1234\nvar char_id: int = 10\nvar health: float = 300.0\nvar max_health: float = 500.0\n" \
			+ "var item_shield_hp: float = 50.0\nvar item_shield_max: float = 100.0\nvar is_downed: bool = false\nvar is_dead: bool = false\n"
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	n.set("match_damage_dealt", dealt)
	n.set("match_damage_taken", taken)
	n.set("player_name", pname)
	return n


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_texts(c, out)


func test_sync_channel_carries_damage_taken() -> void:
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.find("\"dmg_taken\": player.match_damage_taken") != -1, "durum kanalı alınan hasarı göndermeli")
	var rp_src: String = FileAccess.get_file_as_string("res://scripts/remote_player.gd")
	assert(rp_src.find("match_damage_taken = extra.get(\"dmg_taken\"") != -1, "kukla alınan hasarı durum kanalından okumalı")


func test_live_stats_include_damage_taken() -> void:
	var me := _fake(1200.0, 340.0, "")
	me.add_to_group("player")
	add_child(me)
	var ally := _fake(800.0, 910.0, "Mira")
	ally.add_to_group("remote_players")
	add_child(ally)
	var panel: Control = PartyPanelScript.new()
	add_child(panel)
	var entries: Array = panel.call("_gather_live_stats")
	var ok_count: bool = entries.size() == 2
	var first: Dictionary = entries[0] if ok_count else {}
	var second: Dictionary = entries[1] if ok_count else {}
	var texts: Array = []
	panel.call("_refresh_stats_popup")
	var stats_list: Node = panel.get("_stats_list")
	if stats_list:
		_texts(stats_list, texts)
	panel.queue_free()
	me.queue_free()
	ally.queue_free()
	assert(ok_count, "yerel + 1 müttefik girdisi beklenir: %d" % entries.size())
	assert(float(first.get("dealt", 0.0)) == 1200.0 and float(first.get("taken", -1.0)) == 340.0, "en çok vuran önce, alınan hasarıyla: %s" % str(first))
	assert(float(second.get("taken", -1.0)) == 910.0, "müttefiğin alınan hasarı: %s" % str(second))
	assert(stats_list != null, "istatistik listesi kurulmalı")
	assert(texts.has("Alınan") and texts.has("Verilen"), "sütun başlıkları: %s" % str(texts))
	assert(texts.has("910") and texts.has("340"), "alınan hasar sayıları satırlarda görünmeli: %s" % str(texts))
