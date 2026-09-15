extends CharacterBody2D
class_name RemotePlayer

## Remote player puppet for multiplayer.
## Receives synced transform, animation, health and visual state from the network.

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_visual: Node2D = $ShieldVisual
@onready var overhead_bar = $OverheadBar
## bkz. player.gd/downed_timer_label.gd - AYNI script, kullanıcı isteği:
## "düşen oyuncuda ve hayatta olanlarda solda süre görünsün".
@onready var downed_timer_label = $DownedTimerLabel
@onready var name_label: Label = $NameLabel

var peer_id: int = 0
var char_id: int = 1
var player_name: String = "Oyuncu"
var _chat_bubble: Node2D = null

var health: float = 100.0
var max_health: float = 100.0
var item_shield_hp: float = 0.0
var item_shield_max: float = 0.0
var is_dead: bool = false
## Klasik canlanma sistemi (bkz. player.gd is_downed/_go_down/_complete_revive) -
## bu oyuncu yerde yatıyor ama henüz kalıcı ölmedi, bir müttefik yaklaşırsa
## canlanabilir. enemy.gd bu bayrağı okuyup downed oyuncuları hedef almıyor.
var is_downed: bool = false
## "efekt sistemi" (ölüm.png/diriltme.png/kalp.png) - bkz. player.gd'deki
## AYNI mimari (_update_death_status_fx/_update_revive_rewind_fx). Burada
## AYRI bir RPC/broadcast GEREKMİYOR: health/max_health/is_dead/is_downed
## zaten update_extra_state_from_net ile senkronize ediliyor (bkz. main.gd
## state_snapshot), downed iken health/max_health GERÇEK can yerine diriltme
## oranını taşıyor (bkz. player.gd get_revive_progress_ratio üstündeki
## yorum) - yani bu istemci kendi yerel efektini TAMAMEN bu senkronize
## veriden üretebiliyor.
const FxDeathScene := preload("res://scenes/fx_death.tscn")
const FxReviveRewindScene := preload("res://scenes/fx_revive_rewind.tscn")
const FxReviveHeartScene := preload("res://scenes/fx_revive_heart.tscn")
var _death_status_fx: Node = null
var _revive_rewind_fx: Node = null
var _was_downed_for_heart_fx: bool = false

## "efekt sistemi" (iyileşme.png/kalkan.png) - bkz. player.gd _set_ally_aura/
## network_manager.gd broadcast_ally_aura_start/stop. Bu kukla, başka bir
## client'ta ally olarak hedeflenirse (yani BU oyuncu -kendi client'ında
## yerel Player olan biri- bir müttefiğini iyileştiriyorsa VE İZLEYEN
## client'ta o müttefik bir RemotePlayer kuklasıysa) burası çağrılır.
const FxMelekHealAuraScene := preload("res://scenes/fx_melek_heal_aura.tscn")
const FxMelekShieldAuraScene := preload("res://scenes/fx_melek_shield_aura.tscn")
var _ally_aura_fx: Dictionary = {}

func start_ally_aura_fx(aura_type: String) -> void:
	if _ally_aura_fx.has(aura_type) and is_instance_valid(_ally_aura_fx[aura_type]):
		return
	var scene: PackedScene = FxMelekHealAuraScene if aura_type == "heal" else (FxMelekShieldAuraScene if aura_type == "shield" else null)
	if not scene:
		return
	var fx := scene.instantiate()
	add_child(fx)
	_ally_aura_fx[aura_type] = fx


func stop_ally_aura_fx(aura_type: String) -> void:
	if not _ally_aura_fx.has(aura_type):
		return
	var fx = _ally_aura_fx[aura_type]
	if is_instance_valid(fx) and fx.has_method("stop_aura"):
		fx.call("stop_aura")
	_ally_aura_fx.erase(aura_type)
## bkz. main.gd state_snapshot "is_indoors" - host'un enemy.gd'si bu bayrağı
## okuyarak ev içindeki bir katılımcıyı hedef dışı bırakıyor (kullanıcı
## isteği: "içerideyken yaratıklar içeri saldıramamalı").
var is_indoors: bool = false
## bkz. main.gd state_snapshot "is_in_merchant_zone" - seyyar satıcının
## güvenli bölgesi, is_indoors ile AYNI amaç/desen (kullanıcı isteği:
## "oyuncular o bölgeye girince yaratıklar tarafından görünmez olurlar").
var is_in_merchant_zone: bool = false
## bkz. main.gd state_snapshot "dmg_dealt" (kullanıcı isteği: "grup
## penceresinde canlı hasar istatistik paneli") - party_panel.gd
## _build_stats_popup bu müttefiğin canlı toplam verdiği hasarını buradan
## okuyor, tıpkı health/item_shield_hp gibi.
var match_damage_dealt: float = 0.0
var paladin_zone_active: bool = false
var paladin_zone_radius: float = 126.0

## Talon YENİ ULTİ (Devleşme) - karakterin normal (büyümemiş) sprite ölçeği,
## _load_character_frames()'te bir kere kaydedilir - "talon_giant" bayrağı
## geldiğinde/gittiğinde anim.scale'i buna göre 2 katına çıkarıp geri
## indirmek için (bkz. update_extra_state_from_net).
var _base_anim_scale: Vector2 = Vector2(1.27575, 1.27575)
var _talon_giant_active: bool = false
## Talon'un Silah Salvosu (E)/Ayna Formu (R) - bkz. main.gd extra["talon_
## formation"]/player.gd _talon_set_weapons_circular. "" iken silahlar normal
## nişan/orbit mantığıyla (_update_local_weapon_aim/_update_local_uzunkilic_
## orbit) güncellenir; "salvo"/"mirror" iken bunların YERİNE _update_talon_
## formation çağrılır (bkz. _physics_process).
var _talon_formation: String = ""
## SADECE "salvo" formasyonunun dönüş açısı (bkz. talon_formation_math.gd
## advance_salvo_angle) - "mirror" sabit bir dizilim olduğu için kullanılmaz.
var _talon_salvo_angle: float = 0.0

var _target_position: Vector2 = Vector2.ZERO
## Ölü hesaplama (dead reckoning) - kullanıcı bildirimi: "multiplayerda
## dirilme olayı..." AYRI bir sorun olarak "multiplayarda katılımcıların
## hala bir lag sorunu var" - enemy.gd'ye AYNI şikayet için ("yaratıklar
## bianda durup bianda hareket ediyor lag var") zaten bir ölü hesaplama
## düzeltmesi uygulanmıştı (bkz. orada _network_velocity notu), ama oyuncu
## kuklaları (bu script) hiç aynı düzeltmeyi almamıştı - sadece son bilinen
## konuma sabit bir hızla (18.0*delta) lerp ediyordu, yani iki paket (~20Hz,
## ~50ms arayla) arasında GERÇEKTE hareket etmiyor, paket gelince aniden
## "sıçrıyor" gibi görünüyordu - özellikle paket kaybı/gecikme olan bir
## bağlantıda (Ziva Cloud) bu çok daha belirgin, "takılıyor/duruyor" hissi
## veriyordu. Artık enemy.gd'deki AYNI teknik: son iki paket arasındaki
## GERÇEK geçen süreden bir hız türetilip, bir sonraki paket gelene kadar
## o hızla ileri "tahmin" ediliyor.
var _network_velocity: Vector2 = Vector2.ZERO
var _network_time_since_update: float = 0.0
var _position_received: bool = false
const NETWORK_MAX_EXTRAPOLATE_SPEED := 600.0
var _weapon_keys: Array = []
var _weapon_icons: Array[Node2D] = []
## _weapon_icons ile aynı index'e hizalı silah gölgeleri (bkz.
## update_weapon_visuals) - eskiden hiç oluşturulmuyordu, bu yüzden diğer
## oyunculara silahların gölgesi hiç görünmüyordu (kullanıcı bildirimi:
## "silahların gölgeleri diğer oyunculara görünmüyor").
var _weapon_shadows: Array[Node2D] = []
var _heal_display_accum: float = 0.0

## _weapon_icons ile aynı index'e hizalı - nişan açısı artık ağdan
## gelmiyor (bkz. _update_local_weapon_aim), bu yüzden gerçek weapon.gd
## sahnesinin (weapon_root, bkz. update_weapon_visuals) kendi @export
## değerlerini SİLİNMEDEN ÖNCE burada yakalayıp saklıyoruz - böylece her
## silahın KENDİ sprite açısı/aynalama davranışı korunur.
var _weapon_forward_angle_deg: Array = []
var _weapon_mirror_aim: Array = []
var _weapon_icon_flipped: Array = []
## BUG DÜZELTMESİ (kullanıcı bildirimi: "diğer oyuncuların silahlarının bakış
## yönü doğru gözükmüyor, saldırdıkları hedefe dönük olması gerek tıpkı
## single player'da olduğu gibi") - hedef seçimi eskiden HER ZAMAN "kuklanın
## KENDİ konumuna en yakın, menzil sınırı olmayan düşman" şeklinde
## basitleştirilmişti. Ama weapon.gd'nin GERÇEK mantığı (bkz. _attack_origin,
## _get_target_enemy, attack_range) üç noktada farklı: (1) her silah kendi
## KONUMUNDAN (karakterin değil, WEAPON_ICON_SLOTS'taki kendi yerinden)
## hedef arar - aksi halde birden fazla silah hep aynı tek düşmana kilitlenir;
## (2) attack_range sınırı var - menzil dışındaysa silah HİÇBİR yöne
## dönmeden son açısında kalır (host/single player'da da öyle); (3) Tüftüf
## (target_highest_health) ve Buz Asası (target_prefer_unfrozen) farklı bir
## hedef seçer. Şimdi üçü de weapon_root silinmeden önce yakalanıp
## uygulanıyor.
var _weapon_attack_range: Array = []
var _weapon_target_highest_health: Array = []
var _weapon_target_prefer_unfrozen: Array = []
const AIM_EASE_RATE := 12.0

## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "kılıcın animasyonu
## multiplayerda diğer oyunculara doğru gösterilmiyor") - kök neden: kılıç
## (Uzunkılıç) hiç _fire_at()/broadcast_weapon_attack çağırmıyor, sürekli
## kendi etrafında dönen bir yörünge (bkz. weapon.gd _process_uzunkilic_
## orbit) - hiçbir şey yayınlanmadığı için uzak kopya onu normal menzilli
## bir silah sanıp en yakın düşmana "nişan alma" rotasyonu uyguluyordu (bkz.
## _update_local_weapon_aim). Menzilli nişan hesabı gibi bu da TAMAMEN
## YEREL hesaplanabilir - yörünge tamamen deterministik (sadece fire_rate'e
## bağlı sabit açısal hız), ağdan hiçbir veriye ihtiyaç yok. Faz (başlangıç
## açısı) gerçek silahla birebir eşleşmez ama bu sürekli/dekoratif bir
## dönüş olduğu için (ayrı, hedefe kilitli bir vuruş animasyonu değil) fark
## edilmez.
var _weapon_is_orbit_sword: Array = []
var _weapon_fire_rate: Array = []
var _weapon_orbit_angle: Array = []
var _weapon_base_attack_range: Array = []

## DÜZELTME (mimari sadeleştirme - kullanıcı isteği: "singleplayerda zaten
## kayıtlı animasyon/efekt bilgilerinin multiplayerdan gereksiz yere
## alınması yerine kendi bilgisiyle gerçekleşmesi"): weapon.gd'nin
## "weapon_fire"/"weapon_recoil" yayınları eskiden is_melee, reps, forward_deg,
## rest_rotation_deg, slash_fx_offset, slash_fx_above_offset ve
## recoil_distance'ı HER ateşte ağdan gönderiyordu - hepsi bu silahın KENDİ
## sabit tanım değerleri, tıpkı _weapon_forward_angle_deg/_weapon_mirror_aim
## gibi (nişan açısı için zaten aynı desenle) weapon_root silinmeden ÖNCE
## burada yakalanıp saklanıyor, artık network'ten hiç okunmuyorlar.
var _weapon_rest_rotation_deg: Array = []
var _weapon_slash_fx_offset: Array = []
var _weapon_slash_fx_above_offset: Array = []
var _weapon_recoil_distance: Array = []
var _weapon_hit_segments: Array = []

const WEAPON_ICON_SLOTS: Array[Vector2] = [
	Vector2(0, -125), Vector2(62, -70), Vector2(-62, -70),
	Vector2(92, -28), Vector2(-92, -28),
]

## Talon'un Ayna Formu (bkz. player.gd get_max_owned_weapons/MAX_OWNED_
## WEAPONS) silah sayısını normal 5 sınırının 2 katına (10) çıkarabiliyor.
## WEAPON_ICON_SLOTS yukarıda hâlâ SADECE 5 sabit dizilim konumu tanımlıyor
## (normal, formasyonsuz nişan modu için - bu moddayken zaten hiçbir zaman
## 5'ten fazla silah olmuyor), ama ikon SAYISI bu üst sınıra kadar
## oluşturulabilmeli, yoksa 6. ve sonrası silah diğer oyunculara hiç
## görünmez (_update_talon_formation onları zaten WEAPON_ICON_SLOTS'a hiç
## ihtiyaç duymadan dairesel olarak konumlandırıyor).
const MAX_WEAPON_ICONS := 10

const WEAPON_SCENES := {
	"dagger": preload("res://scenes/weapon_dagger.tscn"),
	"fire_staff": preload("res://scenes/weapon_fire.tscn"),
	"lightning_staff": preload("res://scenes/weapon_lightning.tscn"),
	"tabanca": preload("res://scenes/weapon_tabanca.tscn"),
	"tuftuf": preload("res://scenes/weapon_tuftuf.tscn"),
	"tufek": preload("res://scenes/weapon_tufek.tscn"),
	"arcane": preload("res://scenes/weapon_arcane.tscn"),
	"yay": preload("res://scenes/weapon_yay.tscn"),
	"crossbow": preload("res://scenes/weapon_crossbow.tscn"),
	"boomerang": preload("res://scenes/weapon_boomerang.tscn"),
	"buz_asasi": preload("res://scenes/weapon_buz_asasi.tscn"),
	"fisek": preload("res://scenes/weapon_fisek.tscn"),
	"pence": preload("res://scenes/weapon_pence.tscn"),
	"topuz": preload("res://scenes/weapon_topuz.tscn"),
	"uzunkilic": preload("res://scenes/weapon_uzunkilic.tscn"),
}


func _ready() -> void:
	## ÖNEMLİ: RemotePlayer "player" grubuna EKLENMEMELİDİR.
	## "player" grubu yalnızca bu istemcinin kendi yerel Player'ına aittir.
	## RemotePlayer'ların bu grupta olması get_first_node_in_group("player")/
	## is_in_group("player") çağrılarının rastgele RemotePlayer kuklasına
	## çözülmesine yol açar (apply_upgrade/add_xp çökmeleri, VE kullanıcı
	## bildirimi: "katılımcılar altın toplayınca yine hosta gidiyor" - gold_drop.gd
	## _on_body_entered() TAM OLARAK is_in_group("player") ile "bu host'un
	## kendi karakteri mi yoksa bir kukla mı" ayrımı yapıyordu).
	## KÖK NEDEN BULUNDU: script BURADA hiç add_to_group("player") çağırmasa
	## da, remote_player.tscn'in KÖK node'u hâlâ groups=["player","player_ally"]
	## olarak kayıtlıydı - .tscn'deki bu "groups" listesi node ağaca girer
	## girmez, _ready() çalışmadan ÖNCE otomatik uygulanıyor, yani bu script
	## hiçbir zaman devreye giremeden RemotePlayer zaten "player" grubundaydı.
	## .tscn'den "player" kaldırıldı (bkz. o dosya) - artık gerçekten sadece
	## player_ally + (aşağıda) remote_players'ta.
	add_to_group("player_ally")
	add_to_group("remote_players")
	
	_load_character_frames()
	## Kullanıcı isteği (bkz. EntityScale): yerel oyuncuyla AYNI boyut küçültme.
	## Görsel ölçek _load_character_frames() içinde küçültülüyor; burada gövde
	## çemberi ve kalkan baloncuğu (yoksa uzak oyuncunun baloncuğu karakterine
	## göre 5% geniş görünürdü).
	EntityScale.shrink_collision(get_node_or_null("CollisionShape2D"))
	var bubble: Node2D = get_node_or_null("ShieldVisual/BubbleSprite")
	if bubble:
		bubble.scale *= EntityScale.SIZE
	_target_position = global_position

	if overhead_bar:
		overhead_bar.set_health(health, max_health)
		overhead_bar.set_shield(item_shield_hp, item_shield_max)

	## Chat balonu (bkz. scripts/chat_bubble.gd) - player.gd'deki AYNI script.
	_chat_bubble = Node2D.new()
	_chat_bubble.set_script(preload("res://scripts/chat_bubble.gd"))
	add_child(_chat_bubble)


## network_manager.gd broadcast_chat_message RPC alıcı tarafta çağırır -
## bkz. player.gd show_chat_bubble() (birebir aynı imza/davranış).
func show_chat_bubble(text: String) -> void:
	if _chat_bubble and _chat_bubble.has_method("show_message"):
		_chat_bubble.show_message(text)


func setup(p_peer_id: int, p_char_id: int, p_name: String) -> void:
	peer_id = p_peer_id
	char_id = p_char_id
	player_name = p_name
	name = "remote_player_%d" % peer_id
	if name_label:
		name_label.text = player_name
	_load_character_frames()


func _load_character_frames() -> void:
	if not is_instance_valid(anim):
		return
	var def: Dictionary = Characters.get_def(char_id)
	## Kullanıcı isteği ("tüm oynanabilir karakterleri %5 küçült"): yerel
	## oyuncuyla (player.gd _load_character_frames) AYNI çarpan - yoksa çok
	## oyunculuda uzak oyuncular bir %5 daha iri görünürdü. _base_anim_scale de
	## bu değerden atandığı için Talon'un Devleşme ultisi (2x) tutarlı kalır.
	anim.scale = def.get("scale", Vector2(1.27575, 1.27575)) * EntityScale.SIZE
	_base_anim_scale = anim.scale
	anim.offset = def.get("offset", Vector2(0, -5))
	var frames_path: String = def.get("frames", "")
	if ResourceLoader.exists(frames_path):
		var res = load(frames_path)
		if res is SpriteFrames:
			anim.sprite_frames = res
	anim.play("idle_down")



func _physics_process(delta: float) -> void:
	if is_dead:
		return
	# Smoothly interpolate position towards target
	## bkz. update_position_and_anim_from_net üstündeki dead-reckoning notu -
	## iki gerçek paket arasında son bilinen yönde/hızda akıcı hareket
	## etmeye devam eder, sadece paket gelene kadar donup kalmak yerine.
	## 0.4sn'yi aşan bir boşlukta tahmin durdurulur (enemy.gd'deki AYNI sınır)
	## - o kadar uzun bir kesintide gerçekten durmuş olma ihtimali yüksektir.
	_network_time_since_update += delta
	var extrap_time: float = min(_network_time_since_update, 0.4)
	var predicted_target: Vector2 = _target_position + _network_velocity * extrap_time
	global_position = global_position.lerp(predicted_target, 18.0 * delta)
	## Kullanıcı isteği: "en yaygın/en sağlıklı ne ise onu yap" - menzilli
	## silahların nişan dönüşü artık ağdan HİÇ gelmiyor (bkz. main.gd/
	## _rpc_update_player_transform'un kısaltılmış imzası). Her katılımcı
	## zaten hangi yaratıkların nerede olduğunu biliyor (enemy sync sayesinde)
	## - yani "en yakın düşmana dön" kararı, tıpkı weapon.gd'nin gerçek
	## oyuncu için yaptığı gibi, tamamen YEREL olarak hesaplanabilir. Bu,
	## oyunun zaten bildiği bir kural olduğu için ağdan hiç veri gerektirmez.
	## Talon Silah Salvosu/Ayna Formu aktifken silahlar normal nişan/orbit
	## mantığı YERİNE dairesel formasyonda tutulur (bkz. _update_talon_formation).
	if _talon_formation != "":
		_update_talon_formation(delta)
	else:
		_update_local_weapon_aim(delta)
		_update_local_uzunkilic_orbit(delta)


