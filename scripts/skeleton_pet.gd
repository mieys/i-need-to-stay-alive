extends CharacterBody2D

## Necromancer'ın TEMEL yeteneği (İskelet Çağır, skill2 id 19, bkz.
## player.gd _skill_necro_summon_skeleton/characters.gd DEFS[11]) ile
## çağrılan iskelet. player_pet.gd'nin (Matthew'in tilkisi) aksine bu GERÇEK
## bir canı olan, ölebilen bir müttefik (bkz. beni oku.txt: "İskelet ...
## canının ise %100üne sahiptir") - o yüzden ondan farklı olarak:
## - take_damage() GERÇEKTEN can azaltıyor (no-op DEĞİL).
## - Yaratıklar onu "player_ally" grubu üzerinden hedef almıyor (enemy.gd bu
##   grubu tamamen görmezden geliyor, bkz. oradaki not) - bunun yerine
##   _process_incoming_damage() KENDİSİ yakınındaki yaratıkları tarayıp temas
##   hasarı alıyor (bkz. orada) - enemy.gd'nin tek-hedefli (sadece "player"
##   grubunu kovalayan) karmaşık AI/hitbox sistemine dokunmadan "gerçekten
##   hasar alabilen" bir müttefik sağlamanın en düşük riskli yolu bu.
## - 60 saniyelik sabit bir yaşam süresi var (bkz. LIFESPAN parametresi,
##   setup_from_player), süre dolunca sessizce solup kayboluyor.
##
## Multiplayer: Matthew'in pet'iyle AYNI desen - SADECE çağıran istemcide
## gerçek yapay zeka/hasar çalışır, diğer istemcilerde SADECE kozmetik bir
## kopya görünür (bkz. player.gd broadcast_player_vfx "pet_spawn" çağrısı +
## remote_player.gd _spawn_pet_visual - o kozmetik kopyada owner_player hiç
## set edilmediği için aşağıdaki AI/hasar kodu owner_player'a bağımlı
## kısımlarda otomatik olarak devre dışı kalır).

signal died

const ROW_DOWN := 0
const ROW_UP := 1
const ROW_LEFT := 2
const ROW_RIGHT := 3
const WALK_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/İskelet 1/PNG/Skeleton1/With_shadow/Skeleton1_Walk_with_shadow.png")
const ATTACK_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/İskelet 1/PNG/Skeleton1/With_shadow/Skeleton1_Attack_with_shadow.png")
const DEATH_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/İskelet 1/PNG/Skeleton1/With_shadow/Skeleton1_Death_with_shadow.png")
## DÜZELTME (kullanıcı bildirimi: "necromancerın iskeletleri yürümeleri
## gerekmese bile yürüme animasyonu yapıyorlar yaratıklara doğru") - eskiden
## hiç ayrı bir "dur" dokusu yoktu, hareket yokken de WALK_TEXTURE akıtılıyordu
## (bkz. aşağıdaki _advance_animation notu). golem_pet.gd'deki AYNI düzeltmeyle
## (bkz. oradaki IDLE_TEXTURE) tutarlı olacak şekilde, Skeleton1 klasöründe
## zaten kullanılmayan bir Skeleton1_Idle_with_shadow.png var (256x256 =
## 4 kare/satır, WALK'ın 6 kare/satırından FARKLI, bu yüzden kendi HFRAMES'i).
const IDLE_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/İskelet 1/PNG/Skeleton1/With_shadow/Skeleton1_Idle_with_shadow.png")
const HFRAMES := 6
const IDLE_HFRAMES := 4
const VFRAMES := 4
const CELL_SIZE := 64
const SPRITE_FPS := 8.6

const SEEK_RADIUS := 420.0
const MELEE_STOP_RANGE := 42.0
const MELEE_RESUME_CHASE_RANGE := 70.0
## Kullanıcı bildirimi (2026-09-24): "necromancerın iskeleti çok yavaş az vuruyor ve güçsüz" - kök neden (vuruş sıklığı):
## bekleme eskiden saldırı animasyonu (9 kare / 8.6 fps = 1.05sn) BİTTİKTEN sonra sayılmaya başlıyordu, gerçek aralık ~2sn
## idi. Artık bekleme vuruş ANINDA başlar ve animasyon ondan kısa sürer: 0.75sn'de bir vuruş (~2.7 kat daha sık).
const ATTACK_INTERVAL := 0.75
const ATTACK_ANIM_FPS := 15.0 ## 9 kare -> 0.6sn (ATTACK_INTERVAL'den kısa, bir sonraki vuruşu geciktirmez)
const FOLLOW_DISTANCE := 90.0
const CATCH_UP_DISTANCE := 320.0

