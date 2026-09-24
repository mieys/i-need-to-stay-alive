extends CharacterBody2D

## Necromancer'ın ULTİ'si (skill id 20, R tuşu, bkz. player.gd
## _skill_necro_summon_golem/characters.gd DEFS[11]) ile çağrılan Golem.
## Kullanıcı isteği: "necromancerın ultisi hayalet yerine golem çağırsın
## golem necromancerin statlarının %200üne sahiptir ancak %50 daha yavaş
## saldırır ve kalkanı da vardır (can ve kalkan barı üstünde görünsün tıpkı
## diğer karakterlerinki gibi). golem 6 saniyede bir yere vurarak
## çevresindeki yaratıkları 1 saniye sersemletir. golem biraz mor tonlarında
## görünmeli". Eskiden bu ULTİ wraith_pet.gd'yi (Hortlak) çağırıyordu - o
## dosya hâlâ duruyor (zararsız, kullanılmıyor), bu script skeleton_pet.gd'nin
## yakın-dövüş yapay zeka desenini temel alıyor, farklar:
## - setup_from_player'a verilen stat_percent/hp_percent 2.0 (Necromancer'ın
##   statlarının/canının %200'ü, bkz. player.gd NECRO_GOLEM_STAT_PERCENT).
## - ATTACK_INTERVAL skeleton'ın temel değerinin 2 katı ("%50 daha yavaş
##   saldırır" - hasar/vuruş başına DEĞİŞMEDİ, sadece saldırı sıklığı yarıya
##   indi, bkz. _process_attack).
## - Ayrıca bir KALKANI var (max_shield/shield, bkz. take_damage) - diğer
##   Necromancer yaratıklarında (İskelet/Hortlak) bu hiç yok.
## - overhead_bar.gd (oyuncunun/bosların kullandığı AYNI can+kalkan çubuğu
##   komponenti) burada da kullanılıyor ve HER ZAMAN görünür (bkz.
##   _create_overhead_bar) - "tıpkı diğer karakterlerinki gibi" isteğiyle
##   birebir eşleşsin diye.
## - 6 saniyede bir "yere vurup" menzilindeki tüm yaratıkları 1sn sersemletir
##   (bkz. _process_golem_slam, enemy.gd apply_stun - Talon'un Yer Sarsıntısı
##   _skill_berserk() ile AYNI CC mekanizması).
## - Sprite'a hafif mor bir modulate uygulanıyor (bkz. GOLEM_TINT_COLOR,
##   "golem biraz mor tonlarında görünmeli oyunun içinde filtre eklersin").
##
## Multiplayer: skeleton_pet.gd/wraith_pet.gd ile AYNI desen - SADECE çağıran
## istemcide gerçek yapay zeka/hasar çalışır, diğer istemcilerde SADECE
## kozmetik bir kopya görünür. Farktan dolayı (bu Golem'in görünür bir can/
## kalkan barı olması) _broadcast_network_state() burada override edilip
## can/kalkan oranı da yayınlanıyor (bkz. update_network_golem_state,
## network_manager.gd broadcast_pet_state, remote_player.gd
## _update_pet_visual_state) - böylece diğer oyuncular da barın GERÇEK
## değerlerini görür, sadece boş/dolu sabit bir bar değil.

signal died

const ROW_DOWN := 0
const ROW_UP := 1
const ROW_LEFT := 2
const ROW_RIGHT := 3