var _weapon_tiers: Dictionary = {}
## _weapon_icons ile aynı index'e hizalı: her silahın yakın dövüş olup
## olmadığı - ağdan gelen sürekli nişan rotasyonu (bkz.
## update_position_and_anim_from_net) SADECE menzilli silahlara uygulanır,
## yakın dövüş silahları kendi salınım
## animasyonunu (bkz. _animate_weapon_fire_full) kullanmaya devam eder.
var _weapon_melee: Array = []
## _weapon_icons ile aynı index'e hizalı: her ikonun İLK (gerçek dinlenme)
## ölçeği - _animate_weapon_fire_full eskiden "base_scale"i her ateşte
## icon.scale'den (yani O AN hangi değerdeyse) okuyordu. Ateş hızlı silahlarda
## (özellikle Yay) bir önceki büyüme/küçülme tween'i TAM bitmeden yeni ateş
## geldiğinde, "base" olarak zaten büyümüş bir değer yakalanıp üstüne bir kat
## daha büyütülüyordu - bu döngü sınırsız devam edip ikonun sürekli
## büyümesine yol açıyordu (kullanıcı bildirimi: "yay ateşlendikçe diğer
## oyunculara gittikçe daha büyük görünmeye başlıyor"). Artık SABİT, bir kez
## kaydedilmiş gerçek taban ölçek kullanılıyor.
var _weapon_base_scales: Array = []
## _weapon_icons ile aynı index'e hizalı: o ikonun üzerinde o an çalışan
## ateş animasyonu tween'i - yeni bir ateş event'i gelirse öncekini keser,
## böylece üst üste binen tween'ler de büyümeye katkı yapamaz.
var _weapon_fire_tweens: Array = []

## weapon.gd'nin _measure_icon_pixel_size'ıyla aynı mantık (dokunun gerçek
## kullanılan piksel alanını ölçer) - gölgenin ikonun gerçek şekline oranlı
## olması için. Sprite2D ve AnimatedSprite2D ikonları destekler.
func _measure_remote_icon_pixel_size(icon: Node2D) -> Vector2:
	var tex: Texture2D = null
	if icon is Sprite2D and icon.texture:
		tex = icon.texture
	elif icon is AnimatedSprite2D and icon.sprite_frames:
		var anim_name: StringName = icon.animation
		if anim_name != &"" and icon.sprite_frames.has_animation(anim_name):
			tex = icon.sprite_frames.get_frame_texture(anim_name, icon.frame)
	if not tex:
		return Vector2(64.0, 64.0)
	var img: Image = tex.get_image()
	if img:
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			return Vector2(used.size)
	return tex.get_size()


func update_weapon_visuals(new_weapon_keys: Array, weapon_tiers: Dictionary = {}) -> void:
	if new_weapon_keys == _weapon_keys and weapon_tiers == _weapon_tiers:
		return
	_weapon_keys = new_weapon_keys.duplicate()
	_weapon_tiers = weapon_tiers.duplicate()
	for icon: Node2D in _weapon_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	for sh: Node2D in _weapon_shadows:
		if is_instance_valid(sh):
			sh.queue_free()
	for tw: Variant in _weapon_fire_tweens:
		if tw and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_weapon_icons.clear()
	_weapon_shadows.clear()
	_weapon_melee.clear()
	_weapon_base_scales.clear()
	_weapon_fire_tweens.clear()
	_weapon_forward_angle_deg.clear()
	_weapon_mirror_aim.clear()
	_weapon_icon_flipped.clear()
	_weapon_attack_range.clear()
	_weapon_target_highest_health.clear()
	_weapon_target_prefer_unfrozen.clear()
	_weapon_rest_rotation_deg.clear()
	_weapon_slash_fx_offset.clear()
	_weapon_slash_fx_above_offset.clear()
	_weapon_recoil_distance.clear()
	_weapon_hit_segments.clear()
	_weapon_is_orbit_sword.clear()
	_weapon_fire_rate.clear()
	_weapon_orbit_angle.clear()
	_weapon_base_attack_range.clear()
	for i in range(min(_weapon_keys.size(), MAX_WEAPON_ICONS)):
		var key: String = str(_weapon_keys[i])
		var weapon_scene: PackedScene = WEAPON_SCENES.get(key)
		if weapon_scene == null:
			continue
		var weapon_root: Node = weapon_scene.instantiate()
		add_child(weapon_root)
		var icon: Node2D = weapon_root.get_node_or_null("Icon") as Node2D
		if icon == null:
			weapon_root.queue_free()
			continue
		_weapon_melee.append(bool(weapon_root.get("melee")) if "melee" in weapon_root else false)
		weapon_root.remove_child(icon)
		icon.name = "RemoteWeaponIcon_%d" % i
		## bkz. MAX_WEAPON_ICONS yorumu - i, WEAPON_ICON_SLOTS'un 5 sınırını
		## aşabilir (Talon Ayna Formu), o durumda zaten _update_talon_formation
		## bir sonraki fizik karesinde gerçek konumu verecek; burada sadece
		## dizi sınırı aşımını (crash) önlemek için son slota kenetliyoruz.
		icon.position = WEAPON_ICON_SLOTS[min(i, WEAPON_ICON_SLOTS.size() - 1)]
		# Apply staff textures & scales matching weapon.gd
		## DÜZELTME: weapon.gd _update_hover_follow()'daki is_wand dalı, asa
		## ikonunu (0.99 kendi ölçeği) ÜSTÜNE bir de "weapon_root.scale =
		## parent.scale * 0.3" uyguluyor (net ~0.297) - buradaki uzak oyuncu
		## kuklası o ikinci çarpanı hiç uygulamıyordu, yani asalar diğer
		## herkese (host dahil, kendi ekranındaki gibi) ~3.3 kat BÜYÜK
		## görünüyordu ("asalar kocaman görünüyor, diğer silahlarla aynı
		## boyutta değil" bildirimi). Aynı 0.3 çarpanını burada da uygulayarak
		## yerel görünümle eşitliyoruz.
		const REMOTE_WAND_SCALE_MULT := 0.3
		if key.containsn("arcane") or weapon_root.name.containsn("arcane"):
			if icon is Sprite2D:
				icon.texture = load("res://assets/weapons/arcane/icon_v3.png")
			icon.scale = Vector2(0.99, 0.99) * REMOTE_WAND_SCALE_MULT
		elif key.containsn("fire") or weapon_root.name.containsn("fire"):
			if icon is Sprite2D:
				icon.texture = load("res://assets/weapons/fire/firestaff_icon_v3.png")
			icon.scale = Vector2(0.99, 0.99) * REMOTE_WAND_SCALE_MULT
		elif key.containsn("lightning") or weapon_root.name.containsn("lightning"):
			if icon is Sprite2D:
				icon.texture = load("res://assets/weapons/lightning/icon_v3.png")
			icon.scale = Vector2(0.99, 0.99) * REMOTE_WAND_SCALE_MULT
		elif key.containsn("buz") or weapon_root.name.containsn("buz"):
			if icon is Sprite2D:
				icon.texture = load("res://assets/weapons/buz_asasi/icon_v3.png")
			icon.scale = Vector2(0.99, 0.99) * REMOTE_WAND_SCALE_MULT
		else:
			icon.scale *= 0.9

		# Apply tier-based texture if available
		var tier: int = int(weapon_tiers.get(key, 1))
		if tier > 1 and "tier_icon_textures" in weapon_root:
			var tier_textures: Array = weapon_root.tier_icon_textures
			if tier - 1 < tier_textures.size():
				var tier_tex: Texture2D = tier_textures[tier - 1]
				if tier_tex and icon is Sprite2D:
					icon.texture = tier_tex
		# Silah gölgesi (bkz. weapon.gd shadow_sprite) - o script sadece
		# LOKAL (gerçek) oyuncunun kendi weapon.gd node'unda çalışır; burada
		# uzak oyuncu kuklası için icon'la eşleşen basit, sabit bir gölge
		# elle oluşturuluyor. Sıralamada icon'dan ÖNCE eklenip arkasında
		# çizilir (weapon.gd'deki "negatif z_index KULLANMA" notuyla aynı
		# sebep - kardeş sıralamasıyla arkada tutuluyor, z_index'e dokunulmuyor).
		var shadow := Sprite2D.new()
		shadow.set_script(preload("res://scripts/shadow_blob.gd"))
		const SHADOW_TRANSPARENCY := 0.6
		shadow.modulate = Color(1, 1, 1, 1.0 - SHADOW_TRANSPARENCY)
		var icon_px_size: Vector2 = _measure_remote_icon_pixel_size(icon)
		var half_w: float = max(3.5, icon_px_size.x * icon.scale.x * 0.30 * 0.8)
		var half_h: float = max(2.5, icon_px_size.y * icon.scale.y * 0.30 * 0.55 * 0.8)
		shadow.scale = Vector2(half_w, half_h)
		const REMOTE_SHADOW_GAP := 62.0
		shadow.position = icon.position + Vector2(0, REMOTE_SHADOW_GAP)
		add_child(shadow)
		_weapon_shadows.append(shadow)

		add_child(icon)
		_weapon_icons.append(icon)
		_weapon_base_scales.append(icon.scale)
		_weapon_fire_tweens.append(null)
		## weapon_root silinmeden ÖNCE kendi nişan açısı ayarlarını yakala -
		## bkz. _update_local_weapon_aim (artık ağdan gelmiyor, her silahın
		## KENDİ sprite_forward_angle_deg/mirror_icon_when_aiming_left'i
		## gerçek weapon.gd sahnesinden birebir okunuyor).
		_weapon_forward_angle_deg.append(float(weapon_root.get("sprite_forward_angle_deg")) if "sprite_forward_angle_deg" in weapon_root else 0.0)
		_weapon_mirror_aim.append(bool(weapon_root.get("mirror_icon_when_aiming_left")) if "mirror_icon_when_aiming_left" in weapon_root else false)
		_weapon_icon_flipped.append(false)
		## Hedef seçimi için gerçek weapon.gd davranışının kalan üç parçası -
		## bkz. yukarıdaki _weapon_attack_range yorumu.
		_weapon_attack_range.append(float(weapon_root.get("attack_range")) if "attack_range" in weapon_root else 0.0)
		_weapon_target_highest_health.append(bool(weapon_root.get("target_highest_health")) if "target_highest_health" in weapon_root else false)
		_weapon_target_prefer_unfrozen.append(bool(weapon_root.get("target_prefer_unfrozen")) if "target_prefer_unfrozen" in weapon_root else false)
		## "weapon_fire"/"weapon_recoil" ateş animasyonunun artık ağdan hiç
		## okumadığı, bu silahın KENDİ sabit tanım değerleri - bkz. yukarıdaki
		## _weapon_rest_rotation_deg sınıf üstü notu.
		_weapon_rest_rotation_deg.append(float(weapon_root.get("melee_icon_rest_rotation_deg")) if "melee_icon_rest_rotation_deg" in weapon_root else 0.0)
		_weapon_slash_fx_offset.append(float(weapon_root.get("melee_slash_fx_offset")) if "melee_slash_fx_offset" in weapon_root else 95.0)
		_weapon_slash_fx_above_offset.append(float(weapon_root.get("melee_slash_fx_above_offset")) if "melee_slash_fx_above_offset" in weapon_root else 0.0)
		_weapon_recoil_distance.append(float(weapon_root.get("recoil_distance")) if "recoil_distance" in weapon_root else 10.0)
		_weapon_hit_segments.append(int(weapon_root.get("melee_hit_segments")) if "melee_hit_segments" in weapon_root else 1)
		## bkz. _weapon_is_orbit_sword üstündeki BUG DÜZELTMESİ notu - weapon_
		## root zaten add_child() ile _ready()'sini çalıştırdığı için
		## _is_uzunkilic/fire_rate GERÇEK, hesaplanmış değerleriyle okunabilir.
		_weapon_is_orbit_sword.append(bool(weapon_root.get("_is_uzunkilic")) if "_is_uzunkilic" in weapon_root else false)
		_weapon_fire_rate.append(float(weapon_root.get("fire_rate")) if "fire_rate" in weapon_root else 1.0)
		_weapon_orbit_angle.append(0.0)
		_weapon_base_attack_range.append(float(weapon_root.get("_base_attack_range")) if "_base_attack_range" in weapon_root else 0.0)
		weapon_root.queue_free()


