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
## "Temiz" nokta artık sabit bir koordinat DEĞİL (bkz. _find_clear_point_near_house): eskiden
## Ev'in güneyi (3016,1930) "tamamen boş" diye sabitlenmişti, ama orman katmanı
## (plato/uçurum duvarları) sonradan oraya da uzandı (hem önceki hem yeni bake'te
## dolu) ve Tiled'da harita her düzenlendiğinde böyle bir sabit yeniden bayatlar.
const WATER_POINT := Vector2(8.0, 8.0)
const HOUSE_POINT := Vector2(3024.0, 1904.0)


func _inject_map_into_game_manager() -> Node:
	var harita: Node = HaritaScene.instantiate()
	add_child(harita)
	GameManager._terrain_su_layer = harita.get_node("Su/Su")
	GameManager._terrain_ev_layer = harita.get_node("ev/Ev")
	GameManager._terrain_forest_layer = harita.get_node("Orman parçaları/Orman parçaları")
	GameManager._terrain_layers_searched = true
	return harita


func _clear_game_manager_map() -> void:
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false


## Orman katmanında, HEMEN ÜSTÜNDEKİ komşusu (kuzey) boş olan bir hücre bulur ve
## {"wall": duvar hücresinin dünya merkezi, "above": duvarın hemen üstündeki
## boş hücrenin, duvara 1px kala dünya konumu} döner. Koridorun her iki yanı da
## boş olsun diye kuzey ve güney komşu kontrol edilir (dikey yaklaşma testi).
func _find_forest_wall_from_above(forest: TileMapLayer) -> Dictionary:
	for cell: Vector2i in forest.get_used_cells():
		var north: Vector2i = cell + Vector2i(0, -1)
		if forest.get_cell_source_id(north) != -1:
			continue
		var wall_top_y: float = forest.to_global(forest.map_to_local(cell)).y - 8.0
		var center_x: float = forest.to_global(forest.map_to_local(cell)).x
		return {"wall": forest.to_global(forest.map_to_local(cell)), "above": Vector2(center_x, wall_top_y - 1.0)}
	return {}


## Orman katmanında olmayan ve su/ev katmanlarında da olmayan boş bir hücrenin dünya merkezi.
func _find_clear_point(forest: TileMapLayer) -> Vector2:
	for x in range(100, 140):
		var cell := Vector2i(x, 128)
		var pos: Vector2 = forest.to_global(forest.map_to_local(cell))
		if not GameManager.is_position_blocked_by_terrain(pos):
			return pos
	return Vector2(-1.0, -1.0)


func test_forest_layer_is_found_and_blocks_its_own_cells() -> void:
	var harita: Node = _inject_map_into_game_manager()
	var forest: TileMapLayer = GameManager.get_forest_layer()
	assert(forest != null, "GameManager.get_forest_layer() 'Orman parçaları/Orman parçaları' katmanını bulamadı")
	assert(forest.get_used_cells().size() > 1000, "Orman katmanı beklenenden çok boş: %d hücre" % forest.get_used_cells().size())

	for cell: Vector2i in forest.get_used_cells().slice(0, 50):
		var center: Vector2 = forest.to_global(forest.map_to_local(cell))
		assert(GameManager.is_position_blocked_by_forest(center), "Orman karosu blok sayılmadı: %s" % str(cell))
		assert(GameManager.is_position_blocked_by_terrain(center), "is_position_blocked_by_terrain orman karosunu içermeli: %s" % str(cell))

	var clear: Vector2 = _find_clear_point(forest)
	assert(clear.x >= 0.0, "Test için boş bir nokta bulunamadı")
	assert(not GameManager.is_position_blocked_by_forest(clear), "Boş hücre orman olarak algılandı: %s" % str(clear))

	harita.queue_free()
	_clear_game_manager_map()


func test_forest_absent_means_never_blocked() -> void:
	_clear_game_manager_map()
	GameManager._terrain_layers_searched = true ## harita sahnede yok (ana menü): sorgu bulamayıp false dönmeli
	assert(GameManager.get_forest_layer() == null, "Harita yokken orman katmanı null olmalı")
	assert(GameManager.is_position_blocked_by_forest(Vector2(100.0, 100.0)) == false, "Harita yokken hiçbir nokta bloklu olmamalı")
	_clear_game_manager_map()


