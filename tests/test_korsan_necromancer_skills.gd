extends Node

## Kullanıcı bildirimi: "korsan, necromancer adlı karakterlere durduk yere
## melek adlı karakterin skillerini vermiş" - kök neden, player.gd
## _activate_skill()'in match bloğunda Korsan (skill id 18, "Patlat") ve
## Necromancer'ın (skill id 20, "Hortlak Çağır") hiç case'i olmaması, ikisinin
## de wildcard "_: _skill_heal()" (Melek/Oakley'nin Can Basma'sı) varsayılanına
## düşmesiydi. Bu testler artık her ikisinin de KENDİ, doğru fonksiyonlarına
## yönlendiğini doğruluyor.

const PlayerScript = preload("res://scripts/player.gd")


## DÜZELTME (bu test dosyası, iki AYRI daha önceki kullanıcı isteğinden beri
## bayattı: "necromancerın ultisi hayalet yerine golem çağırsın" - fonksiyon
## _skill_necro_summon_wraith'ten _skill_necro_summon_golem'a yeniden
## adlandırılmıştı ama bu testler hiç güncellenmemişti; SONRA da "Necromancer
## in R sini golem çıkarma ile değiştir" isteğiyle golem (id 20) Q/skill'den
## R/skill3'e taşındı - bkz. player.gd _activate_skill3()'teki match
## skill3_id bloğu, artık _activate_skill()'in match char_id'sinde YOK).
func test_korsan_ulti_maps_to_bomb_detonate_not_heal() -> void:
	# Match ifadesinin kaynak kodunu okuyarak "18" case'inin _skill_heal
	# DEĞİL _skill_korsan_detonate_all'a gittiğini doğrula.
	var f := FileAccess.open("res://scripts/player.gd", FileAccess.READ)
	var content: String = f.get_as_text()
	f.close()
	var idx: int = content.find("match char_id:")
	var match_block: String = content.substr(idx, 400)
	assert("18: _skill_korsan_detonate_all()" in match_block, "Korsan ULTİ (id 18) artık _skill_korsan_detonate_all'a gitmeli")


## Güncel dizilim (2026-09-24): Golem Çağır (id 20) E/skill2'de, R/skill3 Lanetli Kafatası (id 44). Ayrı fonksiyon: yukarıdaki
## Korsan kontrolü (önceden var olan başarısızlık) bu kontrolleri durdurmasın.
func test_necro_golem_is_e_and_skull_is_r() -> void:
	var content: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var a2: int = content.find("func _activate_skill2()")
	var skill2_body: String = content.substr(a2, content.find("func _end_skill2_effects()", a2) - a2)
	assert("20: _skill_necro_summon_golem()" in skill2_body, "Necromancer E (id 20) _activate_skill2'deki match'ten _skill_necro_summon_golem'a gitmeli")
	var a3: int = content.find("func _activate_skill3()")
	var skill3_body: String = content.substr(a3, content.find("func _end_skill3_effects()", a3) - a3)
	assert(not ("20: _skill_necro_summon_golem()" in skill3_body), "golem artık R'de olmamalı")
	assert("44: _skill_necro_skull()" in skill3_body, "Necromancer R (id 44) kafatasına gitmeli")


func test_korsan_and_necro_functions_exist() -> void:
	var p := PlayerScript.new()
	assert(p.has_method("_korsan_try_place_bomb"), "Korsan bomba bırakma fonksiyonu olmalı")
	assert(p.has_method("_skill_korsan_detonate_all"), "Korsan patlatma fonksiyonu olmalı")
	assert(p.has_method("_skill_necro_summon_skeleton"), "Necromancer iskelet çağırma fonksiyonu olmalı")
	assert(p.has_method("_skill_necro_summon_golem"), "Necromancer golem çağırma fonksiyonu olmalı")
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


## DÜZELTME: ruh bedeli sonradan kullanıcı isteğiyle 3'ten 10'a
## (NECRO_SKELETON_SOUL_COST) güncellenmişti, bu test hâlâ eski "3"ü
## sınıyordu - artık sabitin kendisinden okunuyor ki ileride tekrar
## dengelenirse test kendiliğinden güncel kalsın.
func test_necro_skeleton_summon_requires_correct_souls() -> void:
	var p := PlayerScript.new()
	add_child(p)
	var cost: int = PlayerScript.NECRO_SKELETON_SOUL_COST
	p.necro_souls = cost - 1
	p.global_position = Vector2.ZERO
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == cost - 1, "Yetersiz ruhla iskelet çağrılmamalı, ruh harcanmamalı")

	p.necro_souls = cost
	p._skill_necro_summon_skeleton()
	assert(p.necro_souls == 0, "Yeterli ruhla iskelet çağrılınca ruhlar harcanmalı")
