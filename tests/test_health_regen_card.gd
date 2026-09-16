extends Node

## Kullanıcı isteği doğrulaması: level atlama kartlarındaki "Can Yenilenmesi"
## statının kart başına verdiği bonus 0.75'den 0.50'ye düşürülmeli.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func test_health_regen_card_grants_half_point_five() -> void:
	var player: Node = PlayerScene.instantiate()
	add_child(player)

	assert(player.heal_regen_card_bonus == 0.0, "Başlangıçta 0 olmalı")
	player.apply_upgrade("health_regen")
	assert(is_equal_approx(player.heal_regen_card_bonus, 0.5),
		"Kart başına can yenilenmesi bonusu 0.5 olmalı, bulunan: %s" % player.heal_regen_card_bonus)

	player.apply_upgrade("health_regen")
	assert(is_equal_approx(player.heal_regen_card_bonus, 1.0),
		"İki kart sonrası toplam 1.0 olmalı (additive), bulunan: %s" % player.heal_regen_card_bonus)

	player.queue_free()


func test_level_up_screen_description_matches() -> void:
	assert(LevelUpScreenScript.UPGRADES.any(func(u): return u["id"] == "health_regen" and u["desc"].find("0.5") != -1),
		"health_regen kartının açıklaması 0.5 içermeli")

const LevelUpScreenScript = preload("res://scripts/level_up_screen.gd")