## Kullanıcı isteği: "bu golemin görsel dosyası dosyaların içinde Golem 1
## adlı klasörde bulunuyor" - aynı asset zaten scenes/creatures/enemy_golem1.
## tscn'de bir düşman türü olarak kullanılıyor, hframes/vframes/cell_size/
## sprite_fps değerleri oradan (Golem1'in kendi atlas boyutları) alındı.
const WALK_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Golem 1/PNG/Golem1/With_shadow/Golem1_Walk_with_shadow.png")
const ATTACK_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Golem 1/PNG/Golem1/With_shadow/Golem1_Attack_with_shadow.png")
const DEATH_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Golem 1/PNG/Golem1/With_shadow/Golem1_Death_with_shadow.png")
## DÜZELTME (kullanıcı bildirimi: "golemin idle animasyonu eklenmemiş onu da
## ekle") - eskiden hareket yokken WALK_TEXTURE'ın 0. karesinde donuyordu,
## hiç ayrı bir "dur" animasyonu yoktu. Golem 1 klasöründe zaten kullanılmayan
## bir Golem1_Idle_with_shadow.png vardı (512x512 = 4 kare/satır, WALK'ın
## 8 kare/satırından FARKLI bir kare sayısı - bu yüzden kendi HFRAMES'i var).
const IDLE_TEXTURE: Texture2D = preload("res://visuals/Yaratıklar/Tüm Yaratıklar/Golem 1/PNG/Golem1/With_shadow/Golem1_Idle_with_shadow.png")
const HFRAMES := 8
const IDLE_HFRAMES := 4
const VFRAMES := 4
const CELL_SIZE := 128
const SPRITE_FPS := 11.4
## enemy_golem1.tscn'in kendi "speed" değeri - SPRITE_FPS aslında o hız için
## ayarlanmıştı (bkz. _advance_animation'daki DÜZELTME notu). Necromancer'ın
## golemi artık farklı bir hızda hareket edebildiği için yürüme animasyonu
## bu referansa göre ölçekleniyor.
const WALK_ANIM_REFERENCE_SPEED := 52.0

## Kullanıcı isteği: "golem biraz mor tonlarında görünmeli oyunun içinde
## filtre eklersin bunun için" - basit bir modulate çarpımı (skeleton_pet.gd'nin
## yeşil tonu ile AYNI yöntem), yeşili biraz kısıp maviyi/kırmızıyı artırarak
## hafif mor/eflatun bir görünüm veriyor.
const GOLEM_TINT_COLOR := Color(0.86, 0.62, 1.12, 1.0)

## Golem, İskelet'e göre çok daha büyük bir sprite'a sahip (128px hücre,
## enemy_golem1.tscn'deki ölçek/offset ile aynı) - menzil/mesafe sabitleri de
## buna göre büyütüldü.
const SEEK_RADIUS := 420.0
const MELEE_STOP_RANGE := 84.0
const MELEE_RESUME_CHASE_RANGE := 140.0
## bkz. _process_attack - kullanıcı isteği: "golemi yaratıklara saldırınca
## alan hasarı vermiyor tekli hasar veriyor". MELEE_STOP_RANGE'den (84,
## golemin durup saldırmaya başladığı mesafe) biraz geniş tutuldu ki
## odaklandığı hedefin hemen yanındaki yaratıklar da vurulsun.
const GOLEM_ATTACK_AOE_RADIUS := 110.0
## DÜZELTME (kullanıcı isteği, 2. tur ayarlama: "saldırı hızı azaltmasını
## %50 den %20 ye düşür") - İLK turda "%50 daha yavaş saldırır" isteği
## ATTACK_INTERVAL'i skeleton_pet.gd'nin tabanının (1.0sn) TAM 2 KATINA
## çıkararak uygulanmıştı (saldırı sıklığı yarıya iniyordu, yani aslında
## %100 yavaşlama - kullanıcının "%50" beklentisinden fazlaydı). Artık
## yavaşlama yüzdesi AÇIKÇA bir sabit olarak tutuluyor ve interval'e ek
## olarak uygulanıyor (interval = taban * (1 + yüzde)) - vuruş başına hasar
## (attack_power, zaten necro'nun statlarının %200'ü) DEĞİŞMEDİ, sadece
## saldırı SIKLIĞI eskisinden daha az yavaşlatılıyor.
const GOLEM_BASE_ATTACK_INTERVAL := 1.0 ## skeleton_pet.gd'nin ATTACK_INTERVAL'iyle AYNI taban
const GOLEM_ATTACK_SLOWDOWN_PERCENT := 0.20
const ATTACK_INTERVAL := GOLEM_BASE_ATTACK_INTERVAL * (1.0 + GOLEM_ATTACK_SLOWDOWN_PERCENT)
const FOLLOW_DISTANCE := 110.0
const CATCH_UP_DISTANCE := 320.0

## Kullanıcı isteği: "golem 6 saniyede bir yere vurarak çevresindeki
## yaratıkları 1 saniye sersemletir".
const GOLEM_SLAM_INTERVAL := 6.0
const GOLEM_SLAM_RADIUS := 160.0
const GOLEM_SLAM_STUN_DURATION := 1.0