## Menzilli silahların (asa/tabanca/yay vb.) sürekli en yakın düşmana dönen
## nişan rotasyonunu uzaktaki oyuncu kuklasında YEREL olarak hesaplar - bkz.
## weapon.gd _update_aim/_get_nearest_enemy (BİREBİR aynı mantık, aynalama
## dahil). Eskiden bu açı her karede ağdan gönderiliyordu; ama her katılımcı
## zaten hangi yaratıkların nerede olduğunu biliyor (enemy sync sayesinde),
## yani "en yakın düşmana dön" oyunun zaten bildiği bir kural - ağdan hiç
## veri gerekmiyor. Yakın dövüş silahları (_weapon_melee) kendi salınım
## animasyonuyla (_animate_weapon_fire_full) çakışmasın diye atlanır.
## PERFORMANS DÜZELTMESİ (kullanıcı bildirimi: "katılımcıların hala çok feci
## fps sorunu var"): _get_target_for_weapon() (bkz. aşağısı) HER çağrıda
## get_tree().get_nodes_in_group("enemies")'i baştan tarayıp TÜM canlı
## yaratıklara mesafe hesabı yapıyor - bu fonksiyon eskiden HER fizik
## karesinde (60/sn), sahnedeki HER RemotePlayer kuklasının (yani lobideki
## HER diğer oyuncu için) SAHİP OLDUĞU HER silah için ayrı ayrı çağrılıyordu.
## 3 katılımcılı, kişi başı 3 silahlı, 80 yaratıklı bir maçta bu saniyede
## ~3*3*80*60 ≈ 43.000 gereksiz mesafe hesabı + grup taraması demekti - hem
## de SADECE "kim en yakın düşmana baksın" gibi görsel bir detay için,
## saniyede birkaç kez yeniden hesaplansa fark edilmeyecek bir şey. Artık
## asıl (pahalı) hedef ARAMASI AIM_RETARGET_INTERVAL'de bir yapılıp
## sonucu önbelleğe alınıyor - rotasyonun kendisi (lerp) hâlâ her karede
## yumuşakça ilerliyor, sadece "hangi düşman" kararı seyrekleşiyor.
const AIM_RETARGET_INTERVAL := 0.15
var _aim_retarget_timer: float = 0.0
var _cached_aim_targets: Array = []

func _update_local_weapon_aim(delta: float) -> void:
	if _weapon_icons.is_empty():
		return
	_aim_retarget_timer -= delta
	var should_retarget: bool = _aim_retarget_timer <= 0.0
	if should_retarget:
		_aim_retarget_timer = AIM_RETARGET_INTERVAL
		_cached_aim_targets.resize(_weapon_icons.size())
	for i in range(_weapon_icons.size()):
		if i < _weapon_melee.size() and _weapon_melee[i]:
			continue
		if i < _weapon_is_orbit_sword.size() and _weapon_is_orbit_sword[i]:
			continue
		var icon: Node2D = _weapon_icons[i]
		if not is_instance_valid(icon):
			continue
		## Her silah KENDİ konumundan hedef arar (bkz. weapon.gd _attack_origin
		## yorumu) - karakterin merkezinden değil, aksi halde birden fazla
		## silah hep aynı tek düşmana kilitlenir.
		var target: Node2D
		if should_retarget:
			target = _get_target_for_weapon(i, icon.global_position)
			_cached_aim_targets[i] = target
		else:
			target = _cached_aim_targets[i] if i < _cached_aim_targets.size() else null
		if not target or not is_instance_valid(target):
			## weapon.gd _update_aim ile birebir aynı davranış: menzilde hedef
			## yoksa döndürmeyi bırak, son açısında kalsın - rastgele/uzak bir
			## düşmana asla dönmesin.
			continue
		var dir: Vector2 = (target.global_position - icon.global_position).normalized()
		var forward: float = deg_to_rad(_weapon_forward_angle_deg[i] if i < _weapon_forward_angle_deg.size() else 0.0)
		var mirror: bool = _weapon_mirror_aim[i] if i < _weapon_mirror_aim.size() else false
		var t: float = clamp(delta * AIM_EASE_RATE, 0.0, 1.0)
		if not mirror:
			icon.rotation = lerp_angle(icon.rotation, dir.angle() - forward, t)
			continue
		var flip: bool = dir.x < 0.0
		var target_rotation: float = (dir.angle() - PI + forward) if flip else (dir.angle() - forward)
		var was_flipped: bool = _weapon_icon_flipped[i] if i < _weapon_icon_flipped.size() else false
		if flip != was_flipped:
			icon.rotation = target_rotation
			icon.set("flip_h", flip)
			if i < _weapon_icon_flipped.size():
				_weapon_icon_flipped[i] = flip
		else:
			icon.rotation = lerp_angle(icon.rotation, target_rotation, t)


## bkz. _weapon_is_orbit_sword üstündeki BUG DÜZELTMESİ notu - weapon.gd
## _process_uzunkilic_orbit() ile AYNI konum/rotasyon matematiği (artık
## weapon_orbit_math.gd'den TEK kaynaktan çağrılıyor, bkz. o dosyanın başı),
## sadece hasar/çarpışma kısmı YOK (uzak kopya asla gerçek hasar vermez,
## diğer kozmetik kopyalarla AYNI kural).
var _orbit_trail_timer: float = 0.0

func _update_local_uzunkilic_orbit(delta: float) -> void:
	for i in range(_weapon_icons.size()):
		if i >= _weapon_is_orbit_sword.size() or not _weapon_is_orbit_sword[i]:
			continue
		var icon: Node2D = _weapon_icons[i]
		if not is_instance_valid(icon):
			continue
		var base_range: float = _weapon_base_attack_range[i] if i < _weapon_base_attack_range.size() else 0.0
		var cur_range: float = _weapon_attack_range[i] if i < _weapon_attack_range.size() else 0.0
		var range_mult: float = (cur_range / base_range) if base_range > 0.001 else 1.0
		var fr: float = _weapon_fire_rate[i] if i < _weapon_fire_rate.size() else 1.0
		var angle_in: float = _weapon_orbit_angle[i] if i < _weapon_orbit_angle.size() else 0.0
		var orbit: Dictionary = WeaponOrbitMath.compute(delta, angle_in, fr, range_mult, scale.x)
		if i < _weapon_orbit_angle.size():
			_weapon_orbit_angle[i] = orbit["angle"]
		icon.position = orbit["offset"]
		icon.rotation = orbit["rotation"]
		if not icon.visible:
			icon.visible = true
		_orbit_trail_timer -= delta
		if _orbit_trail_timer <= 0.0:
			_orbit_trail_timer = WeaponOrbitMath.TRAIL_INTERVAL
			if get_tree().current_scene:
				WeaponOrbitMath.spawn_trail(get_tree().current_scene, icon.global_position, icon.rotation, range_mult, scale.x)


## Talon'un Silah Salvosu (E)/Ayna Formu (R) yeteneklerindeki dairesel silah
## diziliminin KOZMETİK kopyası - bkz. player.gd _talon_set_weapons_circular
## VE talon_formation_math.gd (TEK ortak formül, iki taraf da SADECE onu
## çağırır). _talon_formation aktif olduğu sürece _physics_process bunu
## normal nişan/orbit güncellemesi YERİNE çağırır.
func _update_talon_formation(delta: float) -> void:
	var count: int = _weapon_icons.size()
	if count == 0:
		return
	var radius: float
	if _talon_formation == "salvo":
		radius = TalonFormationMath.SALVO_RADIUS
		_talon_salvo_angle = TalonFormationMath.advance_salvo_angle(_talon_salvo_angle, delta)
	else: ## "mirror" - sabit dizilim, dönmez
		radius = TalonFormationMath.MIRROR_RADIUS
	for i in range(count):
		var icon: Node2D = _weapon_icons[i]
		if not is_instance_valid(icon):
			continue
		var slot: Dictionary = TalonFormationMath.compute_slot(i, count, radius, _talon_salvo_angle)
		icon.position = slot["offset"]
		var forward: float = deg_to_rad(_weapon_forward_angle_deg[i] if i < _weapon_forward_angle_deg.size() else 0.0)
		icon.rotation = slot["angle"] - forward
		if not icon.visible:
			icon.visible = true


## weapon.gd::_get_target_enemy() ile BİREBİR aynı seçim mantığı - hangi
## hedefleme moduna (en yakın / en yüksek can / donmamış tercih) göre
## saldıracağı, o silahın kendi (weapon_root'tan yakalanan) export
## bayraklarına göre belirlenir. `origin` çağıran ikonun KENDİ konumu.
func _get_target_for_weapon(i: int, origin: Vector2) -> Node2D:
	var max_range: float = _weapon_attack_range[i] if i < _weapon_attack_range.size() else 0.0
	if i < _weapon_target_highest_health.size() and _weapon_target_highest_health[i]:
		return _get_highest_health_enemy_from(origin, max_range)
	if i < _weapon_target_prefer_unfrozen.size() and _weapon_target_prefer_unfrozen[i]:
		return _get_nearest_unfrozen_enemy_from(origin, max_range)
	return _get_nearest_enemy_from(origin, max_range)


