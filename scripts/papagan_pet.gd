extends Node2D

## Kullanıcı isteği: "ben zivaya papağan yarattırdım onu karakter olarak
## eklemiş papağan karakterini silip onun korsanın kafasının üstünde duran ve
## ara sıra etrafta uçan bir pet olarak değiştirmeni istiyorum" - "Ziva"nın
## oynanabilir karakter olarak eklediği Papağan artık characters.gd DEFS'te
## bulunmuyor (seçim ekranında zaten görünmüyor - character_select.gd
## kartları doğrudan Characters.DEFS'ten ürettiği için DEFS'te girişi olmayan
## bir karakter hiç seçilemez, yani "karakteri sil" isteği DEFS'te zaten
## karşılanmış durumda). Bu script onun yerine SADECE Korsan'a (characters.gd
## DEFS anahtarı 9, bkz. player.gd _spawn_korsan_parrot) özgü, TAMAMEN
## kozmetik/savaşmayan bir yoldaş sağlıyor. Görsel varlıkları (assets/
## characters/papagan_frames.tres - idle_*/fly_* animasyonları, "Ziva"
## tarafından zaten üretilmiş, silinmedi) olduğu gibi yeniden kullanılıyor -
## skeleton_pet.gd/golem_pet.gd/wraith_pet.gd'nin aksine bu pet'in hiç canı/
## hasarı/hedefi YOK, SADECE Korsan'ın kafasının üstünde durup ara sıra
## rastgele bir yöne kısa bir uçuşa çıkıp geri dönen saf bir dekor.
##
## Multiplayer: diğer Necromancer pet'leriyle AYNI desen - sadece Korsan'ı
## oynayan istemcide GERÇEK durum makinesi çalışır (bkz. player.gd
## _spawn_korsan_parrot), diğer istemcilerde SADECE kozmetik bir kopya
## (mark_as_network_visual) son bildirilen MUTLAK world-space konuma
## yumuşakça kayar (bkz. _process_network_visual - enemy.gd'nin istemci
## tarafı konum senkronuyla AYNI desen).

const IDLE_ANIM_PREFIX := "idle_"
const FLY_ANIM_PREFIX := "fly_"

## Korsan'ın kafasının üstü.
## DÜZELTME (kullanıcı bildirimi: "papağan görünmüyor"): bu değer eskiden
## karakterin HAM sprite boyutuna (64px hücre * 1.27575 ölçek ≈ 82px)
## göre hesaplanmıştı, ama main.tscn'deki GERÇEK Player düğümü ayrıca
## `scale = Vector2(0.5, 0.5)` ile YARI boyuta küçültülüyor (bkz. main.tscn -
## diğer TÜM pet'ler de - skeleton_pet.gd vb. - bu yüzden owner_player'a
## ÇOCUK değil, current_scene'e DOĞRUDAN kardeş olarak ekleniyor, aksi halde
## bu ölçeği de miras alırlardı). Ekrandaki GERÇEK karakter boyutu yaklaşık
## yarı yarıya küçük olduğu için buradaki offset de buna göre küçültüldü -
## eskisi kafanın çok üstünde, neredeyse görünmeyecek kadar yukarıda
## kalıyordu.
const HEAD_OFFSET := Vector2(0, -26)
const PERCH_DURATION_MIN := 6.0
const PERCH_DURATION_MAX := 14.0
const FLY_DURATION_MIN := 3.0
const FLY_DURATION_MAX := 5.0
const FLY_RADIUS_MIN := 18.0
const FLY_RADIUS_MAX := 38.0
## Kullanıcı isteği ("... hareket hızlarını %10 azalt"): papağanın lerp
## hızları da (diğer tüm varlıklar gibi) %10 düşürüldü - 6.0 -> 5.4,
## 2.6 -> 2.34 (x0.9). Lerp oldukları için "hız" değil takip çevikliği
## anlamına gelirler: papağan artık sahibini biraz daha yavaş yakalıyor.
## NOT: diğer pet'lerin (golem/iskelet/hortlak/matthew) hızları sahibin
## `speed`inden türetildiği için onlar player.gd'deki %10'luk düşüşü
## kendiliğinden miras alıyor - papağanın kendi sabitleri olduğu için
## burada ayrıca uygulandı.
const FOLLOW_LERP_SPEED := 5.4
const FLY_LERP_SPEED := 2.34

var owner_player: Node2D = null

## bkz. skeleton_pet.gd dosya başındaki "kozmetik kopya" notu - AYNI desen.
var network_instance_id: String = ""
var _is_network_visual: bool = false
var _network_target_position: Vector2 = Vector2.ZERO
var _network_state_received: bool = false
var _network_is_flying: bool = false