var max_health: float = 50.0
var health: float = 50.0
var speed: float = 120.0
var attack_power: float = 5.0 ## melee vuruş başına hasar (necro'nun saldırı gücünün %30'u, bkz. setup_from_player)

## DÜZELTME (kullanıcı bildirimi: "necromancerin yaratıklarının collision
## shapei yok birbirlerinin içine giriyorlar girmemeleri gerek diğer
## yaratıklarla çarpışmalılar diğer herkes gibi") - enemy.gd'deki AYNI gövde
## yarıçapı/mesafe-temelli itiş sistemi (bkz. oradaki _compute_enemy_
## separation notu - GERÇEK fiziksel collision_layer/mask'a DEĞİL, çünkü
## collision_layer/mask=0 zaten kasıtlı, bkz. aşağıdaki _ready()) burada da
## uygulanıyor (bkz. _compute_pet_separation). Yarıçap değeri enemy_iskelet1.
## tscn'deki (aynı 64px hücreli) düşman İskelet'in gerçek CollisionShape2D
## yarıçapıyla (18.7) AYNI tutuldu, tutarlılık için.
var _body_radius: float = 18.7

## Duvar dolanma (bkz. pet_router.gd) - hedefe/sahibine giden düz çizgiyi orman duvarı kesince A* rotası.
const PetRouterScript := preload("res://scripts/pet_router.gd")
## Sahibinden çok uzakta ve arada duvar varken rotayı bu hız çarpanıyla izler (ışınlanır gibi lerp duvardan geçirirdi).
const CATCH_UP_ROUTE_SPEED_MULT := 2.5
var _router = PetRouterScript.new()

var owner_player: Node2D = null
var is_dead: bool = false
var lifespan: float = 60.0

var facing: String = "down"
var _sprite_row: int = ROW_DOWN
var _frame_time: float = 0.0
var _attack_timer: float = 0.0
var _focus_target: Node2D = null
var _in_melee_stance: bool = false
var _incoming_dmg_timer: float = 0.0
var _animation_state: String = "idle"
var _animation_frame: int = 0
var _animation_elapsed: float = 0.0

## Multiplayer: bkz. dosya başındaki "kozmetik kopya" notu. Eskiden owner_
## player set edilmediği için buradaki AI (_update_focus_target/_process_
## movement) sadece "sahibi izleme" kısımlarında devre dışı kalıyordu - ama
## bu yaratık hedef ararken sahibe değil DOĞRUDAN "enemies" grubuna baktığı
## için (bkz. _update_focus_target) kozmetik kopya GERÇEK pet'ten tamamen
## bağımsız, kendi başına en yakın yaratığı kovalayan ayrı bir yapay zeka
## olarak çalışmaya devam ediyordu - kullanıcı bildirimi: "necromancerin
## yaratıklarını ufacık ve çok hızlı hareket ederken görüyorlar" (hız kısmı
## buradan geliyordu). _is_network_visual true olduğunda TÜM bu bağımsız
## yapay zeka kapanır, yaratık SADECE update_network_pet_state() ile gelen
## gerçek pet konumuna yumuşakça kayan bir kukla olur (bkz. remote_player.gd
## _spawn_pet_visual/mark_as_network_visual ve network_manager.gd
## broadcast_pet_state).
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
		## İskelet doğduğunda henüz hareket etmiyor, bu yüzden baştan IDLE
		## dokusuyla başlıyor (bkz. _advance_animation/_set_locomotion_state).
		sprite.texture = IDLE_TEXTURE
		sprite.hframes = IDLE_HFRAMES
		sprite.vframes = VFRAMES
		sprite.modulate = Color(0.65, 0.95, 0.65, 1.0) # Yeşil ton (Necromancer müttefiği)


