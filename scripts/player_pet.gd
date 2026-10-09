extends CharacterBody2D

## Yaratık aday sorgusu (yeni yolda C++ ızgarası, eski yolda tüm "enemies" grubu; süzgeçler çağıranda aynen kalır).
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

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
## - health/max_health artık hiçbir şeyi belirlemiyor (2026-09-28: Feda Kalkanı saldırı gücünden, tilki hedef alınamaz,
##   bkz. FOX_STAT_RATIO). Pet asla hasar almaz.

signal died

var max_health: float = 50.0
var health: float = 50.0
var speed: float = 150.0 ## flavor stat only - see _process_movement, which never lets it fall behind

const BASE_DAMAGE := 12.0 ## sadece sahip yoksa (yedek)
## Kullanıcı isteği (2026-09-28): "tilkinin statları da düzenlensin artık hedef alınamaz bir varlık olduğu için sadece
## matthewin saldırı gücü saldırı hızı kritik v.b gibi saldırı odaklı güçlerinin %200'üne sahip olmasını istiyorum" -
## tilkinin savunma statı yok (hedef alınamaz; Feda Kalkanı da artık saldırı gücünden hesaplanıyor), saldırısı her
## vuruşta Matthew'in O ANKİ statlarından okunur (kart/eşya aldıkça tilki de güçlenir):
##   hasar        = Matthew saldırı gücü (damage_bonus) x FOX_STAT_RATIO
##   saldırı hızı = Matthew'in saldırı hızı BONUSU x FOX_STAT_RATIO (ör. Matthew +%20 -> tilki +%40); Vahşi Hız (E) ayrıca
##   kritik şansı = Matthew'in yetenek kritik şansı (taban %5 + kart) x FOX_STAT_RATIO (en fazla %100)
##   kritik hasar = Matthew'in kritik hasar çarpanı (taban 1.5 + kart) x FOX_STAT_RATIO
const FOX_STAT_RATIO := 2.0
## Matthew'a (sahibine) bu mesafe içine giren yaratıklara focus atar - "ona yakın olan ve ona saldırmak üzere olan yaratıklara
## focus atmalı" (kullanıcı isteği). Kendi konumuna göre değil, SAHİBİNİN konumuna göre ölçülüyor.
## 2026-10-08: 170 -> 240 ("çevresindeki yaratıklara saldırması gerekiyordu"; eski değer sahibine neredeyse dokunana kadar bekletiyordu).
const FOCUS_RADIUS := 240.0
## Savaşta bile sahibinden bu kadar uzaklaşmaz: hedef bu halkanın dışına çıkarsa bırakılır (uzak yaratığın peşinde kaybolmasın).
const LEASH_RADIUS := 360.0
const RETARGET_INTERVAL := 0.25 ## yeni akın için yaratık taraması aralığı
## AKIN (sortie) - kullanıcı 2026-10-08: "silahlarım yakına gelenleri hemen öldürdüğü için köpek hemen hedef değiştirmek zorunda kalıyor; gittiği
## yönde kararlı bir şekilde yaratık öldürüp sonra gelsin, sürekli zigzag çizerek kararsızca hedef aramasın". Köpek tek yaratığın değil bir
## YÖNÜN peşine düşer: en yoğun yön seçilir, o yönün konisinde yaratık bitene kadar (ölen hedefin yerine AYNI koniden köpeğe en yakın) saldırır, sonra
## sahibine döner; yeni akın için bekleme + sahibin yanında toplanma gerekir (bkz. _update_focus_target).
const SORTIE_SECTOR_HALF_DEG := 55.0 ## akının konisi: seçilen yönün +- bu kadarı
const SORTIE_PICK_HALF_DEG := 45.0 ## yön seçerken pencere yarı açısı
const SORTIE_PICK_WINDOWS := 12 ## yön penceresi sayısı (30 derecede bir)
const SORTIE_ALWAYS_RADIUS := 45.0 ## sahibe bu kadar yakın yaratık her zaman konide sayılır
const SORTIE_END_EMPTY := 1.0 ## konide bu kadar sn yaratık yoksa akın biter
const SORTIE_MAX := 9.0 ## bu süre dolunca en yoğun yön değiştiyse akın biter (aynı yöndeyse sürer, bkz. _update_sortie)
const SORTIE_SAME_DIR_DEG := 60.0 ## "aynı yön" sayılan en büyük sapma
const SORTIE_COOLDOWN := 1.0 ## akın bittikten sonra yenisi için bekleme
const SORTIE_REGROUP_RADIUS := 120.0 ## yeni akın için köpek sahibine bu kadar yakın olmalı (önce geri döner)
const SORTIE_PICK_INTERVAL := 0.1 ## akın içinde hedefsizken yeniden bakış aralığı
## Yakın dövüş menzili - bu mesafenin altına inince saldırmaya başlar.
const MELEE_RANGE := 34.0
const ATTACK_REACH_SLACK := 10.0 ## durma menzilinde ufak oynamalar ısırmayı kaçırmasın
## Hedefe koşarken (savaş modunda) normal takip hızından daha hızlı gider (kullanıcı isteği: pet yaratıklara yetişip saldırabilsin).
const COMBAT_SPEED_MULT := 2.2
const CHASE_SLOW_ZONE := 90.0 ## hedefe bu kadar kala yavaşlamaya başlar (fırlama/titreme olmasın)
## Kullanıcı isteği: "tilki önüne doğru 180 derece alan hasarı versin" - saldırı artık tek hedefe değil, hedefe olan yönü merkez
## alan yarım dairelik bir alana (bkz. _do_cone_attack) hasar veriyor. Yarıçap MELEE_RANGE'den biraz geniş tutuldu ki yakın
## kümelenen yaratıklar da isabet alsın.
const ATTACK_RADIUS := 60.0
const ATTACK_ARC_DEG := 180.0
## Kullanıcı isteği (2026-09-23): "oto saldırılarına özel pixel tarzda bir slash-pençe tarzı bir saldırı efekti hazırla" - eskiden Pençe
## silahının slash_frames.tres'i turuncu tonlanmış olarak yeniden kullanılıyordu (bkz. fx_matthew_claw_slash.gd dosya üstü notu), artık
## kendi özel PixelDraw çizimi var.
const SlashFxScene := preload("res://scenes/fx_matthew_claw_slash.tscn")
const ATTACK_INTERVAL := 1.0
## ---- Takip (topuk noktası) - bkz. "HEDEF SEÇİMİ + TAKİP + SAVAŞ" notu
const HEEL_BEHIND := 54.0 ## sahibin hareket yönünün ARKASINDA
const HEEL_SIDE := 30.0 ## ve yanında
const HEEL_IDLE_RADIUS := 20.0 ## sahip duruyorsa topuk noktasına bu kadar yaklaşınca durur
const HEEL_RESUME_RADIUS := 64.0 ## sahip duruyorken bu kadar uzaklaşırsa (ittirilme vb.) tekrar yürür (histerezis)
const HEEL_GAIN := 4.5 ## hata (px) başına hız (px/sn): yaklaştıkça yumuşakça yavaşlar
const FOLLOW_SPEED_CAP_MULT := 1.6 ## takipte en çok sahibin hızının bu kadar katı (yakalama)
const OWNER_MOVING_SPEED := 25.0 ## sahibin bu hızın üstü "yürüyor" sayılır
const HEADING_SMOOTH := 5.0 ## yön süzgeci (1/sn): sahip kıvrılırken topuk noktası zıplamasın
const ACCEL := 2600.0 ## px/sn^2: hız bu ivmeyle değişir (ani sıçrama yok)
const WARP_DISTANCE := 480.0 ## bu kadar uzakta topuk noktasına atlar (ışınlanma, ev girişi)
const STUCK_WARP_SECONDS := 1.5
## Animasyon eşikleri (px/sn): bunun altı idle, WALK_SPEED_MAX altı walk, üstü run (histerezisli, bkz. _update_animation).
const IDLE_SPEED_MIN := 12.0
const WALK_SPEED_MAX := 130.0
## Kozmetik kopya (bkz. _process_network_visual)
const NET_FOLLOW_GAIN := 6.0
const NET_SLIDE_MIN_SPEED := 24.0 ## ağ hızı bunun altındaysa hedef durmuş sayılır
const NET_SLIDE_RANGE := 28.0 ## bu kadar yakın geri düzeltmeler hız vermeden kaydırılır
const NET_FACING_MIN_SPEED := 50.0 ## duruş anındaki küçük aşmalar bakış yönünü çevirmesin (iki süreçli denetimde görüldü)
const NET_ACCEL := 4000.0
const NET_SNAP_DISTANCE := 260.0
var _heading: Vector2 = Vector2.DOWN
var _heel_active: bool = false
var _retarget_cd: float = 0.0
var _sortie_active: bool = false
var _sortie_dir: Vector2 = Vector2.ZERO
var _sortie_t: float = 0.0
var _sortie_empty_t: float = 0.0
var _sortie_cooldown: float = 0.0
var _stuck_t: float = 0.0
var _stuck_sample_t: float = 0.0
var _stuck_ref: Vector2 = Vector2.ZERO
var _ignored_id: int = 0
var _ignored_until_ms: int = 0
var _bite_left: float = 0.0
var _anim_hold: float = 0.0
var _speed_smooth: float = 0.0
const ANIM_HOLD := 0.14 ## idle/walk/run türü en az bu kadar sürer (titreme yok)
const SPEED_SMOOTH_RATE := 9.0 ## animasyon hızı süzgeci (1/sn)
var _net_velocity: Vector2 = Vector2.ZERO
var _net_last_ms: int = 0
var _net_last_dir: Vector2 = Vector2.ZERO

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


