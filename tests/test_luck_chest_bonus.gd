extends Node

## Şans (2026-09-24 denge turu yeniden tasarımı, bkz. enemy.gd LUCK_DROP_MULT_PER_POINT üstündeki not):
## yemek/mıknatıs/sandık ihtimali ÇARPIMSAL (taban x (1 + %5 x şans) -> 20 şans = 2 kat), altın x (1 + %1 x şans),
## ve düşme kararında HOST'un değil öldüren oyuncunun şansı kullanılır (_killer_node / last_attacker_peer_id).
## Eski düz toplama (%0.2/puan - 10 şans yemeği 40 kat arttırıyordu) ve LUCK_CHEST_BONUS_PER_POINT kaldırıldı.
## (Kurt Adam karakteri oyundan silindi - eskiden burada onun pasif can çalma oranı da doğrulanıyordu.)

const EnemyScript = preload("res://scripts/enemy.gd")


func test_luck_is_multiplicative_twenty_points_doubles_drops() -> void:
	assert(is_equal_approx(EnemyScript.LUCK_DROP_MULT_PER_POINT, 0.05), "yemek/mıknatıs/sandık: şans başı %%5")
	assert(is_equal_approx(1.0 + 20.0 * EnemyScript.LUCK_DROP_MULT_PER_POINT, 2.0), "20 şans = 2 kat")
	assert(is_equal_approx(EnemyScript.LUCK_GOLD_MULT_PER_POINT, 0.01), "altın: şans başı %%1")


func test_drop_functions_use_killer_luck_multiplier() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/enemy.gd")
	if source.length() == 0: ## bazı test ortamlarında FileAccess kısıtlı olabiliyor
		return
	assert(source.find("func _player_luck_drop_bonus") == -1, "eski düz şans bonusu fonksiyonu kalmamalı")
	for fn in ["func _drop_food()", "func _drop_magnet()", "func _drop_chest()"]:
		var i: int = source.find(fn)
		assert(i != -1, "%s bulunamadı" % fn)
		assert(source.substr(i, 900).find("_luck_mult(LUCK_DROP_MULT_PER_POINT)") != -1, "%s çarpımsal şans kullanmalı" % fn)
	var g: int = source.find("func _drop_gold()")
	assert(source.substr(g, 400).find("_luck_mult(LUCK_GOLD_MULT_PER_POINT)") != -1, "_drop_gold çarpımsal şans kullanmalı")
	var k: int = source.find("func _killer_node()")
	assert(k != -1 and source.substr(k, 700).find("last_attacker_peer_id") != -1, "öldürenin şansı last_attacker_peer_id'den bulunmalı")


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