## stat_percent: hız/saldırı gücü/zırh gibi statların oranı (İskelet için
## %30). hp_percent: canın oranı (İskelet için %100, bkz. beni oku.txt).
## NOT: Necromancer'ın kalkanı bu yaratığa hiç kopyalanmıyor - beni oku.txt:
## "İskelet ... fakat kalkanları yoktur."
## speed_percent >= 0: hareket hızı stat_percent'ten BAĞIMSIZ bu oranla ölçeklenir (golem_pet.gd'deki AYNI desen). Kullanıcı
## bildirimi (2026-09-24, "iskelet çok yavaş"): hız eskiden saldırı oranıyla (%30) ölçekleniyordu - Necro 252 iken iskelet
## ~76 birim/sn ile düşmanlara zor yetişiyordu.
func setup_from_player(player: Node, stat_percent: float, hp_percent: float, life: float, speed_percent: float = -1.0) -> void:
	owner_player = player
	lifespan = life
	if "max_health" in player:
		max_health = max(1.0, float(player.max_health) * hp_percent)
	health = max_health
	if "speed" in player:
		speed = max(30.0, float(player.speed) * (speed_percent if speed_percent >= 0.0 else stat_percent))
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


## bkz. yukarıdaki _is_network_visual sınıf üstü notu.
func mark_as_network_visual() -> void:
	_is_network_visual = true


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "necromancerın
## yaratıklarının animasyonları diğer oyunculara yanlış gösteriliyor") - iki
## ayrı kök neden vardı: (1) yön (sprite_row) hiç yayınlanmıyordu, kozmetik
## kopya kendi lerp hareketinden TAHMİN ediyordu - gerçek pet yakın dövüş
## duruşundayken (hareketsiz, saldırırken) hiç yön güncellemediği için iki
## taraf FARKLI, donmuş bir yöne kilitleniyordu. (2) _play_attack_animation()
## her "is_attacking=true" yayınında (saldırı boyunca 2-4 kez, bkz.
## _broadcast_network_state throttle notu) koşulsuz yeniden tetikleniyordu,
## bu da animasyonu ortasında sıfırlayıp kekeletiyordu. Artık gerçek yön
## doğrudan uygulanıyor, saldırı animasyonu SADECE yükselen kenarda
## (false->true geçişinde) tetikleniyor.
## network_manager.gd broadcast_pet_state RPC'sinin çağırdığı karşılık -
## remote_player.gd _update_pet_visual_state() üzerinden buraya ulaşır.
var _last_network_is_attacking: bool = false

func update_network_pet_state(pos: Vector2, is_attacking: bool, sprite_row: int = -1, _teleport: bool = false) -> void:
	_network_target_position = pos
	_network_state_received = true
	if sprite_row >= 0:
		_sprite_row = sprite_row
	if is_attacking and not _last_network_is_attacking:
		_play_attack_animation()
	_last_network_is_attacking = is_attacking


## Kozmetik kopyanın "fizik" adımı: kendi yapay zekası yok, sadece gerçek
## pet'in en son bildirilen konumuna doğru yumuşakça kayar (bkz. enemy.gd
## istemci tarafı _physics_process'teki AYNI lerp deseni) ve yön/animasyonu
## buna göre günceller.
func _process_network_visual(delta: float) -> void:
	if not _network_state_received:
		return
	## bkz. update_network_pet_state üstündeki BUG DÜZELTMESİ notu - yön
	## artık burada TAHMİN edilmiyor, doğrudan gerçek pet'ten yayınlanan
	## sprite_row kullanılıyor (aksi halde bu satır her karede onu ezip
	## düzeltmeyi anlamsız kılardı).
	var to_target: Vector2 = _network_target_position - global_position
	velocity = to_target if to_target.length() > 2.0 else Vector2.ZERO
	global_position = global_position.lerp(_network_target_position, min(1.0, delta * 12.0))