## Köpek sayfasında GÖMÜLÜ gölge yok (tilki sayfasında vardı): karakterlerle AYNI piksel elips ayak gölgesi (ground_shadow.gd). Köpek
## küçük olduğu için yarıçap küçük; y = ayak çizgisi (sprite ofseti + %5 küçültme sonrası).
const SHADOW_RADIUS := Vector2(10.5, 3.6)
const SHADOW_Y := 9.5


func _ready() -> void:
	GroundShadow.apply_to(get_node_or_null("Shadow") as Node2D, {"ground_shadow": SHADOW_RADIUS, "ground_shadow_y": SHADOW_Y})
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
	## (2026-09-28: can artık Matthew'den türemiyor - tilki hedef alınamaz, bkz. FOX_STAT_RATIO notu.)
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
	_bite_left = maxf(0.0, _bite_left - delta)
	_anim_hold = maxf(0.0, _anim_hold - delta)
	_speed_smooth = lerpf(_speed_smooth, velocity.length(), minf(1.0, delta * SPEED_SMOOTH_RATE))
	if _matthew_shield_form:
		_process_matthew_shield_form(delta)
		return
	if _is_network_visual:
		_process_network_visual(delta)
		return
	if _dash_strike_active:
		## bkz. begin_dash_strike() - player.gd _matthew_fox_dash_sequence() tilkiyi dash_to() ile yönetiyor.
		## Periyodik konum yayını bu sırada BİLEREK yapılmıyor: dash_to() varış noktasını kendisi yayınlıyor,
		## ara konumlar gönderilseydi kozmetik kopya kendi dash'ini bitirince eski bir ara noktaya geri kayardı.
		return
	_update_focus_target(delta)
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
	_stop_dash()
	_matthew_shield_form = true
	_matthew_shield_owner = owner
	_focus_target = null
	_sortie_active = false
	_in_melee_stance = false
	_set_body_visible(true)


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
		_set_body_visible(false)