var _state: String = "perched"
var _state_timer: float = 0.0
var _current_offset: Vector2 = HEAD_OFFSET
var _fly_target_offset: Vector2 = HEAD_OFFSET
var _facing: String = "down"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	## Kullanıcı isteği (bkz. EntityScale): tüm varlıklar gibi evcil hayvanlar da
	## %5 küçülür. Papağanın gövde çemberi yok (hiçbir şeyle fiziksel
	## çarpışmıyor), sadece görseli ölçekleniyor.
	EntityScale.shrink(sprite)
	## fx_papagan_feather_storm.gd (Ziva'nın bıraktığı, artık kullanılmayan
	## ULTİ efekt script'i) ile AYNI z_index - kozmetik papağan görselleri
	## için zaten kullanılan bir değer, tutarlılık için korundu.
	z_index = 47
	_state_timer = randf_range(PERCH_DURATION_MIN, PERCH_DURATION_MAX)
	if sprite:
		sprite.play(IDLE_ANIM_PREFIX + _facing)


## bkz. player.gd _spawn_korsan_parrot - GERÇEK pet'i sahibine bağlar.
func setup_from_player(player: Node2D) -> void:
	owner_player = player
	if is_instance_valid(owner_player):
		global_position = owner_player.global_position + HEAD_OFFSET


func mark_as_network_visual() -> void:
	_is_network_visual = true


func _physics_process(delta: float) -> void:
	if _is_network_visual:
		_process_network_visual(delta)
		return
	if not owner_player or not is_instance_valid(owner_player):
		return
	_state_timer -= delta
	match _state:
		"perched":
			var prev_offset: Vector2 = _current_offset
			_current_offset = _current_offset.lerp(HEAD_OFFSET, delta * FOLLOW_LERP_SPEED)
			_update_facing_from_motion(_current_offset - prev_offset)
			if _state_timer <= 0.0:
				_enter_flying_state()
		"flying":
			var prev_offset2: Vector2 = _current_offset
			_current_offset = _current_offset.lerp(_fly_target_offset, delta * FLY_LERP_SPEED)
			_update_facing_from_motion(_current_offset - prev_offset2)
			if _state_timer <= 0.0:
				_enter_perched_state()
			elif _current_offset.distance_to(_fly_target_offset) < 8.0:
				_pick_new_fly_target()
	global_position = owner_player.global_position + _current_offset
	_update_animation()
	_broadcast_network_state()


func _enter_flying_state() -> void:
	_state = "flying"
	_state_timer = randf_range(FLY_DURATION_MIN, FLY_DURATION_MAX)
	_pick_new_fly_target()


func _enter_perched_state() -> void:
	_state = "perched"
	_state_timer = randf_range(PERCH_DURATION_MIN, PERCH_DURATION_MAX)


func _pick_new_fly_target() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf_range(FLY_RADIUS_MIN, FLY_RADIUS_MAX)
	_fly_target_offset = HEAD_OFFSET + Vector2(cos(angle), sin(angle)) * dist


func _update_facing_from_motion(motion: Vector2) -> void:
	if motion.length() < 0.5:
		return
	if abs(motion.x) > abs(motion.y):
		_facing = "right" if motion.x > 0 else "left"
	else:
		_facing = "up" if motion.y < 0 else "down"


func _update_animation() -> void:
	if not sprite:
		return
	var prefix: String = FLY_ANIM_PREFIX if _state == "flying" else IDLE_ANIM_PREFIX
	var anim_name: String = prefix + _facing
	if sprite.animation != anim_name:
		sprite.play(anim_name)


## bkz. skeleton_pet.gd'deki AYNI fonksiyon - tek fark, MUTLAK global_position
## yayınlanıyor (owner_player'a göre offset DEĞİL) - kozmetik kopyanın kendi
## owner referansı hiç yok, sadece bu mutlak konuma kayıyor.
func _broadcast_network_state() -> void:
	if not NetworkManager.is_multiplayer_active or network_instance_id.is_empty():
		return
	if NetworkManager.should_throttle("petpos_%s" % network_instance_id, 0.2):
		return
	NetworkManager.broadcast_pet_state.rpc(multiplayer.get_unique_id(), network_instance_id, global_position, _state == "flying")


## broadcast_pet_state RPC'sinin (bkz. network_manager.gd) çağırdığı istemci
## tarafı karşılığı - "is_attacking" parametresi burada "is_flying" olarak
## yeniden yorumlanıyor (uçuyorsa fly_*, değilse idle_* animasyonu).
## DÜZELTME: remote_player.gd _update_pet_visual_state() bu fonksiyonu
## sprite_row dahil 3 argümanla çağırıyor (bkz. skeleton_pet.gd/player_pet.gd
## AYNI düzeltme) - eski 2 parametreli imza "too many arguments" hatasıyla
## sessizce başarısız olup Papağan'ı diğer oyunculara hareketsiz gösteriyordu.
func update_network_pet_state(pos: Vector2, is_flying: bool, _sprite_row: int = -1) -> void:
	_network_target_position = pos
	_network_state_received = true
	_network_is_flying = is_flying


func _process_network_visual(delta: float) -> void:
	if not _network_state_received:
		return
	var to_target: Vector2 = _network_target_position - global_position
	if to_target.length() > 1.0:
		_update_facing_from_motion(to_target)
	global_position = global_position.lerp(_network_target_position, min(1.0, delta * 10.0))
	if sprite:
		var prefix: String = FLY_ANIM_PREFIX if _network_is_flying else IDLE_ANIM_PREFIX
		var anim_name: String = prefix + _facing
		if sprite.animation != anim_name:
			sprite.play(anim_name)