## Kullanıcı isteği: "kalkanı da vardır" - kalkan kapasitesi Golem'in kendi
## (zaten %200'e çıkarılmış) canının bir oranı olarak belirleniyor. Hasar
## önce kalkana işler, kalkan biterse cana geçer (enemy.gd'nin item_shield
## sistemiyle AYNI mantık, sadece armor hesaplaması skeleton_pet.gd'nin
## basit sabit-çıkarma yöntemiyle uyumlu tutuldu).
const GOLEM_SHIELD_HP_RATIO := 0.5
const GOLEM_SHIELD_REGEN_DELAY := 10.0 ## saniye, hasarsız geçen süre sonunda kalkan yenilenmeye başlar
const GOLEM_SHIELD_REGEN_RATE := 0.03 ## saniyede, max kalkanın bu oranı kadar yenilenir

## overhead_bar.gd'nin varsayılan y_offset'i (-62) oyuncu sprite'ı için
## ayarlı - Golem'in çok daha büyük sprite'ı için çubuk yukarı çekildi (bkz.
## enemy_spawner.gd _attach_boss_bar / enemy.gd get_overhead_bar_offset ile
## AYNI gerekçe: büyük yaratıklarda çubuk kafanın çok üstünde durmalı).
const GOLEM_BAR_Y_OFFSET := -132.0

var max_health: float = 100.0
var health: float = 100.0
var speed: float = 120.0
var attack_power: float = 10.0 ## melee vuruş başına hasar (necro'nun saldırı gücünün %200'ü, bkz. setup_from_player)

## DÜZELTME (kullanıcı bildirimi: "necromancerin yaratıklarının collision
## shapei yok birbirlerinin içine giriyorlar girmemeleri gerek diğer
## yaratıklarla çarpışmalılar diğer herkes gibi") - bkz. skeleton_pet.gd'deki
## AYNI notun karşılığı. Yarıçap enemy_golem1.tscn'deki (aynı 128px hücreli,
## aynı sprite ölçeğindeki) düşman Golem'in gerçek CollisionShape2D
## yarıçapıyla (44.2) AYNI tutuldu.
var _body_radius: float = 44.2

var max_shield: float = 0.0
var shield: float = 0.0
var _shield_regen_delay: float = 0.0

var owner_player: Node2D = null
var is_dead: bool = false
var lifespan: float = 120.0

var facing: String = "down"
var _sprite_row: int = ROW_DOWN
var _frame_time: float = 0.0
var _attack_timer: float = 0.0
var _focus_target: Node2D = null
var _in_melee_stance: bool = false
var _incoming_dmg_timer: float = 0.0
var _slam_timer: float = GOLEM_SLAM_INTERVAL
var _animation_state: String = "idle"
var _animation_frame: int = 0
var _animation_elapsed: float = 0.0

## bkz. skeleton_pet.gd dosya başındaki "kozmetik kopya" notu - AYNI desen.
var network_instance_id: String = ""
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false

var _overhead_bar: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	## Kullanıcı isteği (bkz. EntityScale): tüm varlıklar gibi evcil hayvanlar da
	## %5 küçülür - görsel ve gövde çemberi orantılı.
	EntityScale.shrink(sprite, get_node_or_null("CollisionShape2D"))
	collision_layer = 0
	collision_mask = 0
	add_to_group("player_allies")
	if sprite:
		## Kullanıcı isteği: "golemin idle animasyonu eklenmemiş onu da ekle" -
		## Golem doğduğunda henüz hareket etmiyor, bu yüzden baştan IDLE
		## dokusuyla başlıyor (bkz. _advance_animation'daki "idle"/"walk"
		## geçişi).
		sprite.texture = IDLE_TEXTURE
		sprite.hframes = IDLE_HFRAMES
		sprite.vframes = VFRAMES
		sprite.modulate = GOLEM_TINT_COLOR
	_create_overhead_bar()


