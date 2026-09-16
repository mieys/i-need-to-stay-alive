extends Node

## Kullanıcı isteği doğrulaması: "Kurt adamın yetenekleri kalkan harcamamalı."
## bkz. player.gd _activate_skill()/_activate_skill2() üstündeki muafiyet
## kontrolleri (Paladin/Matthew/Büyücü ile AYNI desen) - artık Kurt Adam'ın
## ULTİ'si (Kudurmuş Saldırı, id 14) ve TEMEL'i (Vahşi Kesik, skill2 id 13)
## bu listede.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func _make_kurtadam_player() -> Node:
	GameManager.selected_char_id = 6 ## Kurt Adam (raw character id)
	GameManager.selected_character = 14 ## Kurt Adam'ın ULTİ id'si (Kudurmuş Saldırı)
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.item_shield_max = 100.0
	player.item_shield_hp = 100.0
	return player


func test_ulti_does_not_spend_shield() -> void:
	var player: Node = _make_kurtadam_player()
	var before: float = player.item_shield_hp

	player._activate_skill()

	assert(player.item_shield_hp == before,
		"Kudurmuş Saldırı (ULTİ) kalkan harcamamalı, önce: %s sonra: %s" % [before, player.item_shield_hp])
	assert(player.skill_state == "active", "ULTİ yine de normal şekilde aktifleşmeli")

	player.queue_free()


func test_temel_does_not_spend_shield() -> void:
	var player: Node = _make_kurtadam_player()
	var before: float = player.item_shield_hp

	player._activate_skill2()

	assert(player.item_shield_hp == before,
		"Vahşi Kesik (TEMEL) kalkan harcamamalı, önce: %s sonra: %s" % [before, player.item_shield_hp])
	assert(player.skill2_state == "active", "TEMEL yine de normal şekilde aktifleşmeli")

	player.queue_free()


## Kontrol: muafiyet SADECE Kurt Adam'a özel bir istisna değil, genel
## mekanizma bozulmamış - başka bir karakterin (Oakley, ULTİ id 1) yeteneği
## hâlâ normal şekilde kalkan harcamalı.
func test_other_character_still_spends_shield() -> void:
	GameManager.selected_char_id = 2 ## Oakley
	GameManager.selected_character = 1 ## Oakley'nin ULTİ id'si (Can Basma)
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.item_shield_max = 100.0
	player.item_shield_hp = 100.0
	var before: float = player.item_shield_hp

	player._activate_skill()

	assert(player.item_shield_hp < before,
		"Oakley'nin ULTİ'si hâlâ kalkan harcamalı (genel mekanizma bozulmuş olabilir)")

	player.queue_free()
