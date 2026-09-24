extends Node

## Kullanıcı bildirimi (ekran görüntüsüyle, 2026-09-23): "bazı yaratıklar sıkıştıklarında arkalarına yana
## falan bakıp saldırı hareketi yapıyor". Kök neden host tarafında (_physics_process "not think" dalı) VE
## istemci tarafında (aşağıdaki dead-reckoning yön türetme) AYRI AYRI mekanizmalardı - biri düzeltilip diğeri
## unutulursa CLAUDE.md'nin uyardığı "kaster/host görür, diğerleri görmez" hata sınıfına tam uyardı, bu yüzden
## istemci (katılımcı) tarafı BURADA ayrı test ediliyor.
##
## Senaryo: istemci puppet'ı (NetworkManager.is_host = false), host bir yaratığın DURUP saldırıya geçtiğini
## bildiriyor (aynı konum arka arkaya 2 paket - _network_velocity küçük kalır, 15.0 eşiğinin altında) ama
## yaratığın SON GERÇEK hareketi (kalabalıkta ayrışmayla saptırılmış gibi) oyuncudan TAMAMEN FARKLI bir yöndeydi.
## Beklenen: yaratık er ya da geç (AI_THINK_INTERVAL_FRAMES karede bir, host'un kendi throttle'ıyla AYNI desen)
## GERÇEK hedefe (en yakın oyuncu) doğru bakmaya döner - eski hareket yönünde donup kalmaz.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _spawned: Array = []


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	NetworkManager.is_host = false
	for n in _spawned:
		if is_instance_valid(n):
			n.queue_free()
	_spawned.clear()


func _physics_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame


func test_stopped_puppet_eventually_faces_the_real_nearby_player_not_stale_movement_direction() -> void:
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = false

	var player: Node2D = PlayerScene.instantiate()
	add_child(player)
	player.global_position = Vector2(1000.0, 1000.0)
	_spawned.append(player)

	var enemy: Node2D = EnemyScene.instantiate()
	add_child(enemy)
	## Yaratığın SON GERÇEK hareketi oyuncudan tamamen ZIT yöndeydi (ör. bir ayrışma/knockback şokuyla).
	enemy.global_position = Vector2(1000.0, 940.0) ## oyuncunun 60px ÜSTÜNDE (yani oyuncuya bakması "aşağı" olmalı)
	_spawned.append(enemy)
	await _physics_frames(2) ## @onready alanları (frame_sprite vb.) hazır olsun

	## Host, yaratığın DURDUĞUNU bildiriyor: iki paket AYNI konumda (velocity ~ 0) - ama yaratık şu an
	## _sprite_row = ROW_UP (yukarı bakıyor, yani oyuncudan UZAĞA) gibi eski/yanlış bir yönde donmuş olsun.
	enemy._sprite_row = 1 ## ROW_UP - kasıtlı olarak YANLIŞ (oyuncu aşağıda, doğrusu ROW_DOWN=0 olmalı)
	enemy.update_network_state(enemy.global_position, false, -1.0, -1.0, false, -1, 0)
	await _physics_frames(1)
	enemy.update_network_state(enemy.global_position, false, -1.0, -1.0, false, -1, 0) ## aynı konum -> velocity küçük

	var turned: bool = false
	for i in range(enemy.AI_THINK_INTERVAL_FRAMES + 2):
		await get_tree().physics_frame
		if int(enemy._sprite_row) == 0: ## ROW_DOWN = oyuncuya (aşağıya) bakıyor
			turned = true
			break
	assert(turned, "Duran istemci puppet'ı birkaç kare içinde GERÇEK hedefe (oyuncuya) dönmeli, eski hareket yönünde donmamalı")
	_cleanup()