## Kullanıcı isteği: "can ve kalkan barı üstünde görünsün tıpkı diğer
## karakterlerinki gibi" - overhead_bar.gd (oyuncunun/bosların kullandığı
## AYNI komponent) doğrudan bu node'a çocuk olarak ekleniyor (bkz. enemy.gd
## _create_overhead_bar ile AYNI desen), ama boss'ların aksine burada HER
## ZAMAN görünür - hasarsız birkaç saniye sonra otomatik gizlenmiyor, çünkü
## kullanıcı isteği "diğer karakterlerinki gibi" (oyuncunun kendi barı hiç
## gizlenmiyor).
func _create_overhead_bar() -> void:
	if _overhead_bar and is_instance_valid(_overhead_bar):
		return
	_overhead_bar = Node2D.new()
	_overhead_bar.set_script(preload("res://scripts/overhead_bar.gd"))
	add_child(_overhead_bar)
	_overhead_bar.set_offset(GOLEM_BAR_Y_OFFSET)
	_overhead_bar.set_health(health, max_health)
	_overhead_bar.set_shield(shield, max_shield)
	_overhead_bar.visible = true


## stat_percent: hız/saldırı gücü/zırh gibi statların oranı (Golem için
## %200, bkz. player.gd NECRO_GOLEM_STAT_PERCENT). hp_percent: canın oranı
## (Golem için de %200 - "necromancerin statlarının %200üne sahiptir" canı
## da kapsıyor). Kalkan kapasitesi bu canın GOLEM_SHIELD_HP_RATIO'su olarak
## ayrıca hesaplanıyor (necro'nun kendi kalkanından bağımsız - "kalkanı da
## vardır" Golem'e ÖZGÜ yeni bir kalkan, necro'nunkinin kopyası değil).
## DÜZELTME (kullanıcı bildirimi: "necromancerin golemi aşırı hızlı hareket
## ediyor statlardan aldığı hareket hızı oranını %200 den %70e düşür") -
## hareket hızı artık stat_percent'ten (armor/attack_power hâlâ bunu
## kullanıyor, %200 aynı kalıyor) BAĞIMSIZ ayrı bir speed_percent
## parametresiyle ölçekleniyor (bkz. player.gd NECRO_GOLEM_SPEED_PERCENT).
## speed_percent verilmezse (-1.0, eski/harici çağrılarla geriye dönük
## uyumluluk) stat_percent'e geri düşer.
## Kullanıcı isteği: "Necromancerın goleminin saldırı gücü oranını %50 ile
## sabitle" - saldırı gücü de artık (speed_percent ile AYNI desen)
## stat_percent'ten BAĞIMSIZ, kendi attack_power_percent'ine göre hesaplanıyor
## (bkz. player.gd NECRO_GOLEM_ATTACK_POWER_PERCENT). Verilmezse (-1.0) yine
## stat_percent'e geri düşer.
func setup_from_player(player: Node, stat_percent: float, hp_percent: float, life: float, speed_percent: float = -1.0, attack_power_percent: float = -1.0) -> void:
	owner_player = player
	lifespan = life
	if "max_health" in player:
		max_health = max(1.0, float(player.max_health) * hp_percent)
	health = max_health
	var effective_speed_percent: float = speed_percent if speed_percent >= 0.0 else stat_percent
	if "speed" in player:
		speed = max(30.0, float(player.speed) * effective_speed_percent)
	## DÜZELTME (kullanıcı bildirimi: "necromancerın golemi orta oyun ve late
	## game de çok güçsüz ve gereksiz kalıyor") - eskiden hasar SADECE
	## damage_bonus'a (küçük, sabit bir "+X saldırı gücü" statı) bağlıydı;
	## oyunun asıl güç eksenine (dükkandan geliştirilen silah tier'ları,
	## bkz. player.gd owned_weapon_nodes) HİÇ bağlı değildi, bu yüzden oyuncu
	## silahlarını geliştirdikçe golem giderek daha alakasız kalıyordu.
	## Artık _skill_assasin_dash()'teki AYNI "tüm silahların toplam hasarı"
	## deseni kullanılıyor - golem artık oyuncunun gerçek silah gücüyle
	## birlikte ölçekleniyor. Hiç silahı yoksa (olmamalı, herkes artık kart
	## seçimiyle başlıyor) eski damage_bonus'a düşülüyor.
	var effective_attack_power_percent: float = attack_power_percent if attack_power_percent >= 0.0 else stat_percent
	var total_weapon_damage: float = 0.0
	if "owned_weapon_nodes" in player:
		for w in player.owned_weapon_nodes:
			if is_instance_valid(w) and "damage" in w:
				total_weapon_damage += float(w.get("damage"))
	if total_weapon_damage > 0.0:
		attack_power = max(1.0, total_weapon_damage * effective_attack_power_percent)
	elif "damage_bonus" in player:
		attack_power = max(1.0, float(player.damage_bonus) * effective_attack_power_percent)
	max_shield = max_health * GOLEM_SHIELD_HP_RATIO
	shield = max_shield
	if _overhead_bar and is_instance_valid(_overhead_bar):
		_overhead_bar.set_health(health, max_health)
		_overhead_bar.set_shield(shield, max_shield)


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
	_process_golem_slam(delta)
	_process_shield_regen(delta)
	_broadcast_network_state()