## Sadece GERÇEK pet (kozmetik olmayan) çalıştırır - kendi konumunu/saldırı
## durumunu diğer istemcilere periyodik olarak yayınlar (bkz. network_
## manager.gd broadcast_pet_state). network_instance_id boşsa (tekli oyuncu
## veya henüz atanmadıysa) no-op.
## DÜZELTME (kullanıcı bildirimi: "necromancer oynayınca yaratıklar bazen
## kopyalanıyor ve insanlar rasgele oyundan atılıyor"): Necromancer aynı anda
## 10'a kadar yaratık yaşatabiliyor (bkz. NECRO_MAX_ACTIVE_PETS,
## player.gd) - eskiden HER biri saniyede ~12.5 kez (0.08sn) kendi konumunu
## yayınlıyordu, yani TEK bir Necromancer 10 yaratıkla saniyede ~125 RPC
## gönderebiliyordu. Bu, relay'in bağlantı başı mesaj/byte bütçesini kolayca
## aşıp bağlantının "sel" (flood) sayılıp sessizce kapatılmasına yol açıyordu
## (bkz. network_manager.gd should_throttle üstündeki Ziva notu - "birden
## hostun ya da katılımcının oyunu kapanması" tam olarak budur, gözlemlenen
## "rastgele atılma" muhtemelen buydu). Enemy pozisyon senkronunda daha önce
## yapılan aynı düzeltmeyle (bkz. enemy_spawner.gd) tutarlı olacak şekilde
## aralık belirgin şekilde arttırıldı.
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("petpos_%s" % network_instance_id, 0.2):
		return
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, _animation_state == "attack", -1.0, -1.0, _sprite_row)


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


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "oyuncuların yarattığı
## yaratıklar collision shapelerden geçebiliyor") - haritadaki engeller
## (su/ev, bkz. GameManager.is_position_blocked_by_terrain) fizik
## collision_layer/mask ile DEĞİL, bu özel tile-sorgusuyla engelleniyor.
## enemy.gd/player.gd zaten bunu çağırıyordu, bu pet script'i hiç
## çağırmıyordu - bkz. enemy.gd _block_movement_into_terrain() ile BİREBİR
## AYNI fonksiyon.
## DÜZELTME (kullanıcı bildirimi 2026-09-24: "Necromancerın tüm yaratıkları duvarları dolanmayı bilmiyor"): eskiden
## is_position_blocked_by_TERRAIN (su + ev + orman) kullanılıyordu - oyuncu ve yaratıklar ise yıllardır SADECE ormanla
## engelleniyor (su/ev bilerek açık, bkz. enemy.gd _block_movement_into_terrain notu) ve duvar dolanma A*'ı da
## (pet_router.gd / enemy_pathing.gd) sadece ormanı bilir - su/ev engeli rotayı izleyen peti suyun kıyısında
## hapsederdi. Artık oyuncu/yaratıklarla aynı kural: sadece orman. Zaten ormanın İÇİNDEYSE engelleme atlanır
## (sonsuza dek hapsolmasın - enemy.gd/player.gd ile aynı güvenlik ağı).
func _block_movement_into_terrain() -> void:
	if velocity.length() < 0.1:
		return
	if GameManager.is_position_blocked_by_forest(global_position):
		return
	var probe_dist: float = 10.0
	if velocity.x != 0.0:
		var probe_x: Vector2 = global_position + Vector2(sign(velocity.x) * probe_dist, 0.0)
		if GameManager.is_position_blocked_by_forest(probe_x):
			velocity.x = 0.0
	if velocity.y != 0.0:
		var probe_y: Vector2 = global_position + Vector2(0.0, sign(velocity.y) * probe_dist)
		if GameManager.is_position_blocked_by_forest(probe_y):
			velocity.y = 0.0


