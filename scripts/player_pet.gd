extends CharacterBody2D

## Matthew's companion creature (see player.gd's _passive_matthew /
## _spawn_matthew_pet). Follows the player, and melees whatever enemy strays
## closest to MATTHEW (not to itself) - see _pick_focus_target(). Reports its
## death via the "died" signal so the player can start its 30s respawn timer
## (also used when Matthew sacrifices it for his "Feda Kalkanı" active).
## Also the generic "player_ally" the other new characters (Oakley's heal) can
## target - added to that group by whoever spawns it.
##
## Kullanıcı isteği: pet ÖLÜMSÜZ olmalı ve yakın dövüşçü olmalı, yaratıklar
## onu görmezden gelmeli. Buna göre:
## - can/kalkan HASAR sistemi tamamen kaldırıldı: take_damage() artık no-op
##   (savunma amaçlı - hiçbir yoldan cana/kalkana dokunmuyor), hurt animasyonu
##   ve overhead can/kalkan barı yok.
## - enemy.gd (_on_hit_area_body_entered) ve enemy_projectile.gd artık pet'i
##   "player_ally" grubunda bulsa da HEDEF/TEMAS olarak hiç işlemiyor - yani
##   yaratıklar onu tamamen görmezden geliyor, ona asla saldırmıyor.
## - eskiden uzaktan (projectile ile) saldırıyordu, artık yakın dövüşçü:
##   Matthew'a FOCUS_RADIUS içine giren en yakın yaratığa koşup MELEE_RANGE'e
##   girince doğrudan hasar veriyor.
## - health/max_health SADECE Matthew'in "Feda Kalkanı" ultisinin kalkan
##   boyutunu belirlemek için bir stat olarak kalıyor (bkz. player.gd'nin
##   _skill_shield_dome'u - _matthew_pet.health okuyor). Pet asla hasar
##   almadığı için health hep max_health'e eşit kalır.

signal died

var max_health: float = 50.0
var health: float = 50.0
var speed: float = 150.0 ## flavor stat only - see _process_movement, which never lets it fall behind

const BASE_DAMAGE := 12.0
## Matthew'a (sahibine) bu mesafe içine giren yaratıklara focus atar - "ona
## yakın olan ve ona saldırmak üzere olan yaratıklara focus atmalı" (kullanıcı
## isteği). Kendi konumuna göre değil, SAHİBİNİN konumuna göre ölçülüyor.
## Eskiden 260.0 idi - kullanıcı bildirimi ("çok yavaş, yaratıklara
## saldıramıyor koşmaktan") üzerine daha da sıkılaştırıldı: artık sadece
## Matthew'a GERÇEKTEN yakın (yakında ona saldıracak) yaratıklara odaklanıyor,
## uzaktaki bir yaratığın peşinden koşup yetişememesi engelleniyor.
const FOCUS_RADIUS := 170.0
## Yakın dövüş menzili - bu mesafenin altına inince saldırmaya başlar.
const MELEE_RANGE := 34.0
## Hedefe koşarken (savaş modunda) normal takip hızından daha hızlı gider -
## kullanıcı isteği: pet artık yaratıklara yetişip saldırabilsin diye.
## Eskiden 1.6 idi - "hâlâ yetişemiyor" bildirimi üzerine arttırıldı.
const COMBAT_SPEED_MULT := 2.2
## Kullanıcı isteği: "tilki önüne doğru 180 derece alan hasarı versin" -
## saldırı artık tek hedefe değil, hedefe olan yönü merkez alan yarım
## dairelik bir alana (bkz. _do_cone_attack) hasar veriyor. Yarıçap
## MELEE_RANGE'den biraz geniş tutuldu ki yakın kümelenen yaratıklar da
## isabet alsın.
const ATTACK_RADIUS := 60.0
const ATTACK_ARC_DEG := 180.0
## Efekt olarak Uzunkılıç'ın savuruş animasyonu kullanılıyor ama turuncu
## tonda (bkz. fx_matthew_pet_slash.tscn modulate) - kullanıcı isteği.
const SlashFxScene := preload("res://scenes/fx_matthew_pet_slash.tscn")
const ATTACK_INTERVAL := 1.0
const FOLLOW_DISTANCE := 90.0 ## hedefi yokken sahibe bu kadar yakın durur
## Eskiden 260.0 idi - kullanıcı bildirimi "Matthew'i düzgün takip edemiyor,
## çok geride kalıyor" üzerine düşürüldü, bu sınıra ulaşınca artık daha
## çabuk (görünmez şekilde) sahibin yanına ışınlanıyor.
const CATCH_UP_DISTANCE := 220.0
## Sahip FOLLOW_DISTANCE dışına çıkar çıkmaz anında peşinden gitmesin diye -
## kısa bir tepki gecikmesi (bkz. _process_follow) daha gerçekçi bir "fark
## edip sonra harekete geçen" evcil hayvan hissi verir. Eskiden 0.5sn idi -
## "geride kalıyor" bildirimi üzerine kısaltıldı, artık daha çabuk tepki verir.
const FOLLOW_REACTION_DELAY := 0.2
## Sahibi takip ederken sahibin KENDİ hızından daha yavaş gitmez, DAHA HIZLI
## gider - eşit hızla asla kapanmayan (sabit) bir mesafe farkı yerine,
## gerçekten arayı kapatıp yanına gelebilsin diye (kullanıcı isteği: "2
## [saniye/adım] geride bekliyor, düzgün takip edemiyor").
const FOLLOW_SPEED_MULT := 1.45
var _follow_delay_timer: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

