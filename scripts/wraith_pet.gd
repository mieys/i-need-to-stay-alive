extends CharacterBody2D

## Necromancer'ın ULTİ'si (Hortlak Çağır, skill id 20, bkz. player.gd
## _skill_necro_summon_wraith/characters.gd DEFS[11]) ile çağrılan hortlak.
## skeleton_pet.gd ile aynı temel desende (gerçek can, kendi hasar/tarama
## mantığı, bkz. orasının dosya başı notu) ama YAKIN DÖVÜŞ değil MENZİLLİ
## saldırıyor ve düşmanlardan UZAK durmaya çalışıyor (bkz. beni oku.txt:
## "yaratıklardan uzaklaşmaya çalışarak savaşır içlerine girip hasar
## almamaya özen gösterir").

signal died

const ROW_DOWN := 0
const ROW_UP := 1
const ROW_LEFT := 2
const ROW_RIGHT := 3
const WALK_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Hayalet 1/PNG/Ghost1/With_shadow/Ghost1_Walk_with_shadow.png")
const ATTACK_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Hayalet 1/PNG/Ghost1/With_shadow/Ghost1_Attack_with_shadow.png")
const DEATH_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Hayalet 1/PNG/Ghost1/With_shadow/Ghost1_Death_with_shadow.png")
const HFRAMES := 6
const VFRAMES := 4
const CELL_SIZE := 64
const SPRITE_FPS := 8.6
const HitSparkScene := preload("res://scenes/fx_hit_mini_spark.tscn")

const SEEK_RADIUS := 500.0
const FIRE_RANGE := 260.0 ## bu menzildeyken ateş eder
const KEEP_DISTANCE := 170.0 ## bundan yakına girmemeye çalışır (bkz. _process_movement)
const ATTACK_INTERVAL := 1.2
const FOLLOW_DISTANCE := 100.0
const CATCH_UP_DISTANCE := 360.0

const INCOMING_CONTACT_RANGE := 40.0
const INCOMING_TICK_INTERVAL := 1.0
const INCOMING_FALLBACK_DAMAGE := 6.0

var max_health: float = 50.0
var health: float = 50.0
var speed: float = 130.0
var attack_power: float = 5.0 ## menzilli vuruş başına hasar (kendi saldırı gücünün %100'ü, bkz. beni oku.txt)

## DÜZELTME (kullanıcı bildirimi: "necromancerin yaratıklarının collision
## shapei yok birbirlerinin içine giriyorlar girmemeleri gerek diğer
## yaratıklarla çarpışmalılar diğer herkes gibi") - bkz. skeleton_pet.gd'deki
## AYNI notun karşılığı (bu dosya şu an hiçbir yerden çağrılmıyor, bkz. dosya
## başı notu, ama tutarlılık için AYNI düzeltme uygulandı).
var _body_radius: float = 18.7

var owner_player: Node2D = null
var is_dead: bool = false
var lifespan: float = 120.0

var facing: String = "down"
var _sprite_row: int = ROW_DOWN
var _frame_time: float = 0.0
var _attack_timer: float = 0.0
var _focus_target: Node2D = null
var _incoming_dmg_timer: float = 0.0
var _animation_state: String = "walk"
var _animation_frame: int = 0
var _animation_elapsed: float = 0.0
## Histerezis (hysteris) tamponu: hortlağın geri kaçarken sürekli git-gel yapıp
## titreşmesini/glitchlenmesini önlemek için - kalkan mesafesinden (170) yakınsa
## geri kaçma moduna girer, hedeften 210px uzaklaşana kadar da bu moddan
## çıkmaz, böylece hareket akıcı olur.
var _backing_away: bool = false

## Multiplayer: bkz. skeleton_pet.gd'deki AYNI notun karşılığı - kozmetik
## kopya, hedef ararken sahibe değil "enemies" grubuna baktığından
## owner_player set edilmese bile GERÇEK pet'ten bağımsız kendi başına
## hareket etmeye devam ediyordu (kullanıcı bildirimi: "necromancerin
## yaratıklarını ufacık ve çok hızlı hareket ederken görüyorlar").
## _is_network_visual true olunca bu bağımsız yapay zeka tamamen kapanır.
var network_instance_id: String = ""
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	## Kullanıcı isteği (bkz. EntityScale): tüm varlıklar gibi evcil hayvanlar da
	## %5 küçülür - görsel ve gövde çemberi orantılı.
	EntityScale.shrink(sprite, get_node_or_null("CollisionShape2D"))
	collision_layer = 0
	collision_mask = 0
	add_to_group("player_allies")
	if sprite:
		sprite.texture = WALK_TEXTURE
		sprite.hframes = HFRAMES
		sprite.vframes = VFRAMES
		sprite.modulate = Color(0.55, 0.95, 0.55, 0.88) ## Yeşil ton (Necromancer müttefiği)