func _get_nearest_enemy_from(origin: Vector2, max_range: float) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var d: float = origin.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if nearest == null:
		return null
	if max_range > 0.0 and nearest_dist > max_range:
		return null
	return nearest


## weapon.gd::_get_nearest_unfrozen_enemy() ile birebir aynı - Buz Asası
## için: hiç donmamış düşman yoksa (veya menzil dışındaysa) normal en yakın
## düşmana düşer, asa "hedefsiz" kalmasın diye.
func _get_nearest_unfrozen_enemy_from(origin: Vector2, max_range: float) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for e in enemies:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if e.get("is_frozen") == true:
			continue
		var d: float = origin.distance_to(e.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	if nearest == null:
		return _get_nearest_enemy_from(origin, max_range)
	if max_range > 0.0 and nearest_dist > max_range:
		return _get_nearest_enemy_from(origin, max_range)
	return nearest


## weapon.gd::_get_highest_health_enemy() ile birebir aynı - Tüftüf için.
func _get_highest_health_enemy_from(origin: Vector2, max_range: float) -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	var best: Node2D = null
	var best_health: float = -INF
	for e in enemies:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if max_range > 0.0 and origin.distance_to(e.global_position) > max_range:
			continue
		var h: float = e.get("health") if "health" in e else 0.0
		if h > best_health:
			best_health = h
			best = e
	return best


## SÜREKLİ kanal (bkz. main.gd _rpc_update_player_transform, unreliable,
## ~20Hz): sadece her karede gerçekten değişebilecek şeyler - konum ve o anki
## animasyon adı. Kullanıcı bildirimi: "bağlantım yaratıkların/silahların
## animasyonlarını bile veri olarak gönderiyor, halbuki bunlar oyunun
## kodlarıyla otomatik çalışmalı" - haklıydı; can/kalkan/silah envanteri/
## durum efektleri gibi NADİREN değişen veriler eskiden bu fonksiyonun
## İÇİNDE, aynı sıklıkta gönderiliyordu (bkz. update_extra_state_from_net,
## sadece değiştiğinde çalışır), silah nişan dönüşü de artık hiç ağdan
## gelmiyor (bkz. _update_local_weapon_aim - tamamen yerel hesaplanıyor).
func update_position_and_anim_from_net(pos: Vector2, cur_anim: String) -> void:
	## bkz. yukarıdaki _network_velocity sınıf üstü notu - enemy.gd
	## update_network_state() ile BİREBİR aynı türetme.
	if _position_received and _network_time_since_update > 0.02:
		var raw_velocity: Vector2 = (pos - _target_position) / _network_time_since_update
		if raw_velocity.length() > NETWORK_MAX_EXTRAPOLATE_SPEED:
			raw_velocity = raw_velocity.normalized() * NETWORK_MAX_EXTRAPOLATE_SPEED
		_network_velocity = raw_velocity
	else:
		_network_velocity = Vector2.ZERO
	_network_time_since_update = 0.0
	_position_received = true
	_target_position = pos
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(cur_anim):
		if anim.animation != cur_anim:
			anim.play(cur_anim)
		elif cur_anim.begins_with("spellcast") and not anim.is_playing():
			## DÜZELTME (derin multiplayer görsel denetimi: "Büyücü Kız'ın
			## Meteor kanalı uzak ekranlarda donuyor") - spellcast animasyonu
			## kendi kendine döngü yapmıyor (bkz. player.gd
			## _process_buyucu_meteor'daki yerel zorla-yeniden-oynatma). Bu
			## fonksiyon animasyon ADI DEĞİŞMEDİĞİ sürece play() çağırmadığı
			## için 5 saniyelik kanal boyunca uzak oyuncular karakterin son
			## karede donduğunu görüyordu - burada da aynı şekilde yeniden
			## başlatıyoruz.
			anim.play(cur_anim)


## DURUM kanalı (bkz. main.gd _rpc_update_player_extra_state, reliable):
## can, kalkan, silah envanteri, durum efektleri gibi nadiren değişen her şey.
## Gönderen taraf (main.gd) bunu SADECE bir önceki gönderilenden farklıysa
## (ya da birkaç saniyede bir "heartbeat" olarak) yolluyor - burada özel bir
## işlem gerekmiyor, gelen her çağrı zaten "uygulanması gereken yeni durum".
## bkz. dosya başındaki "efekt sistemi" DÜZELTME notu - player.gd'deki AYNI
## reaktif desen, sadece is_dead/is_downed/health/max_health parametre
## olarak (henüz atanmadan ÖNCE, eski değerlerle) değil GÜNCEL değerleriyle
## çağrılıyor (bkz. update_extra_state_from_net içindeki çağrı yeri - alanlar
## atandıktan HEMEN SONRA çağrılıyor).
func _update_death_status_fx() -> void:
	if is_dead:
		if not _death_status_fx or not is_instance_valid(_death_status_fx):
			_death_status_fx = FxDeathScene.instantiate()
			add_child(_death_status_fx)
	elif _death_status_fx and is_instance_valid(_death_status_fx):
		_death_status_fx.queue_free()
		_death_status_fx = null


func _update_revive_rewind_fx() -> void:
	## bkz. player.gd get_revive_progress_ratio üstündeki yorum - downed iken
	## health/max_health GERÇEK can yerine diriltme oranını taşıyor.
	var ratio: float = (health / max_health) if (is_downed and max_health > 0.0) else 0.0
	if is_downed and ratio > 0.0:
		if not _revive_rewind_fx or not is_instance_valid(_revive_rewind_fx):
			_revive_rewind_fx = FxReviveRewindScene.instantiate()
			add_child(_revive_rewind_fx)
		if _revive_rewind_fx.has_method("set_progress"):
			_revive_rewind_fx.set_progress(ratio)
	elif _revive_rewind_fx and is_instance_valid(_revive_rewind_fx):
		_revive_rewind_fx.queue_free()
		_revive_rewind_fx = null

	if _was_downed_for_heart_fx and not is_downed and not is_dead:
		var heart := FxReviveHeartScene.instantiate()
		add_child(heart)
	_was_downed_for_heart_fx = is_downed


func update_extra_state_from_net(hp: float, max_hp: float, s_hp: float, s_max: float, p_zone: bool, dead: bool, weapon_keys: Array, extra: Dictionary = {}) -> void:
	update_weapon_visuals(weapon_keys, extra.get("weapon_tiers", {}))
	health = hp
	max_health = max_hp
	item_shield_hp = s_hp
	item_shield_max = s_max
	paladin_zone_active = p_zone

	# Handle death state change
	if dead and not is_dead:
		_play_death_animation()
	is_dead = dead
	is_downed = extra.get("is_downed", false)
	_update_death_status_fx()
	_update_revive_rewind_fx()
	is_indoors = extra.get("is_indoors", false)
	is_in_merchant_zone = extra.get("is_in_merchant_zone", false)
	match_damage_dealt = extra.get("dmg_dealt", 0.0)
	if downed_timer_label:
		downed_timer_label.set_remaining_seconds(extra.get("downed_remaining", 0.0) if is_downed else 0.0)

	# Apply character modulate (invisibility, rage tint, etc.)
	## DÜZELTME (derin multiplayer görsel denetimi, kök neden): bazı
	## yetenekler tonu KÖK `modulate` üzerine uyguluyor (Godot'ta CanvasItem
	## modulate alt öğelere çarpımsal yayılır), bazıları `anim.modulate`
	## üzerine - main.gd artık ikisinin çarpımını (caster'ın GERÇEKTEN
	## gördüğü etkin renk) gönderiyor. Burada da bunu `anim.modulate` yerine
	## KÖK `modulate`'e uyguluyoruz ki hem anim'e hem de silah
	## ikonlarına/gölgelerine (anim'in KARDEŞİ, add_child ile köke
	## eklendiği için - bkz. update_weapon_visuals) doğru şekilde yayılsın.
	if extra.has("modulate"):
		modulate = Color(extra["modulate"])
	elif is_downed:
		## Yerde yatan (downed) müttefik griye boyanır ki diğer oyuncular
		## kimin canlandırılmayı beklediğini görsel olarak ayırt edebilsin.
		modulate = Color(0.5, 0.5, 0.55, 1.0)
	elif extra.get("is_invisible", false):
		modulate = Color(1.0, 1.0, 1.0, 0.35)
	else:
		modulate = Color.WHITE

	# Update paladin barrier visual
	if extra.get("is_shielded", false) or paladin_zone_active:
		_ensure_barrier_visual()
	else:
		_remove_barrier_visual()

	# Matthew dome visual
	if extra.get("matthew_dome", false):
		_ensure_matthew_dome_visual()
	else:
		_remove_matthew_dome_visual()

	## DÜZELTME (derin multiplayer görsel denetimi): Elara'nın "Çift Tetik"
	## ve Kurt Adam'ın "Kudurmuş Saldırı" efektleri TEK SEFERLİK (kısa süreli,
	## kendi kendini yok eden) sahnelerdir - aktivasyon anında zaten
	## _broadcast_skill_scene ile doğru şekilde bir kez yayınlanıyor (bkz.
	## player.gd _skill_elara_double_fire / _skill_kurtadam_ulti). Burada
	## "extra" durum bayrağı true kaldığı sürece (25s / 30s boyunca) bu
	## tek-seferlik sahneyi _ensure_overlay ile tekrar tekrar yeniden
	## başlatıyorduk - efekt kendi kendine bitip _ensure_overlay'in
	## is_instance_valid kontrolünü geçersiz kıldığı anda, bir sonraki durum
	## güncellemesinde yeniden doğuyordu. Sonuç: uzak oyuncular caster'ın
	## SADECE BİR KEZ gördüğü patlama/parıltı efektini ~1.3-2 saniyede bir
	## tekrar tekrar (sesiyle birlikte) görüyordu. Kurt Adam'ın kalıcı kızıl
	## tonu artık yukarıdaki "modulate" senkronuyla zaten doğru gösteriliyor;
	## Elara'nın 25s'lik etkisi için ayrıca kalıcı bir görsel yoktu (caster da
	## sadece aktivasyon anında görüyor), o yüzden burada hiçbir şey
	## eklemiyoruz - eski hatalı tekrar mantığını tamamen kaldırıyoruz.

	# Talon Devleşme (YENİ ULTİ) - boyut büyümesi diğer oyunculara da yansısın
	# (bkz. main.gd extra["talon_giant"] / player.gd _talon_ulti_active).
	if extra.get("talon_giant", false):
		if not _talon_giant_active:
			_talon_giant_active = true
			if anim and is_instance_valid(anim):
				anim.scale = _base_anim_scale * 2.0
	elif _talon_giant_active:
		_talon_giant_active = false
		if anim and is_instance_valid(anim):
			anim.scale = _base_anim_scale

	## Talon Silah Salvosu/Ayna Formu (bkz. main.gd extra["talon_formation"] /
	## _update_talon_formation) - HERHANGİ bir TAZE geçişte dönüş açısını
	## sıfırlıyoruz ki her aktivasyon caster'la aynı şekilde 0'dan başlasın
	## (bkz. player.gd _skill_talon_weapon_salvo() _talon_salvo_elapsed = 0.0
	## VE _skill_talon_mirror_form()'un HER ZAMAN 0.0 ile çağırdığı
	## _talon_set_weapons_circular). DÜZELTME (kullanıcı bildirimi: "talonun
	## yetenek animasyonları diğer oyunculara yanlış gösteriliyor") - eskiden
	## SADECE "salvo"ya geçişte sıfırlanıyordu, "mirror"a geçişte DEĞİL. Salvo
	## (E) her kullanımda _talon_salvo_angle'ı ilerletip DÖNMÜŞ bir değerde
	## bırakıyor (sıfırlanmıyor); sonra Ayna Formu (R) tetiklenince remote
	## tarafta bu ESKİ/rastgele açı Ayna Formu'nun (dönmeyen, sabit) dizilimi
	## için kullanılıyordu - caster'da HER ZAMAN 0.0'dan başlayan sabit
	## dizilimle eşleşmeyip silahlar uzak ekranlarda yanlış konum/rotasyonda
	## görünüyordu.
	var new_talon_formation: String = extra.get("talon_formation", "")
	if new_talon_formation != "" and _talon_formation != new_talon_formation:
		_talon_salvo_angle = 0.0
	_talon_formation = new_talon_formation

	if overhead_bar:
		overhead_bar.set_health(health, max_health)
		overhead_bar.set_shield(item_shield_hp, item_shield_max)

	if shield_visual:
		## DÜZELTME (derin multiplayer görsel denetimi): kalkanın GÖRSEL türü
		## (standart/enerji/kale/savaş - bkz. player.gd SHIELD_TYPES /
		## _owned_shield_type_key) hiç senkronize edilmiyordu, uzak oyuncular
		## her zaman varsayılan (standart) baloncuk görselini görüyordu.
		shield_visual.set_shield_type(extra.get("shield_type", ""))
		## DÜZELTME (kullanıcı bildirimi #41): eskiden salt "item_shield_hp >
		## 0.0" kontrolü kalkan dolu dururken bile baloncuğu sürekli
		## gösteriyordu. Artık gönderen tarafın gerçek _bubble_active kararını
		## (bkz. main.gd extra["shield_bubble_visible"] / player.gd
		## _update_shield_bubble) doğrudan kullanıyoruz.
		shield_visual.visible = extra.get("shield_bubble_visible", item_shield_hp > 0.0 or paladin_zone_active)
	## Şovalye Adam'ın Koruma Bariyeri (skill3 id 29) - bkz. main.gd extra
	## dict/fx_paladin_barrier_link.gd. shield_bubble_visible ile AYNI
	## desen, sadece basit bir spawn/despawn child (hazır sahne node'u yok).
	_refresh_barrier_link_visual(extra.get("barrier_link_active", false))


func _play_death_animation() -> void:
	var anim_name: String = "death"
	if anim and anim.sprite_frames and not anim.sprite_frames.has_animation("death") and anim.sprite_frames.has_animation("hurt"):
		anim_name = "hurt"
		
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)
		var tw := create_tween()
		tw.tween_property(anim, "modulate:a", 0.0, 0.6).set_delay(0.8)
		tw.tween_callback(queue_free)
	else:
		# No death animation - just fade and free
		var tw := create_tween()
		var target_node: CanvasItem = anim
		if target_node == null:
			target_node = self
		tw.tween_property(target_node, "modulate:a", 0.0, 0.6)
		tw.tween_callback(queue_free)