func _process(delta: float) -> void:
	_advance_animation(delta)


## bkz. skeleton_pet.gd'deki AYNI fonksiyon.
func mark_as_network_visual() -> void:
	_is_network_visual = true


## Eski (bar bilgisi olmayan) çağrılar için geriye dönük uyumluluk - şu an
## bu fonksiyon kullanılmıyor (bkz. update_network_golem_state) ama
## has_method("update_network_pet_state") ile genel kontrol yapan başka bir
## yer olursa diye (skeleton_pet.gd/wraith_pet.gd ile aynı arayüz) korunuyor.
func update_network_pet_state(pos: Vector2, is_attacking: bool) -> void:
	_network_target_position = pos
	_network_state_received = true
	if is_attacking:
		_play_attack_animation()


## network_manager.gd broadcast_pet_state RPC'sinin Golem'e özgü karşılığı -
## remote_player.gd _update_pet_visual_state() bu metodu (varsa) genel
## update_network_pet_state yerine tercih eder, çünkü can/kalkan oranını da
## taşıyor (bkz. dosya başı "Multiplayer" notu).
## bkz. skeleton_pet.gd update_network_pet_state üstündeki BUG DÜZELTMESİ
## notu - AYNI iki düzeltme burada da uygulandı (yön artık doğrudan
## yayınlanıyor, saldırı animasyonu sadece yükselen kenarda tetikleniyor).
var _last_network_is_attacking: bool = false

func update_network_golem_state(pos: Vector2, is_attacking: bool, health_ratio: float, shield_ratio: float, sprite_row: int = -1) -> void:
	_network_target_position = pos
	_network_state_received = true
	if sprite_row >= 0:
		_sprite_row = sprite_row
	if is_attacking and not _last_network_is_attacking:
		_play_attack_animation()
	_last_network_is_attacking = is_attacking
	if _overhead_bar and is_instance_valid(_overhead_bar):
		_overhead_bar.set_health(clamp(health_ratio, 0.0, 1.0) * 100.0, 100.0)
		_overhead_bar.set_shield(clamp(shield_ratio, 0.0, 1.0) * 100.0, 100.0)


func _process_network_visual(delta: float) -> void:
	if not _network_state_received:
		return
	## bkz. update_network_golem_state üstündeki BUG DÜZELTMESİ notu - yön
	## artık burada TAHMİN edilmiyor.
	var to_target: Vector2 = _network_target_position - global_position
	velocity = to_target if to_target.length() > 2.0 else Vector2.ZERO
	global_position = global_position.lerp(_network_target_position, min(1.0, delta * 12.0))


## bkz. skeleton_pet.gd'deki AYNI fonksiyon - tek fark, kalkan/can oranını da
## yayınlaması (bkz. dosya başı notu).
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("petpos_%s" % network_instance_id, 0.2):
		return
	var health_ratio: float = clamp(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	var shield_ratio: float = clamp(shield / max_shield, 0.0, 1.0) if max_shield > 0.0 else 0.0
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, _animation_state == "attack", health_ratio, shield_ratio, _sprite_row)


