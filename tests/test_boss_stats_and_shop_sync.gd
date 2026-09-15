extends Node

## Kullanıcı isteği doğrulaması:
##  1) "Bossların canını %100 ve kalkanlarını da %200 arttır ve bossların
##     kalkanının hasar soğurmasını %85 düzeyine sabitle."
##  2) "Level atladıktan sonra dükkan açılıyor ama ... bazen hostta açılıp
##     diğer oyunlarda açılmıyor." (karar artık host otoritesinde)
##
## Doğrulananlar:
##  - can çarpanı tam 2 katı, kalkanın MUTLAK miktarı tam 3 katı (can da ikiye
##    katlandığı için oran 1.5 katı),
##  - soğurma oranı 0.85 ve buna göre bir vuruşun %85'i kalkandan, %15'i candan
##    gidiyor (canlı davranış testi),
##  - dükkan kararı host otoritesinde: client kendi başına karar vermiyor,
##    host kararı yayınlıyor, RPC yalnızca host'u kabul ediyor ve client'ta
##    güvenlik zaman aşımı var,
##  - 5 dakikalık bekleme kuralı aynen duruyor.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")

## Bu değişiklikten ÖNCEKİ boss değerleri (artış yüzdelerini ölçmenin tabanı).
const OLD_BOSS_HEALTH_MULT := 44.0
const OLD_BOSS_SHIELD_RATIO := 5.2


func _boss_constants() -> Dictionary:
	return SpawnerScript.get_script_constant_map()


func test_boss_health_doubled() -> void:
	var new_health_mult: float = float(_boss_constants()["BOSS_HEALTH_MULT"])
	assert(is_equal_approx(new_health_mult, OLD_BOSS_HEALTH_MULT * 2.0),
		"Boss canı %%100 artmamış: %s (eskiden %s)" % [new_health_mult, OLD_BOSS_HEALTH_MULT])


func test_boss_shield_amount_tripled() -> void:
	var constants: Dictionary = _boss_constants()
	var new_health_mult: float = float(constants["BOSS_HEALTH_MULT"])
	var new_shield_ratio: float = float(constants["BOSS_SHIELD_RATIO"])
	## Kalkan havuzu = max_health x oran (bkz. enemy.gd enable_item_shield).
	## Can da ikiye katlandığı için MUTLAK kalkan miktarının tam 3 katı
	## (+%200) olması için oran x1.5 olmalı.
	var old_absolute: float = OLD_BOSS_HEALTH_MULT * OLD_BOSS_SHIELD_RATIO
	var new_absolute: float = new_health_mult * new_shield_ratio
	assert(absf(new_absolute / old_absolute - 3.0) < 0.001,
		"Boss kalkan miktarı %%200 artmamış: %s katı (eskiden mutlak %s, şimdi %s)" % [new_absolute / old_absolute, old_absolute, new_absolute])
	assert(absf(new_shield_ratio - OLD_BOSS_SHIELD_RATIO * 1.5) < 0.001,
		"Kalkan oranı can artışı hesaba katılmadan değiştirilmiş: %s" % new_shield_ratio)


func test_boss_shield_absorption_is_85_percent() -> void:
	assert(is_equal_approx(float(_boss_constants()["BOSS_SHIELD_PROTECTION"]), 0.85),
		"Boss kalkan soğurması %%85'e sabitlenmemiş: %s" % _boss_constants()["BOSS_SHIELD_PROTECTION"])

	## Canlı davranış: 100 hasar vuran bir vuruşta kalkan 85, can 15 kaybetmeli.
	## NOT: _apply_damage hasar yazısını get_tree().current_scene'e ekliyor -
	## test ortamında current_scene boş olabildiği için geçici olarak bu test
	## düğümünü gösteriyoruz (bkz. test_boomerang_impact_sound.gd'deki AYNI desen).
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var enemy: Node = EnemyScene.instantiate()
	add_child(enemy)
	enemy.apply_boss_stats(1000.0, 10.0, 1.7, 5)
	enemy.enable_item_shield(0.85, 7.8)
	assert(absf(enemy.item_shield_max - 1000.0 * 7.8) < 0.01,
		"Kalkan havuzu can x oran değil: %s" % enemy.item_shield_max)

	var shield_before: float = enemy.item_shield_hp
	var health_before: float = enemy.health
	enemy._apply_damage(100.0, false, 0.0)
	assert(absf((shield_before - enemy.item_shield_hp) - 85.0) < 0.01,
		"Kalkan vuruşun %%85'ini emmiyor: %s" % (shield_before - enemy.item_shield_hp))
	assert(absf((health_before - enemy.health) - 15.0) < 0.01,
		"Cana kalan hasar %%15 değil: %s" % (health_before - enemy.health))
	enemy.queue_free()
	get_tree().current_scene = previous_scene