# Matthew dome visual (simplified - just a colored circle indicator)
var _matthew_dome_fx: Node2D = null

## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "matthewin kalkan
## efekti diğer oyunculara farklı gösteriliyor") - kök neden: bu fonksiyon
## Matthew'in turuncu/tilki kulaklı kalkanı (res://scenes/fx_matthew_fox_
## shield.tscn, bkz. player.gd _skill_shield_dome/_matthew_fox_shield_fx)
## yerine, muhtemelen kopyala-yapıştırla, Şovalye'nin (Paladin) TAMAMEN
## FARKLI mavi baloncuk script'ini (fx_paladin_barrier.gd - bkz. aşağıdaki
## GERÇEK Paladin kullanımı _ensure_barrier_visual) çiziyordu. Uzak
## oyuncular Matthew'in gerçek görselini hiç görmüyor, yanlış karaktere ait
## mavi bir halka görüyordu, ayrıca kapanışta pop/küçülme animasyonu yerine
## anlık kayboluyordu. Artık caster'ın kendi ekranındaki GERÇEK sahne
## kullanılıyor (bkz. player.gd _skill_shield_dome/_pop_matthew_dome ile
## BİREBİR AYNI script/metod).
func _ensure_matthew_dome_visual() -> void:
	if _matthew_dome_fx and is_instance_valid(_matthew_dome_fx):
		return
	var shield_scene: PackedScene = load("res://scenes/fx_matthew_fox_shield.tscn") as PackedScene
	if not shield_scene:
		return
	_matthew_dome_fx = shield_scene.instantiate() as Node2D
	add_child(_matthew_dome_fx)

func _remove_matthew_dome_visual() -> void:
	if _matthew_dome_fx and is_instance_valid(_matthew_dome_fx):
		if _matthew_dome_fx.has_method("pop"):
			_matthew_dome_fx.pop()
		else:
			_matthew_dome_fx.queue_free()
	_matthew_dome_fx = null


var _barrier_visual: Node2D = null

func _ensure_barrier_visual() -> void:
	if _barrier_visual and is_instance_valid(_barrier_visual):
		return
	## Bkz. _ensure_matthew_dome_visual üzerindeki yorum - "fx_paladin_barrier.tscn"
	## diye bir sahne hiç yoktu, bu bir script (res://scripts/fx_paladin_barrier.gd)
	## olarak doğrudan bir Node2D'ye atanmalı (bkz. player.gd _skill_paladin_ulti).
	_barrier_visual = Node2D.new()
	_barrier_visual.set_script(load("res://scripts/fx_paladin_barrier.gd"))
	add_child(_barrier_visual)

func _remove_barrier_visual() -> void:
	if _barrier_visual and is_instance_valid(_barrier_visual):
		_barrier_visual.queue_free()
		_barrier_visual = null


## Şovalye Adam'ın Koruma Bariyeri (skill3 id 29) - bkz. main.gd extra
## dict/fx_paladin_barrier_link.gd/player.gd damage_redirect_*. Basit bir
## spawn/despawn child - _ensure_barrier_visual gibi hazır bir .tscn yok,
## script doğrudan bir Node2D'ye atanıyor.
var _barrier_link_fx: Node2D = null

func _refresh_barrier_link_visual(active: bool) -> void:
	if active:
		if not _barrier_link_fx or not is_instance_valid(_barrier_link_fx):
			_barrier_link_fx = Node2D.new()
			_barrier_link_fx.set_script(load("res://scripts/fx_paladin_barrier_link.gd"))
			add_child(_barrier_link_fx)
	elif _barrier_link_fx and is_instance_valid(_barrier_link_fx):
		_barrier_link_fx.queue_free()
		_barrier_link_fx = null


## Network VFX helpers — called by broadcast_player_vfx RPC.

func _spawn_burst_vfx(radius: float, col: Color) -> void:
	var burst: Node2D = load("res://scenes/fx_skill_burst.tscn").instantiate() as Node2D
	add_child(burst)
	if burst.has_method("setup"):
		burst.setup(radius, col)

func _spawn_ring_vfx(radius: float, col: Color) -> void:
	var ring: Node2D = load("res://scenes/fx_skill_ring.tscn").instantiate() as Node2D
	add_child(ring)
	if ring.has_method("setup"):
		ring.setup(radius, col)

## Lightning beam VFX — managed on remote player by broadcast_player_vfx.
var _beam_fx: Node2D = null

func _start_beam_vfx(_beam_type: String, target_pos: Vector2, extra_data: Dictionary) -> void:
	if _beam_fx and is_instance_valid(_beam_fx):
		_beam_fx.queue_free()
		_beam_fx = null
	var beam_scene: PackedScene = load("res://scenes/fx_lightning_beam.tscn") as PackedScene
	if beam_scene:
		_beam_fx = beam_scene.instantiate() as Node2D
		add_child(_beam_fx)
		if _beam_fx.has_method("setup_network"):
			_beam_fx.setup_network(target_pos, extra_data)

func _stop_beam_vfx() -> void:
	if _beam_fx and is_instance_valid(_beam_fx):
		_beam_fx.queue_free()
		_beam_fx = null

func _update_beam_vfx(target_pos: Vector2, origin_pos: Vector2 = Vector2.ZERO) -> void:
	if _beam_fx and is_instance_valid(_beam_fx) and _beam_fx.has_method("update_target"):
		_beam_fx.update_target(target_pos, origin_pos)


## Pet visuals — spawns simplified visual-only pets on remote players (bkz.
## player.gd broadcast_pet_spawn/_despawn çağrıları).
## BUG DÜZELTMESİ (kullanıcı bildirimi: "Necromancer yaratık çağırınca diğer
## oyuncular yaratığı hiç görmüyor"): burası eskiden TEK bir "_pet_visual"
## slotuna sahipti - yeni bir "pet_spawn" geldiğinde HER ZAMAN öncekini
## queue_free() edip yerine geçiyordu. Bu, Matthew'in HER ZAMAN tek bir
## pet'i olduğu için görünmüyordu, ama Necromancer'ın temel yeteneği
## (İskelet Çağır, bkz. player.gd _activate_skill2 skill2_id==19 "cooldown
## yok, ruh yettiğince çağrılabilir" kuralı) aynı anda BİRDEN FAZLA yaratık
## yaşatabiliyor - ikinci bir iskelet çağrıldığında diğer istemcilerde
## BİRİNCİNİN kozmetik kopyası silinip ikincisiyle değiştiriliyordu, yani
## aynı anda 3-4 iskelet varken diğer oyuncular sadece EN SON çağrılanı
## görüyordu (ve o da ölüp yenisi çağrılınca o da kayboluyordu - pratikte
## "yaratığı hiç görmüyorum" izlenimi veriyordu). Şimdi her çağırmaya
## player.gd tarafından üretilen BENZERSİZ bir "instance_id" eşlik ediyor ve
## kopyalar id'ye göre ayrı ayrı bir Dictionary'de tutuluyor - Matthew de
## (tek, sabit bir id ile) aynı mekanizmayı kullanıyor, davranışı değişmedi.
var _pet_visuals: Dictionary = {} ## instance_id(String) -> Node2D

