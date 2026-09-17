extends Node

## Kullanıcı isteği doğrulaması: Oakley'nin TAM kit değişikliği - "Oakleyin
## pasifi silinecek ve Q su bundan sonra pasifi olacak... otomatik olarak
## yakınlarına çiçek bırakacak... Oakleyin R yeteneği artık boşta kalan Q
## yeteneği olacak... Yeni R yeteneği ise canı en az olan arkadaşına
## koruyucu bir büyü yapar".
##
## NOT: bu dosya eskiden Oakley'nin ÇOK DAHA ÖNCEKİ bir kitini (Can Basma/
## Kalkan Yenileme - "Oakley yeni yetenekleri" reworkundan ÖNCEKİ, Melek'le
## paylaşılan kit) test ediyordu; o fonksiyonlar (_skill_heal/_passive_oakley/
## _process_oakley_heal_tick vb.) hâlâ var ama artık SADECE Melek'e ait
## ("oakley_" adlandırması tarihsel bir kalıntı, bkz. player.gd _process_
## character_passive'teki roster id ayrımı) - bu test dosyası ÇOKTAN bayattı,
## bugünkü rework onu daha da alakasız hale getirdiği için TAMAMEN
## yenilendi.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")


func _make_oakley_player() -> Node:
	GameManager.selected_char_id = 2 ## Oakley (roster id)
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	return player


## characters.gd DEFS'in yeni kiti doğru taşıdığını doğrular - id'ler
## KODUN gerçekte okuduğu değerlerle (player.gd match blokları) birebir
## eşleşmeli, aksi halde tuşlar sessizce hiçbir şey yapmaz.
func test_defs_reflect_new_kit() -> void:
	var def: Dictionary = Characters.get_def(2)
	assert(def.get("name", "") == "Oakley", "roster id 2 Oakley olmalı")
	assert(int(def.get("skill", 0)) == 33,
		"Oakley'nin Q'su artık Arı Sürüsü (id 33) olmalı, bulunan: %s" % def.get("skill"))
	assert(int(def.get("skill3", 0)) == 39,
		"Oakley'nin R'si artık Koruyucu Büyü (id 39) olmalı, bulunan: %s" % def.get("skill3"))
	assert(int(def.get("skill2", 0)) == 10,
		"Oakley'nin E'si (Sarmaşıklar) değişmemeli, bulunan: %s" % def.get("skill2"))
	assert(def.get("passive", "").find("çiçek") != -1,
		"Oakley'nin yeni pasifi çiçek bırakmaktan bahsetmeli, bulunan: %s" % def.get("passive"))


## Eski 2-yük/18sn şarj sistemi tamamen kaldırılmış olmalı - Çiçek artık bir
## tuş yeteneği değil, tamamen otomatik bir pasif.
func test_old_flower_charge_system_removed() -> void:
	var player: Node = _make_oakley_player()
	assert(not player.has_method("_try_oakley_flower"),
		"_try_oakley_flower kaldırılmış olmalı - Çiçek artık pasif")
	assert(not ("oakley_flower_charges" in player),
		"oakley_flower_charges kaldırılmış olmalı - yük sistemi yok")
	player.queue_free()


## Kullanıcı isteği: "2 yük olayı falan yok bunda dolduğu anda oakleyin
## yakınında rasgele yerlere bıraksın" - yeni pasif tek, sabit bir
## zamanlayıcı kullanmalı.
func test_flower_passive_is_automatic_timer() -> void:
	var player: Node = _make_oakley_player()
	assert(player.has_method("_process_oakley_passive"), "_process_oakley_passive olmalı")
	assert(player.has_method("_spawn_oakley_flower_auto"), "_spawn_oakley_flower_auto olmalı")
	assert(is_equal_approx(player._oakley_flower_auto_timer, player.OAKLEY_FLOWER_AUTO_INTERVAL),
		"Zamanlayıcı tam aralıkla başlamalı")
	player._process_oakley_passive(1.0)
	assert(is_equal_approx(player._oakley_flower_auto_timer, player.OAKLEY_FLOWER_AUTO_INTERVAL - 1.0),
		"Zamanlayıcı her karede azalmalı, bulunan: %s" % player._oakley_flower_auto_timer)
	player.queue_free()