## Tilki (fox) görseli 4 yönlü (down/up/left/right), her biri idle/walk/run/
## death animasyonlarına sahip - bkz. assets/pets/fox/fox_frames.tres. (hurt
## animasyonu artık hiç oynatılmıyor - pet hasar almıyor.)
var facing: String = "down"
## Sahibi çok uzaktaysa (CATCH_UP_DISTANCE'a yakın) "run", normal takip
## mesafesindeyse "walk", durgunken "idle" oynar.
const RUN_SPEED_THRESHOLD := 170.0
## death_<facing> animasyonunun oynaması için gereken süre (6 kare / 7 fps).
const DEATH_ANIM_DURATION := 0.9

var owner_player: Node2D = null
var is_dead: bool = false
var _attack_timer: float = 0.0
var _speed_line_timer: float = 0.0
const FxSpeedLineScene := preload("res://scenes/fx_speed_line.tscn")
## Matthew'a en yakın yaratık - bkz. _pick_focus_target(). FOCUS_RADIUS
## dışına çıkarsa veya ölürse otomatik bırakılıp yeniden seçilir.
var _focus_target: Node2D = null

## Oakley's active heal-over-time tail (see set_temp_heal_regen) - tracks its
## own source/range every frame so it correctly stops healing if the caster
## moves out of range mid-effect, per "menzil dışına çıkarsa iyileşmez". Pet
## artık hasar almadığı için pratikte hep max_health'te tavan yapar, ama
## zararsız - olduğu gibi bırakıldı.
var _temp_regen_rate: float = 0.0
var _temp_regen_timer: float = 0.0
var _temp_regen_source: Node2D = null
var _temp_regen_range: float = 0.0

## Multiplayer: kozmetik kopya bu SCRIPT'in aynısını taşıyor ve owner_player
## hiç set edilmiyor - bu yüzden _pick_focus_target() (owner_player'a bağlı)
## VE _process_follow() (yine owner_player'a bağlı) ikisi de no-op kalıp
## kozmetik tilki diğer oyuncuların ekranında doğduğu yerde SONSUZA KADAR
## hareketsiz duruyordu (Matthew'in gerçek tilkisi ise sahibini takip edip
## savaşırken). _is_network_visual ile artık kendi (zaten çalışmayan) yapay
## zekası yerine gerçek pet'in yayınladığı konuma yumuşakça kayıyor.
var network_instance_id: String = ""
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false
var _matthew_shield_form: bool = false
var _matthew_shield_owner: Node2D = null
const MATTHEW_SHIELD_ARRIVAL_DISTANCE := 18.0


func _ready() -> void:
	## Kullanıcı isteği (bkz. EntityScale): tüm varlıklar gibi evcil hayvanlar da
	## %5 küçülür - görsel ve gövde çemberi orantılı.
	EntityScale.shrink(anim, get_node_or_null("CollisionShape2D"))
	## Kullanıcı isteği: yaratıklar onu tamamen görmezden gelsin - hiçbir
	## Area/Body onu artık fiziksel olarak algılamıyor.
	collision_layer = 0
	collision_mask = 0
	if anim:
		anim.play("idle_" + facing)


