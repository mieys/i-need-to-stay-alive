extends Node

## Kullanıcı isteği doğrulaması: "oyundaki tüm oynanabilir karakterleri ve
## yaratıkları v.s %5 küçültüp hareket hızlarını %10 azaltmanı istiyorum".
##
## Doğrulananlar:
##  1) EntityScale sabitleri (%5 boyut, %10 hız),
##  2) oynanabilir karakter: hız -%10, görsel -%5 (karakter tabanından),
##     gövde çemberi -%5, kalkan baloncuğu -%5,
##  3) yaratık: hız (mevcut GLOBAL_SPEED_SCALE üstüne) -%10, görsel/gövde/
##     vuruş çemberi -%5 ve body-block yarıçapının (_body_radius) yeni
##     yarıçapla senkron kalması,
##  4) aynı sahneden ikinci yaratık küçültmenin KATLANMAMASI (paylaşılan şekil
##     kaynağı yerinde değiştirilmemeli),
##  5) boss ölçeklemesinin (1.7) küçültmeyle ÇARPIMSAL birleşmesi,
##  6) evcil hayvanların (golem) -%5 boyutu ve hızı sahibinden miras alması,
##  7) player.gd / enemy.gd'deki PLAYER_BODY_RADIUS kopyalarının senkron
##     kalması ve papağanın kendi lerp hızlarının -%10 olması.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")
const GolemPetScene: PackedScene = preload("res://scenes/golem_pet.tscn")
const EnemyScript: GDScript = preload("res://scripts/enemy.gd")

## enemy.gd _ready(): menzilli OLMAYAN yaratıklar %5 daha hızlı (sabit kod).
const MELEE_SPEED_BONUS := 1.05


func _make_player() -> Node:
	GameManager.selected_char_id = 1
	GameManager.selected_character = 1
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	return player


func test_entity_scale_constants() -> void:
	assert(is_equal_approx(EntityScale.SIZE, 0.95),
		"Boyut çarpanı %%5 küçültme olmalı, bulunan: %s" % EntityScale.SIZE)
	assert(is_equal_approx(EntityScale.SPEED, 0.9),
		"Hız çarpanı %%10 azaltma olmalı, bulunan: %s" % EntityScale.SPEED)


func test_player_speed_reduced_by_10_percent() -> void:
	## Taban hız ağaca girmeden (yani _ready çalışmadan) okunuyor - böylece
	## player.tscn'deki değer ileride değişse de test doğru kalır.
	var preview: Node = PlayerScene.instantiate()
	var base_speed: float = preview.speed
	preview.free()
	var player: Node = _make_player()
	assert(absf(player.speed - base_speed * EntityScale.SPEED) < 0.01,
		"Oyuncu hızı %%10 azalmamış: %s (taban %s)" % [player.speed, base_speed])
	## Koşma animasyonu eşiği bu değerden türetildiği için o da kaymalı.
	assert(absf(player._anim_base_speed - player.speed) < 0.01,
		"_anim_base_speed hız ile senkron değil: %s vs %s" % [player._anim_base_speed, player.speed])
	player.queue_free()


func test_player_visual_and_body_shrunk_by_5_percent() -> void:
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	var def_scale: Vector2 = def.get("scale", Vector2(1.27575, 1.27575))
	var player: Node = _make_player()
	assert(player.anim.scale.is_equal_approx(def_scale * EntityScale.SIZE),
		"Karakter görseli %%5 küçülmemiş: %s (beklenen %s)" % [player.anim.scale, def_scale * EntityScale.SIZE])
	## char_base_anim_scale her yerde (canlanma, ateş sarsıntısı sonrası,
	## Talon 2x ultisi) taban olarak kullanılıyor - küçülmüş değeri tutmalı.
	assert(player.char_base_anim_scale.is_equal_approx(player.anim.scale),
		"char_base_anim_scale küçültülmüş tabanı tutmuyor: %s" % player.char_base_anim_scale)
	player.queue_free()


func test_player_collision_and_shield_bubble_shrunk() -> void:
	var player: Node = _make_player()
	var body: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	assert(body != null and body.shape is CircleShape2D, "Oyuncunun gövde çemberi bulunamadı")
	assert(absf(body.shape.radius - 16.0 * EntityScale.SIZE) < 0.01,
		"Oyuncu gövde çemberi %%5 küçülmemiş: %s" % body.shape.radius)
	var bubble: Node2D = player.get_node_or_null("ShieldVisual/BubbleSprite")
	assert(bubble != null, "Kalkan baloncuğu bulunamadı")
	assert(absf(bubble.scale.x - 4.37475 * EntityScale.SIZE) < 0.01,
		"Kalkan baloncuğu %%5 küçülmemiş: %s" % bubble.scale)
	player.queue_free()