func end_matthew_shield_form() -> void:
	_matthew_shield_form = false
	_matthew_shield_owner = null
	velocity = Vector2.ZERO
	if owner_player and is_instance_valid(owner_player):
		global_position = owner_player.global_position + Vector2(48.0, 0.0)
	_set_body_visible(true)
	if anim:
		anim.play("idle_" + facing)


## Sprite + ayak gölgesi birlikte gizlenir/gösterilir (Feda Kalkanı formunda köpek sahibe girip kaybolur).
func _set_body_visible(v: bool) -> void:
	if anim:
		anim.visible = v
	var sh: CanvasItem = get_node_or_null("Shadow") as CanvasItem
	if sh:
		sh.visible = v


func mark_as_network_visual() -> void:
	_is_network_visual = true


## network_manager.gd broadcast_pet_state RPC'sinin çağırdığı karşılık.
## DÜZELTME (kullanıcı bildirimi: "diğer oyuncular matthewin tilkisini ve animasyonunu efektini göremiyor") - remote_player.gd
## _update_pet_visual_state() bu fonksiyonu sprite_row dahil çağırıyordu ama imza kabul etmiyordu (bkz. skeleton_pet.gd'deki AYNI düzeltme).
## "dash" true ise (ağdaki adı hâlâ "teleport" - bkz. network_manager.gd broadcast_pet_state) gerçek köpek Köpek Hücumu'nda ya da
## topuk noktasına atlayışta pos'a gitti demektir: kozmetik kopya yumuşak kaymak yerine AYNI dash_to() görselini oynatır.
## 2026-10-08: "is_attacking" true ise gerçek köpek ISIRDI; sprite_row = bakış yönü dizini (FACINGS) -> kopya aynı yöne dönüp aynı
## ısırma klibini oynatır (kaster doğru görür, diğerleri görmez hata sınıfı).
const FACINGS := ["down", "left", "right", "up"]


func update_network_pet_state(pos: Vector2, is_attacking: bool, sprite_row: int = -1, dash: bool = false) -> void:
	## Gelen konumlar arasındaki hızdan "ağ hızı" çıkarılır (kopya ona göre AKAR; eskiden her paketten sonra üstel yaklaşma
	## hız dalgalanması yaratıp walk/run klibini titretiyordu).
	var now_ms: int = Time.get_ticks_msec()
	if _net_last_ms > 0 and not dash:
		var dt: float = float(now_ms - _net_last_ms) / 1000.0
		if dt > 0.03 and dt < 1.0:
			var step: Vector2 = pos - _network_target_position
			## Durmuş paket (konum değişmedi): ileri besleme hızı HEMEN sıfırlanır - yavaş sönerse kopya hedefi aşıp geri geri yürüyordu
			## (iki süreçli denetim + test_matthew_dog: duruşta 17 px aşma, bakış sola dönüyordu).
			_net_velocity = Vector2.ZERO if step.length() < 1.0 else _net_velocity.lerp(step / dt, 0.6)
			if _net_velocity.length() > NET_SLIDE_MIN_SPEED:
				_net_last_dir = _net_velocity.normalized()
	elif dash:
		_net_velocity = Vector2.ZERO
	_net_last_ms = now_ms
	_network_target_position = pos
	_network_state_received = true
	if dash:
		dash_to(pos)
	elif is_attacking:
		if sprite_row >= 0 and sprite_row < FACINGS.size():
			facing = FACINGS[sprite_row]
		_play_bite()


## Kozmetik kopyanın fizik adımı: kendi (zaten çalışmayan) yapay zekası yerine gerçek köpeğin bildirdiği konumu AKARAK izler
## (ağ hızı + konum hatasıyla orantılı düzeltme); animasyon gerçek hızdan seçilir.
func _process_network_visual(delta: float) -> void:
	if _dash_moving:
		return ## dash_to()'nun tween'i konumu ve "run" klibini yönetiyor
	if not _network_state_received:
		velocity = Vector2.ZERO
		_update_animation()
		return
	var to_target: Vector2 = _network_target_position - global_position
	if to_target.length() > NET_SNAP_DISTANCE:
		global_position = _network_target_position ## geç katılan / çok uzak: anında yerine
		velocity = Vector2.ZERO
	else:
		var desired: Vector2 = _net_velocity + to_target * NET_FOLLOW_GAIN
		if to_target.length() < 6.0 and _net_velocity.length() < IDLE_SPEED_MIN * 2.0:
			desired = Vector2.ZERO
		if to_target.length() < NET_SLIDE_RANGE and _net_velocity.length() < NET_SLIDE_MIN_SPEED and to_target.dot(_net_last_dir) < 0.0:
			## Hedef durdu ve kopya onu (tahmin yüzünden) az aştı: geri geri yürümek yerine hız/klip OLMADAN yumuşakça yerine kay.
			desired = Vector2.ZERO
			global_position = global_position.lerp(_network_target_position, minf(1.0, delta * 10.0))
		velocity = velocity.move_toward(desired, NET_ACCEL * delta)
		global_position += velocity * delta
		if velocity.length() > NET_FACING_MIN_SPEED and _bite_left <= 0.0:
			_update_facing(velocity)
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
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, false, -1.0, -1.0, -1, false)


## ---------- Tilki Hücumu dash görseli (kullanıcı isteği 2026-09-23) ----------
## "tilki dash atarken arkasında dash çizgisi olmalı ve tilkinin arkasında kendi görüntüsü gibi parça parça
## izler olmalı". Önceki sürüm tilkiyi hedefler arasında IŞINLIYORDU - görünür bir hareket yoktu, iz ve
## hayaletler ışınlanma anında hepsi birden, statik şekilde beliriyordu. Artık tilki kısa bir tween ile
## GERÇEKTEN hedefe atılıyor; hareket sürerken arkasında hız çizgileri (fx_matthew_dash_lines.gd, tilkinin
## çocuğu) duruyor ve yol boyunca aralıklarla kendi o anki karesinin sönen kopyalarını bırakıyor
## (fx_matthew_fox_afterimage.gd). Hem gerçek tilki hem kozmetik kopya bu AYNI fonksiyonu çalıştırır.
const DASH_HOP_TIME := 0.09
const DASH_AFTERIMAGE_INTERVAL := 0.02
const FoxAfterimageScene := preload("res://scenes/fx_matthew_fox_afterimage.tscn")
const DashLinesScript := preload("res://scripts/fx_matthew_dash_lines.gd")
var _dash_tween: Tween = null
var _dash_moving: bool = false
var _afterimage_timer: float = 0.0
var _dash_lines: Node2D = null