## Called once right after spawning (see player.gd's _spawn_matthew_pet).
func setup_from_player(player: Node) -> void:
	owner_player = player
	if "max_health" in player:
		max_health = player.max_health * 0.5
	health = max_health
	if "speed" in player:
		## Eskiden 0.5 (yarım hız) idi, sonra 0.75 - kullanıcı bildirimleri
		## ("çok yavaş, yaratıklara saldıramıyor" ve "Matthew'i düzgün takip
		## edemiyor") üzerine oyuncu hızından bile hızlı yapıldı. Savaşırken
		## (bkz. _process_movement) buna ayrıca COMBAT_SPEED_MULT de biniyor.
		speed = player.speed * 1.1


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if _matthew_shield_form:
		_process_matthew_shield_form(delta)
		return
	if _is_network_visual:
		_process_network_visual(delta)
		return
	_update_focus_target()
	_process_movement(delta)
	_process_attack(delta)
	_process_temp_regen(delta)
	_update_animation()
	_broadcast_network_state()

	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("is_skill2_active") and owner_player.has_method("get_skill2_id"):
		if owner_player.is_skill2_active() and owner_player.get_skill2_id() == 21 and velocity.length() > 20.0:
			_speed_line_timer -= delta
			if _speed_line_timer <= 0.0:
				_speed_line_timer = 0.05
				_spawn_speed_line(velocity)


## bkz. yukarıdaki _is_network_visual sınıf üstü notu.
func begin_matthew_shield_form(owner: Node2D) -> void:
	_matthew_shield_form = true
	_matthew_shield_owner = owner
	_focus_target = null
	_in_melee_stance = false
	if anim:
		anim.visible = true


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "oyuncuların yarattığı
## yaratıklar (... ve matthew'in tilkisi) collision shapelerden geçebiliyor")
## - bkz. skeleton_pet.gd/golem_pet.gd'deki BİREBİR AYNI fonksiyon/gerekçe.
func _block_movement_into_terrain() -> void:
	if velocity.length() < 0.1:
		return
	var probe_dist: float = 10.0
	if velocity.x != 0.0:
		var probe_x: Vector2 = global_position + Vector2(sign(velocity.x) * probe_dist, 0.0)
		if GameManager.is_position_blocked_by_terrain(probe_x):
			velocity.x = 0.0
	if velocity.y != 0.0:
		var probe_y: Vector2 = global_position + Vector2(0.0, sign(velocity.y) * probe_dist)
		if GameManager.is_position_blocked_by_terrain(probe_y):
			velocity.y = 0.0


func _process_matthew_shield_form(delta: float) -> void:
	if not _matthew_shield_owner or not is_instance_valid(_matthew_shield_owner):
		return
	var to_owner: Vector2 = _matthew_shield_owner.global_position - global_position
	if to_owner.length() > MATTHEW_SHIELD_ARRIVAL_DISTANCE:
		velocity = to_owner.normalized() * speed * COMBAT_SPEED_MULT * 1.35
		_block_movement_into_terrain()
		move_and_slide()
		_update_facing(to_owner)
		if anim and anim.animation != "run_" + facing:
			anim.play("run_" + facing)
	else:
		velocity = Vector2.ZERO
		global_position = _matthew_shield_owner.global_position
		if anim:
			anim.visible = false


func end_matthew_shield_form() -> void:
	_matthew_shield_form = false
	_matthew_shield_owner = null
	velocity = Vector2.ZERO
	if owner_player and is_instance_valid(owner_player):
		global_position = owner_player.global_position + Vector2(48.0, 0.0)
	if anim:
		anim.visible = true
		anim.play("idle_" + facing)


func mark_as_network_visual() -> void:
	_is_network_visual = true


## network_manager.gd broadcast_pet_state RPC'sinin çağırdığı karşılık.
## DÜZELTME (kullanıcı bildirimi: "diğer oyuncular matthewin tilkisini ve
## animasyonunu efektini göremiyor") - remote_player.gd _update_pet_visual_
## state() bu fonksiyonu 3 argümanla (sprite_row dahil) çağırıyordu ama imza
## sadece 2 kabul ediyordu ("too many arguments" - bkz. skeleton_pet.gd'deki
## AYNI düzeltmenin karşılığı). Çağrı sessizce başarısız olduğu için
## _network_target_position/_network_state_received HİÇBİR ZAMAN set
## edilmiyordu - tilki diğer oyuncularda spawn noktasında sonsuza dek
## hareketsiz/idle kalıyordu.
func update_network_pet_state(pos: Vector2, _is_attacking: bool, _sprite_row: int = -1) -> void:
	_network_target_position = pos
	_network_state_received = true