func test_enemy_speed_and_size() -> void:
	var enemy: Node = EnemyScene.instantiate()
	## Taban değerler ağaca girmeden (yani _ready çalışmadan) okunuyor.
	var base_speed: float = enemy.speed
	var base_sprite: Vector2 = enemy.get_node("Sprite2D").scale
	var base_body_radius: float = enemy.get_node("CollisionShape2D").shape.radius
	var base_hit_radius: float = enemy.get_node("HitArea/HitCollision").shape.radius
	add_child(enemy)

	var global_speed_scale: float = float(EnemyScript.get_script_constant_map()["GLOBAL_SPEED_SCALE"])
	var expected_speed: float = base_speed * global_speed_scale * EntityScale.SPEED
	if not enemy.is_ranged:
		expected_speed *= MELEE_SPEED_BONUS
	assert(absf(enemy.speed - expected_speed) < 0.01,
		"Yaratık hızı beklenen değerde değil: %s (beklenen %s)" % [enemy.speed, expected_speed])

	var sprite: Sprite2D = enemy.get_node("Sprite2D")
	assert(sprite.scale.is_equal_approx(base_sprite * EntityScale.SIZE),
		"Yaratık görseli %%5 küçülmemiş: %s" % sprite.scale)

	var body: CollisionShape2D = enemy.get_node("CollisionShape2D")
	assert(absf(body.shape.radius - base_body_radius * EntityScale.SIZE) < 0.01,
		"Yaratık gövde çemberi %%5 küçülmemiş: %s" % body.shape.radius)
	## KRİTİK: _ready() body-block yarıçapını bu çemberden okuyor; küçültme
	## okumadan SONRA yapılsaydı yaratıklar küçülür ama birbirlerine/itmeye
	## eski mesafede takılırdı.
	assert(absf(enemy._body_radius - body.shape.radius) < 0.01,
		"body-block yarıçapı küçültülmüş çemberle senkron değil: %s vs %s" % [enemy._body_radius, body.shape.radius])

	var hit: CollisionShape2D = enemy.get_node("HitArea/HitCollision")
	assert(absf(hit.shape.radius - base_hit_radius * EntityScale.SIZE) < 0.01,
		"Yaratık vuruş çemberi %%5 küçülmemiş: %s" % hit.shape.radius)
	enemy.queue_free()


## Ortak şekil kaynağı yerinde değiştirilirse ikinci örnek iki kez küçülür
## (0.95² = 0.9025) - sahne başına paylaşılan kaynak bu yüzden duplicate.
func test_second_enemy_is_not_double_shrunk() -> void:
	var first: Node = EnemyScene.instantiate()
	add_child(first)
	var first_radius: float = first.get_node("CollisionShape2D").shape.radius
	first.queue_free()

	var second: Node = EnemyScene.instantiate()
	add_child(second)
	var second_radius: float = second.get_node("CollisionShape2D").shape.radius
	assert(absf(first_radius - second_radius) < 0.001,
		"Aynı sahneden ikinci yaratık KATLANMIŞ küçültülmüş: %s vs %s" % [first_radius, second_radius])
	second.queue_free()


func test_boss_scale_composes_with_shrink() -> void:
	var enemy: Node = EnemyScene.instantiate()
	var base_sprite: Vector2 = enemy.get_node("Sprite2D").scale
	var base_radius: float = enemy.get_node("CollisionShape2D").shape.radius
	add_child(enemy)

	var boss_mult: float = 1.7 ## enemy_spawner.gd BOSS_SCALE_MULT
	enemy.apply_boss_stats(500.0, 20.0, boss_mult, 5)

	var sprite: Sprite2D = enemy.get_node("Sprite2D")
	assert(sprite.scale.is_equal_approx(base_sprite * EntityScale.SIZE * boss_mult),
		"Boss ölçeği küçültmeyle çarpımsal birleşmiyor: %s" % sprite.scale)
	var body: CollisionShape2D = enemy.get_node("CollisionShape2D")
	assert(absf(body.shape.radius - base_radius * EntityScale.SIZE * boss_mult) < 0.01,
		"Boss gövde yarıçapı yanlış: %s" % body.shape.radius)
	enemy.queue_free()