## Boss bilinçli olarak kalkanı BİTMEDEN ölmemeli, yoksa kalkan boşa gider:
## kalkan havuzu (oran x can) en az "can / (1 - soğurma) x soğurma" kadar olmalı.
func test_boss_shield_pool_is_large_enough_to_matter() -> void:
	var constants: Dictionary = _boss_constants()
	var protection: float = float(constants["BOSS_SHIELD_PROTECTION"])
	var ratio: float = float(constants["BOSS_SHIELD_RATIO"])
	## Kann kaybedeceği toplam hasar (sadece can) = health / (1 - protection);
	## bu süre boyunca kalkanın emmesi gereken miktar = o hasar x protection.
	var needed_pool_ratio: float = (1.0 / (1.0 - protection)) * protection
	assert(ratio >= needed_pool_ratio - 0.001,
		"Kalkan havuzu (oran %s) boss ölmeden tükenir - gereken en az %s" % [ratio, needed_pool_ratio])


func test_mini_shop_decision_is_host_authoritative() -> void:
	assert(NetworkManager.has_signal("mini_shop_decision_received"),
		"mini_shop_decision_received sinyali yok")
	assert(NetworkManager.has_method("broadcast_mini_shop_decision"),
		"Host kararı yayınlayan fonksiyon yok")
	assert(NetworkManager.has_method("_rpc_mini_shop_decision"),
		"Karar RPC'si yok")

	var net_src: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	assert(net_src.find("if multiplayer.get_remote_sender_id() != _host_peer_id():") != -1,
		"Karar mesajı yalnızca host'a kısıtlanmamış")

	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.length() > 0, "main.gd okunamadı")
	assert(main_src.find("if NetworkManager.is_multiplayer_active and not NetworkManager.is_host:") != -1,
		"Client, host'tan ayrı ele alınmıyor (kendi başına karar veriyor olabilir)")
	assert(main_src.find("NetworkManager.broadcast_mini_shop_decision(open_shop)") != -1,
		"Host kararı yayınlamıyor - diğer oyuncularda dükkan açılmaz")
	assert(main_src.find("func _on_mini_shop_decision_received(") != -1,
		"Host kararını işleyen fonksiyon yok")
	assert(main_src.find("func _on_mini_shop_decision_timeout(") != -1,
		"Host'tan karar gelmezse oyun askıda kalır (güvenlik zaman aşımı yok)")
	assert(main_src.find("NetworkManager.mini_shop_decision_received.connect(_on_mini_shop_decision_received)") != -1,
		"Karar sinyali main.gd'de bağlanmamış")


## Kural: dükkan, level atlamasından sonra SADECE bekleme süresi (bkz.
## MINI_SHOP_COOLDOWN - şu an 3 dakika) dolmuşsa açılır ve açıldığı an süre
## sıfırdan başlar.
func test_mini_shop_cooldown_rule_unchanged() -> void:
	GameManager.reset()
	assert(GameManager.is_mini_shop_cooldown_ready(),
		"Oyun başında bekleme süresi 'hazır' olmalı (ilk dükkan açılabilsin)")
	GameManager.start_mini_shop_cooldown()
	assert(not GameManager.is_mini_shop_cooldown_ready(),
		"Dükkan açılınca bekleme süresi başlamadı")
	GameManager._process(GameManager.MINI_SHOP_COOLDOWN * 0.5)
	assert(not GameManager.is_mini_shop_cooldown_ready(),
		"Süre yarıda doldu sayıldı")
	GameManager._process(GameManager.MINI_SHOP_COOLDOWN * 0.5)
	assert(GameManager.is_mini_shop_cooldown_ready(),
		"Bekleme süresi dolduğu hâlde 'hazır' sayılmıyor")
	GameManager.reset()