## Kozmetik kopyanın fizik adımı: kendi (zaten owner_player'sız çalışmayan)
## takip/savaş mantığı yerine gerçek tilkinin bildirdiği konuma kayar.
func _process_network_visual(delta: float) -> void:
	if not _network_state_received:
		velocity = Vector2.ZERO
		_update_animation()
		return
	var to_target: Vector2 = _network_target_position - global_position
	if to_target.length() > 2.0:
		# _update_animation() walk/run eşiğini velocity BÜYÜKLÜĞÜNE göre
		# seçtiği için burada gerçek bir hız değeri kullanılıyor (ham
		# mesafe vektörü değil) - yoksa uzaktaki bir hedefe kısa bir anlık
		# kayarken yanlışlıkla hep "run" animasyonu tetiklenirdi.
		velocity = to_target.normalized() * speed
		_update_facing(to_target)
	else:
		velocity = Vector2.ZERO
	global_position = global_position.lerp(_network_target_position, min(1.0, delta * 12.0))
	_update_animation()


## Sadece GERÇEK tilki çalıştırır - konumunu diğer istemcilere periyodik
## yayınlar (bkz. network_manager.gd broadcast_pet_state).
## DÜZELTME: relay flood/kick riskini azaltmak için (bkz. skeleton_pet.gd'
## deki aynı düzeltmenin üstündeki ayrıntılı not) yayın aralığı arttırıldı -
## Matthew'in tilkisi tek olduğu için etkisi küçük ama tutarlılık için aynı
## enemy pozisyon senkronu aralığına (0.15sn) çekildi.
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("petpos_%s" % network_instance_id, 0.15):
		return
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, false)


## Matthew'a (sahibine) EN YAKIN, FOCUS_RADIUS içindeki yaratığı seçer -
## pet'in kendi konumuna göre değil. Mevcut hedef hâlâ geçerliyse (ölmediyse
## ve hâlâ Matthew'a yakınsa) değiştirmiyor, gereksiz hedef atlamasını önler.
func _update_focus_target() -> void:
	if _focus_target and is_instance_valid(_focus_target) and _focus_target.get("is_dead") != true:
		if owner_player and is_instance_valid(owner_player) and owner_player.global_position.distance_to(_focus_target.global_position) <= FOCUS_RADIUS:
			return
	_focus_target = _pick_focus_target()


