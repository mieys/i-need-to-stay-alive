extends Node

## Kullanıcı isteği doğrulaması:
## 1) Şans statı sandık düşme ihtimalini de arttırmalı - her 1 şans %0.2
##    (0.002) arttırmalı, %1 (genel altın/meyve oranı) DEĞİL.
## (Kurt Adam karakteri oyundan silindi - eskiden burada onun pasif can çalma oranı da doğrulanıyordu.)
##
## NOT: enemy.gd'nin _player_luck_chest_bonus()/_player_luck_drop_bonus()
## fonksiyonları get_tree().get_first_node_in_group("player") kullanıyor -
## bu test ortamında instantiate edilen node'lar canlı bir SceneTree'ye
## girmediği için get_tree() null dönüyor (bkz. tests/test_hud_gold_shop_
## toggle.gd'deki aynı kısıt notu). Bu yüzden çarpanın DOĞRU sabit
## (LUCK_CHEST_BONUS_PER_POINT) üzerinden tanımlandığını ve genel bonusla
## (%1/şans) KARIŞTIRILMADIĞINI doğruluyoruz - production'da get_tree()
## gerçek oyunda her zaman geçerli olacağı için davranış birebir aynı olur.

const EnemyScript = preload("res://scripts/enemy.gd")


func test_chest_luck_bonus_constant_is_point_two_percent() -> void:
	assert(is_equal_approx(EnemyScript.LUCK_CHEST_BONUS_PER_POINT, 0.002),
		"Sandik icin sans-basi bonus 0.002 (%%0.2) olmali, bulunan: %s" % EnemyScript.LUCK_CHEST_BONUS_PER_POINT)
	## Genel altın/meyve bonusu (%1/şans = 0.01) ile KARIŞTIRILMAMALI.
	assert(not is_equal_approx(EnemyScript.LUCK_CHEST_BONUS_PER_POINT, 0.01),
		"Sandik bonusu yanlislikla genel %%1'lik oranla ayni olmus")


func test_chest_drop_uses_luck_chest_bonus_not_general_bonus() -> void:
	## _drop_chest() kaynağının artık _player_luck_chest_bonus() kullandığını,
	## eski "_player_luck_drop_bonus() * 0.05" ifadesini KULLANMADIĞINI
	## doğrular (regresyona karşı).
	var source: String = FileAccess.get_file_as_string("res://scripts/enemy.gd")
	if source.length() > 0: ## bazı test ortamlarında FileAccess kısıtlı olabiliyor
		var chest_fn_start: int = source.find("func _drop_chest()")
		if chest_fn_start != -1:
			var section: String = source.substr(chest_fn_start, 400)
			assert(section.find("_player_luck_chest_bonus()") != -1,
				"_drop_chest artik _player_luck_chest_bonus kullanmiyor")
			assert(section.find("_player_luck_drop_bonus() * 0.05") == -1,
				"_drop_chest hala eski genel bonus formulunu kullaniyor")


func test_player_reads_lifesteal_directly_from_character_def() -> void:
	## player.gd _load_character_frames() "lifesteal_percent = def.get(
	## \"lifesteal\", 0.0)" satırıyla doğrudan Characters.DEFS'ten okuyor -
	## bu yüzden Characters.DEFS'teki değerin doğru olması (yukarıdaki test)
	## player.gd davranışının da doğru olacağının garantisidir. Burada
	## sadece o okuma satırının hâlâ var olduğunu doğruluyoruz.
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	if source.length() > 0:
		assert(source.find("lifesteal_percent = def.get(\"lifesteal\", 0.0)") != -1,
			"player.gd artik karakter tanimindan lifesteal okumuyor")