## bkz. skeleton_pet.gd'deki aynı imza/gerekçe - stat_percent (Hortlak için
## %100) hız/saldırı gücü/zırh statlarına, hp_percent (Hortlak için de %100)
## sadece cana uygulanır.
func setup_from_player(player: Node, stat_percent: float, hp_percent: float, life: float) -> void:
	owner_player = player
	lifespan = life
	if "max_health" in player:
		max_health = max(1.0, float(player.max_health) * hp_percent)
	health = max_health
	if "speed" in player:
		speed = max(30.0, float(player.speed) * stat_percent)
	if "damage_bonus" in player:
		attack_power = max(1.0, float(player.damage_bonus) * stat_percent)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _is_network_visual:
		_process_network_visual(delta)
		return
	lifespan -= delta
	if lifespan <= 0.0:
		_expire()
		return
	_update_focus_target()
	_process_movement(delta)
	_process_attack(delta)
	_process_incoming_damage(delta)
	_broadcast_network_state()



func _process(delta: float) -> void:
	_advance_animation(delta)


func mark_as_network_visual() -> void:
	_is_network_visual = true


## DÜZELTME: remote_player.gd _update_pet_visual_state() bu fonksiyonu
## sprite_row dahil 3 argümanla çağırıyor (bkz. skeleton_pet.gd/player_pet.gd
## AYNI düzeltme) - eski 2 parametreli imza "too many arguments" hatasıyla
## sessizce başarısız oluyordu.
func update_network_pet_state(pos: Vector2, is_attacking: bool, _sprite_row: int = -1) -> void:
	_network_target_position = pos
	_network_state_received = true
	if is_attacking:
		_play_attack_animation()


func _process_network_visual(delta: float) -> void:
	if not _network_state_received:
		return
	var to_target: Vector2 = _network_target_position - global_position
	if to_target.length() > 2.0:
		velocity = to_target
		_update_facing(to_target)
	else:
		velocity = Vector2.ZERO
	global_position = global_position.lerp(_network_target_position, min(1.0, delta * 12.0))


## DÜZELTME (kullanıcı bildirimi: necromancer oynayınca "rasgele oyundan
## atılma" - bkz. skeleton_pet.gd'deki aynı düzeltmenin üstündeki ayrıntılı
## not): yayın aralığı flood/kick riskini azaltmak için arttırıldı.
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("petpos_%s" % network_instance_id, 0.2):
		return
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, _animation_state == "attack")


