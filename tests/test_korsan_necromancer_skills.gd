extends Node

## Kullanıcı bildirimi: "korsan, necromancer adlı karakterlere durduk yere
## melek adlı karakterin skillerini vermiş" - kök neden, player.gd
## _activate_skill()'in match bloğunda Korsan (skill id 18, "Patlat") ve
## Necromancer'ın (skill id 20, "Hortlak Çağır") hiç case'i olmaması, ikisinin
## de wildcard "_: _skill_heal()" (Melek/Oakley'nin Can Basma'sı) varsayılanına
## düşmesiydi. Bu testler artık her ikisinin de KENDİ, doğru fonksiyonlarına
## yönlendiğini doğruluyor.

const PlayerScript = preload("res://scripts/player.gd")


func test_korsan_ulti_maps_to_bomb_detonate_not_heal() -> void:
	# Match ifadesinin kaynak kodunu okuyarak "18" case'inin _skill_heal
	# DEĞİL _skill_korsan_detonate_all'a gittiğini doğrula.
	var f := FileAccess.open("res://scripts/player.gd", FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	var idx: int = content.find("match char_id:")
	var match_block: String = content.substr(idx, 400)
	assert("18: _skill_korsan_detonate_all()" in match_block, "Korsan ULTİ (id 18) artık _skill_korsan_detonate_all'a gitmeli")
	assert("20: _skill_necro_summon_wraith()" in match_block, "Necromancer ULTİ (id 20) artık _skill_necro_summon_wraith'e gitmeli")


func test_korsan_and_necro_functions_exist() -> void:
	var p := PlayerScript.new()
	assert(p.has_method("_korsan_try_place_bomb"), "Korsan bomba bırakma fonksiyonu olmalı")
	assert(p.has_method("_skill_korsan_detonate_all"), "Korsan patlatma fonksiyonu olmalı")
	assert(p.has_method("_skill_necro_summon_skeleton"), "Necromancer iskelet çağırma fonksiyonu olmalı")
	assert(p.has_method("_skill_necro_summon_wraith"), "Necromancer hortlak çağırma fonksiyonu olmalı")
	assert(p.has_method("on_enemy_killed"), "Öldürme bildirim hook'u olmalı")
	assert(p.has_method("get_necro_souls"), "Ruh sayısını okuyan getter olmalı")
	p.free()


func test_korsan_bomb_charges_default_to_two() -> void:
	var p := PlayerScript.new()
	assert(p.korsan_bomb_charges == 2, "Korsan 2 bomba şarjıyla başlamalı")
	p.free()


const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")


func test_necro_souls_start_at_zero_and_accumulate_on_kill() -> void:
	var p := PlayerScript.new()
	add_child(p)
	p.necro_souls = 0
	# Necromancer'ın skill id'si 20 olmalı ki on_enemy_killed doğru dallansın.
	# get_skill_character_id() GameManager.selected_character'a bağlı olduğu
	# için burada doğrudan _necro_on_kill'i çağırıyoruz (izole test). Gerçek
	# bir Enemy sahnesi kullanıyoruz çünkü "is_boss" script-tanımlı bir
	# property - script'siz düz bir Node'a .set() ile eklenemez.
	var real_enemy: Node = EnemyScene.instantiate()
	add_child(real_enemy)
	real_enemy.is_boss = false
	p._necro_on_kill(real_enemy.is_boss)
	assert(p.necro_souls == 1, "Normal öldürmede 1 ruh kazanılmalı, bulunan: %d" % p.necro_souls)

	real_enemy.is_boss = true
	p._necro_on_kill(real_enemy.is_boss)
	assert(p.necro_souls == 6, "Boss öldürmede 5 ek ruh kazanılmalı (toplam 6), bulunan: %d" % p.necro_souls)

	real_enemy.queue_free()
	p.free()


func test_necro_skeleton_summon_requires_three_souls() -> void:
	var p := PlayerScript.new()
	add_child(p)
	p.necro_souls = 2
	p.global_position = Vector2.ZERO
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == 2, "Yetersiz ruhla iskelet çağrılmamalı, ruh harcanmamalı")

	p.necro_souls = 3
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == 0, "3 ruh ile iskelet çağrılınca ruhlar harcanmalı")