func test_player_blocked_moving_into_forest_but_free_sideways() -> void:
	var harita: Node = _inject_map_into_game_manager()
	var forest: TileMapLayer = GameManager.get_forest_layer()
	var found: Dictionary = _find_forest_wall_from_above(forest)
	assert(not found.is_empty(), "Test için üstü boş bir orman duvarı hücresi bulunamadı")

	var player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = found["above"]
	## Duvara doğru (güney, +y) hareket: probe orman karosuna düşer, y hızı iptal olmalı.
	player.velocity = Vector2(0.0, 50.0)
	player._block_movement_into_terrain()
	assert(player.velocity.y == 0.0, "Oyuncu orman duvarına doğru hareket ederken engellenmedi (y hız iptal edilmeliydi)")

	## Duvardan UZAĞA (kuzey) hareket: engellenmemeli.
	player.velocity = Vector2(0.0, -50.0)
	player._block_movement_into_terrain()
	assert(player.velocity.y == -50.0, "Oyuncu duvardan uzaklaşırken engellendi")

	player.queue_free()
	harita.queue_free()
	_clear_game_manager_map()


func test_player_already_inside_forest_can_walk_out() -> void:
	var harita: Node = _inject_map_into_game_manager()
	var forest: TileMapLayer = GameManager.get_forest_layer()
	var cell: Vector2i = forest.get_used_cells()[0]

	var player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = forest.to_global(forest.map_to_local(cell))
	player.velocity = Vector2(50.0, 50.0)
	player._block_movement_into_terrain()
	assert(player.velocity == Vector2(50.0, 50.0),
		"Zaten duvarın içindeki oyuncu kısıtlanmamalı (yoksa sonsuza dek hapsolur): %s" % str(player.velocity))

	player.queue_free()
	harita.queue_free()
	_clear_game_manager_map()


func test_enemy_blocked_by_forest_and_free_when_inside() -> void:
	var harita: Node = _inject_map_into_game_manager()
	var forest: TileMapLayer = GameManager.get_forest_layer()
	var found: Dictionary = _find_forest_wall_from_above(forest)
	assert(not found.is_empty(), "Test için üstü boş bir orman duvarı hücresi bulunamadı")

	var enemy = EnemyScene.instantiate()
	add_child(enemy)
	enemy.global_position = found["above"]
	enemy.velocity = Vector2(0.0, 50.0)
	enemy._block_movement_into_terrain()
	assert(enemy.velocity.y == 0.0, "Yaratık orman duvarına doğru hareket ederken engellenmedi")

	enemy.global_position = found["wall"]
	enemy.velocity = Vector2(0.0, 50.0)
	enemy._block_movement_into_terrain()
	assert(enemy.velocity.y == 50.0, "Zaten duvarın içindeki yaratık kısıtlanmamalı (yoksa sonsuza dek hapsolur)")

	enemy.queue_free()
	harita.queue_free()
	_clear_game_manager_map()


func test_spawner_never_picks_forest_position() -> void:
	var harita: Node = _inject_map_into_game_manager()
	var forest: TileMapLayer = GameManager.get_forest_layer()
	var found: Dictionary = _find_forest_wall_from_above(forest)
	assert(not found.is_empty(), "Test için üstü boş bir orman duvarı hücresi bulunamadı")
	## Merkez duvarın hemen üstü: halka (40-120px) çoğunlukla açık alana düşer, spawner
	## orman karolarına denk gelen adayları reddedip yeniden denemeli (en fazla 10 deneme).
	var center: Vector2 = found["above"]

	var spawner = EnemySpawnerScript.new()
	add_child(spawner)
	spawner.min_spawn_distance = 40.0
	spawner.max_spawn_distance = 120.0
	for _i in range(40):
		var pos: Vector2 = spawner._random_spawn_position(center, false)
		assert(not GameManager.is_position_blocked_by_forest(pos), "Spawner orman duvarının üstüne bir pozisyon seçti: %s" % str(pos))

	spawner.queue_free()
	harita.queue_free()
	_clear_game_manager_map()