func test_pet_size_and_speed_inheritance() -> void:
	var pet: Node = GolemPetScene.instantiate()
	var base_sprite: Vector2 = pet.get_node("Sprite2D").scale
	var base_radius: float = pet.get_node("CollisionShape2D").shape.radius
	add_child(pet)

	var sprite: Sprite2D = pet.get_node("Sprite2D")
	assert(sprite.scale.is_equal_approx(base_sprite * EntityScale.SIZE),
		"Evcil hayvan görseli %%5 küçülmemiş: %s" % sprite.scale)
	var body: CollisionShape2D = pet.get_node("CollisionShape2D")
	assert(absf(body.shape.radius - base_radius * EntityScale.SIZE) < 0.01,
		"Evcil hayvan gövde çemberi %%5 küçülmemiş: %s" % body.shape.radius)

	## Hızı sahibinden türetiliyor - sahibin hızı %%10 düşük olduğu için
	## evcil hayvan da kendiliğinden %%10 yavaş olmalı.
	var player: Node = _make_player()
	pet.setup_from_player(player, 1.0, 1.0, 60.0, 0.7)
	assert(absf(pet.speed - player.speed * 0.7) < 0.01,
		"Evcil hayvan hızı sahibinin (%%10 düşük) hızına bağlı değil: %s" % pet.speed)
	pet.queue_free()
	player.queue_free()


## player.gd ve enemy.gd'de iki KOPYA olarak duran body-block yarıçapı aynı
## olmazsa iki taraf farklı sınırda anlaşır (bkz. iki dosyadaki notlar).
func test_player_body_radius_copies_stay_in_sync() -> void:
	var player_src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var enemy_src: String = FileAccess.get_file_as_string("res://scripts/enemy.gd")
	assert(player_src.find("const PLAYER_BODY_RADIUS := 11.4") != -1,
		"player.gd PLAYER_BODY_RADIUS küçültülmemiş")
	assert(enemy_src.find("const PLAYER_BODY_RADIUS := 11.4") != -1,
		"enemy.gd PLAYER_BODY_RADIUS küçültülmemiş (player.gd'nin kopyası)")
	assert(enemy_src.find("speed *= GLOBAL_SPEED_SCALE * EntityScale.SPEED") != -1,
		"Yaratık hızına %%10'luk düşüş uygulanmıyor")


func test_parrot_lerp_speeds_reduced() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/papagan_pet.gd")
	assert(src.find("const FOLLOW_LERP_SPEED := 5.4") != -1,
		"Papağanın takip hızı %%10 düşürülmemiş (6.0 -> 5.4 olmalı)")
	assert(src.find("const FLY_LERP_SPEED := 2.34") != -1,
		"Papağanın uçuş hızı %%10 düşürülmemiş (2.6 -> 2.34 olmalı)")


## Çok oyunculuda diğer oyuncular bu kukla üzerinden görünür - yerel
## karakterle AYNI oranda küçülmezse uzak oyuncular %5 daha iri görünürdü.
func test_remote_player_puppet_shrunk_too() -> void:
	var puppet: Node = RemotePlayerScene.instantiate()
	puppet.char_id = 1
	var base_radius: float = puppet.get_node("CollisionShape2D").shape.radius
	var base_bubble: float = puppet.get_node("ShieldVisual/BubbleSprite").scale.x
	add_child(puppet)

	var body: CollisionShape2D = puppet.get_node("CollisionShape2D")
	assert(absf(body.shape.radius - base_radius * EntityScale.SIZE) < 0.01,
		"Uzak oyuncu kuklasının gövde çemberi %%5 küçülmemiş: %s" % body.shape.radius)
	var bubble: Node2D = puppet.get_node("ShieldVisual/BubbleSprite")
	assert(absf(bubble.scale.x - base_bubble * EntityScale.SIZE) < 0.01,
		"Uzak oyuncu kuklasının kalkan baloncuğu %%5 küçülmemiş: %s" % bubble.scale)
	## Görsel ölçek de yerel oyuncuyla aynı kuraldan (DEFS tabanı x 0.95).
	var def_scale: Vector2 = Characters.get_def(1).get("scale", Vector2(1.27575, 1.27575))
	assert(puppet.anim.scale.is_equal_approx(def_scale * EntityScale.SIZE),
		"Uzak oyuncu kuklası görseli %%5 küçülmemiş: %s" % puppet.anim.scale)
	assert(puppet._base_anim_scale.is_equal_approx(puppet.anim.scale),
		"Kuklanın _base_anim_scale değeri küçültülmüş tabanı tutmuyor")
	puppet.queue_free()
