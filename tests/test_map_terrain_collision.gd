extends Node

## Kullanıcı isteği doğrulaması: "haritamdaki 'su' ve 'ev' layerlarını
## collisionshape olarak atar mısın. yani bunların olduğu hiçbirşeye
## hiçkimse giremez yaratıklar orada spawnlanamaz içinden geçemez."
##
## Gerçek çözüm TileSet'e fiziksel collision EKLEMİYOR (bkz. game_manager.gd
## is_position_blocked_by_terrain yorumu - TileSet TÜM katmanlar arasında
## paylaşılıyor ve YATI her bake'te sıfırdan üretiyor) - bunun yerine
## harita_baked.tscn'deki "Su/Su" ve "ev/Ev" katmanlarına doğrudan karo
## sorgusu yapılıyor. Bu testler: (1) çekirdek sorgu fonksiyonunun bilinen
## su/ev/temiz hücrelerde doğru sonuç verdiğini, (2) player.gd/enemy.gd'nin
## hareket engelleme fonksiyonlarının gerçekten hızı iptal ettiğini,
## (3) enemy_spawner.gd'nin su/ev üstüne spawn ETMEDİĞİNİ doğruluyor.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const EnemySpawnerScript = preload("res://scripts/enemy_spawner.gd")

## Bilinen hücreler (bkz. get_tilemap_layout ile doğrulanmış):
## - (8,8) piksel -> tile (0,0): Su/Su katmanında dolu (su).
## - Ev katmanı tile (189,119) -> piksel (3024,1904): dolu (ev duvarı).
## - Ev'in hemen güneyi tile (188/189,120) -> piksel (3016,1930): tamamen boş.
const WATER_POINT := Vector2(8.0, 8.0)
const HOUSE_POINT := Vector2(3024.0, 1904.0)
const CLEAR_POINT := Vector2(3016.0, 1930.0)


func _inject_map_into_game_manager() -> Node:
	var harita: Node = HaritaScene.instantiate()
	add_child(harita)
	GameManager._terrain_su_layer = harita.get_node("Su/Su")
	GameManager._terrain_ev_layer = harita.get_node("ev/Ev")
	GameManager._terrain_layers_searched = true
	return harita


func test_is_position_blocked_by_terrain_core_lookup() -> void:
	var harita: Node = _inject_map_into_game_manager()

	assert(GameManager.is_position_blocked_by_terrain(WATER_POINT) == true,
		"Su karosu blok olarak algılanmadı")
	assert(GameManager.is_position_blocked_by_terrain(HOUSE_POINT) == true,
		"Ev karosu blok olarak algılanmadı")
	assert(GameManager.is_position_blocked_by_terrain(CLEAR_POINT) == false,
		"Temiz (su/ev olmayan) hücre yanlışlıkla blok sayıldı")

	harita.queue_free()
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_layers_searched = false


## DÜZELTME (kullanıcı bildirimi: "aşırı geniş olmuş" - probe_dist artık
## sabit 10.0, gövde yarıçapına bağlı değil) - test noktası artık ev
## duvarının (satır 119, dünya y:1904-1920) HEMEN güneyinde (y=1921, sadece
## 1px mesafede) - 10px'lik küçük yoklama bu mesafeden duvara ulaşabiliyor.
const HOUSE_ADJACENT_POINT := Vector2(3016.0, 1921.0)


func test_player_blocked_moving_into_house() -> void:
	var harita: Node = _inject_map_into_game_manager()

	var player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = HOUSE_ADJACENT_POINT
	## Eve doğru (kuzey/yukarı, -y) hareket - probe noktası ev duvarına düşer.
	player.velocity = Vector2(0.0, -50.0)
	player._block_movement_into_terrain()
	assert(player.velocity.y == 0.0,
		"Oyuncu eve doğru hareket ederken engellenmedi (y hız iptal edilmeliydi)")

	## Yana doğru (ev/su olmayan yön) hareket - engellenmemeli.
	player.velocity = Vector2(50.0, 0.0)
	player._block_movement_into_terrain()
	assert(player.velocity.x == 50.0,
		"Oyuncu bloklu OLMAYAN yönde yanlışlıkla engellendi")

	player.queue_free()
	harita.queue_free()
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_layers_searched = false


func test_enemy_blocked_moving_into_water() -> void:
	var harita: Node = _inject_map_into_game_manager()

	var enemy = EnemyScene.instantiate()
	add_child(enemy)
	## Su noktasının hemen güneyinde (y ekseninde suya doğru hareket).
	enemy.global_position = Vector2(8.0, 8.0 + enemy._body_radius + 8.0)
	enemy.velocity = Vector2(0.0, -50.0) ## suya doğru (-y)
	enemy._block_movement_into_terrain()
	assert(enemy.velocity.y == 0.0,
		"Yaratık suya doğru hareket ederken engellenmedi")

	enemy.queue_free()
	harita.queue_free()
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_layers_searched = false


func test_spawner_never_picks_water_or_house_position() -> void:
	var harita: Node = _inject_map_into_game_manager()

	var spawner = EnemySpawnerScript.new()
	add_child(spawner)
	spawner.min_spawn_distance = 10.0
	spawner.max_spawn_distance = 40.0

	## Su noktasının hemen yanında bir "oyuncu" merkezi seçip defalarca
	## spawn pozisyonu üretiyoruz - hiçbiri su/ev üstüne düşmemeli.
	var center: Vector2 = WATER_POINT
	for _i in range(30):
		var pos: Vector2 = spawner._random_spawn_position(center, false)
		assert(not GameManager.is_position_blocked_by_terrain(pos),
			"Spawner su/ev üstüne bir pozisyon seçti: %s" % str(pos))

	spawner.queue_free()
	harita.queue_free()
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_layers_searched = false