func dash_to(dest: Vector2) -> void:
	var travel: Vector2 = dest - global_position
	if travel.length() > 0.5:
		_update_facing(travel)
	_set_body_visible(true)
	if anim:
		anim.play("run_" + facing)
	if _dash_tween and _dash_tween.is_valid():
		_dash_tween.kill()
	velocity = Vector2.ZERO
	_dash_moving = true
	_afterimage_timer = DASH_AFTERIMAGE_INTERVAL
	_spawn_afterimage()
	if not is_instance_valid(_dash_lines):
		_dash_lines = DashLinesScript.new()
		add_child(_dash_lines)
		move_child(_dash_lines, 0) ## AnimatedSprite2D'den önce çizilsin = gövdenin arkasında
	_dash_lines.call("start", travel)
	_dash_tween = create_tween()
	_dash_tween.tween_property(self, "global_position", dest, DASH_HOP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_tween.finished.connect(_on_dash_finished)
	## Gerçek tilki varış noktasını anında yayınlar - kozmetik kopyalar aynı dash'i kendileri oynatır.
	if not _is_network_visual and NetworkManager.is_multiplayer_active and not network_instance_id.is_empty():
		NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, dest, false, -1.0, -1.0, -1, true)


func _on_dash_finished() -> void:
	_dash_moving = false
	if is_instance_valid(_dash_lines):
		_dash_lines.call("stop")


func _stop_dash() -> void:
	if _dash_tween and _dash_tween.is_valid():
		_dash_tween.kill()
	_on_dash_finished()


func _process(delta: float) -> void:
	if not _dash_moving:
		return
	_afterimage_timer -= delta
	if _afterimage_timer <= 0.0:
		_afterimage_timer = DASH_AFTERIMAGE_INTERVAL
		_spawn_afterimage()


func _spawn_afterimage() -> void:
	if not anim or not is_inside_tree():
		return
	var ghost: Sprite2D = FoxAfterimageScene.instantiate() as Sprite2D
	get_tree().current_scene.add_child(ghost)
	ghost.global_position = anim.global_position
	ghost.call("setup", anim)


## Matthew'in Tilki Hücumu (Q, bkz. player.gd _matthew_fox_dash_sequence) sırasında tilkiyi kendi normal
## takip/savaş yapay zekasından (_update_focus_target/_process_movement/_process_attack) ÇIKARIR - o
## coroutine konumu/yönü/animasyonu elle (her dash sıçramasında) kontrol ederken ikisi ÇAKIŞMASIN diye
## (bkz. _matthew_shield_form ile AYNI "askıya al" deseni, _physics_process'teki erken dönüş).
var _dash_strike_active: bool = false


func begin_dash_strike() -> void:
	_bite_left = 0.0
	_dash_strike_active = true
	_focus_target = null
	_sortie_active = false
	_in_melee_stance = false
	velocity = Vector2.ZERO


func end_dash_strike() -> void:
	_stop_dash()
	_dash_strike_active = false


## ================================================================================================================
## HEDEF SEÇİMİ + TAKİP + SAVAŞ (2026-10-08 BAŞTAN YAZILDI)
## Kullanıcı: "yeni köpeğin hareket anlayışını değiştir, çok bugluydu tilkiyken. Matthewi takip etmesi, onun çevresindeki
## yaratıklara saldırması gerekiyordu. takip anlayışı çok tuhaf". Eski davranışın sorunları (kodda ölçüldü/okundu):
##  - sahibe 90 px kala DURUR, sahip her adımda bu çemberin dışına çıkıp 0,2 sn bekletme + yeniden kalkışla DUR-KALK yapardı;
##  - 220 px'te "yumuşak yakalama" = hız 0 + lerp ile KAYARDI (koşu klibi yok, ışınlanma gibi);
##  - savaş duruşunda durup hedefe DÖNMEDEN ısırırdı (bakış yönü sadece hareket ederken güncelleniyordu), hedefe anlık hız
##    değişimiyle fırlayıp durur (titreme/ters tepme), uzaktaki hedefe takılıp sahibini bırakırdı;
##  - hedef seçimi sadece hedef ÖLÜNCE yenilenirdi: sahibe dokunan yaratık varken uzaktaki eskisinin peşinde koşardı.
## Yeni model:
##  1) TAKİP = "topuk noktası": sahibin hareket yönünün ARKASINDA ve yanında sabit bir nokta (HEEL_*). Hedef hız = sahibin hızı
##     (ileri besleme) + hataya orantılı düzeltme -> sahip yürürken köpek DURMADAN onunla akar, sahip durunca yumuşakça yavaşlayıp
##     durur. Durma/kalkma eşikleri farklı (histerezis). Hız ivmeyle değişir (ACCEL) -> ani dönüş/fırlama yok.
##  2) SAVAŞ = AKIN (sortie, bkz. SORTIE_* sabitleri; 2026-10-08 ikinci tur: "silahlarım yakındakileri öldürüyor, köpek zigzag çizerek hedef arıyor"):
##     sahibin FOCUS_RADIUS'undaki en YOĞUN yön seçilir, köpek o yönün konisinde YAPIŞKAN hedeflerle (ölünce aynı koniden köpeğe en yakın) saldırır,
##     koni boşalınca / tasma aşılınca / süre dolunca sahibine döner. Hedefe yaklaşırken yavaşlar, durunca hedefe DÖNER ve ısırır.
##  3) Çok uzakta (ışınlanma/ev girişi/Hadime vb.) ya da sıkışmışsa (haritada engele takıldı) topuk noktasına atlar.
func _focus_target_ok() -> bool:
	return is_instance_valid(_focus_target) and _focus_target.get("is_dead") != true