## DÜZELTME (kullanıcı bildirimi: "golem etrafında bir kaç düşman olunca
## olduğu yerde kalıyor") - eskiden ölene/menzil dışına çıkana kadar AYNI
## hedefe kilitleniyordu; birkaç yaratık birbirini iterken hedef 84-140px
## kararsızlık bandının sınırında ileri geri kaydıkça golem sürekli
## saldırı duruşu <-> kovalama arasında titreyip yerinde kalmış gibi
## görünebiliyordu. Artık HER karede gerçekten EN YAKIN yaratık aranıp
## hedef ona göre güncelleniyor - kalabalık ortada, golem her zaman en
## yakın tehdide yönelir (saldırı zaten alan hasarlı, bkz. _process_attack,
## bu yüzden hangi belirli hedefe kilitlendiği hasarı etkilemiyor, sadece
## hangi yöne yürüdüğünü etkiliyor).
func _update_focus_target() -> void:
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


## bkz. skeleton_pet.gd'deki BİREBİR AYNI fonksiyon/gerekçe ("oyuncuların
## yarattığı yaratıklar collision shapelerden geçebiliyor").
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


## Duvar dolanma (bkz. pet_router.gd) - hedefe/sahibine giden düz çizgiyi orman duvarı kesince A* rotası.
const PetRouterScript := preload("res://scripts/pet_router.gd")
## Sahibinden çok uzakta ve arada duvar varken rotayı bu hız çarpanıyla izler (ışınlanır gibi lerp duvardan geçirirdi).
const CATCH_UP_ROUTE_SPEED_MULT := 2.5
var _router = PetRouterScript.new()


func _process_movement(delta: float) -> void:
	## DÜZELTME: bkz. skeleton_pet.gd'deki AYNI notun karşılığı - ayrışma
	## itişi artık TÜM dallarda (saldırı/bekleme dahil) uygulanıyor.
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
		## bkz. skeleton_pet.gd'deki AYNI BUG DÜZELTMESİ notu ("bir anda
		## necromancerin yanına ışınlanıyor") - anlık atama yerine yumuşak
		## yakalama.
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


## bkz. skeleton_pet.gd'deki BİREBİR AYNI fonksiyonlar/gerekçe - Golem de hem
## diğer Necromancer yaratıklarından ("player_allies") hem de düşmanlardan
## ("enemies") aynı yumuşak mesafe mantığıyla itiliyor.
const PET_SEPARATION_GAP := 2.0
const PET_SEPARATION_CHECK_RADIUS := 100.0
const PET_SEPARATION_FORCE := 130.0

## DÜZELTME (kullanıcı isteği: "necromancerin yaratıkları diğer yaratıklar
## itemez, onlar da necromancerı itemez") - bkz. skeleton_pet.gd'deki AYNI
## düzeltme notu. "enemies" grubuna karşı itiş kaldırıldı.
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


## Kullanıcı isteği: "golemin idle animasyonu eklenmemiş onu da ekle" -
## hareket yokken artık WALK dokusunun 0. karesinde donmuyor, kendi
## IDLE_TEXTURE'ını (4 kare/satır) döngüde oynatıyor. "walk"/"idle" arası
## geçiş sadece durum GERÇEKTEN değiştiğinde dokuyu değiştiriyor (her karede
## gereksiz texture ataması yapmamak için).
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
			_set_locomotion_state("walk" if (velocity.length() > 0.1 and not _in_melee_stance) else "idle")
			_animation_elapsed = 0.0
		else:
			sprite.frame = _sprite_row * action_frames + min(int(_animation_elapsed * SPRITE_FPS), action_frames - 1)
			return
	## DÜZELTME (kullanıcı bildirimi: "golem diğer yaratıklara saldırabilirken
	## yani saldırı menzil içindeyken yürüme animasyonu göstermesin") -
	## _in_melee_stance (bkz. _process_movement) iken velocity SADECE
	## civardaki diğer yaratık/pet'lerin ayrışma itişinden geliyor (bkz.
	## _compute_pet_separation) - kalabalık bir savaşta bu itiş 0.1 eşiğini
	## sıkça aşıp golem yerinde dururken bile "yürüyormuş" gibi görünmesine
	## yol açıyordu. Saldırı menzilindeyken hareket velocity'den bağımsız
	## olarak HER ZAMAN idle sayılır.
	var moving: bool = velocity.length() > 0.1 and not _in_melee_stance
	_set_locomotion_state("walk" if moving else "idle")
	## DÜZELTME (kullanıcı bildirimi: "golemin yürüme animasyonunun hızının
	## yavaşlaması gerekiyor çünkü kendisi de çok yavaş"): SPRITE_FPS sabiti
	## enemy_golem1.tscn'den (bu yürüme dokusunun asıl sahibi, bkz. yukarıdaki
	## "Golem 1 klasöründen alındı" notu) o düşmanın KENDİ hızına (speed=52)
	## göre tutulmuştu. NECRO_GOLEM_SPEED_PERCENT %200'den %70'e düşürüldükten
	## sonra (player.gd) bu golem artık o referans hızdan belirgin şekilde
	## yavaş/farklı hareket edebiliyor ama bacak animasyonu hep AYNI sabit
	## hızda oynayıp golem yerinde kayıyormuş gibi görünüyordu. Artık kare
	## hızı golemin O ANKİ gerçek hareket hızına (speed) oranlanıyor.
	var walk_fps: float = SPRITE_FPS
	if moving and WALK_ANIM_REFERENCE_SPEED > 0.0:
		walk_fps = clamp(SPRITE_FPS * (speed / WALK_ANIM_REFERENCE_SPEED), 2.0, SPRITE_FPS)
	_frame_time += delta * walk_fps
	var frames: int = HFRAMES if moving else IDLE_HFRAMES
	sprite.frame = _sprite_row * frames + (int(_frame_time) % frames)


