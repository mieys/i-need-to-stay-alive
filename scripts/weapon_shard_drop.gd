extends Area2D

## SİLAH PARÇACIĞI drop'u - kullanıcı isteği (2026-10-08): "silah parçacıkları tıpkı yemek gibi yerde duracak ve animasyonlu şekilde hafif
## yukarı aşağı olacak" + "bu silah parçacıkları oyunculara eşit miktarda gidecek (biri 5 tane alırsa 5 tane herkese gibi)". Demirci
## dükkanında silah almak için kullanılır (weapon_shop_logic.gd). Düşme kuralları enemy.gd _drop_weapon_shards'ta (yaratık %0.5, elit 1, boss 5).
##
## food_drop.gd ile AYNI desen: kök (position.y) zıplar, gölge yerde kalır (drop_shadow.gd), 300 sn sonra kendiliğinden kaybolur, host'un GERÇEK
## drop'u fiziksel olarak da toplanabilir, istemcide görsel kopya (network_spawned) toplanınca host'a "weapon_shard" isteği gider. Fark: ödül
## BÖLÜNMEZ - toplayan kim olursa olsun yaşayan HER oyuncuya `amount` kadar gider (NetworkManager.host_award_weapon_shards). Tek oyunculuda
## doğrudan oyuncuya. Boss 5 AYRI drop düşürür (her biri amount = 1), böylece boss ganimeti yerde 5 parça olarak görünür.

const FloatingText := preload("res://scenes/floating_text.tscn")
const DropShadowScript := preload("res://scripts/drop_shadow.gd")
const DropAttractionScript := preload("res://scripts/drop_attraction.gd")

## bkz. food_drop.gd EXPIRE_SECONDS (xp_orb.gd'deki "FPS düşüyor" düzeltme notu): sonsuza kadar kalan drop'lar birikmesin.
const EXPIRE_SECONDS := 300.0
const BOB_AMPLITUDE := 3.0
const BOB_SPEED := 4.0
const TEXT_COLOR := Color(0.72, 0.84, 1.0)

## Bu drop'un herkese vereceği parçacık sayısı (broadcast_drop "amount" alanı da bunu taşır, bkz. NetworkManager.broadcast_drop).
var amount: int = 1
var bob_time: float = 0.0
var _last_bob_offset: float = 0.0
## Aynı fizik adımında iki gövde birden girerse çift ödül olmasın (bkz. gold_drop.gd _collected notu).
var _collected: bool = false


## Host / tek oyunculu: yerde bir parçacık drop'u yaratır; çok oyunculuda istemcilere görsel kopyasını da yayınlar (broadcast_drop "weapon_shard").
## enemy.gd (_drop_weapon_shards) ve debug menüsü bunu kullanır - "drop sahnesi + ağ yayını" sözleşmesi tek yerde. Sahne load() ile
## okunur (preload bu betik <-> sahne arasında döngüsel başvuru olurdu).
static func spawn(tree: SceneTree, world_pos: Vector2, amount_each: int = 1) -> Node:
	var root: Node = tree.current_scene if tree != null else null
	if root == null:
		return null
	var shard = (load("res://scenes/weapon_shard_drop.tscn") as PackedScene).instantiate()
	shard.amount = amount_each
	shard.global_position = world_pos
	if NetworkManager.is_multiplayer_active:
		var drop_id: int = NetworkManager._gen_drop_id()
		shard.set_meta("drop_network_id", drop_id)
		NetworkManager.broadcast_drop.rpc("weapon_shard", world_pos, amount_each, drop_id)
	root.call_deferred("add_child", shard)
	return shard


func _ready() -> void:
	add_to_group("weapon_shard_drops")
	body_entered.connect(_on_body_entered)
	bob_time = randf() * TAU ## yan yana düşen parçalar aynı fazda zıplamasın
	var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.play(&"shine")
		sprite.frame = randi() % maxi(1, sprite.sprite_frames.get_frame_count(&"shine")) ## parlama bantları da eşzamanlı olmasın
	## Gölge (bkz. drop_shadow.gd): kök zıplıyor - gölge yerde kalır.
	DropShadowScript.attach(self, sprite, true)
	get_tree().create_timer(EXPIRE_SECONDS).timeout.connect(_on_expire)
	_place_on_ground.call_deferred()


## Zeminde, karakterlerin altında çizil (bkz. drop_attraction.gd place_on_ground).
func _place_on_ground() -> void:
	DropAttractionScript.place_on_ground(self)


func _on_expire() -> void:
	if not is_instance_valid(self) or get_meta("network_spawned", false):
		return
	if NetworkManager.is_multiplayer_active:
		if not NetworkManager.is_host:
			return
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.queue_remove_drop(drop_id)
	queue_free()


func _process(delta: float) -> void:
	bob_time += delta
	var bob_offset: float = sin(bob_time * BOB_SPEED) * BOB_AMPLITUDE
	position.y += bob_offset - _last_bob_offset
	_last_bob_offset = bob_offset


func _on_body_entered(body: Node) -> void:
	if not is_instance_valid(body) or _collected or is_queued_for_deletion():
		return
	## İstemcideki GÖRSEL KOPYA: sadece bu istemcinin KENDİ oyuncusu tetikler, ödülü host dağıtır (bkz. food_drop.gd aynı not).
	if NetworkManager.is_multiplayer_active and get_meta("network_spawned", false):
		if not body.is_in_group("player"):
			return
		_collected = true
		var drop_id: int = int(get_meta("drop_network_id", 0))
		if drop_id > 0:
			NetworkManager.request_drop_pickup.rpc_id(NetworkManager._host_peer_id(), drop_id, "weapon_shard")
			NetworkManager.discard_visual_drop(drop_id)
		queue_free()
		return
	## Host'un gerçek drop'u ya da tek oyunculu: host'un kendi oyuncusu VEYA host'taki uzak oyuncu kuklası (güvenlik ağı + RPC yolu) toplar.
	if not (body.is_in_group("player") or body.is_in_group("remote_players")):
		return
	_collected = true
	award_to_everyone(body)
	if NetworkManager.is_multiplayer_active:
		var drop_id2: int = int(get_meta("drop_network_id", 0))
		if drop_id2 > 0:
			NetworkManager.queue_remove_drop(drop_id2)
	_play_pickup_sound()
	queue_free()


## Ödülü dağıtır (host / tek oyunculu): çok oyunculuda yaşayan HER katılımcıya `amount` (bölünmez); kimse kalmadıysa (herkes kalıcı
## ölü - normalde buraya hiç gelinmez) toplayana. Tek oyunculuda doğrudan oyuncuya. Dönen: ödül alan oyuncu sayısı.
func award_to_everyone(collector: Node) -> int:
	if NetworkManager.is_multiplayer_active:
		var n: int = NetworkManager.host_award_weapon_shards(amount)
		if n == 0 and collector.is_in_group("player"):
			GameManager.add_weapon_shards(amount)
			NetworkManager.show_weapon_shard_text(amount)
			return 1
		return n
	GameManager.add_weapon_shards(amount)
	NetworkManager.show_weapon_shard_text(amount)
	return 1


## Ses kök silinirken kesilmesin: bkz. gold_drop.gd _play_pickup_sound (aynı numara).
func _play_pickup_sound() -> void:
	var sfx: AudioStreamPlayer2D = get_node_or_null("PickupSound") as AudioStreamPlayer2D
	if sfx == null or get_tree().current_scene == null:
		return
	var world_pos: Vector2 = sfx.global_position
	remove_child(sfx)
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = world_pos
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