func _spawn_pet_visual(pet_scene_path: String, instance_id: String = "") -> void:
	if instance_id.is_empty():
		instance_id = "_default" ## geriye dönük uyumluluk (id göndermeyen eski çağrılar)
	_despawn_pet_visual(instance_id)
	if pet_scene_path.is_empty() or not ResourceLoader.exists(pet_scene_path):
		return
	var pet_scene: PackedScene = load(pet_scene_path) as PackedScene
	if not pet_scene:
		return
	var pet_visual: Node2D = pet_scene.instantiate() as Node2D
	## DÜZELTME (Necromancer yaratıkları diğer oyunculara ufacık görünüyor):
	## burası eskiden pet_visual'i `self`'in (RemotePlayer) ÇOCUĞU yapıyordu.
	## remote_player.tscn'nin kök düğümünde gizli bir `scale = Vector2(0.5,
	## 0.5)` var (uzaktaki oyuncu kuklasını küçültmek için) - pet buraya
	## eklenince bu ölçeği de MİRAS ALIP yarı boyutta görünüyordu. Gerçek
	## pet (sahibinin kendi ekranında) sahneye DOĞRUDAN (ölçeksiz)
	## eklendiğinden ikisi arasında fark oluşuyordu. Artık kozmetik kopya da
	## GERÇEK pet ile birebir aynı şekilde sahnenin köküne ekleniyor.
	get_tree().current_scene.add_child(pet_visual)
	pet_visual.global_position = global_position
	pet_visual.set_meta("network_spawned", true)
	# Disable combat functionality on visual pet
	if pet_visual is Area2D:
		pet_visual.set_deferred("monitoring", false)
	## DÜZELTME (Necromancer yaratıkları diğer oyunculara ÇOK HIZLI/rastgele
	## hareket ederken görünüyor): kozmetik kopya, GERÇEK pet ile AYNI script'i
	## (skeleton_pet.gd/wraith_pet.gd/player_pet.gd) taşıyor ve owner_player
	## hiç set edilmediği için o script'in normal "sahibi takip et" mantığı
	## devre dışı kalıyor - AMA Necromancer'ın yaratıkları hedef ararken
	## sahibe değil DOĞRUDAN "enemies" grubuna bakıyor, yani kozmetik kopya
	## KENDİ BAŞINA, gerçek pet'ten tamamen bağımsız bir yapay zekayla en
	## yakın yaratığı kovalıyordu - varsayılan (host'taki gerçek hıza göre
	## ÖLÇEKLENMEMİŞ) hızda, senkronize olmayan bir hedefe. Artık
	## mark_as_network_visual() ile bu bağımsız yapay zeka TAMAMEN
	## kapatılıyor; kozmetik kopya artık SADECE _update_pet_visual_state()
	## üzerinden gelen gerçek pet konumuna/yönüne yumuşakça kayan (enemy.gd
	## istemci tarafının konum senkronu ile AYNI desen) bir kukla.
	## BUG DÜZELTMESİ (kullanıcı bildirimi: "şaman'ın kalkan totemi dost
	## oyunculara kalkan verme efekti görünmüyor") - kök neden: totem_shield.gd
	## _spawn_shield_waves() (kozmetik dalga efekti, bkz. orada) `caster` null
	## olduğunda sessizce hiçbir şey çizmiyor - ama kozmetik totem kopyaları
	## için `caster` BURADA hiç set edilmiyordu, sadece GERÇEK totemi diken
	## client'ta player.gd _spawn_shaman_totem() bunu yapıyordu. Artık totem
	## kopyalarına (SADECE totem - `setup_from_player` adı skeleton_pet.gd/
	## wraith_pet.gd/golem_pet.gd/papagan_pet.gd/player_pet.gd'de DE var ama
	## FARKLI imzalarla, o yüzden `is TotemBase` ile daralt, aksi halde yanlış
	## imzayla çağrı hata verir) sahibinin bu client'taki KENDİ kuklasını
	## (self) `caster` olarak veriyoruz - dalga artık her client'ta görünür.
	if pet_visual is TotemBase:
		pet_visual.setup_from_player(self)
	if pet_visual.has_method("mark_as_network_visual"):
		pet_visual.mark_as_network_visual()
	_pet_visuals[instance_id] = pet_visual
	## Kozmetik kopya sahneden HERHANGİ bir sebeple (kendi ömrü, harici bir
	## queue_free, vs.) çıkarsa sözlükten HEMEN silinsin - yoksa burada kalan
	## artık geçersiz referans, ileride _despawn_pet_visual() tarafından
	## okunduğunda "Trying to assign invalid previously freed instance"
	## çökmesine yol açıyordu (bkz. kullanıcı bildirimi + ekran görüntüsü:
	## oyunculardan biri bu hatayla oyunun kapandığını bildirdi).
	pet_visual.tree_exiting.connect(func() -> void:
		if _pet_visuals.get(instance_id) == pet_visual:
			_pet_visuals.erase(instance_id)
	)


func _despawn_pet_visual(instance_id: String = "") -> void:
	if instance_id.is_empty():
		# Eski (id'siz) despawn çağrısı - hepsini temizle, geriye dönük uyumluluk.
		for key in _pet_visuals.keys():
			var p = _pet_visuals[key]
			if is_instance_valid(p):
				p.queue_free()
		_pet_visuals.clear()
		return
	if _pet_visuals.has(instance_id):
		## DÜZELTME (çökme: "Trying to assign invalid previously freed
		## instance"): kozmetik kopya kendi kendine (örn. eski bir AI/lifespan
		## kalıntısı ya da harici queue_free) sahneden çıkmış ama sözlükteki
		## referans hâlâ duruyorsa, bunu STATİK TİPLİ (`var p: Node = ...`)
		## bir değişkene atamak Godot'ta "geçersiz, önceden serbest bırakılmış
		## instance" hatasıyla TÜM istemciyi çökertiyordu. Artık (bkz.
		## network_manager.gd remove_drop()'taki AYNI kalıp) tipsiz değişken +
		## is_instance_valid() kontrolü kullanılıyor.
		var p = _pet_visuals[instance_id]
		if is_instance_valid(p):
			p.queue_free()
		_pet_visuals.erase(instance_id)


## broadcast_pet_state RPC'sinin (bkz. network_manager.gd) çağırdığı istemci
## tarafı karşılığı - Necromancer/Matthew'in GERÇEK pet'i (sahibinin
## ekranında) kendi konumunu/saldırı durumunu periyodik olarak yayınlar,
## burası da o veriyi ilgili kozmetik kopyaya (instance_id ile eşleşen)
## iletip enemy.gd'nin istemci tarafı konum senkronuyla AYNI şekilde
## yumuşakça oraya kaymasını sağlar - artık kendi başına rastgele/hızlı
## dolaşmıyor, gerçek pet'i BİREBİR takip ediyor.
## DÜZELTME (Golem'in can/kalkan çubuğu diğer oyunculara hiç senkron
## olmuyordu - bkz. golem_pet.gd update_network_golem_state/network_manager.gd
## broadcast_pet_state'in genişletilmiş imzası): health_ratio/shield_ratio
## artık buraya da ulaşıyor. health_ratio negatifse (varsayılan -1.0, bkz.
## network_manager.gd) gönderen pet'in çubuğu yok demektir (İskelet/Hortlak/
## Matthew'in tilkisi) - o zaman eskisi gibi genel update_network_pet_state'e
## düşülür. 0.0-1.0 arası GERÇEK bir oran geldiyse VE kozmetik kopya Golem'e
## özgü update_network_golem_state metoduna sahipse ONUN üzerinden gidilir.
func _update_pet_visual_state(instance_id: String, pos: Vector2, is_attacking: bool, health_ratio: float = -1.0, shield_ratio: float = -1.0, sprite_row: int = -1) -> void:
	if not _pet_visuals.has(instance_id):
		return
	var p = _pet_visuals[instance_id]
	if not is_instance_valid(p):
		return
	if health_ratio >= 0.0 and p.has_method("update_network_golem_state"):
		p.update_network_golem_state(pos, is_attacking, health_ratio, shield_ratio, sprite_row)
	elif p.has_method("update_network_pet_state"):
		p.update_network_pet_state(pos, is_attacking, sprite_row)


## BUG DÜZELTMESİ (derin multiplayer denetimi bulgusu: "boomerang ve fişek
## ... diğer oyunculara yeni bir projectile fırlatılıyormuş gibi görünüyor")
## - bkz. weapon.gd _broadcast_weapon_icon_visibility notu. Boomerang/fişek
## havadayken (ve tabanca reload'dayken) caster'ın kendi ekranında kafadaki
## ikon gizlenir - bu artık uzak kopyaya da uygulanıyor, yoksa GERÇEKTEN uçan
## mermiyle kafadaki (hâlâ görünür) ikon üst üste binip "iki tane" gibi
## görünüyordu.
func _set_weapon_icon_visible(slot_index: int, is_visible: bool) -> void:
	if slot_index < 0 or slot_index >= _weapon_icons.size():
		return
	var icon: Node2D = _weapon_icons[slot_index]
	if is_instance_valid(icon):
		icon.visible = is_visible
	if slot_index < _weapon_shadows.size():
		var shadow: Node2D = _weapon_shadows[slot_index]
		if is_instance_valid(shadow):
			shadow.visible = is_visible