## Arı Sürüsü Q'ya taşındı ama KENDİ mekaniği (yarıçap/hasar/süre) hiç
## değişmedi - bkz. oakley_bee_swarm.gd, sadece hangi tuştan tetiklendiği
## değişti.
func test_bee_swarm_function_unchanged_on_q() -> void:
	var player: Node = _make_oakley_player()
	assert(player.has_method("_skill_oakley_bee_swarm"), "_skill_oakley_bee_swarm hâlâ olmalı (artık Q)")
	assert(is_equal_approx(player.SKILL_TIMING[33]["cooldown"], 20.0),
		"Arı Sürüsü'nün 20sn bekleme süresi Q'ya taşınırken değişmemeli")
	assert(is_equal_approx(player.SKILL_TIMING[33]["duration"], 10.0),
		"Arı Sürüsü'nün 10sn süresi Q'ya taşınırken değişmemeli")
	player.queue_free()


## Kullanıcı isteği: "Yeni R yeteneği ise canı en az olan arkadaşına
## koruyucu bir büyü yapar... 8 saniye... (60 saniye bekleme süresi)".
func test_bond_timing_matches_request() -> void:
	var player: Node = _make_oakley_player()
	assert(is_equal_approx(player.OAKLEY_BOND_DURATION, 8.0), "Koruyucu Büyü 8sn sürmeli")
	assert(is_equal_approx(player.SKILL3_TIMING[39]["cooldown"], 60.0), "Koruyucu Büyü 60sn beklemeli")
	assert(is_equal_approx(player.OAKLEY_BOND_HEAL_RATIO, 0.10), "Can yenileme saldırı gücünün %%10'u olmalı")
	assert(is_equal_approx(player.OAKLEY_BOND_SHIELD_RATIO, 0.05), "Kalkan yenileme saldırı gücünün %%5'i olmalı")
	assert(is_equal_approx(player.OAKLEY_BOND_DAMAGE_REDUCTION, 0.20), "Hasar azaltma %%20 olmalı")
	player.queue_free()


## Kullanıcı isteği: "Eğer canı en az olan kişi oakleyse bu büyüyü kendisine
## yapar" - test ortamında get_tree() yeni eklenen node'lar için sınırlı
## olduğundan (bkz. dosya başı notu, diğer testlerdeki AYNI kısıt) hiçbir
## dost bulunamaz, bu da "tek başına/en düşük canlı kendisi" durumunu doğal
## olarak test eder.
func test_bond_target_defaults_to_self_when_no_allies() -> void:
	var player: Node = _make_oakley_player()
	player.max_health = 200.0
	player.health = 50.0

	var target: Node = player._oakley_lowest_hp_bond_target(9999.0)

	assert(target == player, "Dost yokken büyü kendisine hedeflenmeli")
	player.queue_free()


## Koruyucu Büyü'nün asıl etkisi: hedef her hasar aldığında can/kalkan
## yenilemeli VE hasarın %20'si azalmalı - bkz. take_damage() içindeki
## oakley_bond_active dalı.
func test_bond_proc_heals_shields_and_reduces_damage_on_hit() -> void:
	var player: Node = _make_oakley_player()
	player.max_health = 200.0
	player.health = 100.0
	player.item_shield_max = 100.0
	player.item_shield_hp = 0.0
	player.oakley_bond_active = true
	player.oakley_bond_heal_per_hit = 12.0
	player.oakley_bond_shield_per_hit = 6.0
	player.oakley_bond_damage_reduction = 0.20

	player.take_damage(50.0)

	## %20 azaltma sonrası ham hasar 40 olmalı, ama can yenilemesi (12) bunu
	## kısmen telafi ediyor - net can kaybı 40 - 12 = 28.
	assert(is_equal_approx(player.health, 100.0 - 40.0 + 12.0),
		"Can hem hasar (azaltılmış) hem proc yenilemesi yansıtmalı, bulunan: %s" % player.health)
	assert(is_equal_approx(player.item_shield_hp, 6.0),
		"Kalkan proc'u 6 kalkan vermeli, bulunan: %s" % player.item_shield_hp)
	player.queue_free()


## Süre dolunca (bkz. _process_oakley_bond) tüm alanlar sıfırlanmalı ki
## diriltme/yeni büyü sonrası eski değerler sızmasın.
func test_bond_expires_after_duration() -> void:
	var player: Node = _make_oakley_player()
	player.oakley_bond_active = true
	player.oakley_bond_heal_per_hit = 5.0
	player.oakley_bond_timer = 1.0

	player._process_oakley_bond(1.5)

	assert(not player.oakley_bond_active, "Süre dolunca büyü kapanmalı")
	assert(is_equal_approx(player.oakley_bond_heal_per_hit, 0.0), "Süre dolunca can miktarı sıfırlanmalı")
	player.queue_free()