func _update_focus_target(delta: float) -> void:
	_sortie_cooldown = maxf(0.0, _sortie_cooldown - delta)
	if not is_instance_valid(_focus_target) or not _focus_target_ok():
		_focus_target = null
	if not _owner_ok():
		return
	if owner_player.get("is_in_merchant_zone") == true:
		_end_sortie(0.0) ## güvenli bölgede kovalamaz
		return
	if _sortie_active:
		_update_sortie(delta)
		return
	## Akın dışında (sahibin yanında): bekleme bitmiş, köpek sahibinin yanına toplanmış ve yakında yaratık varsa YENİ akın başlat.
	_retarget_cd -= delta
	if _retarget_cd > 0.0 or _sortie_cooldown > 0.0:
		return
	_retarget_cd = RETARGET_INTERVAL
	if global_position.distance_to(owner_player.global_position) > SORTIE_REGROUP_RADIUS:
		return
	var dir: Vector2 = _choose_sortie_dir()
	if dir == Vector2.ZERO:
		return
	_sortie_active = true
	_sortie_dir = dir
	_sortie_t = 0.0
	_sortie_empty_t = 0.0
	_focus_target = _pick_sortie_target()


## Akın sürerken: hedef YAPIŞKAN (ölene / koniden çıkana / tasma dışına kadar değişmez); ölünce AYNI koniden köpeğe en yakın yaratığa geçer;
## koni SORTIE_END_EMPTY sn boş kalırsa, akın SORTIE_MAX sn'yi geçerse ya da köpek sahibinden LEASH_RADIUS uzaklaşırsa akın biter (geri dönüş).
func _update_sortie(delta: float) -> void:
	_sortie_t += delta
	if global_position.distance_to(owner_player.global_position) > LEASH_RADIUS:
		_end_sortie(SORTIE_COOLDOWN)
		return
	if _sortie_t >= SORTIE_MAX:
		## Süre doldu: en yoğun yön hâlâ AYNI yöndeyse (yaratık akışı o taraftan sürüyor) akın kesilmeden sürer - sahibine dönüp aynı yöne
		## yeniden çıkmak anlamsız bir ters dönüş olurdu; yön değiştiyse dönüp yeni akın başlatılır.
		var nd: Vector2 = _choose_sortie_dir()
		if nd == Vector2.ZERO or absf(_sortie_dir.angle_to(nd)) > deg_to_rad(SORTIE_SAME_DIR_DEG):
			_end_sortie(SORTIE_COOLDOWN)
			return
		_sortie_t = 0.0
	if _focus_target_ok() and _in_sortie_sector(_focus_target):
		_sortie_empty_t = 0.0
		return
	_focus_target = null
	_retarget_cd -= delta
	if _retarget_cd <= 0.0:
		_retarget_cd = SORTIE_PICK_INTERVAL
		_focus_target = _pick_sortie_target()
	if _focus_target != null:
		_sortie_empty_t = 0.0
		return
	_sortie_empty_t += delta
	if _sortie_empty_t >= SORTIE_END_EMPTY:
		_end_sortie(SORTIE_COOLDOWN)


func _end_sortie(cooldown: float) -> void:
	_sortie_active = false
	_focus_target = null
	_in_melee_stance = false
	_sortie_cooldown = cooldown
	_retarget_cd = 0.0


## Yaratık, akının konisinde mi? Sahibin 45 px içindekiler (sahibe dokunanlar) her zaman; diğerleri tasma içinde ve akın yönünün +-SORTIE_SECTOR_HALF_DEG'inde.
func _in_sortie_sector(e: Node2D) -> bool:
	var v: Vector2 = e.global_position - owner_player.global_position
	var d: float = v.length()
	if d > LEASH_RADIUS:
		return false
	if d < SORTIE_ALWAYS_RADIUS:
		return true
	return absf(_sortie_dir.angle_to(v)) <= deg_to_rad(SORTIE_SECTOR_HALF_DEG)