## Weapon icon recoil animation for remote players. recoil_dist artık ağdan
## gelmiyor - bu silahın KENDİ sabit recoil_distance'ı (bkz.
## _weapon_recoil_distance) kullanılıyor.
func _animate_weapon_recoil(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _weapon_icons.size():
		return
	var icon: Node2D = _weapon_icons[slot_index]
	if not is_instance_valid(icon):
		return
	var recoil_dist: float = _weapon_recoil_distance[slot_index] if slot_index < _weapon_recoil_distance.size() else 10.0
	var base_pos: Vector2 = WEAPON_ICON_SLOTS[slot_index] if slot_index < WEAPON_ICON_SLOTS.size() else icon.position
	# Quick kick-back tween
	var tw := create_tween()
	tw.tween_property(icon, "position", base_pos + Vector2(0, recoil_dist), 0.04)
	tw.tween_property(icon, "position", base_pos, 0.08).set_delay(0.02)


## Kapsamlı silah ateş animasyonu — ana oyuncunun weapon.gd'deki tam birebir
## _do_melee_swing zigzag + hold + ease dönüşü ve _do_recoil mekanizmasını
## uzaktaki oyuncu kuklası üzerinde de oynatır.
## DÜZELTME (mimari sadeleştirme): is_melee/reps/forward_deg/rest_rotation_deg/
## slash_fx_offset/slash_fx_above_offset artık `data` (ağdan gelen) yerine bu
## silahın update_weapon_visuals()'ta yakalanmış KENDİ sabit değerlerinden
## okunuyor - bkz. sınıf üstündeki _weapon_rest_rotation_deg notu. `data`'da
## artık SADECE gerçekten o ana özel olan şeyler var: yön, (yakın dövüşse)
## vuruş noktası, tutma süresi.
func _animate_weapon_fire_full(data: Dictionary) -> void:
	var slot_index: int = int(data.get("slot_index", 0))
	if slot_index < 0 or slot_index >= _weapon_icons.size():
		return
	var icon: Node2D = _weapon_icons[slot_index]
	if not is_instance_valid(icon):
		return
	var base_pos: Vector2 = WEAPON_ICON_SLOTS[slot_index] if slot_index < WEAPON_ICON_SLOTS.size() else icon.position
	var is_melee: bool = _weapon_melee[slot_index] if slot_index < _weapon_melee.size() else bool(data.get("is_melee", false))
	var dir := Vector2(float(data.get("direction_x", 0.0)), float(data.get("direction_y", -1.0)))
	if dir.is_zero_approx():
		dir = Vector2.UP
	else:
		dir = dir.normalized()

	if is_melee:
		var target_pos := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		var reps: int = _weapon_hit_segments[slot_index] if slot_index < _weapon_hit_segments.size() else 3
		var forward: float = deg_to_rad(_weapon_forward_angle_deg[slot_index] if slot_index < _weapon_forward_angle_deg.size() else 0.0)
		var rest_rot: float = deg_to_rad(_weapon_rest_rotation_deg[slot_index] if slot_index < _weapon_rest_rotation_deg.size() else 0.0)
		var slash_offset: float = _weapon_slash_fx_offset[slot_index] if slot_index < _weapon_slash_fx_offset.size() else 18.0
		var slash_above: float = _weapon_slash_fx_above_offset[slot_index] if slot_index < _weapon_slash_fx_above_offset.size() else 0.0
		var hold_duration: float = float(data.get("hold_duration", 0.0))
		
		var dist: float = global_position.distance_to(target_pos)
		var strike_center: Vector2 = base_pos + dir * max(0.0, dist - slash_offset) + Vector2(0.0, -slash_above)
		var perp := Vector2(-dir.y, dir.x)
		var points: Array[Vector2] = []
		for i in range(reps):
			var side: float = 1.0 if i % 2 == 0 else -1.0
			points.append(strike_center + perp * 24.0 * side)
			
		var tw := create_tween()
		var prev_p: Vector2 = base_pos
		for i in range(points.size()):
			var p: Vector2 = points[i]
			var seg_dir: Vector2 = p - prev_p
			var seg_rot: float = (seg_dir.angle() - forward) if seg_dir.length() > 1.0 else (dir.angle() - forward)
			var dur: float = 0.12 if i == 0 else 0.09
			tw.tween_property(icon, "position", p, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(icon, "rotation", seg_rot, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			prev_p = p
			
		if hold_duration > 0.0:
			tw.tween_interval(hold_duration)
			
		tw.tween_property(icon, "position", base_pos, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.parallel().tween_property(icon, "rotation", rest_rot, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		var recoil_dist: float = _weapon_recoil_distance[slot_index] if slot_index < _weapon_recoil_distance.size() else 8.0
		var kick: Vector2 = -dir * recoil_dist
		## SABİT taban ölçek (bkz. _weapon_base_scales üzerindeki yorum) -
		## eskiden "icon.scale" (o an ne kadar büyümüşse) okunuyordu, hızlı
		## ateşte tween tam bitmeden yeni ateş gelince taban da büyümüş
		## yakalanıp üstüne bir kat daha ekleniyordu -> sınırsız büyüme.
		var base_scale: Vector2 = _weapon_base_scales[slot_index] if slot_index < _weapon_base_scales.size() else icon.scale
		
		# If this is an AnimatedSprite2D (e.g. Bow / Yay) with "draw" animation
		if icon is AnimatedSprite2D and icon.sprite_frames and icon.sprite_frames.has_animation("draw"):
			var held_arrow: Node2D = icon.get_node_or_null("HeldArrow") as Node2D
			if held_arrow:
				held_arrow.visible = false
			icon.stop()
			icon.frame = 0
			
			# Schedule next draw cycle
			get_tree().create_timer(0.1).timeout.connect(func():
				if is_instance_valid(icon) and icon is AnimatedSprite2D:
					if held_arrow and is_instance_valid(held_arrow):
						held_arrow.visible = true
						held_arrow.position.x = 0.0
					icon.play("draw")
			)
		
		## Önceki ateşten kalan (henüz bitmemiş) tween varsa öldürülür - üst
		## üste binen tween'ler aynı sabit hedeflere gittiği için artık
		## büyümeye katkı yapamaz, ama yine de titremeyi önlemek için kesilir.
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		
		var tw := create_tween()
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = tw
		tw.set_parallel(true)
		tw.tween_property(icon, "position", base_pos + kick, 0.04)
		tw.tween_property(icon, "scale", base_scale * 1.15, 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().set_parallel(true)
		tw.tween_property(icon, "position", base_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(icon, "scale", base_scale, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## Eski format için geri uyumluluk.
func _animate_weapon_fire(slot_index: int, fire_direction: Vector2, is_melee: bool, atk_range: float) -> void:
	_animate_weapon_fire_full({
		"slot_index": slot_index,
		"direction_x": fire_direction.x,
		"direction_y": fire_direction.y,
		"is_melee": is_melee,
		"attack_range": atk_range,
	})


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = min(max_health, health + amount)
	if overhead_bar:
		overhead_bar.set_health(health, max_health)
	_heal_display_accum += amount
	if _heal_display_accum >= 1.0:
		var shown: int = int(_heal_display_accum)
		_heal_display_accum -= shown
		_spawn_floating_text("%d" % shown, Color(0.4, 0.9, 0.45), true)


func heal_shield(amount: float) -> void:
	if is_dead or amount <= 0.0 or item_shield_max <= 0.0:
		return
	item_shield_hp = min(item_shield_max, item_shield_hp + amount)
	if overhead_bar:
		overhead_bar.set_shield(item_shield_hp, item_shield_max)
	_spawn_floating_text("%d" % int(round(amount)), Color(0.4, 0.7, 1.0), true)


func _spawn_floating_text(text: String, color: Color, is_heal: bool = false) -> void:
	var scene: PackedScene = load("res://scenes/floating_text.tscn")
	if scene:
		var ft = scene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.global_position = global_position + Vector2(randf_range(-15, 15), -45)
		if ft.has_method("setup"):
			ft.setup(text, color, is_heal)


## Called by XP orbs when a remote player touches them on the host.
func add_xp(amount: float) -> void:
	if NetworkManager.is_host:
		NetworkManager.host_collect_xp(amount)


## Called by gold drops when a remote player touches them on the host.
## Gold is now PERSONAL (bkz. kullanıcı isteği: "oyundaki para ortak
## olmamalı herkesin parası kişisel olmalı") - host burada SADECE bu drop'u
## toplayan gerçek uzak oyuncuya (peer_id) altın ekletir, kendi GameManager'ına
## dokunmaz.
func collect_gold(amount: int) -> void:
	if NetworkManager.is_multiplayer_active and peer_id > 0:
		NetworkManager.grant_personal_gold.rpc_id(peer_id, amount)


## Bu RemotePlayer kuklası bir yaratığın hedefi olduğunda (bkz. enemy.gd
## take_damage/_schedule_melee_hit'in "target_player.has_method("take_damage")"
## kontrolü) ÇAĞRILIR - eskiden bu metod HİÇ yoktu, bu yüzden yaratıklar
## katılımcıya "saldırıyor" gibi görünse de has_method kontrolü false dönüp
## hasar sessizce hiç uygulanmıyordu (kullanıcı bildirimi: "yaratıklar
## katılımcıya saldırıyor ancak katılan kişi hasar almıyor"). Bu SADECE
## host'ta çalışır (yaratık AI'ı zaten sadece host'ta _physics_process
## işletiyor, bkz. enemy.gd) - host burada gerçek hasarı KENDİSİ
## HESAPLAMAZ, sadece asıl client'a "sen bu kadar hasar aldın, şu yaratıktan"
## diye bir RPC yollar; hasarın gerçek uygulanması (zırh, kalkan, ölüm vb.)
## o client'ın kendi yetkili Player node'unda, oradaki take_damage() içinde
## olur - can/kalkan durumu değiştiği için zaten normal _rpc_update_player_
## extra_state senkron döngüsüyle (bkz. main.gd) herkese geri yayılır.
func take_damage(amount: float, source: Node2D = null) -> void:
	if is_dead or peer_id <= 0:
		return
	var enemy_net_id: int = 0
	if source and is_instance_valid(source):
		enemy_net_id = int(source.get_meta("network_enemy_id", 0))
	NetworkManager.forward_damage_to_peer.rpc_id(peer_id, amount, enemy_net_id, false)


## Şovalye ultisi (Koruma Baloncuğu) aktifken kalkana giren hasar için
## take_damage ile AYNI yönlendirme deseni - bkz. player.gd
## take_paladin_barrier_damage. is_barrier_damage=true bayrağıyla asıl
## client tarafında doğru fonksiyona (take_paladin_barrier_damage) yönlendirilir.
func take_paladin_barrier_damage(amount: float, attacker: Node2D = null) -> void:
	if is_dead or peer_id <= 0:
		return
	var enemy_net_id: int = 0
	if attacker and is_instance_valid(attacker):
		enemy_net_id = int(attacker.get_meta("network_enemy_id", 0))
	NetworkManager.forward_damage_to_peer.rpc_id(peer_id, amount, enemy_net_id, true)
