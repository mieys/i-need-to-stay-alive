extends Node

## Hareket hızı göstergesi (stats_panel.gd, 2026-10-12): kart/eşya alınca sayı artmalı; gösterilen değer gerçek kalıcı hıza eşit olmalı.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const StatsPanelScene: PackedScene = preload("res://scenes/stats_panel.tscn")


func test_panel_shows_permanent_move_speed_including_cards_and_items() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var panel: Node = StatsPanelScene.instantiate()
	add_child(panel)
	panel.player = player
	panel._refresh()
	var base_text: String = panel.speed_value.text
	assert(base_text == str(int(round(player.speed))), "kart/eşya yokken sayı taban hız: %s" % base_text)
	player.apply_upgrade("speed") ## +%4
	player.item_speed_percent = 0.10
	panel._refresh()
	var want: int = int(round(player.speed * (1.0 + 0.04 + 0.10)))
	assert(panel.speed_value.text == str(want), "kart + eşya sayıya yansımalı: %s (beklenen %d)" % [panel.speed_value.text, want])
	assert(is_equal_approx(player.get_base_move_speed(), player.speed * 1.14), "get_base_move_speed taban x (1 + kart + eşya)")
	panel.queue_free()
	player.queue_free()