## Akının hedefi: konideki canlı yaratıklardan KÖPEĞE en yakın (sahibe değil: köpek koni içinde ileri doğru ilerler, sahibin silahları
## yakındakileri öldürdükçe geri sahibe dönmez). Sıkışıp bırakılan hedef kısa süre yok sayılır.
func _pick_sortie_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	var now_ms: int = Time.get_ticks_msec()
	for e in EnemyQueryScript.candidates(get_tree(), owner_player.global_position, LEASH_RADIUS + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if _ignored_id == e.get_instance_id() and now_ms < _ignored_until_ms:
			continue
		if not _in_sortie_sector(e):
			continue
		var d: float = global_position.distance_squared_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Akın yönü: sahibin FOCUS_RADIUS'undaki yaratıkların en YOĞUN yönü (12 pencere, her biri +-SORTIE_PICK_HALF_DEG; eşitlikte en yakın olan).
## Dönen vektör penceredeki yaratıkların birim yönlerinin ortalaması; yaratık yoksa Vector2.ZERO. Böylece köpek tek bir yaratığın rastgele
## yönüne değil, vuracak en çok şey olan yöne gider ve oraya bağlı kalır.
func _choose_sortie_dir() -> Vector2:
	var o: Vector2 = owner_player.global_position
	var vs: Array[Vector2] = []
	var now_ms: int = Time.get_ticks_msec()
	for e in EnemyQueryScript.candidates(get_tree(), o, FOCUS_RADIUS + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if _ignored_id == e.get_instance_id() and now_ms < _ignored_until_ms:
			continue
		var v: Vector2 = e.global_position - o
		if v.length() <= FOCUS_RADIUS:
			vs.append(v)
	if vs.is_empty():
		return Vector2.ZERO
	var best_score: float = -INF
	var best_dir: Vector2 = Vector2.ZERO
	for i in range(SORTIE_PICK_WINDOWS):
		var center: float = TAU * float(i) / float(SORTIE_PICK_WINDOWS)
		var sum: Vector2 = Vector2.ZERO
		var cnt: int = 0
		var nearest: float = INF
		for v in vs:
			if absf(angle_difference(center, v.angle())) <= deg_to_rad(SORTIE_PICK_HALF_DEG):
				sum += v.normalized()
				cnt += 1
				nearest = minf(nearest, v.length())
		if cnt == 0:
			continue
		var score: float = float(cnt) * 1000.0 - nearest
		if score > best_score:
			best_score = score
			best_dir = sum.normalized() if sum.length() > 0.01 else Vector2.from_angle(center)
	return best_dir


## Menzile girip duracağı mesafe ile TEKRAR koşmaya başlayacağı mesafe FARKLI (histerezis) - aksi halde tam sınırda hedef ya da
## pet ufak titreşse DUR/KOŞ her karede yer değiştirip "glitch" gibi görünürdü (kullanıcı bildirimi "hayvan saldırırken bazen glitchleniyor").
const MELEE_STOP_RANGE := MELEE_RANGE
const MELEE_RESUME_CHASE_RANGE := MELEE_RANGE * 1.6
var _in_melee_stance: bool = false


func _owner_velocity() -> Vector2:
	if _owner_ok() and "velocity" in owner_player:
		return owner_player.get("velocity") as Vector2
	return Vector2.ZERO


## Köpeğin taban hızı: sahibin O ANKİ hızı x1,1 (kart/eşya hız alınca köpek geride kalmasın); sahip yoksa kurulumdaki değer.
func _base_speed() -> float:
	if _owner_ok() and "speed" in owner_player:
		return float(owner_player.get("speed")) * 1.1
	return speed


func _process_movement(delta: float) -> void:
	var desired: Vector2 = Vector2.ZERO
	if _focus_target_ok():
		desired = _chase_velocity(_focus_target)
	else:
		_in_melee_stance = false
		desired = _follow_velocity(delta)
	## Hız ivmeyle değişir: ani yön/hız sıçraması (titreme, fırlama, ters tepme) olmaz.
	velocity = velocity.move_toward(desired, ACCEL * delta)
	if velocity.length() > 1.0:
		_block_movement_into_terrain()
		move_and_slide()
		if not _in_melee_stance and velocity.length() > IDLE_SPEED_MIN:
			_update_facing(velocity)
	_check_stuck(delta, desired.length() > 80.0)


## Hedefe koş, yaklaşırken yavaşla, menzile girince dur ve hedefe dön (ısırma _process_attack'ta).
func _chase_velocity(tgt: Node2D) -> Vector2:
	var to_t: Vector2 = tgt.global_position - global_position
	var dist: float = to_t.length()
	if _in_melee_stance:
		if dist > MELEE_RESUME_CHASE_RANGE:
			_in_melee_stance = false
	elif dist <= MELEE_STOP_RANGE:
		_in_melee_stance = true
	if _in_melee_stance:
		_update_facing(to_t)
		return Vector2.ZERO
	var spd: float = _base_speed() * COMBAT_SPEED_MULT * _get_speed_mult()
	spd *= clampf((dist - MELEE_STOP_RANGE * 0.5) / CHASE_SLOW_ZONE, 0.35, 1.0)
	return to_t.normalized() * spd


## Takip: sahibin arkasındaki yan "topuk noktası"na ileri besleme + orantılı düzeltmeyle akar (bkz. yukarıdaki model notu).
func _follow_velocity(delta: float) -> Vector2:
	if not _owner_ok():
		return Vector2.ZERO
	var o: Vector2 = owner_player.global_position
	if global_position.distance_to(o) > WARP_DISTANCE:
		_warp_to_heel()
		return Vector2.ZERO
	var ov: Vector2 = _owner_velocity()
	var owner_moving: bool = ov.length() > OWNER_MOVING_SPEED
	if owner_moving:
		_heading = _heading.lerp(ov.normalized(), minf(1.0, delta * HEADING_SMOOTH))
		_heading = _heading.normalized() if _heading.length() > 0.05 else ov.normalized()
	var err: Vector2 = _heel_point() - global_position
	var d: float = err.length()
	if _heel_active:
		if not owner_moving and d < HEEL_IDLE_RADIUS:
			_heel_active = false
	elif owner_moving or d > HEEL_RESUME_RADIUS:
		_heel_active = true
	if not _heel_active:
		return Vector2.ZERO
	var v: Vector2 = (ov if owner_moving else Vector2.ZERO) + err * HEEL_GAIN
	var cap: float = _base_speed() * FOLLOW_SPEED_CAP_MULT * _get_speed_mult()
	return v.limit_length(cap)


## Topuk noktası: sahibin hareket yönünün arkası + yan (sahibin tam önüne/üstüne basmasın). Engelin içindeyse sahibin kendi konumu.
func _heel_point() -> Vector2:
	var o: Vector2 = owner_player.global_position
	var p: Vector2 = o - _heading * HEEL_BEHIND + _heading.orthogonal() * HEEL_SIDE
	if GameManager.is_position_blocked_by_terrain(p):
		return o
	return p


## Çok uzaktaki (ışınlanma/ev girişi) ya da sıkışmış köpeği topuk noktasına atlatır; kozmetik kopyalar AYNI atlayışı alır (teleport bayrağı).
func _warp_to_heel() -> void:
	if not _owner_ok():
		return
	var dest: Vector2 = _heel_point()
	global_position = dest
	velocity = Vector2.ZERO
	_heel_active = false
	_stuck_t = 0.0
	if not _is_network_visual and NetworkManager.is_multiplayer_active and not network_instance_id.is_empty():
		NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, dest, false, -1.0, -1.0, -1, true)


## Gitmek istediği halde 0,5 sn'de 14 px'ten az ilerliyorsa "sıkışık" sayar; STUCK_WARP_SECONDS sürerse: savaşta o hedefi 3 sn
## bırakır (yola dönsün), takipte sahibe uzaksa topuk noktasına atlar.
func _check_stuck(delta: float, wants_move: bool) -> void:
	_stuck_sample_t += delta
	if _stuck_sample_t < 0.5:
		return
	var moved: float = global_position.distance_to(_stuck_ref)
	_stuck_ref = global_position
	_stuck_sample_t = 0.0
	if wants_move and moved < 14.0:
		_stuck_t += 0.5
	else:
		_stuck_t = 0.0
		return
	if _stuck_t < STUCK_WARP_SECONDS:
		return
	_stuck_t = 0.0
	if _focus_target_ok():
		_ignored_id = _focus_target.get_instance_id()
		_ignored_until_ms = Time.get_ticks_msec() + 3000
		_focus_target = null
		_in_melee_stance = false
	elif _owner_ok() and global_position.distance_to(owner_player.global_position) > 140.0:
		_warp_to_heel()


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


## Köpek (eskiden tilki) animasyonu: ısırma klibi bitene kadar ezilmez; hareket hızına göre idle / walk / run (kullanıcı bildirimi
## 2026-10-08: eski "hareket = run" kuralı yavaş süzülmede de koşu klibi oynatıyordu). walk <-> run eşiği histerezisli: eşik civarında
## klip her karede değişmesin. 2026-10-08 (iki süreçli denetim: kopyada duruş sırasında idle<->walk 0,1 sn aralıkla titriyordu): hız süzülür
## (_speed_smooth), idle<->hareket eşikleri histerezisli ve hareket klibi türü (idle/walk/run) en az ANIM_HOLD sn sürer.
func _update_animation() -> void:
	if not anim:
		return
	var current: String = String(anim.animation)
	if current.begins_with("death") and anim.is_playing():
		return
	if _bite_left > 0.0 and current.begins_with("bite"):
		return
	var cur_prefix: String = current.get_slice("_", 0) + "_"
	var moving_clip: bool = cur_prefix == "walk_" or cur_prefix == "run_"
	var spd: float = _speed_smooth
	var want_prefix: String = "idle_"
	if spd > (IDLE_SPEED_MIN * 0.5 if moving_clip else IDLE_SPEED_MIN * 1.6):
		var run_threshold: float = WALK_SPEED_MAX * (0.8 if cur_prefix == "run_" else 1.1)
		want_prefix = "run_" if spd > run_threshold else "walk_"
	if want_prefix != cur_prefix and (cur_prefix == "idle_" or moving_clip):
		if _anim_hold > 0.0:
			want_prefix = cur_prefix
		else:
			_anim_hold = ANIM_HOLD
	var target_anim: String = want_prefix + facing
	if anim.animation != target_anim:
		anim.play(target_anim)


func _process_attack(delta: float) -> void:
	_attack_timer -= delta * _get_attack_speed_mult() * _owner_attack_speed_mult()
	if _attack_timer > 0.0:
		return
	## DÜZELTME (kullanıcı bildirimi: "Shopta kalkan baloncuğunun içinde silahlar ateş etmesin") - pet seyyar satıcının güvenli
	## bölgesindeki sahibini korurken saldırmaz (totem_base.gd _process()'teki AYNI kontrol).
	if _owner_ok() and owner_player.get("is_in_merchant_zone") == true:
		return
	if not _focus_target_ok():
		return
	var to_target: Vector2 = _focus_target.global_position - global_position
	if to_target.length() > MELEE_RANGE + ATTACK_REACH_SLACK:
		return
	_attack_timer = ATTACK_INTERVAL
	var attack_dir: Vector2 = to_target.normalized() if to_target.length() > 0.1 else Vector2.DOWN
	## 2026-10-08: ısırmadan ÖNCE hedefe dön (eskiden bakış yönü sadece hareket ederken güncelleniyordu: savaş duruşunda durup
	## hedefe SIRTINI dönük ısırırdı) ve ısırma klibini oynat; uzak kopyalar aynı klibi is_attacking + yön (sprite_row) ile alır.
	_update_facing(attack_dir)
	_play_bite()
	_do_cone_attack(attack_dir)
	_spawn_slash_fx(attack_dir)
	_broadcast_bite()


## Önüne doğru (attack_dir merkezli) 180 derecelik bir alandaki TÜM
## yaratıklara hasar verir - bkz. ATTACK_RADIUS/ATTACK_ARC_DEG sınıf üstü
## yorumu. DÜZELTME (kullanıcı bildirimi: "matthewin tilkisinin fazladan 1
## tane kocaman bir saldırı efekti var onu kaldır"): her isabet ayrıca
## Pençe silahının (fx_pence_slash.tscn) darbe efektini de spawnluyordu -
## bu küçük tilkiye göre orantısız büyük görünüyordu ve zaten _process_
## attack()'ın çağırdığı _spawn_slash_fx() (fx_matthew_pet_slash.tscn,
## tilkiye özel) ile üst üste biniyordu. Artık SADECE hasar veriliyor.
func _do_cone_attack(attack_dir: Vector2) -> void:
	var base_dmg: float = _owner_attack_power() * FOX_STAT_RATIO
	for e in EnemyQueryScript.candidates(get_tree(), global_position, ATTACK_RADIUS + 1.0):
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
			var is_crit: bool = randf() < _crit_chance()
			e.take_damage(base_dmg * (_crit_damage_mult() if is_crit else 1.0), is_crit)
			## Yetenek evrimi "Sersemleten Isırık" (2026-09-28): Vahşi Hız aktifken tilkinin saldırıları sersemletir - süre
			## sahibinden (player.gd matthew_fox_stun_time, 0 = yok).
			if _owner_ok() and owner_player.has_method("matthew_fox_stun_time"):
				var stun_t: float = float(owner_player.call("matthew_fox_stun_time"))
				if stun_t > 0.0 and e.has_method("apply_stun"):
					e.apply_stun(stun_t)


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu, CLAUDE.md'nin "kaster görür diğeri görmez" hata
## sınıfı): bu fonksiyon SADECE GERÇEK tilkinin (Matthew'in kendi makinesinde) çalıştığı _process_attack()
## tarafından çağrılır (bkz. _is_network_visual erken dönüşü) - eskiden burada hiç broadcast YOKTU, yani
## tilkinin oto saldırı efektini SADECE Matthew kendi ekranında görüyordu, diğer oyuncular hiçbir şey
## görmüyordu. weapon.gd _spawn_muzzle_flash ile AYNI desen: yerel spawn + "muzzle_flash" vfx_type'ıyla
## world-space konum/rotasyon broadcast (bkz. network_manager.gd broadcast_player_vfx, rotation zaten
## destekliyor).
func _spawn_slash_fx(attack_dir: Vector2) -> void:
	var pos: Vector2 = global_position + attack_dir * (ATTACK_RADIUS * 0.5)
	var rot: float = attack_dir.angle()
	_spawn_claw_slash_at(pos, rot)
	if NetworkManager.is_multiplayer_active and not network_instance_id.is_empty():
		NetworkManager.send_player_vfx(multiplayer.get_unique_id(), "muzzle_flash", pos, {
			"scene_path": SlashFxScene.resource_path,
			"rotation": rot,
		})


## Isırma klibi (köpek sayfasının BITE_<yön> satırı, 5 kare, bkz. tools/import_dog_sheet.py). Gerçek köpek _process_attack'tan, kozmetik
## kopya is_attacking paketinden (update_network_pet_state) çağırır; klip bitene kadar _update_animation onu ezmez (_bite_left).
func _play_bite() -> void:
	if not anim or not anim.sprite_frames:
		return
	var clip: String = "bite_" + facing
	if not anim.sprite_frames.has_animation(clip):
		return
	anim.play(clip)
	_bite_left = float(anim.sprite_frames.get_frame_count(clip)) / maxf(0.1, anim.sprite_frames.get_animation_speed(clip))


## Gerçek köpek ısırdığını (konum + bakış yönü dizini) kozmetik kopyalara hemen bildirir (periyodik yayın is_attacking=false gönderir).
func _broadcast_bite() -> void:
	if _is_network_visual or not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, true, -1.0, -1.0, FACINGS.find(facing), false)