## Kullanıcı isteği: "dükkan 3 dakika bekleme süresine sahip olacak."
func test_shop_cooldown_is_three_minutes() -> void:
	assert(is_equal_approx(GameManager.MINI_SHOP_COOLDOWN, 180.0),
		"Dükkan bekleme süresi 3 dakika değil: %s sn" % GameManager.MINI_SHOP_COOLDOWN)


## Kullanıcı isteği: "bir kişi dükkanda çarpıya basınca diğerlerinin bekleme
## süresi başlayacak." - ilk kapatma, kalan oyuncular için bekleme sayacını
## (yeniden) başlatır; SONRAKİ kapatmalar süreyi uzatmaz.
func test_first_close_starts_waiting_period_for_others() -> void:
	NetworkManager.mini_shop_timer_active = true
	NetworkManager.mini_shop_countdown = 4.0 ## dükkan açılışından kalan güvenlik sayacı
	NetworkManager._mini_shop_first_close_happened = false
	assert(not NetworkManager.is_mini_shop_wait_started(),
		"Yeni oturumda bekleme süresi henüz başlamamış olmalı")

	NetworkManager._begin_mini_shop_waiting_after_first_close()
	assert(NetworkManager.is_mini_shop_wait_started(), "İlk kapatmada bekleme süresi başlamadı")
	assert(is_equal_approx(NetworkManager.mini_shop_countdown, NetworkManager.MINI_SHOP_WAIT_AFTER_FIRST_CLOSE),
		"Bekleme süresi %s sn'ye kurulmadı: %s" % [NetworkManager.MINI_SHOP_WAIT_AFTER_FIRST_CLOSE, NetworkManager.mini_shop_countdown])

	## Süre biraz azaldıktan sonra İKİNCİ bir oyuncu kapatırsa süre UZAMAMALI.
	NetworkManager.mini_shop_countdown = 12.0
	NetworkManager._begin_mini_shop_waiting_after_first_close()
	assert(is_equal_approx(NetworkManager.mini_shop_countdown, 12.0),
		"İkinci kapatma bekleme süresini uzattı (olmamalı): %s" % NetworkManager.mini_shop_countdown)

	NetworkManager._mini_shop_first_close_happened = false
	NetworkManager.mini_shop_timer_active = false


## Dükkanı hâlâ açık olan oyuncuların kalan süreyi görebilmesi için bildirim
## altyapısı: hem tik bağlantısı dükkan AÇILIRKEN yapılmalı (kapatan tarafın
## aksine), hem de sayaç "ilk kapatma"dan sonra anlamlı olmalı.
func test_remaining_players_see_the_waiting_countdown() -> void:
	assert(NetworkManager.has_method("is_mini_shop_wait_started"),
		"Bekleme süresinin başlayıp başlamadığını soran fonksiyon yok")

	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.find("func _update_mini_shop_countdown_notice(") != -1,
		"Kalan süre bildirimi fonksiyonu yok")
	assert(main_src.find("func _hide_mini_shop_countdown_notice(") != -1,
		"Bildirimi gizleyen fonksiyon yok")
	## Bildirim yalnızca dükkan AÇIKKEN ve İLK kapatmadan SONRA gösterilmeli.
	assert(main_src.find("if not _mini_shop_pause_active or _mini_shop_closed_locally or not NetworkManager.is_mini_shop_wait_started():") != -1,
		"Bildirim koşulu eksik/yanlış (her dükkan açılışında görünürdü)")
	## Tik bağlantısı dükkan açılışında yapılmalı, yoksa alışveriş yapan taraf
	## sayacı hiç güncellenmez.
	assert(main_src.find("_mini_shop_closed_locally = false") != -1,
		"Yeni dükkan oturumunda 'kapattım' bayrağı sıfırlanmıyor")
	assert(main_src.find("_mini_shop_closed_locally = true") != -1,
		"Dükkan kapatıldığında yerel bayrak işaretlenmiyor")