func _process_movement(delta: float) -> void:
	## DÜZELTME: bkz. yukarıdaki _body_radius/_compute_pet_separation notu -
	## bu itiş artık AŞAĞIDAKİ TÜM dallarda (saldırı/bekleme dahil) velocity'ye
	## eklenip move_and_slide() çağrılıyor, enemy.gd'nin kendi mantığıyla AYNI
	## şekilde (orada da ATTACK durumunda velocity sıfırlansa bile ayrışma
	## itişi HER ZAMAN uygulanıp move_and_slide() çağrılıyor) - yoksa iki
	## iskelet birbirine yakın dövüş menzilinde durup saldırırken (_in_melee_
	## stance) hiç move_and_slide() çağrılmadığı için asla ayrışamazlardı.
	var separation: Vector2 = _compute_pet_separation()
	if _focus_target and is_instance_valid(_focus_target):
		var to_target: Vector2 = _focus_target.global_position - global_position
		var dist: float = to_target.length()
		if _in_melee_stance:
			if dist > MELEE_RESUME_CHASE_RANGE:
				_in_melee_stance = false
		elif dist <= MELEE_STOP_RANGE:
			_in_melee_stance = true
		if not _in_melee_stance:
			## Duvar arkasındaki hedefe A* rotasıyla dolanır (bkz. pet_router.gd); rota izlerken yürüdüğü yöne bakar.
			var chase_dir: Vector2 = _router.direction(global_position, _focus_target.global_position, delta)
			velocity = chase_dir * speed + separation
			_block_movement_into_terrain()
			move_and_slide()
			_update_facing(chase_dir if _router.following_route else to_target)
		else:
			velocity = separation
			_block_movement_into_terrain()
			move_and_slide()
		return
	_in_melee_stance = false
	if not owner_player or not is_instance_valid(owner_player):
		velocity = separation
		_block_movement_into_terrain()
		move_and_slide()
		return
	var to_owner: Vector2 = owner_player.global_position - global_position
	var dist_owner: float = to_owner.length()
	if dist_owner > CATCH_UP_DISTANCE:
		## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "necromancerın
		## yaratıkları bazen bir anda necromancerin yanına ışınlanıyor") -
		## eskiden anlık global_position = ATAMASI yapılıyordu (gerçek bir
		## "sıçrama"). Artık yumuşak bir yakalama (lerp) - hâlâ hızlı ama
		## artık bir kare içinde ışınlanmıyor. Bu pozisyon zaten ağa
		## yayınlandığı için (bkz. _broadcast_network_state) uzak
		## istemcilerdeki kozmetik kopya da otomatik olarak düzeliyor, ayrıca
		## bir değişikliğe gerek yok.
		## Sahibiyle arasında orman duvarı varsa yumuşak yakalama (lerp) peti duvarın İÇİNDEN geçirirdi - o durumda
		## rotayı hızlandırılmış yürüyüşle izler (bkz. pet_router.gd), düz çizgi açıkken eski hızlı yakalama aynen.
		var catch_dir: Vector2 = _router.direction(global_position, owner_player.global_position, delta)
		if _router.following_route:
			velocity = catch_dir * speed * CATCH_UP_ROUTE_SPEED_MULT + separation
			_block_movement_into_terrain()
			move_and_slide()
			_update_facing(catch_dir)
		else:
			var catch_up_target: Vector2 = owner_player.global_position - to_owner.normalized() * FOLLOW_DISTANCE
			global_position = global_position.lerp(catch_up_target, min(1.0, delta * 6.0))
			velocity = Vector2.ZERO
	elif dist_owner > FOLLOW_DISTANCE:
		var follow_dir: Vector2 = _router.direction(global_position, owner_player.global_position, delta)
		velocity = follow_dir * speed + separation
		_block_movement_into_terrain()
		move_and_slide()
		_update_facing(follow_dir)
	else:
		velocity = separation
		_block_movement_into_terrain()
		move_and_slide()


## Kullanıcı bildirimi: "necromancerin yaratıklarının collision shapei yok
## birbirlerinin içine giriyorlar girmemeleri gerek diğer yaratıklarla
## çarpışmalılar diğer herkes gibi" - enemy.gd'deki _compute_enemy_separation/
## _separation_push_from_group ile BİREBİR AYNI yumuşak mesafe algoritması,
## ama HEM "player_allies" (diğer Necromancer yaratıkları) HEM DE "enemies"
## (asıl düşmanlar) grubuna karşı uygulanıyor - böylece iskelet hem başka bir
## iskelet/golem/hortlağın hem de düşmanların içine giremiyor. enemy.gd
## tarafı da artık "player_allies" grubuna karşı AYNI itişi uyguladığı için
## (bkz. oradaki DÜZELTME notu) itiş her zaman KARŞILIKLI.
const PET_SEPARATION_GAP := 2.0
const PET_SEPARATION_CHECK_RADIUS := 100.0
const PET_SEPARATION_FORCE := 130.0