func _spawn_claw_slash_at(pos: Vector2, rot: float) -> void:
	var fx: Node2D = SlashFxScene.instantiate() as Node2D
	get_tree().current_scene.add_child(fx)
	fx.global_position = pos
	fx.rotation = rot


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


## Vahşi Hız (Matthew E) açıkken tilkinin payı - sayılar sahibinden (player.gd matthew_haste_bonus: "Vahşi Koşu" %30/%50,
## "Tilki Ruhu" tilkiye 2 katı). Eskiden burada sabit 1.15/1.40 yazıyordu (Matthew'deki sabitlerin ikinci kopyası).
func _get_speed_mult() -> float:
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("is_skill2_active") and owner_player.has_method("get_skill2_id"):
		if owner_player.is_skill2_active() and owner_player.get_skill2_id() == 21:
			if owner_player.has_method("matthew_haste_bonus"):
				return 1.0 + float(owner_player.call("matthew_haste_bonus", "move", true))
			return 1.15
	return 1.0


## ---- Matthew'den okunan saldırı statları (bkz. FOX_STAT_RATIO notu). Sahip yoksa tilki eski yedek değerleri kullanır.
func _owner_ok() -> bool:
	return owner_player != null and is_instance_valid(owner_player)


func _owner_attack_power() -> float:
	if _owner_ok() and "damage_bonus" in owner_player:
		return maxf(1.0, float(owner_player.get("damage_bonus")))
	return BASE_DAMAGE / FOX_STAT_RATIO