func _update_focus_target() -> void:
	if _focus_target and is_instance_valid(_focus_target) and _focus_target.get("is_dead") != true:
		if global_position.distance_to(_focus_target.global_position) <= SEEK_RADIUS:
			return
	_focus_target = null
	var nearest: Node2D = null
	var nearest_dist: float = SEEK_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = global_position.distance_to(e.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = e
	_focus_target = nearest


## Kilit fark: hedefe koşup durmak yerine - hedef KEEP_DISTANCE'tan yakınsa
## ondan UZAKLAŞIR, FIRE_RANGE'in dışındaysa (ama KEEP_DISTANCE'tan da
## uzaksa) yaklaşır, ikisi arasındaysa (iyi menzil) yerinde durup ateş eder.
func _process_movement(_delta: float) -> void:
	## DÜZELTME: bkz. skeleton_pet.gd'deki AYNI notun karşılığı - ayrışma
	## itişi artık TÜM dallarda (ateş ederken beklemek dahil) uygulanıyor.
	var separation: Vector2 = _compute_pet_separation()
	if _focus_target and is_instance_valid(_focus_target):
		var to_target: Vector2 = _focus_target.global_position - global_position
		var dist: float = to_target.length()

		# Histerezis eşikleri
		if dist < KEEP_DISTANCE:
			_backing_away = true
		elif dist > KEEP_DISTANCE + 40.0:
			_backing_away = false

		if _backing_away:
			velocity = -to_target.normalized() * speed + separation
			move_and_slide()
			_update_facing(-to_target)
		elif dist > FIRE_RANGE:
			velocity = to_target.normalized() * speed + separation
			move_and_slide()
			_update_facing(to_target)
		else:
			velocity = separation
			move_and_slide()
			_update_facing(to_target)
		return
	if not owner_player or not is_instance_valid(owner_player):
		velocity = separation
		move_and_slide()
		return
	var to_owner: Vector2 = owner_player.global_position - global_position
	var dist_owner: float = to_owner.length()
	if dist_owner > CATCH_UP_DISTANCE:
		global_position = owner_player.global_position - to_owner.normalized() * FOLLOW_DISTANCE
		velocity = Vector2.ZERO
	elif dist_owner > FOLLOW_DISTANCE:
		velocity = to_owner.normalized() * speed + separation
		move_and_slide()
		_update_facing(to_owner)
	else:
		velocity = separation
		move_and_slide()


## bkz. skeleton_pet.gd'deki BİREBİR AYNI fonksiyonlar/gerekçe.
const PET_SEPARATION_GAP := 2.0
const PET_SEPARATION_CHECK_RADIUS := 100.0
const PET_SEPARATION_FORCE := 130.0

func _compute_pet_separation() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	push += _separation_push_from_group("player_allies")
	push += _separation_push_from_group("enemies")
	return push * PET_SEPARATION_FORCE


func _separation_push_from_group(group_name: String) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for e in get_tree().get_nodes_in_group(group_name):
		if e == self or not is_instance_valid(e):
			continue
		if e.get("is_dead") == true:
			continue
		var to_me: Vector2 = global_position - e.global_position
		var d: float = to_me.length()
		if d < 0.001:
			to_me = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
			d = to_me.length()
			if d < 0.001:
				continue
		if d >= PET_SEPARATION_CHECK_RADIUS:
			continue
		var other_radius: float = 20.0
		var r_variant = e.get("_body_radius")
		if r_variant != null:
			other_radius = float(r_variant)
		var min_gap: float = _body_radius + other_radius + PET_SEPARATION_GAP
		if d < min_gap:
			var overlap: float = (min_gap - d) / min_gap
			push += (to_me / d) * overlap
	return push


func _update_facing(direction: Vector2) -> void:
	if direction.length() < 0.1:
		return
	if abs(direction.x) > abs(direction.y):
		facing = "right" if direction.x > 0 else "left"
		_sprite_row = ROW_RIGHT if direction.x > 0 else ROW_LEFT
	else:
		facing = "up" if direction.y < 0 else "down"
		_sprite_row = ROW_UP if direction.y < 0 else ROW_DOWN


func _advance_animation(delta: float) -> void:
	if not sprite:
		return
	_animation_elapsed += delta
	if _animation_state == "death" or _animation_state == "attack":
		var action_texture: Texture2D = DEATH_TEXTURE if _animation_state == "death" else ATTACK_TEXTURE
		var action_frames: int = max(int(action_texture.get_width() / float(CELL_SIZE)), 1)
		var action_duration: float = action_frames / SPRITE_FPS
		if _animation_elapsed >= action_duration:
			if _animation_state == "death":
				queue_free()
				return
			_animation_state = "walk"
			sprite.texture = WALK_TEXTURE
			sprite.hframes = HFRAMES
			sprite.vframes = VFRAMES
			_animation_elapsed = 0.0
		else:
			sprite.frame = _sprite_row * action_frames + min(int(_animation_elapsed * SPRITE_FPS), action_frames - 1)
			return
	if velocity.length() > 0.1:
		_frame_time += delta * SPRITE_FPS
	else:
		_frame_time = 0.0
	sprite.frame = _sprite_row * HFRAMES + (int(_frame_time) % HFRAMES)


func _play_attack_animation() -> void:
	if not sprite or _animation_state == "death":
		return
	_animation_state = "attack"
	_animation_elapsed = 0.0
	sprite.texture = ATTACK_TEXTURE
	sprite.hframes = max(int(ATTACK_TEXTURE.get_width() / float(CELL_SIZE)), 1)
	sprite.vframes = VFRAMES
	sprite.frame = _sprite_row * max(int(ATTACK_TEXTURE.get_width() / float(CELL_SIZE)), 1)


func _process_attack(delta: float) -> void:
	if _animation_state == "attack":
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	if not _focus_target or not is_instance_valid(_focus_target) or _focus_target.get("is_dead") == true:
		return
	if global_position.distance_to(_focus_target.global_position) > FIRE_RANGE:
		return
	_attack_timer = ATTACK_INTERVAL
	_play_attack_animation()
	
	# Saldırdığına dair yeşil menzilli mermi fırlatır (visual + collision damage)
	var proj_scene: PackedScene = load("res://scenes/projectile.tscn")
	if proj_scene:
		var proj := proj_scene.instantiate() as Area2D
		get_tree().current_scene.add_child(proj)
		proj.global_position = global_position
		proj.collision_mask = 4 # Düşmanlara çarpar (enemies layer=3 / mask=4)
		proj.set("damage", attack_power)
		proj.set("speed", 400.0)
		var dir := (_focus_target.global_position - global_position).normalized()
		proj.set("direction", dir)
		proj.modulate = Color(0.3, 1.0, 0.4) # Yeşil büyü mermisi tonu


func _process_incoming_damage(delta: float) -> void:
	_incoming_dmg_timer -= delta
	if _incoming_dmg_timer > 0.0:
		return
	var total: float = 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= INCOMING_CONTACT_RANGE:
			total += float(e.get("contact_damage")) if "contact_damage" in e else INCOMING_FALLBACK_DAMAGE
	if total > 0.0:
		_incoming_dmg_timer = INCOMING_TICK_INTERVAL
		take_damage(total)


func take_damage(amount: float, _source: Node2D = null) -> void:
	if is_dead or amount <= 0.0:
		return
	health -= max(amount, 1.0)
	if health <= 0.0:
		_die()


func _expire() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	_play_death_animation()


func _play_death_animation() -> void:
	_animation_state = "death"
	_animation_elapsed = 0.0
	if sprite:
		sprite.texture = DEATH_TEXTURE
		sprite.hframes = max(int(DEATH_TEXTURE.get_width() / float(CELL_SIZE)), 1)
		sprite.vframes = VFRAMES
		sprite.modulate = Color(0.55, 0.95, 0.55, 0.88)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	_play_death_animation()