## bkz. _advance_animation - "walk"/"idle" arasında dokuyu (ve kare sayısını)
## sadece durum gerçekten değiştiğinde günceller.
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
	if _animation_state == "attack":
		return
	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	if not _focus_target or not is_instance_valid(_focus_target) or _focus_target.get("is_dead") == true:
		return
	if global_position.distance_to(_focus_target.global_position) > MELEE_STOP_RANGE + 6.0:
		return
	_attack_timer = ATTACK_INTERVAL
	_play_attack_animation()
	## DÜZELTME (kullanıcı bildirimi: "necromancerin golemi yaratıklara
	## saldırınca alan hasarı vermiyor tekli hasar veriyor") - eskiden SADECE
	## _focus_target'a hasar veriyordu. Golem büyük/ağır bir yakın dövüşçü
	## (bkz. 6sn'de bir uyguladığı GOLEM_SLAM_RADIUS'lu alan sersemletmesi ile
	## AYNI ruh) - normal saldırısı da artık GOLEM_ATTACK_AOE_RADIUS içindeki
	## TÜM yaratıklara birden vuruyor, tek bir hedefe kilitli kalmıyor.
	## Kullanıcı isteği: "bütün yetenekler kritik vuruş yapabilir" - Golem'i
	## çağıran Necromancer'ın kritik statlarını kullanıyor; TÜM alan hasarı
	## tek bir ortak kritik zarına bağlı (diğer alan yeteneklerindeki - Don
	## Nova/Meteor - AYNI desen, her hedef ayrı zar atmıyor).
	var is_crit: bool = false
	var dmg: float = attack_power
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("_roll_ability_crit"):
		is_crit = owner_player._roll_ability_crit()
		dmg = owner_player._apply_ability_crit(dmg, is_crit)
	var spark_scene: PackedScene = load("res://scenes/fx_hit_mini_spark.tscn")
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) > GOLEM_ATTACK_AOE_RADIUS:
			continue
		if e.has_method("take_damage"):
			e.take_damage(dmg, is_crit)
		# Saldırdığına dair mor kıvılcım efekti (Golem'in mor tonuyla uyumlu)
		if spark_scene:
			var spark := spark_scene.instantiate() as Node2D
			get_tree().current_scene.add_child(spark)
			spark.global_position = e.global_position
			spark.modulate = Color(0.75, 0.5, 1.0) # Mor kıvılcım