## Sayaç hız çarpanı: 1 + (Matthew'in saldırı hızı bonusu x 2).
func _owner_attack_speed_mult() -> float:
	if _owner_ok() and owner_player.has_method("get_attack_speed_bonus_percent"):
		return maxf(0.1, 1.0 + float(owner_player.call("get_attack_speed_bonus_percent")) / 100.0 * FOX_STAT_RATIO)
	return 1.0


## Matthew'in yetenek kritik tabanları (player.gd ABILITY_BASE_CRIT_*) - betiğin sabit tablosundan (tek kaynak).
func _owner_const(n: String, fallback: float) -> float:
	var sc: Script = owner_player.get_script() if _owner_ok() else null
	if sc == null:
		return fallback
	return float(sc.get_script_constant_map().get(n, fallback))


func _crit_chance() -> float:
	if _owner_ok() and "crit_chance_bonus" in owner_player:
		return clampf((_owner_const("ABILITY_BASE_CRIT_CHANCE", 0.05) + float(owner_player.get("crit_chance_bonus"))) * FOX_STAT_RATIO, 0.0, 1.0)
	return 0.0


func _crit_damage_mult() -> float:
	if _owner_ok() and "crit_damage_bonus" in owner_player:
		return (_owner_const("ABILITY_BASE_CRIT_DAMAGE", 1.5) + float(owner_player.get("crit_damage_bonus"))) * FOX_STAT_RATIO
	return 1.5


func _get_attack_speed_mult() -> float:
	if owner_player and is_instance_valid(owner_player) and owner_player.has_method("is_skill2_active") and owner_player.has_method("get_skill2_id"):
		if owner_player.is_skill2_active() and owner_player.get_skill2_id() == 21:
			if owner_player.has_method("matthew_haste_bonus"):
				return 1.0 + float(owner_player.call("matthew_haste_bonus", "attack", true))
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