## HOUSE_POINT'e EN YAKIN, su/ev/orman katmanlarının HİÇBİRİNDE dolu olmayan hücrenin
## dünya merkezi (yoksa Vector2.INF). Katmanlara doğrudan bakar, test edilen
## GameManager.is_position_blocked_by_terrain'i kullanmaz.
func _find_clear_point_near_house(harita: Node) -> Vector2:
	var layers: Array = [harita.get_node("Su/Su"), harita.get_node("ev/Ev"), harita.get_node("Orman parçaları/Orman parçaları")]
	var ev: TileMapLayer = layers[1]
	var origin_cell: Vector2i = ev.local_to_map(ev.to_local(HOUSE_POINT))
	for r: int in range(1, 60):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var world: Vector2 = ev.to_global(ev.map_to_local(origin_cell + Vector2i(dx, dy)))
				var clear: bool = true
				for layer: TileMapLayer in layers:
					if layer.get_cell_source_id(layer.local_to_map(layer.to_local(world))) != -1:
						clear = false
						break
				if clear:
					return world
	return Vector2.INF


func test_is_position_blocked_by_terrain_core_lookup() -> void:
	var harita: Node = _inject_map_into_game_manager()

	assert(GameManager.is_position_blocked_by_terrain(WATER_POINT) == true,
		"Su karosu blok olarak algılanmadı")
	assert(GameManager.is_position_blocked_by_terrain(HOUSE_POINT) == true,
		"Ev karosu blok olarak algılanmadı")
	var clear_point: Vector2 = _find_clear_point_near_house(harita)
	assert(clear_point != Vector2.INF, "Ev'in yakınında su/ev/orman olmayan temiz bir hücre bulunamadı")
	assert(GameManager.is_position_blocked_by_terrain(clear_point) == false,
		"Temiz (su/ev/orman olmayan) hücre yanlışlıkla blok sayıldı: %s" % str(clear_point))

	harita.queue_free()
	_clear_game_manager_map()


## DÜZELTME (kullanıcı bildirimi: "aşırı geniş olmuş" - probe_dist artık
## sabit 10.0, gövde yarıçapına bağlı değil) - test noktası artık ev
## duvarının (satır 119, dünya y:1904-1920) HEMEN güneyinde (y=1921, sadece
## 1px mesafede) - 10px'lik küçük yoklama bu mesafeden duvara ulaşabiliyor.
const HOUSE_ADJACENT_POINT := Vector2(3016.0, 1921.0)


## SU/EV ENGELİ OYUNCU VE YARATIKLAR İÇİN BİLEREK KAPALI (kullanıcı isteği:
## "oyundaki collision shapeleri kaldır haritada istediğimiz yere hareket
## edebilelim sonra sıfırdan collision shape dizicem çünkü" - bkz. player.gd/
## enemy.gd _block_movement_into_terrain). Bu iki test bu durumu BELGELER: eve/suya
## doğru hareket kısıtlanmıyor. Su/ev yeniden açılırsa bunlar ters çevrilmeli.
func test_player_is_free_to_walk_into_house_while_house_collision_is_off() -> void:
	var harita: Node = _inject_map_into_game_manager()

	var player = PlayerScene.instantiate()
	add_child(player)
	player.global_position = HOUSE_ADJACENT_POINT
	## Eve doğru (kuzey/yukarı, -y) hareket - su/ev kapalı, hız iptal EDİLMEMELİ.
	player.velocity = Vector2(0.0, -50.0)
	player._block_movement_into_terrain()
	assert(player.velocity.y == -50.0,
		"Ev engeli kapalıyken oyuncu eve doğru engellendi (kullanıcı su/ev collision'ını bilerek kapattı)")

	player.queue_free()
	harita.queue_free()
	_clear_game_manager_map()


func test_enemy_is_free_to_walk_into_water_while_water_collision_is_off() -> void:
	var harita: Node = _inject_map_into_game_manager()

	var enemy = EnemyScene.instantiate()
	add_child(enemy)
	## Su noktasının hemen güneyinde (y ekseninde suya doğru hareket).
	enemy.global_position = Vector2(8.0, 8.0 + enemy._body_radius + 8.0)
	enemy.velocity = Vector2(0.0, -50.0) ## suya doğru (-y)
	enemy._block_movement_into_terrain()
	assert(enemy.velocity.y == -50.0,
		"Su engeli kapalıyken yaratık suya doğru engellendi (kullanıcı su/ev collision'ını bilerek kapattı)")

	enemy.queue_free()
	harita.queue_free()
	_clear_game_manager_map()


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
	_clear_game_manager_map()