## Kullanıcı isteği: "golem 6 saniyede bir yere vurarak çevresindeki
## yaratıkları 1 saniye sersemletir" - Talon'un Yer Sarsıntısı
## (player.gd _skill_berserk/TALON_SLAM_RADIUS) ile AYNI enemy.gd apply_stun
## mekanizması, sadece bu periyodik ve otomatik (savaş durumundan bağımsız,
## Golem hayatta olduğu sürece 6 saniyede bir tetiklenir).
func _process_golem_slam(delta: float) -> void:
	_slam_timer -= delta
	if _slam_timer > 0.0:
		return
	_slam_timer = GOLEM_SLAM_INTERVAL
	## DÜZELTME (kullanıcı bildirimi: "necromancerın golemi bazen etrafta
	## yaratık olmasa bile yere saldırıyor") - bu periyodik yer vuruşu
	## KOŞULSUZDU: 6 saniyede bir menzilde hiç yaratık olmasa da saldırı
	## animasyonunu ve mor patlama efektini oynatıyordu. Artık menzilde
	## (GOLEM_SLAM_RADIUS) en az bir canlı yaratık yoksa hiçbir görsel/efekt
	## tetiklenmiyor - golem sadece gerçekten vuracağı bir şey varken "saldırı"
	## gösteriyor.
	var any_target_in_range: bool = false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) <= GOLEM_SLAM_RADIUS:
			any_target_in_range = true
			if e.has_method("apply_stun"):
				e.apply_stun(GOLEM_SLAM_STUN_DURATION)
	if not any_target_in_range:
		return
	## DÜZELTME (kullanıcı bildirimi: "necromancerin golemi 6 saniyede bir
	## sersemleme skilini attığında saldırı animasyonunu yapmıyor") - bu
	## periyodik yer vuruşu, normal yakın dövüş saldırısının (bkz.
	## _process_attack) aksine _play_attack_animation() hiç çağırmıyordu,
	## golem sersemletirken/patlama efekti çıkarken sprite'ı hangi
	## durumdaysa (yürüme/bekleme) onda donuk kalıyordu.
	_play_attack_animation()
	var burst_scene: PackedScene = load("res://scenes/fx_hit_big_burst.tscn")
	if burst_scene:
		var burst := burst_scene.instantiate() as Node2D
		get_tree().current_scene.add_child(burst)
		burst.global_position = global_position
		burst.modulate = Color(0.8, 0.55, 1.05) # Mor patlama


## enemy.gd sadece "player" grubunu hedef aldığı için (bkz. skeleton_pet.gd
## dosya başı notu) bu müttefiğin GERÇEKTEN hasar alabilmesi için kendi
## yakınındaki yaratıkları kendisi tarar.
const INCOMING_CONTACT_RANGE := 60.0
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


## Kullanıcı isteği: "kalkanı da vardır" - hasar önce kalkana işler (tamamı,
## enemy.gd'nin shield_protection oranlı kısmi emme sisteminden farklı olarak
## burada basitlik için TAMAMEN emiyor, tıpkı klasik bir "kalkan" gibi),
## kalkan biterse kalan hasar cana geçer.
func take_damage(amount: float, _source: Node2D = null) -> void:
	if is_dead or amount <= 0.0:
		return
	var reduced: float = max(amount, 1.0)
	if max_shield > 0.0 and shield > 0.0:
		var absorbed: float = min(shield, reduced)
		shield -= absorbed
		reduced -= absorbed
		_shield_regen_delay = GOLEM_SHIELD_REGEN_DELAY
		if _overhead_bar and is_instance_valid(_overhead_bar):
			_overhead_bar.set_shield(shield, max_shield)
	if reduced <= 0.0:
		return
	health -= reduced
	if _overhead_bar and is_instance_valid(_overhead_bar):
		_overhead_bar.set_health(health, max_health)
	if health <= 0.0:
		_die()


## bkz. take_damage üstündeki not - enemy.gd'nin item shield yenilenme
## deseniyle AYNI (uzun bir hasarsız bekleme, sonra yavaş yenilenme).
func _process_shield_regen(delta: float) -> void:
	if max_shield <= 0.0 or shield >= max_shield:
		return
	if _shield_regen_delay > 0.0:
		_shield_regen_delay -= delta
		return
	shield = min(max_shield, shield + max_shield * GOLEM_SHIELD_REGEN_RATE * delta)
	if _overhead_bar and is_instance_valid(_overhead_bar):
		_overhead_bar.set_shield(shield, max_shield)


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
		sprite.modulate = GOLEM_TINT_COLOR
	if _overhead_bar and is_instance_valid(_overhead_bar):
		_overhead_bar.visible = false


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	_play_death_animation()