## DÜZELTME (kullanıcı isteği: "necromancerin yaratıkları diğer yaratıklar
## itemez, onlar da necromancerı itemez") - "enemies" grubuna karşı ayrışma
## itişi (hem bu pet'in düşmanlarca itilmesi HEM DE enemy.gd tarafındaki
## karşılık - bkz. oradaki AYNI düzeltme) kaldırıldı. Necromancer
## yaratıkları artık SADECE kendi türdeşleriyle ("player_allies" - diğer
## iskelet/golem/hortlaklar) yumuşak ayrışma uyguluyor, gerçek düşmanlarla
## karşılıklı iç içe geçebiliyorlar (ki zaten savaşırken doğal olarak
## bitişik duruyorlar).
func _compute_pet_separation() -> Vector2:
	return _separation_push_from_group("player_allies") * PET_SEPARATION_FORCE


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
		var action_fps: float = SPRITE_FPS if _animation_state == "death" else ATTACK_ANIM_FPS
		var action_duration: float = action_frames / action_fps
		if _animation_elapsed >= action_duration:
			if _animation_state == "death":
				queue_free()
				return
			_set_locomotion_state("walk" if (velocity.length() > 0.1 and not _in_melee_stance) else "idle")
			_animation_elapsed = 0.0
		else:
			sprite.frame = _sprite_row * action_frames + min(int(_animation_elapsed * action_fps), action_frames - 1)
			return
	## DÜZELTME (kullanıcı bildirimi: "necromancerın iskeletleri yürümeleri
	## gerekmese bile yürüme animasyonu yapıyorlar yaratıklara doğru"): eskiden
	## bu blok velocity'ye BAKMADAN her zaman WALK_TEXTURE'ı akıtıyordu (önceki
	## düzeltme, bkz. Git geçmişi: "iskeletler yürümüyor" - o zamanki tek amaç
	## kare akışının donmasını önlemekti, ayrı bir IDLE dokusu yoktu). Ama
	## iskelet _in_melee_stance'teyken (bkz. _process_movement) velocity
	## SADECE civardaki diğer iskelet/golem/hortlaklardan gelen ayrışma
	## itişinden ibaret (bkz. _compute_pet_separation) - kalabalık bir savaşta
	## bu itiş sık sık 0'dan farklı olup iskelet hedefinin önünde durup
	## saldırırken bile yürüyormuş gibi görünmesine yol açıyordu. golem_pet.
	## gd'deki AYNI düzeltmeyle (bkz. oradaki _advance_animation) tutarlı
	## olacak şekilde artık gerçek bir IDLE dokusu var ve saldırı menzilinde
	## olmak velocity'den bağımsız HER ZAMAN idle sayılıyor.
	var moving: bool = velocity.length() > 0.1 and not _in_melee_stance
	_set_locomotion_state("walk" if moving else "idle")
	_frame_time += delta * SPRITE_FPS
	var frames: int = HFRAMES if moving else IDLE_HFRAMES
	sprite.frame = _sprite_row * frames + (int(_frame_time) % frames)


## bkz. _advance_animation - "walk"/"idle" arasında dokuyu (ve kare sayısını)
## sadece durum GERÇEKTEN değiştiğinde günceller (her karede gereksiz texture
## ataması yapmamak için, golem_pet.gd'deki AYNI desen).
func _set_locomotion_state(state: String) -> void:
	if _animation_state == state:
		return
	_animation_state = state
	if not sprite:
		return
	if state == "walk":
		sprite.texture = WALK_TEXTURE
		sprite.hframes = HFRAMES
	else:
		sprite.texture = IDLE_TEXTURE
		sprite.hframes = IDLE_HFRAMES
	sprite.vframes = VFRAMES
	_frame_time = 0.0


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
	## Bekleme animasyon sırasında da akar (bkz. ATTACK_INTERVAL notu); yeni vuruş yine de önceki animasyon bitince başlar.
	_attack_timer -= delta
	if _animation_state == "attack":
		return
	if _attack_timer > 0.0:
		return
	if not _focus_target or not is_instance_valid(_focus_target) or _focus_target.get("is_dead") == true:
		return
	if global_position.distance_to(_focus_target.global_position) > MELEE_STOP_RANGE + 6.0:
		return
	_attack_timer = ATTACK_INTERVAL
	_play_attack_animation()
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - İskelet'i
	## çağıran Necromancer'ın kritik statlarını kullanıyor (bkz. player.gd
	## _roll_ability_crit/_apply_ability_crit).
	if _focus_target.has_method("take_damage"):
		var is_crit: bool = false
		var dmg: float = attack_power
		if owner_player and is_instance_valid(owner_player) and owner_player.has_method("_roll_ability_crit"):
			is_crit = owner_player._roll_ability_crit()
			dmg = owner_player._apply_ability_crit(dmg, is_crit)
		_focus_target.take_damage(dmg, is_crit)
	
	# Saldırdığına dair yeşil kıvılcım efekti
	var spark_scene: PackedScene = load("res://scenes/fx_hit_mini_spark.tscn")
	if spark_scene:
		var spark := spark_scene.instantiate() as Node2D
		get_tree().current_scene.add_child(spark)
		spark.global_position = _focus_target.global_position
		spark.modulate = Color(0.3, 1.0, 0.4) # Yeşil kıvılcım


## enemy.gd sadece "player" grubunu hedef aldığı için (bkz. dosya başı notu)
## bu müttefiğin GERÇEKTEN hasar alabilmesi için kendi yakınındaki
## yaratıkları kendisi tarar - en yakın yaratığın contact_damage statını
## (yoksa düz bir varsayılanı) periyodik olarak kendi canından düşer.
const INCOMING_CONTACT_RANGE := 40.0
const INCOMING_TICK_INTERVAL := 1.0
const INCOMING_FALLBACK_DAMAGE := 6.0

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
		sprite.modulate = Color(0.65, 0.95, 0.65, 1.0)


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	_play_death_animation()