func _pick_focus_target() -> Node2D:
	if not owner_player or not is_instance_valid(owner_player):
		return null
	var nearest: Node2D = null
	var nearest_dist: float = FOCUS_RADIUS
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = owner_player.global_position.distance_to(e.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest


## Menzile girip duracağı mesafe ile TEKRAR koşmaya başlayacağı mesafe
## FARKLI (histerezis) - aksi halde tam sınırda (MELEE_RANGE civarında)
## hedef veya pet ufak bir titreşimle ileri geri gidip gelirse, DUR/KOŞ
## durumu her karede yer değiştirip "glitch" gibi görünen bir titremeye yol
## açıyordu - kullanıcı bildirimi "hayvan saldırırken bazen glitchleniyor",
## özellikle COMBAT_SPEED_MULT'un yüksek olmasıyla (hızlı gidip aniden
## durma/tekrar fırlama) çok daha belirgindi.
const MELEE_STOP_RANGE := MELEE_RANGE
const MELEE_RESUME_CHASE_RANGE := MELEE_RANGE * 1.6
var _in_melee_stance: bool = false


## Hedefi varsa ona koşup yakın dövüş menziline girince durur; yoksa eskisi
## gibi sahibi takip eder (bkz. _process_follow).
func _process_movement(delta: float) -> void:
	if _focus_target and is_instance_valid(_focus_target):
		var to_target: Vector2 = _focus_target.global_position - global_position
		var dist: float = to_target.length()
		if _in_melee_stance:
			if dist > MELEE_RESUME_CHASE_RANGE:
				_in_melee_stance = false
		else:
			if dist <= MELEE_STOP_RANGE:
				_in_melee_stance = true
		if not _in_melee_stance:
			## Savaş modunda (bir hedefe koşarken) normal takip hızından daha
			## hızlı - bkz. COMBAT_SPEED_MULT sınıf üstü yorumu.
			velocity = to_target.normalized() * speed * COMBAT_SPEED_MULT * _get_speed_mult()
			_block_movement_into_terrain()
			move_and_slide()
			_update_facing(to_target)
		else:
			velocity = Vector2.ZERO
		return
	_in_melee_stance = false
	_process_follow(delta)


func _process_follow(delta: float) -> void:
	if not owner_player or not is_instance_valid(owner_player):
		return
	var to_owner: Vector2 = owner_player.global_position - global_position
	var dist: float = to_owner.length()
	if dist > CATCH_UP_DISTANCE:
		## bkz. skeleton_pet.gd/golem_pet.gd'deki AYNI BUG DÜZELTMESİ notu
		## ("bir anda ... yanına ışınlanıyor") - anlık atama yerine yumuşak
		## yakalama.
		var catch_up_target: Vector2 = owner_player.global_position - to_owner.normalized() * FOLLOW_DISTANCE
		global_position = global_position.lerp(catch_up_target, min(1.0, delta * 6.0))
		velocity = Vector2.ZERO
		_follow_delay_timer = 0.0
		return
	if dist > FOLLOW_DISTANCE:
		## Sahip yeni yeni uzaklaşmaya başladıysa hemen atılmaz - kısa bir
		## süre "fark etme" gecikmesi yaşar, sonra peşinden gider.
		_follow_delay_timer += delta
		if _follow_delay_timer < FOLLOW_REACTION_DELAY:
			velocity = Vector2.ZERO
			return
		## Sahibin hızıyla BİREBİR aynı hızda gitmek, aradaki farkı asla
		## kapatamaz (sabit bir mesafede sonsuza dek "geride" kalır) - bkz.
		## FOLLOW_SPEED_MULT sınıf üstü yorumu. Bu yüzden sahibinden HER ZAMAN
		## belirgin şekilde daha hızlı gidip gerçekten yanına ulaşabiliyor.
		var base_follow_speed: float = owner_player.speed if "speed" in owner_player else speed
		var follow_speed: float = base_follow_speed * FOLLOW_SPEED_MULT * _get_speed_mult()
		velocity = to_owner.normalized() * follow_speed
		_block_movement_into_terrain()
		move_and_slide()
		_update_facing(to_owner)
	else:
		velocity = Vector2.ZERO
		_follow_delay_timer = 0.0


## Same axis-dominance logic as player.gd's _update_facing - keeps the last
## facing while idle instead of flickering on tiny diagonal drift.
func _update_facing(direction: Vector2) -> void:
	if direction.length() < 0.1:
		return
	var ax: float = abs(direction.x)
	var ay: float = abs(direction.y)
	if ax > ay * 1.3:
		facing = "right" if direction.x > 0 else "left"
	elif ay > ax * 1.3:
		facing = "up" if direction.y < 0 else "down"


## Tilki hareket ettiği anda koşu animasyonu kullanır. Takip/savaş hızları
## oyuncunun ölçeğine ve statlarına göre değişebildiği için sabit hız eşiği
## kullanmak, görsel olarak hızlı giden tilkinin yanlışlıkla walk oynamasına
## neden oluyordu. Artık hareket = run, hareketsiz = idle.
func _update_animation() -> void:
	if not anim:
		return
	var current: String = String(anim.animation)
	if current.begins_with("death") and anim.is_playing():
		return
	var prefix: String = "idle_"
	if velocity.length() > 0.1:
		prefix = "run_"
	var target_anim: String = prefix + facing
	if anim.animation != target_anim:
		anim.play(target_anim)


func _process_attack(delta: float) -> void:
	_attack_timer -= delta * _get_attack_speed_mult()
	if _attack_timer > 0.0:
		return
	## DÜZELTME (kullanıcı bildirimi: "Shopta kalkan baloncuğunun içinde
	## silahlar ateş etmesin") - Matthew'in tilkisi hiçbir zaman _necro_
	## active_pets'e kaydedilmiyordu (bkz. player.gd _spawn_matthew_pet), bu
	## yüzden set_combat_active()'in devre dışı bıraktığı silahların/necro
	## yaratıklarının aksine, Matthew seyyar satıcının güvenli bölgesine
	## girse BİLE saldırmaya devam ediyordu - totem_base.gd _process()'teki
	## AYNI kontrol.
	if is_instance_valid(owner_player) and owner_player.get("is_in_merchant_zone") == true:
		return
	if not _focus_target or not is_instance_valid(_focus_target) or _focus_target.get("is_dead") == true:
		return
	var to_target: Vector2 = _focus_target.global_position - global_position
	if to_target.length() > MELEE_RANGE:
		return
	_attack_timer = ATTACK_INTERVAL
	var attack_dir: Vector2 = to_target.normalized() if to_target.length() > 0.1 else Vector2.DOWN
	_do_cone_attack(attack_dir)
	_spawn_slash_fx(attack_dir)


## Önüne doğru (attack_dir merkezli) 180 derecelik bir alandaki TÜM
## yaratıklara hasar verir - bkz. ATTACK_RADIUS/ATTACK_ARC_DEG sınıf üstü
## yorumu. DÜZELTME (kullanıcı bildirimi: "matthewin tilkisinin fazladan 1
## tane kocaman bir saldırı efekti var onu kaldır"): her isabet ayrıca
## Pençe silahının (fx_pence_slash.tscn) darbe efektini de spawnluyordu -
## bu küçük tilkiye göre orantısız büyük görünüyordu ve zaten _process_
## attack()'ın çağırdığı _spawn_slash_fx() (fx_matthew_pet_slash.tscn,
## tilkiye özel) ile üst üste biniyordu. Artık SADECE hasar veriliyor.
func _do_cone_attack(attack_dir: Vector2) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var to_enemy: Vector2 = e.global_position - global_position
		var dist: float = to_enemy.length()
		if dist > ATTACK_RADIUS:
			continue
		if dist > 0.1:
			var angle: float = abs(attack_dir.angle_to(to_enemy.normalized()))
			if angle > deg_to_rad(ATTACK_ARC_DEG * 0.5):
				continue
		if e.has_method("take_damage"):
			e.take_damage(BASE_DAMAGE)


func _spawn_slash_fx(attack_dir: Vector2) -> void:
	var fx: Node2D = SlashFxScene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	fx.global_position = global_position + attack_dir * (ATTACK_RADIUS * 0.5)
	fx.rotation = attack_dir.angle()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = min(max_health, health + amount)


## Oakley's active: a flat rate that only actually heals while _temp_regen_source
## stays within _temp_regen_range - see _process_temp_regen.
func set_temp_heal_regen(rate: float, duration: float, source: Node2D, max_range: float) -> void:
	_temp_regen_rate = rate
	_temp_regen_timer = duration
	_temp_regen_source = source
	_temp_regen_range = max_range


func _process_temp_regen(delta: float) -> void:
	if _temp_regen_timer <= 0.0:
		return
	_temp_regen_timer -= delta
	if _temp_regen_source and is_instance_valid(_temp_regen_source):
		if global_position.distance_to(_temp_regen_source.global_position) <= _temp_regen_range:
			heal(_temp_regen_rate * delta)


## Kullanıcı isteği: "pet ölümsüz olmalı" - hiçbir hasar kaynağından
## etkilenmiyor (no-op, savunma amaçlı bırakıldı - normalde artık hiçbir
## düşman sistemi bunu çağırmıyor bile, bkz. yukarıdaki dosya notu).
func take_damage(_amount: float, _source: Node2D = null) -> void:
	pass


func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	died.emit()
	## Sahibin 30sn'lik yeniden doğma sayacı "died" sinyaliyle hemen başlar -
	## ama görsel olarak death_<facing> animasyonu bitene kadar sahnede kalıp
	## sonra kaybolur (queue_free bekletilir).
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("death_" + facing):
		anim.play("death_" + facing)
		get_tree().create_timer(DEATH_ANIM_DURATION).timeout.connect(func(): if is_instance_valid(self): queue_free())
	else:
		queue_free()


func _get_speed_mult() -> float:
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("is_skill2_active") and owner_player.has_method("get_skill2_id"):
		if owner_player.is_skill2_active() and owner_player.get_skill2_id() == 21:
			return 1.15
	return 1.0


func _get_attack_speed_mult() -> float:
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("is_skill2_active") and owner_player.has_method("get_skill2_id"):
		if owner_player.is_skill2_active() and owner_player.get_skill2_id() == 21:
			return 1.40
	return 1.0


func _spawn_speed_line(dir: Vector2) -> void:
	if not FxSpeedLineScene:
		return
	var fx := FxSpeedLineScene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	var offset := Vector2(randf_range(-4.0, 4.0), randf_range(-6.0, 6.0))
	fx.global_position = global_position + offset
	fx.setup(dir, Color(1.0, 0.75, 0.15, 0.75))

