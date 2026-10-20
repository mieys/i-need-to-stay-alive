extends CharacterBody2D
class_name RemotePlayer

const PhysicsInterp := preload("res://scripts/physics_interp.gd")
const PaladinDome := preload("res://scripts/paladin_dome.gd") ## Şovalye R: havada süzülme (klip adından)
const HideBrushScript := preload("res://scripts/hide_brush.gd")
const DeathBlood := preload("res://scripts/death_blood.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")
const KorsanParrotScript := preload("res://scripts/korsan_parrot.gd")
const ManaShieldFxScript := preload("res://scripts/mana_shield_fx.gd")
const KelebekRuhuScript := preload("res://scripts/kelebek_ruhu.gd")
const LightningBeamFxScript := preload("res://scripts/fx_lightning_beam.gd") ## Yıldırım Asası vuruş sesi (_beam_hit_sfx)
const PeriPetScript := preload("res://scripts/peri_pet.gd")
const KirpiPetScript := preload("res://scripts/kirpi_pet.gd")
const KORSAN_CHAR_ID := 9 ## Characters.DEFS roster id'si (player.gd ile aynı)
const WeaponTargetPriorityScript := preload("res://scripts/weapon_target_priority.gd")
## Aday sorgusu (host'ta yeni yolda C++ ızgarası, aksi halde tüm grup) - nişan seçicilerinin süzgeçleri aynen kalır.
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const OakleyLeafBarrierScene: PackedScene = preload("res://scenes/fx_oakley_leaf_barrier.tscn")

## Remote player puppet for multiplayer.
## Receives synced transform, animation, health and visual state from the network.

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_visual: Node2D = $ShieldVisual
## Mana Kalkanı görseli "B - Mühür" (mana_shield_fx.gd, madde 148) - player.gd ile AYNI düğüm; yenilenme/doldu
## item_shield_hp/item_shield_max anlık görüntüsünden, darbe/kırılma network_manager.gd "shield_hit_flash"ten.
var mana_fx: Node2D = null
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
## Sahibinin gerçek yürüme hızı (main.gd extra["move_speed"]); henüz paket gelmediyse 0 (bkz. get_effective_move_speed).
var synced_move_speed: float = 0.0
var synced_base_move_speed: float = 0.0 ## bkz. get_base_move_speed
## Sahibinin taban "Hasar" statı (player.gd damage_bonus, main.gd extra["dmg"]) - host'taki "Kopyanı Öldür" kopyası
## silah hasarını bundan türetir (bkz. mission_player_copy.gd _weapon_hit_damage). Yerel oyuncuyla aynı alan adı.
var damage_bonus: float = 10.0
## Saldırı hızı çarpanı + kritik bonusları (main.gd extra "atk_iv"/"cc"/"cd") - host'taki "Kopyanı Öldür" kopyası kopyalar (2026-10-11).
var synced_attack_interval_mult: float = 1.0
var crit_chance_bonus: float = 0.0
var crit_damage_bonus: float = 0.0
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
const TuftufTargetingScript: GDScript = preload("res://scripts/tuftuf_targeting.gd")
## Vampir Çocuk: silah çekilme formülü player.gd ile PAYLAŞILAN (bkz. vampir_math.gd üstündeki not).
const VampirMath := preload("res://scripts/vampir_math.gd")
const VampirBatSwarmScript: GDScript = preload("res://scripts/vampir_bat_swarm.gd")
## Suriyeli Hadime: süzülme/form görünümü/ceset/aura player.gd ile PAYLAŞILAN yardımcılardan (bkz. hadime_math.gd).
const HadimeMath := preload("res://scripts/hadime_math.gd")
const CadiMath := preload("res://scripts/cadi_math.gd")
## Shaman R - Elemental Golem: form kuralları player.gd ile PAYLAŞILIR (bkz. shaman_golem_math.gd).
const ShamanGolemMath := preload("res://scripts/shaman_golem_math.gd")
## Matthew rework (2026-10-12, madde 98): şimşek kiti - player.gd ile PAYLAŞILAN sayılar/sayfalar/parıltı.
const MatthewLightning := preload("res://scripts/matthew_lightning.gd")
const MatthewTrailScript := preload("res://scripts/fx_matthew_trail.gd")
## Klip adı kuralları (player.gd ile ortak) - bkz. char_anim.gd.
const CharAnim := preload("res://scripts/char_anim.gd")
## Son yarasa konum paketinden bu kadar süre (sn) geçtiyse (kapanış paketi kaybolduysa) kozmetik sürü silinir.
const VAMPIR_BATS_TIMEOUT := 1.0
const FxReviveRewindScene := preload("res://scenes/fx_revive_rewind.tscn")
const FxReviveHeartScene := preload("res://scenes/fx_revive_heart.tscn")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const REMOTE_HEART_Y := -142.0
var _death_status_fx: Node = null
var _revive_rewind_fx: Node = null
var _was_downed_for_heart_fx: bool = false
## update_extra_state_from_net en az bir kez geldi mi (bkz. ally_down sesi).
var _net_state_seen: bool = false

## "efekt sistemi" (iyileşme.png/kalkan.png) - bkz. player.gd _set_ally_aura/
## network_manager.gd broadcast_ally_aura_start/stop. Bu kukla, başka bir
## client'ta ally olarak hedeflenirse (yani BU oyuncu -kendi client'ında
## yerel Player olan biri- bir müttefiğini iyileştiriyorsa VE İZLEYEN
## client'ta o müttefik bir RemotePlayer kuklasıysa) burası çağrılır.
## bkz. player.gd start_ally_aura_fx - ikisi birlikte güncellenmeli. 2026-10-17 (madde 212): "heal"/"shield" = Melek Q/E
## SİHİRLİ BAĞI (melek_bond_fx.gd: bel halkası + kasterin halesinden gelen ip), "holy" = R parıltısı.
const MelekBondScript := preload("res://scripts/melek_bond_fx.gd")
const FxMelekHolyScene := preload("res://scenes/fx_melek_holy.tscn")
var _ally_aura_fx: Dictionary = {}

## caster: bağı kuran Melek (kukla ya da izleyenin kendi Player'ı) - ip onun halesinden çıkar (null = sadece halka).
func start_ally_aura_fx(aura_type: String, caster: Node2D = null) -> void:
	if _ally_aura_fx.has(aura_type) and is_instance_valid(_ally_aura_fx[aura_type]):
		return
	var fx: Node = null
	if aura_type == "heal" or aura_type == "shield":
		fx = MelekBondScript.new()
		fx.setup(aura_type, caster)
	elif aura_type == "holy":
		fx = FxMelekHolyScene.instantiate()
	if fx == null:
		return
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
## DÜZELTME (kullanıcı bildirimi: "assasin çocuk görünmezken hala
## görebiliyorlar vuramıyorlar ama görebiliyorlar") - kök neden: bu alan
## HİÇ YOKTU, update_position_and_anim_from_net() extra["is_invisible"]'ı
## SADECE modulate (saydamlık) için satır içi okuyordu, gerçek bir üye
## değişkene hiç YAZMIYORDU. enemy.gd'nin hedefleme kontrolü ("is_invisible"
## in rp) is_indoors/is_in_merchant_zone İLE AYNI desende bu üye değişkeni
## okuyor - o yüzden host olmayan bir oyuncu görünmez olunca (host'un
## çalıştırdığı enemy.gd AÇISINDAN) HİÇBİR ZAMAN görünmez sayılmıyordu,
## yaratıklar onu normal hedefleyip kovalamaya/bakmaya devam ediyordu -
## sadece hasar (player.gd take_damage(), HER ZAMAN kendi istemcisinde
## çalışır) doğru şekilde engelleniyordu.
var is_invisible: bool = false
## Büyücü Kız "Yükseliş" evrimi (main.gd extra["byc_fly"]) - bkz. update_extra_state_from_net.
var buyucu_airborne: bool = false
const BuyucuLevitateScript := preload("res://scripts/buyucu_levitate.gd")


func is_buyucu_airborne() -> bool:
	return buyucu_airborne and not is_dead
## bkz. main.gd state_snapshot "dmg_dealt" (kullanıcı isteği: "grup
## penceresinde canlı hasar istatistik paneli") - party_panel.gd
## _build_stats_popup bu müttefiğin canlı toplam verdiği hasarını buradan
## okuyor, tıpkı health/item_shield_hp gibi.
var match_damage_dealt: float = 0.0
## Aynı kanaldan ("dmg_taken"): müttefiğin canlı toplam ALDIĞI hasar (grup paneli Hasar Sıralaması "Alınan" sütunu, 2026-10-18).
var match_damage_taken: float = 0.0
var paladin_zone_active: bool = false
## Şovalye E (Koruma Bariyeri) açık mı - ağdan "paladin_guard" (asist: host kimin kimi koruduğuna bakar, bkz. assist.gd).
var paladin_guard_active: bool = false
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
## Talon Ayna Formu (R): main.gd extra["talon_form"] - karakter + silah ikonları %10 büyür (TalonFormationMath.FORM_SCALE_MULT,
## player.gd _talon_form_apply_scale ile AYNI çarpan). fx_talon_form.gd bu bayrağı okuyup alev aurasını sürdürür.
var _talon_form_active: bool = false
var _talon_form_scale_applied: float = 1.0
## Oakley Koruyucu Büyü (R) hedefi mi (main.gd extra["oakley_bond"]) - true iken çocuk olarak yeşil yaprak bariyeri FX'i durur
## (fx_oakley_leaf_barrier.gd bayrağı ve sağlık düşüşünü buradan okur).
var _oakley_bond_on: bool = false
var _oakley_bond_fx: Node = null

## Vampir Çocuk Yarasa Formu (bkz. player.gd _skill_vampir_bat_form): "bat_*" animasyon adı geldiği sürece
## silahlar gövdeye çekilir (0 = normal yerinde, 1 = tamamen içeride) - anim ADI zaten transform
## kanalından geliyor, ek ağ alanı yok.
var _vampir_bat_form: bool = false
## Shaman Elemental Golem (bkz. player.gd "SHAMAN: ELEMENTAL GOLEM"): "golem_*" klip adı geldiği sürece form açık - silahlar
## Vampir'in yarasa formundaki gibi gövdeye çekilir, can çubuğu/isim golemin üstüne çıkar; "golem_jump_*" sürerken (havada)
## host'taki yaratıklar kuklanın içinden geçer. Ek ağ alanı yok (klip adı transform kanalından geliyor).
var _shaman_golem_form: bool = false
var _shaman_golem_jumping: bool = false
## Elara'nın Sıvışma'sı (bkz. main.gd extra dict, update_extra_state_from_net) - Vampir'in Yarasa Formu'nun
## AKSİNE özel bir animasyonu olmadığı için animasyon adından ÇIKARILAMIYOR, AYRI bir ağ bayrağı gerekiyor.
var _elara_evasion: bool = false
## Elara E (odak) - main.gd extra["elara_focus"]; görseli elara_fx.gd Driver'ı okur (madde 178).
var _elara_focus: bool = false
var _item_ninja: bool = false ## Ninja'nın El Kitabı - main.gd extra["ninja"]
## Ruhani Yetenek "Savaş Şevki" - bkz. main.gd extra dict/enemy.gd _attacker_has_savas_sevki üstündeki AYNI not.
var has_savas_sevki: bool = false
## Denge turu (2026-09-24): bu uzak oyuncunun şansı / Şanslı Zar ekstra altın şansı / Tecrübe Kazanımı - host'taki
## düşme (enemy.gd _killer_node) ve XP toplama (xp_orb.gd, network_manager.gd) kararları için (bkz. main.gd extra dict).
var luck: float = 0.0
var item_extra_gold_chance: float = 0.0
var exp_gain_percent: float = 0.0
var _vampir_pull: float = 0.0
var _vampir_rest_positions: Array = []
## Matthew rework (2026-10-12, madde 98; main.gd extra["mt"] -> _apply_matthew_net_state): kasterdeki SÜREKLİ durumların kukladaki
## karşılığı. Top formu (0 yok / 1 normal / 2 büyük): sprite gizlenir, top döngüsü oynar, silahlar içe çekilir, yaratıklar içinden
## geçer. Güçlenmiş iz: kukla kendi hareketinden iz bırakır (fx_matthew_trail.gd), tam hızdaysa güçlenmiş sayfayla. Parıltı
## basamağı (0..10): Yıldırım Kalkanı kırılmaya yaklaştıkça sarı parıltı (shaders/matthew_glow.gdshader).
var _matthew_has_mt: bool = false
var _matthew_ball: int = 0
var _matthew_ball_fx: Node2D = null
var _matthew_empowered: bool = false
var _matthew_glow_step: int = 0
var _matthew_trail: Node = null
var _matthew_trail_prev: Vector2 = Vector2.ZERO
var _matthew_move_grace: float = 0.0
## Suriyeli Hadime (bkz. _apply_hadime_net_state / main.gd extra["hadime"]). hadime_ghost_active herkese açık:
## world_event_manager.gd hayaleti görev bölgesinde saymasın diye okur.
var hadime_ghost_active: bool = false
var _hadime_q: bool = false
var _hadime_q_time: float = 0.0
var _hadime_nm: bool = false
var _hadime_aura_on: bool = false
var _hadime_levitate_on: bool = false
var _hadime_corpse_pos: Vector2 = Vector2.ZERO
var _hadime_corpse_clip: String = ""
var _hadime_base_offset: Vector2 = Vector2.ZERO
var _base_collision_layer: int = 2
var _vampir_swarm: Node2D = null
var _vampir_bats_last_msec: int = 0

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

## Uzunkılıç slotları (_weapon_icons ile aynı index). 2026-09-26'dan beri kılıç etrafta DÖNMEZ, hedefe savrulur: kaster
## (weapon.gd _start_sword_swing) "weapon_fire" yayınına sword_side/sword_size/sword_speed ekler, bu kukla AYNI planı
## scripts/sword_swing_math.gd ile kendi ölçeğinde kurup aynı savuruşu + hilali oynatır (bkz. _animate_weapon_fire_full).
## (Eski yerel yörünge simülasyonu - _update_local_uzunkilic_orbit - kaldırıldı.)
var _weapon_is_sword: Array = []
const SwordSwingMath := preload("res://scripts/sword_swing_math.gd")
const DaggerStabMath := preload("res://scripts/dagger_stab_math.gd")
const TopuzSlamMath := preload("res://scripts/topuz_slam_math.gd")
const PenceHookMath := preload("res://scripts/pence_hook_math.gd")
const MizrakThrustMath := preload("res://scripts/mizrak_thrust_math.gd") ## madde 305
const KalkanBashMath := preload("res://scripts/kalkan_bash_math.gd") ## madde 338
## Tabanca/Tüfek şarjörü (madde 296): kasterle AYNI doldurma sürücüsü + kovan (weapon.gd _start_reload / _fire_at).
const GunReloadFx := preload("res://scripts/gun_reload_fx.gd")
const ShellCasingFx := preload("res://scripts/shell_casing_fx.gd")
const GunMagMath := preload("res://scripts/gun_mag_math.gd")

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
	"mizrak": preload("res://scenes/weapon_mizrak.tscn"),
	"kalkan": preload("res://scenes/weapon_kalkan.tscn"),
	"yinyang": preload("res://scenes/weapon_yinyang.tscn"), ## madde 334
	"gokkusagi": preload("res://scenes/weapon_gokkusagi.tscn"),
}


func _ready() -> void:
	## Fizik interpolasyonu (bkz. physics_interp.gd): _physics_process'te hareket ediyor.
	PhysicsInterp.opt_in(self)
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
	_base_collision_layer = collision_layer
	
	_load_character_frames()
	## Kullanıcı isteği (bkz. EntityScale): yerel oyuncuyla AYNI boyut küçültme.
	## Görsel ölçek _load_character_frames() içinde küçültülüyor; burada gövde
	## çemberi ve kalkan baloncuğu (yoksa uzak oyuncunun baloncuğu karakterine
	## göre 5% geniş görünürdü).
	EntityScale.shrink_collision(get_node_or_null("CollisionShape2D"))
	var bubble: Node2D = get_node_or_null("ShieldVisual/BubbleSprite")
	if bubble:
		bubble.scale *= EntityScale.ATTACHED_SIZE ## kalkan gövdeyle birlikte küçülmez (bkz. EntityScale.ATTACHED_SIZE)
	mana_fx = ManaShieldFxScript.attach(self, false) ## sesler eskisi gibi sadece kalkan sahibinin kendi ekranında
	mana_fx.hit_only = true ## sadece darbe mührü; baloncuk/kırılma/yenilenme eski kalkan (shield_bubble_visible)
	_target_position = global_position

	if overhead_bar:
		## Şapkalar örtülmesin (kullanıcı bildirimi 2026-09-25) - player.gd ile AYNI sabit (overhead_bar.gd CHARACTER_Y_OFFSET).
		overhead_bar.set_offset(overhead_bar.CHARACTER_Y_OFFSET)
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
	_hadime_base_offset = anim.offset
	cadi_base_offset = anim.offset ## Cadı'nın süpürgesine binince yükselme bu tabana eklenir
	## Ayak gölgesi (Vampir): yerel oyuncuyla AYNI yardımcı/DEFS değerleri (bkz. ground_shadow.gd) - uzak ekranda da görünsün.
	GroundShadow.apply_to(get_node_or_null("Shadow") as Node2D, def)
	var frames_path: String = def.get("frames", "")
	if ResourceLoader.exists(frames_path):
		var res = load(frames_path)
		if res is SpriteFrames:
			anim.sprite_frames = res
	anim.play("idle_down")
	## Papağan (evcil hayvan) - KUKLA modunda: kararları sahibinin ekranı verir, buraya olay olarak gelir (bkz.
	## korsan_parrot.gd, NetworkManager.broadcast_korsan_parrot -> korsan_parrot_event); kukla ilk olayda kurulur.


## bkz. _load_character_frames papağan notu.
func korsan_parrot_event(state: int, target: Vector2, carry: int, speed: float) -> void:
	var parrot: Node = get_node_or_null("KorsanParrot")
	if parrot == null and anim != null:
		var puppet: Node2D = KorsanParrotScript.new()
		add_child(puppet)
		puppet.setup(self, anim, true)
		parrot = puppet
	if parrot and parrot.has_method("apply_event"):
		parrot.apply_event(state, target, carry, speed)


## Kelebek Ruhu (evcil hayvan) - KUKLA: sahibinin ekranından gelen "buradayım" / "şuraya atış yaptım" olayı (bkz. kelebek_ruhu.gd,
## NetworkManager.broadcast_kelebek_ruhu). Kukla ilk olayda kurulur; atış sadece görsel (hasarı sahibinin ekranı verir).
func kelebek_ruhu_event(target: Vector2, shot: bool) -> void:
	var kelebek: Node = get_node_or_null("KelebekRuhu")
	if kelebek == null and anim != null:
		var puppet: Node2D = KelebekRuhuScript.new()
		add_child(puppet)
		puppet.setup(self, anim, true)
		kelebek = puppet
	if shot and kelebek and kelebek.has_method("fire_visual"):
		kelebek.fire_visual(target)


## Peri (evcil hayvan) - KUKLA: sahibinin ekranından gelen "buradayım" / "can basma büyüsü yaptım" olayı (bkz. peri_pet.gd,
## NetworkManager.broadcast_peri). Kukla ilk olayda kurulur; büyü sadece görsel (canı sahibinin ekranı verir).
func peri_event(cast: bool) -> void:
	var peri: Node = get_node_or_null("Peri")
	if peri == null and anim != null:
		var puppet: Node2D = PeriPetScript.new()
		add_child(puppet)
		puppet.setup(self, anim, true)
		peri = puppet
	if cast and peri and peri.has_method("play_cast_visual"):
		peri.play_cast_visual()


## Kirpi (evcil hayvan) - KUKLA: sahibinin ekranından gelen "dikenler açık/kapalı" olayı (bkz. kirpi_pet.gd, NetworkManager.broadcast_kirpi).
## Kukla ilk olayda kurulur; konumunu kendi hesaplar, hasar kuralları sadece sahibin ekranında (player.gd _kirpi_on_hit).
func kirpi_event(open: bool) -> void:
	var kirpi: Node = get_node_or_null("Kirpi")
	if kirpi == null and anim != null:
		var puppet: Node2D = KirpiPetScript.new()
		add_child(puppet)
		puppet.setup(self, anim, true)
		kirpi = puppet
	if kirpi and kirpi.has_method("apply_remote_state"):
		kirpi.apply_remote_state(open)



## Fizik interpolasyonu: bu adımdan ÖNCEKİ konum - _process'te buna yapışan görseller
## (hasar sayıları, auralar) çizilen konumu bulsun diye (bkz. PhysicsInterp.visual_position).
var _interp_prev_pos: Vector2 = Vector2.ZERO
var _interp_prev_frame: int = -1


## Bu oyuncu güvenli alanda mı (player.gd is_safe_zone_frozen ile AYNI tanım: satıcı koruma bölgesi - anlık görüntüde gelir - VEYA demirci iç mekanı - konumdan).
## Kuklaya bağlı evcil hayvan / Necro kafatası / totem bunu sorar; bar üstü kum saati de buna göre (madde 327).
func is_safe_zone_frozen() -> bool:
	return is_in_merchant_zone or HouseSiege.in_smithy(self)


var _safe_zone_icon_on: bool = false


func _sync_safe_zone_icon() -> void:
	var frozen: bool = is_safe_zone_frozen()
	if frozen == _safe_zone_icon_on:
		return
	_safe_zone_icon_on = frozen
	if overhead_bar != null:
		overhead_bar.set_time_frozen(frozen)


func _physics_process(delta: float) -> void:
	_interp_prev_pos = global_position ## bkz. PhysicsInterp.visual_position
	_interp_prev_frame = Engine.get_physics_frames()
	_sync_safe_zone_icon()
	_refresh_remote_weapon_shadows()
	_process_vampir_remote(delta)
	_process_hadime_remote(delta)
	_process_matthew_remote(delta)
	_process_cadi_remote(delta) ## Hadime'den SONRA: binen bir Hadime'nin ofsetini süpürge belirler
	_process_paladin_levitate_remote(delta)
	if _beam_fx and is_instance_valid(_beam_fx) and (is_dead or Time.get_ticks_msec() - _beam_last_net_msec > BEAM_NET_TIMEOUT_MSEC):
		_stop_beam_vfx() ## bkz. BEAM_NET_TIMEOUT_MSEC
	if _rbeam_fx and is_instance_valid(_rbeam_fx) and (is_dead or Time.get_ticks_msec() - _rbeam_last_net_msec > BEAM_NET_TIMEOUT_MSEC):
		_stop_rbeam_vfx()
	_update_beam_tremor()
	if is_dead:
		_wf_update_all(delta) ## ölünce silahlar göğse çekilip kaybolur (weapon.gd _owner_gone ile aynı kural)
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
	## Cadı'nın süpürgesinde YOLCU: kukla ağ konumunu beklemeden cadının arkasındaki koltuğuna oturtulur - her ekranda
	## süpürgeye yapışık görünür (yolcunun kendi istemcisi de AYNI formülle konumlanır, bkz. player.gd _cadi_passenger_follow).
	if cadi_ride_host_peer != 0:
		_cadi_snap_to_seat()
	## Kullanıcı isteği: "en yaygın/en sağlıklı ne ise onu yap" - menzilli
	## silahların nişan dönüşü artık ağdan HİÇ gelmiyor (bkz. main.gd/
	## _rpc_update_player_transform'un kısaltılmış imzası). Her katılımcı
	## zaten hangi yaratıkların nerede olduğunu biliyor (enemy sync sayesinde)
	## - yani "en yakın düşmana dön" kararı, tıpkı weapon.gd'nin gerçek
	## oyuncu için yaptığı gibi, tamamen YEREL olarak hesaplanabilir. Bu,
	## oyunun zaten bildiği bir kural olduğu için ağdan hiç veri gerektirmez.
	## Talon Silah Salvosu/Ayna Formu aktifken silahlar normal nişan/orbit
	## mantığı YERİNE dairesel formasyonda tutulur (bkz. _update_talon_formation).
	## Vampir Yarasa Formu: silahlar gövdeye çekilirken/geri çıkarken (pull > 0) nişan/orbit
	## güncellemesi konumu EZMESİN diye atlanır - bkz. _process_vampir_remote.
	if _vampir_pull > 0.0:
		pass
	elif _dome_rim_owns_icons(): ## kubbe içinde halka Talon diziliminden önce gelir (2026-10-15, kubbe girdabı)
		_update_dome_rim(delta)
	elif _talon_formation != "":
		_update_talon_formation(delta)
	else:
		_update_local_weapon_aim(delta)
	_wf_update_all(delta)


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
	_wf_clear() ## hücum takibi pivotları + hayaletler (madde 247)
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
	_weapon_is_sword.clear()
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
		## Kullanıcı isteği (2026-09-25): tüm silahlar %15 küçük - yerel weapon.gd ile AYNI çarpan (bkz. WeaponOrbitMath).
		icon.scale *= WeaponOrbitMath.ICON_SIZE_MULT

		# Apply tier-based texture if available
		var tier: int = int(weapon_tiers.get(key, 1))
		if tier > 1 and "tier_icon_textures" in weapon_root:
			var tier_textures: Array = weapon_root.tier_icon_textures
			if tier - 1 < tier_textures.size():
				var tier_tex: Texture2D = tier_textures[tier - 1]
				if tier_tex and icon is Sprite2D:
					icon.texture = tier_tex
		## Zanaatkâr seti (madde 196): yerel weapon.gd _apply_tier_art ile AYNI sanat + dünya pikseli (weapon_tier_art.gd); kukla kökü
		## (0,5) altında doğrudan çocuk -> PUPPET_ICON_SCALE. Kademe değişimi _apply_enchant_glows'ta (ench_tiers).
		if WeaponTierArt.has_art(key) and WeaponTierArt.set_art(icon, key, 1):
			icon.scale = Vector2.ONE * WeaponTierArt.PUPPET_ICON_SCALE
			icon.set_meta("tier_art", 1)
		if key == "kalkan":
			icon.set_meta("kalkan", true) ## dönmez, yönlü görünüş (KalkanBashMath.face) - bkz. _wf_face
		elif key == "yinyang":
			icon.set_meta("upright", true) ## Yin Yang Kitabı (madde 334) nişanla dönmez, dik durur - weapon.gd _face_dir ile aynı
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
		shadow.position = icon.position + Vector2(0, WeaponOrbitMath.hover_shadow_gap(icon.position.y))
		add_child(shadow)
		## Karakterin ALTINDA (ayak gölgesiyle aynı katman): "Shadow" düğümünün hemen arkasına, sprite'tan önce.
		var foot_shadow: Node = get_node_or_null("Shadow")
		if foot_shadow != null:
			move_child(shadow, foot_shadow.get_index() + 1)
		_weapon_shadows.append(shadow)

		## Hücum takibi (madde 247): ikon kendi Node2D pivotunun çocuğu - hücum/çıkış/çekilme dönüşümü pivotta, ikonun kendi
		## konumu eskisi gibi slot tabanlı kalır (ateş/savuruş tween'leri, kubbe, Talon dizilimi, ölüm düşüşü dokunulmadan çalışır).
		var pivot := Node2D.new()
		pivot.name = "WeaponPivot_%d" % i
		add_child(pivot)
		pivot.add_child(icon)
		_wf_add_icon(icon, shadow)
		_weapon_icons.append(icon)
		_weapon_base_scales.append(icon.scale)
		## Asa ucu partikülleri (madde 299): yerel weapon.gd ile aynı yayıcı, kuklanın kendi ikonunun ucundan (ağ verisi yok).
		if icon is Sprite2D:
			StaffTipFxScript.attach(icon as Sprite2D, String(key))
		_talon_form_scale_applied = 1.0 ## ikonlar yeniden yaratıldı: taban ölçek sıfırlandı, _apply_talon_form_scale yeniden uygular
		_weapon_fire_tweens.append(null)
		## weapon_root silinmeden ÖNCE kendi nişan açısı ayarlarını yakala -
		## bkz. _update_local_weapon_aim (artık ağdan gelmiyor, her silahın
		## KENDİ sprite_forward_angle_deg/mirror_icon_when_aiming_left'i
		## gerçek weapon.gd sahnesinden birebir okunuyor).
		if WeaponTierArt.has_art(key):
			_weapon_forward_angle_deg.append(float(WeaponTierArt.FORWARD[key]))
		else:
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
		if WeaponTierArt.REST.has(key):
			_weapon_rest_rotation_deg.append(float(WeaponTierArt.REST[key]))
		else:
			_weapon_rest_rotation_deg.append(float(weapon_root.get("melee_icon_rest_rotation_deg")) if "melee_icon_rest_rotation_deg" in weapon_root else 0.0)
		_weapon_slash_fx_offset.append(float(weapon_root.get("melee_slash_fx_offset")) if "melee_slash_fx_offset" in weapon_root else 95.0)
		_weapon_slash_fx_above_offset.append(float(weapon_root.get("melee_slash_fx_above_offset")) if "melee_slash_fx_above_offset" in weapon_root else 0.0)
		_weapon_recoil_distance.append(float(weapon_root.get("recoil_distance")) if "recoil_distance" in weapon_root else 10.0)
		_weapon_hit_segments.append(int(weapon_root.get("melee_hit_segments")) if "melee_hit_segments" in weapon_root else 1)
		## weapon_root add_child() ile _ready()'sini çalıştırdığı için _is_uzunkilic gerçek değeriyle okunur.
		_weapon_is_sword.append(bool(weapon_root.get("_is_uzunkilic")) if "_is_uzunkilic" in weapon_root else false)
		weapon_root.queue_free()


## [ikon Sprite2D, sprite_forward_angle_deg] - player.gd get_weapon_icon_info ile AYNI imza. slot = sahibin ağ silah slotu
## (main.gd "weapon_keys" sırası). update_weapon_visuals sahnesi olmayan anahtarı atladığı için ikon index'i slotla ancak
## atlanan yoksa aynıdır - burada aynı atlama kuralıyla eşlenir.
func get_weapon_icon_info(slot: int) -> Array:
	if slot < 0 or slot >= _weapon_keys.size() or slot >= MAX_WEAPON_ICONS:
		return []
	var idx: int = 0
	for i in range(slot):
		if WEAPON_SCENES.get(str(_weapon_keys[i])) != null:
			idx += 1
	if WEAPON_SCENES.get(str(_weapon_keys[slot])) == null or idx >= _weapon_icons.size():
		return []
	var icon: Sprite2D = _weapon_icons[idx] as Sprite2D
	if not is_instance_valid(icon):
		return []
	return [icon, float(_weapon_forward_angle_deg[idx]) if idx < _weapon_forward_angle_deg.size() else 0.0]


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
	## Hücum takibi (madde 247): hedefsiz silahın ucu gidiş yönüne / görüşteki düşmana - kubbe/Talon dizilimi kendi bakışını yönetir.
	var follow_facing: bool = _talon_formation == "" and not _dome_rim_owns_icons()
	for i in range(_weapon_icons.size()):
		if i < _weapon_melee.size() and _weapon_melee[i]:
			if follow_facing and is_instance_valid(_weapon_icons[i]):
				_wf_melee_facing(i, _weapon_icons[i], delta)
			continue
		var icon: Node2D = _weapon_icons[i]
		if not is_instance_valid(icon):
			continue
		if icon.has_meta(GunReloadFx.META):
			continue ## şarjör dolduruluyor (madde 296): pozu GunReloadFx sürüyor - kasterde de nişan durur
		## Her silah KENDİ yatay konumundan, karakterin ORTASI hizasından hedef arar (bkz. weapon.gd _attack_origin /
		## WeaponTargetPriority.range_center) - gerçek silahla aynı merkez, kozmetik nişan kasterinkiyle aynı yöne döner.
		var target: Node2D
		if should_retarget:
			## Kubbe halkasındaki silah (bkz. _update_dome_rim) kendi konumundan hedef arar - weapon.gd _attack_origin ile aynı kural.
			var aim_origin: Vector2 = WeaponTargetPriorityScript.range_center(global_position, icon.global_position)
			if _dome_rim_icon_on_rim(i):
				aim_origin = _dome_rim_aim[i] if i < _dome_rim_aim.size() else icon.global_position
			target = _get_target_for_weapon(i, aim_origin)
			_cached_aim_targets[i] = target
		else:
			## Önbellekteki hedef iki yeniden-hedefleme arasında (AIM_RETARGET_INTERVAL)
			## queue_free() ile silinmiş olabilir - silinmiş bir nesneyi doğrudan
			## "Node2D" tipli değişkene atamak "previously freed instance" hatası
			## verip fonksiyonun geri kalanını (diğer silahların nişanı) atlatıyordu
			## (2 süreçli multiplayer testinde ölen yaratıklarda görüldü). Önce
			## Variant olarak okunup geçerliyse atanıyor.
			var cached_target: Variant = _cached_aim_targets[i] if i < _cached_aim_targets.size() else null
			target = cached_target if is_instance_valid(cached_target) else null
		if not target or not is_instance_valid(target):
			## Menzilde hedef yok: weapon.gd ile aynı hücum kuralı (yürürken gidiş yönü, dururken görüşteki düşman; ikisi de yoksa
			## son açısında kalır) - bkz. weapon.gd _wf_update_facing.
			if follow_facing:
				var idle_dir: Vector2 = _wf_idle_dir(icon)
				if idle_dir != Vector2.ZERO:
					_wf_face(i, icon, idle_dir, clampf(delta * WeaponFollowMath.TURN_RATE, 0.0, 1.0))
			continue
		var dir: Vector2 = (target.global_position - icon.global_position).normalized()
		_wf_face(i, icon, dir, clamp(delta * AIM_EASE_RATE, 0.0, 1.0))


## İkonun ucunu dünya yönü `dir`'e çevirir (aynalama dahil) - weapon.gd _face_dir ile aynı kural (WeaponFollowMath.face_rotation).
func _wf_face(i: int, icon: Node2D, dir: Vector2, t: float) -> void:
	if icon.has_meta("upright"): ## Yin Yang Kitabı (madde 334): dik durur
		return
	if icon.has_meta("kalkan"): ## Kalkan (madde 338): dönmek yerine yüzü dir'e bakan görünüş - weapon.gd _kalkan_face ile aynı
		if not _wf_fire_tween_running(i):
			KalkanBashMath.face(icon, int(icon.get_meta("tier_art", 1)), dir)
		return
	var forward: float = deg_to_rad(_weapon_forward_angle_deg[i] if i < _weapon_forward_angle_deg.size() else 0.0)
	var mirror: bool = _weapon_mirror_aim[i] if i < _weapon_mirror_aim.size() else false
	var r: Array = WeaponFollowMath.face_rotation(dir, forward, mirror)
	if not mirror:
		icon.rotation = lerp_angle(icon.rotation, float(r[0]), t)
		return
	var flip: bool = r[1]
	var was_flipped: bool = _weapon_icon_flipped[i] if i < _weapon_icon_flipped.size() else false
	if flip != was_flipped:
		icon.rotation = float(r[0])
		icon.set("flip_h", flip)
		if i < _weapon_icon_flipped.size():
			_weapon_icon_flipped[i] = flip
	else:
		icon.rotation = lerp_angle(icon.rotation, float(r[0]), t)


## ---------- HÜCUM takibi (madde 247) - yerel weapon.gd _wf_update ile AYNI kural (WeaponFollowMath / WeaponFollowFx) ----------
## İkon başına pivot (ikonun ebeveyni): hücum ofseti + çıkış/çekilme dönüşümü + saydamlık pivotta; ikonun kendi konumu slot tabanlı
## kalır. Kubbe / Talon dizilimi / Vampir çekilmesi / ölüm düşüşü ikonları yönetirken pivot kimliktir.
var _wf_pivots: Array = []
var _wf_w: Array = [] ## Vector2 hız yayı
var _wf_v: Array = []
var _wf_vis: Array = [] ## Dictionary görünürlük durumu
var _wf_reveal_glinted: Array = []
var _wf_glint_cd: Array = []
var _wf_shadow_base: Array = [] ## gölgenin taban ölçeği (çıkışta küçülür)
var _wf_bob_phase: Array = []
var _wf_prev_pos: Vector2 = Vector2.INF
var _wf_vel: Vector2 = Vector2.ZERO
var _wf_prev_speed: float = 0.0
var _wf_bob_t: float = 0.0


func _wf_add_icon(icon: Node2D, shadow: Node2D) -> void:
	_wf_pivots.append(icon.get_parent())
	_wf_w.append(Vector2.ZERO)
	_wf_v.append(Vector2.ZERO)
	_wf_vis.append({})
	_wf_reveal_glinted.append(false)
	_wf_glint_cd.append(0.0)
	_wf_shadow_base.append(shadow.scale if is_instance_valid(shadow) else Vector2.ONE)
	_wf_bob_phase.append(randf_range(0.0, TAU))


func _wf_clear() -> void:
	for pv in _wf_pivots:
		if is_instance_valid(pv):
			(pv as Node).queue_free()
	_wf_pivots.clear()
	_wf_w.clear()
	_wf_v.clear()
	_wf_vis.clear()
	_wf_reveal_glinted.clear()
	_wf_glint_cd.clear()
	_wf_shadow_base.clear()
	_wf_bob_phase.clear()


## Pivotu kimliğe döndürür, silahı görünür yapar (başka bir sistem ikon konumunu yönetirken).
func _wf_identity(i: int) -> void:
	var pv: Node2D = _wf_pivots[i] as Node2D if i < _wf_pivots.size() else null
	if pv != null and is_instance_valid(pv):
		pv.transform = Transform2D.IDENTITY
		pv.modulate = Color.WHITE
	if i < _weapon_shadows.size() and is_instance_valid(_weapon_shadows[i]):
		_weapon_shadows[i].modulate.a = 0.4
		if i < _wf_shadow_base.size():
			_weapon_shadows[i].scale = _wf_shadow_base[i]
	if i < _wf_vis.size():
		(_wf_vis[i] as Dictionary)["s"] = WeaponFollowMath.SHOWN


func _wf_fire_tween_running(i: int) -> bool:
	if i >= _weapon_fire_tweens.size() or not (_weapon_fire_tweens[i] is Tween):
		return false
	var tw: Tween = _weapon_fire_tweens[i]
	return tw.is_valid() and tw.is_running()


## Hedefsiz silahın bakacağı yön (weapon.gd _wf_update_facing): yürürken gidiş yönü, dururken görüşteki en yakın düşman.
func _wf_idle_dir(icon: Node2D) -> Vector2:
	var sc: Dictionary = WeaponFollowMath.scan(self)
	var focus_dir: Vector2 = ((sc["focus"] as Vector2) - icon.global_position) if sc["seen"] else Vector2.ZERO
	return WeaponFollowMath.idle_facing_dir(_wf_vel, focus_dir)


## Yakın dövüş ikonu: savuruş tween'i sürerken dokunulmaz; menzilde düşman varken dinlenme pozu (savuruş oradan başlar),
## yoksa hücum kuralı. weapon.gd _wf_update_facing ile aynı.
func _wf_melee_facing(i: int, icon: Node2D, delta: float) -> void:
	if _wf_fire_tween_running(i) or not icon.visible:
		return
	var t: float = clampf(delta * WeaponFollowMath.TURN_RATE, 0.0, 1.0)
	var sc: Dictionary = WeaponFollowMath.scan(self)
	var rng: float = float(_weapon_attack_range[i]) if i < _weapon_attack_range.size() else 0.0
	if sc["seen"] and rng > 0.0:
		var origin: Vector2 = WeaponTargetPriorityScript.range_center(global_position, icon.global_position)
		if origin.distance_to(sc["focus"] as Vector2) <= rng:
			if icon.has_meta("kalkan"):
				_wf_face(i, icon, (sc["focus"] as Vector2) - icon.global_position, t) ## kalkan yüzünü düşmana çevirir
				return
			var rest: float = deg_to_rad(_weapon_rest_rotation_deg[i] if i < _weapon_rest_rotation_deg.size() else 0.0)
			icon.rotation = lerp_angle(icon.rotation, rest, t)
			return
	var dir: Vector2 = _wf_idle_dir(icon)
	if dir != Vector2.ZERO:
		_wf_face(i, icon, dir, t)


func _wf_update_all(delta: float) -> void:
	if _weapon_icons.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var gp: Vector2 = global_position
	if _wf_prev_pos == Vector2.INF or delta <= 0.0 or gp.distance_to(_wf_prev_pos) > 200.0:
		_wf_vel = Vector2.ZERO
	else:
		_wf_vel = (gp - _wf_prev_pos) / delta
	_wf_prev_pos = gp
	_wf_bob_t += delta
	var speed: float = _wf_vel.length()
	var gone: bool = is_dead or is_downed ## ölü/yerde: silahlar yere düşmez, çalıdaki gibi göğse çekilip kaybolur (bekleme payı yok)
	var owned_elsewhere: bool = not gone and (_vampir_pull > 0.0 or _dome_rim_owns_icons() or _talon_formation != "")
	var sc: Dictionary = WeaponFollowMath.scan(self)
	var any_target: bool = false
	for tg: Variant in _cached_aim_targets:
		if is_instance_valid(tg):
			any_target = true
			break
	var want: bool = (bool(sc["seen"]) or any_target) and not gone and brush_state != HideBrushScript.STATE_HIDDEN ## saklıyken içe çekili (madde 283)
	for i in mini(_weapon_icons.size(), _wf_pivots.size()):
		var icon: Node2D = _weapon_icons[i]
		var pv: Node2D = _wf_pivots[i] as Node2D
		if not is_instance_valid(icon) or pv == null or not is_instance_valid(pv):
			continue
		if owned_elsewhere:
			_wf_identity(i)
			continue
		var slot: Vector2 = WEAPON_ICON_SLOTS[mini(i, WEAPON_ICON_SLOTS.size() - 1)]
		var kind: int = WeaponFollowMath.slot_kind(slot)
		var r: Array = WeaponFollowMath.spring_step(_wf_w[i], _wf_v[i], WeaponFollowMath.move_target(_wf_vel),
				WeaponFollowMath.spring_w(kind), WeaponFollowMath.SPRING_ZETA, delta)
		_wf_w[i] = r[0]
		_wf_v[i] = r[1]
		var w: Vector2 = r[0]
		var bob: float = sin(_wf_bob_t * WeaponFollowMath.BOB_SPEED + float(_wf_bob_phase[i])) * WeaponFollowMath.BOB_AMPLITUDE
		bob *= WeaponFollowMath.bob_scale(w)
		var home: Vector2 = slot + WeaponFollowMath.charge_offset(kind, w) + Vector2(0.0, bob)
		var vis: Dictionary = _wf_vis[i]
		WeaponFollowMath.step_visibility(vis, want, false, now, kind, gone)
		var p: Dictionary = WeaponFollowMath.pose(vis, now, kind, home)
		var st: int = int(vis["s"])
		var u: float = float(p["u"])
		var sc_pose: float = float(p["scale"])
		var spin: float = float(p["spin"])
		## Yakın dövüş savuruşu sürerken pivot dondurulur (savuruş yolu kaymaz; bitince yay kaldığı yerden sürer).
		var melee_busy: bool = i < _weapon_melee.size() and _weapon_melee[i] and _wf_fire_tween_running(i)
		if not melee_busy:
			pv.rotation = spin
			pv.scale = Vector2(sc_pose, sc_pose)
			pv.position = (p["pos"] as Vector2) - slot.rotated(spin) * sc_pose
		var flash: float = 0.0
		if st == WeaponFollowMath.REVEAL and u >= WeaponFollowMath.GLINT_REVEAL_AT:
			flash = 0.6 * clampf(1.0 - (u - WeaponFollowMath.GLINT_REVEAL_AT) / 0.12, 0.0, 1.0)
		var alpha: float = float(p["alpha"])
		pv.modulate = Color(1.0 + flash, 1.0 + flash, 1.0 + flash, alpha)
		if i < _weapon_shadows.size() and is_instance_valid(_weapon_shadows[i]):
			var sh: Node2D = _weapon_shadows[i]
			var icon_local: Vector2 = pv.transform * icon.position
			sh.position = icon_local + Vector2(0.0, WeaponOrbitMath.hover_shadow_gap((p["pos"] as Vector2).y - bob))
			sh.modulate.a = 0.4 * alpha
			if i < _wf_shadow_base.size():
				sh.scale = (_wf_shadow_base[i] as Vector2) * sc_pose
		## En üst kademe uç parıltısı - weapon.gd _wf_update ile aynı.
		_wf_glint_cd[i] = maxf(0.0, float(_wf_glint_cd[i]) - delta)
		if WeaponFollowMath.has_glint(int(icon.get_meta("tier_art", 1))):
			var fwd: float = _weapon_forward_angle_deg[i] if i < _weapon_forward_angle_deg.size() else 0.0
			if st == WeaponFollowMath.REVEAL and not _wf_reveal_glinted[i] and u >= WeaponFollowMath.GLINT_REVEAL_AT:
				_wf_reveal_glinted[i] = true
				_wf_glint_cd[i] = WeaponFollowMath.GLINT_STOP_COOLDOWN
				WeaponFollowFx.spawn_glint(self, icon, fwd)
			elif st == WeaponFollowMath.SHOWN and float(_wf_glint_cd[i]) <= 0.0 and WeaponFollowMath.just_stopped(_wf_prev_speed, speed):
				_wf_glint_cd[i] = WeaponFollowMath.GLINT_STOP_COOLDOWN
				WeaponFollowFx.spawn_glint(self, icon, fwd)
		if st != WeaponFollowMath.REVEAL:
			_wf_reveal_glinted[i] = false
	_wf_prev_speed = speed

## ---------- Şovalye kubbesi tacı (KOZMETİK kopya) ----------
## Kuklanın kubbenin içindeyken silahlarının kubbe tepesindeki taç dairesine dizilmesi - karar/konum DomeWeaponRing'de
## (her istemcide aynı kural, ağdan veri gitmez), yerel karşılığı weapon.gd set_rim_target. Dünya konumları buraya set_dome_rim_targets
## ile gelir (ikon sırasıyla; boş dizi = kubbeden çıktı), slot <-> halka geçişi weapon.gd RIM_BLEND_TIME ile aynı süre.
var _dome_rim_targets: Array = [] ## ikon başına dünya konumu (Vector2)
## Kubbe girdabı (Talon E kubbede): ikon başına dışa bakış açısı - boşsa normal nişan (dome_weapon_ring.gd).
var _dome_rim_spin: Array = []
## İkon başına hedef arama merkezi (DomeWeaponRing.aim_point = eski kenar halkası; weapon.gd _attack_origin ile aynı kural).
var _dome_rim_aim: Array = []
var _dome_rim_world: Array = [] ## ikon başına SON halka konumu (geri dönüş geçişinde de kullanılır)
var _dome_rim_blend: Array = [] ## ikon başına 0..1 geçiş
var _dome_rim_z_on: Array = [] ## ikon başına: şu an yazılı halka z'si (0 = halkada değil; weapon.gd RIM_Z_INDEX / RIM_BACK_Z_INDEX)
const DOME_RIM_Z_INDEX := 21
const DOME_RIM_BACK_Z_INDEX := 19
var _dome_rim_front: Array = [] ## ikon başına: halka noktası kubbenin ön yarısında mı (dome_weapon_ring.gd rim_in_front)


func set_dome_rim_targets(targets: Array, spin_angles: Array = [], aims: Array = [], fronts: Array = []) -> void:
	_dome_rim_targets = targets
	_dome_rim_spin = spin_angles
	_dome_rim_aim = aims
	_dome_rim_front = fronts
	if targets.is_empty() and (is_dead or is_downed):
		_dome_rim_blend.clear() ## ölü kukla: halka bırakılır (silahlar göğse çekilir), geçiş sıfırlanır


## Kubbe halkası ikon konumlarını yönetiyor mu (ya da halkadan slota dönüş geçişi sürüyor mu).
## DÜZELTME (2026-10-17, kullanıcı: "talonun E yeteneği şovalye adamın içine girip çıktıktan sonra dönme becerisini kaybediyor"):
## sadece MEVCUT ikonların geçişine bakar. Eskiden ikon sayısı kubbedeyken azalınca (Ayna Formu kopyaları bitince / silah satılınca)
## fazla indekslerin geçişi 1'de takılı kalıyordu -> bu fonksiyon sonsuza dek true -> _update_talon_formation hiç çalışmıyordu.
func _dome_rim_owns_icons() -> bool:
	if not _dome_rim_targets.is_empty():
		return true
	for i in range(mini(_dome_rim_blend.size(), _weapon_icons.size())):
		if float(_dome_rim_blend[i]) > 0.0:
			return true
	return false


## İkon `i` şu an (büyük ölçüde) halkada mı - nişan merkezi için (weapon.gd is_on_dome_rim ile aynı eşik).
func _dome_rim_icon_on_rim(i: int) -> bool:
	return i < _dome_rim_targets.size() and i < _dome_rim_blend.size() and float(_dome_rim_blend[i]) >= 0.5


func _set_dome_rim_icon_z(i: int, on: bool) -> void:
	var front: bool = bool(_dome_rim_front[i]) if i < _dome_rim_front.size() else true
	var z: int = (DOME_RIM_Z_INDEX if front else DOME_RIM_BACK_Z_INDEX) if on else 0
	if i >= _dome_rim_z_on.size() or int(_dome_rim_z_on[i]) == z or not is_instance_valid(_weapon_icons[i]):
		return
	_dome_rim_z_on[i] = z
	var icon: Node2D = _weapon_icons[i]
	icon.z_as_relative = not on
	icon.z_index = z


func _update_dome_rim(delta: float) -> void:
	var count: int = _weapon_icons.size()
	while _dome_rim_blend.size() < count:
		_dome_rim_blend.append(0.0)
	while _dome_rim_world.size() < count:
		_dome_rim_world.append(Vector2.ZERO)
	while _dome_rim_z_on.size() < count:
		_dome_rim_z_on.append(0)
	## İkon sayısı azaldıysa (Ayna Formu kopyaları bitti / silah gitti) artan geçişler takılı kalmasın (bkz. _dome_rim_owns_icons).
	_dome_rim_blend.resize(count)
	_dome_rim_world.resize(count)
	for i in range(count):
		var icon: Node2D = _weapon_icons[i]
		if not is_instance_valid(icon):
			_dome_rim_blend[i] = 0.0
			continue
		if is_dead or is_downed:
			_dome_rim_blend[i] = 0.0 ## ölü/yerde: halka bırakılır, silahlar göğse çekilir
			_set_dome_rim_icon_z(i, false)
			continue
		var active: bool = i < _dome_rim_targets.size()
		if active:
			_dome_rim_world[i] = _dome_rim_targets[i]
		var blend: float = move_toward(float(_dome_rim_blend[i]), 1.0 if active else 0.0, delta / DOME_RIM_BLEND_TIME)
		_dome_rim_blend[i] = blend
		var slot: Vector2 = WEAPON_ICON_SLOTS[mini(i, WEAPON_ICON_SLOTS.size() - 1)]
		icon.position = slot.lerp(to_local(_dome_rim_world[i]), smoothstep(0.0, 1.0, blend)) + _formation_kick_offset(i)
		## Halkada: ön yarıda kabuğun üstünde, arka yarıda altında çizilir; yerdeki gölge durur (weapon.gd ile aynı eşik/kural).
		_set_dome_rim_icon_z(i, blend >= 0.5)
		if i < _weapon_shadows.size() and is_instance_valid(_weapon_shadows[i]):
			_weapon_shadows[i].modulate.a = 0.4
	_update_local_weapon_aim(delta)
	## Kubbe girdabı: halkadaki ikon dışa bakar (gerçek silahın weapon.gd set_rim_spin pozuyla AYNI formül) - nişanın üstüne yazar.
	for i in range(mini(count, _dome_rim_spin.size())):
		var icon: Node2D = _weapon_icons[i]
		if not is_instance_valid(icon) or _dome_rim_spin[i] == null or not _dome_rim_icon_on_rim(i):
			continue
		var forward: float = deg_to_rad(_weapon_forward_angle_deg[i] if i < _weapon_forward_angle_deg.size() else 0.0)
		var mirrors: bool = _weapon_mirror_aim[i] if i < _weapon_mirror_aim.size() else false
		var pose: Dictionary = TalonFormationMath.compute_icon_pose(float(_dome_rim_spin[i]), forward, mirrors)
		icon.rotation = pose["rotation"]
		if mirrors:
			icon.set("flip_h", pose["flip_h"])
			if i < _weapon_icon_flipped.size():
				_weapon_icon_flipped[i] = pose["flip_h"]


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
		## Yetenek evrimi "Uzun Girdap": kasterle AYNI dönüş çarpanı (player.gd _talon_salvo_spin_mult).
		var spin_mult: float = TalonFormationMath.EVO_SALVO_SPIN_MULT if has_evo("talon_e2") else 1.0
		_talon_salvo_angle = TalonFormationMath.advance_salvo_angle(_talon_salvo_angle, delta, spin_mult)
	else: ## "mirror" - sabit dizilim, dönmez
		radius = TalonFormationMath.MIRROR_RADIUS
	## Yetenek evrimi "Kan Aynası" (Talon R finali): Ayna Formu'nun kopyaları (listenin ikinci yarısı - player.gd kopyaları
	## sona ekler) kasterdeki gibi kan kırmızısı.
	var tint_copies: bool = has_evo("talon_rf")
	for i in range(count):
		var icon: Node2D = _weapon_icons[i]
		if not is_instance_valid(icon):
			continue
		if tint_copies:
			icon.modulate = TALON_BLOOD_COPY_TINT if (_talon_form_active and i >= count / 2) else Color.WHITE
		var slot: Dictionary = TalonFormationMath.compute_slot(i, count, radius, _talon_salvo_angle)
		icon.position = slot["offset"] + _formation_kick_offset(i)
		## Ayna Formu (R) TEK BAŞINA: sadece konum çember, namlular normal nişanla en yakın yaratığa döner
		## (kullanıcı isteği: sabit dışa-bakan duruş SADECE E ile kombine ettiğinde) - bkz. player.gd
		## _talon_set_weapons_circular face_outward. Nişan döngü sonunda _update_local_weapon_aim ile yapılır.
		if _talon_formation != "salvo":
			if not icon.visible:
				icon.visible = true
			continue
		var forward: float = deg_to_rad(_weapon_forward_angle_deg[i] if i < _weapon_forward_angle_deg.size() else 0.0)
		## DÜZELTME (kullanıcı bildirimi: "silahların dışa bakması gerekirken
		## içe bakıyorlar") - bkz. player.gd _talon_set_weapons_circular
		## üstündeki AYNI düzeltme notu: slot["angle"] KENDİSİ zaten merkezden
		## dışa bakan açı (bkz. talon_formation_math.gd compute_slot - offset
		## de aynı açıyla hesaplanıyor), weapon.gd _update_aim'deki genel
		## "rotation = hedef_açısı - forward" kuralıyla AYNI formül kullanılmalı.
		## Önceki +PI fazladan 180° ekleyip namluları içe (karaktere doğru)
		## çeviriyordu.
		## bkz. talon_formation_math.gd compute_icon_pose - aynalanan
		## silahlar (tabanca/tüfek) için flip_h da slot açısına göre
		## belirlenir (yoksa bayat flip_h namluyu içe çevirirdi).
		var mirrors: bool = _weapon_mirror_aim[i] if i < _weapon_mirror_aim.size() else false
		var pose: Dictionary = TalonFormationMath.compute_icon_pose(slot["angle"], forward, mirrors)
		icon.rotation = pose["rotation"]
		if mirrors:
			icon.set("flip_h", pose["flip_h"])
			if i < _weapon_icon_flipped.size():
				_weapon_icon_flipped[i] = pose["flip_h"]
		if not icon.visible:
			icon.visible = true
	if _talon_formation != "salvo":
		_update_local_weapon_aim(delta)


## Vampir Çocuk'un Yarasa Formu (bkz. player.gd _process_vampir_weapon_pull - AYNI formül,
## VampirMath'ten): form sürerken silah ikonları gövdeye çekilip solar, bitince geri çıkar. Dinlenme
## konumu çekilme başlarken ikonun kendi o anki konumundan yakalanır (dönen kılıç gibi sabit slotu
## olmayan silahlar da doğru yere döner).
func _process_vampir_remote(delta: float) -> void:
	var prev: float = _vampir_pull
	## Yetenek evrimi "Silahlı Yarasa" (Vampir E finali): silahlar formda çekilmez - player.gd _vampir_weapons_absorbed ile aynı karar.
	## Shaman golem formu da aynı çekilmeyi kullanır (player.gd _vampir_weapons_absorbed ile aynı karar).
	## Matthew'in Elektrik Topu (2026-10-12) da.
	var absorbed: bool = (_vampir_bat_form and not has_evo("vampir_ef")) or _shaman_golem_form or _matthew_ball > 0
	_vampir_pull = VampirMath.step_pull(_vampir_pull, absorbed and not is_dead, delta)
	if _vampir_pull > 0.0:
		if prev <= 0.0:
			_vampir_rest_positions.clear()
			for icon: Node2D in _weapon_icons:
				_vampir_rest_positions.append(icon.position if is_instance_valid(icon) else Vector2.ZERO)
		var alpha: float = VampirMath.icon_alpha(_vampir_pull)
		for i in range(_weapon_icons.size()):
			var icon: Node2D = _weapon_icons[i]
			if not is_instance_valid(icon):
				continue
			var rest: Vector2 = _vampir_rest_positions[i] if i < _vampir_rest_positions.size() else icon.position
			icon.position = VampirMath.icon_offset(rest, _vampir_pull)
			icon.modulate.a = alpha
			if i < _weapon_shadows.size() and is_instance_valid(_weapon_shadows[i]):
				_weapon_shadows[i].modulate.a = 0.4 * alpha
				_refresh_remote_weapon_shadow(i)
	elif prev > 0.0:
		for i in range(_weapon_icons.size()):
			var icon: Node2D = _weapon_icons[i]
			if not is_instance_valid(icon):
				continue
			if i < _vampir_rest_positions.size():
				icon.position = _vampir_rest_positions[i]
			icon.modulate.a = 1.0
			if i < _weapon_shadows.size() and is_instance_valid(_weapon_shadows[i]):
				_weapon_shadows[i].modulate.a = 0.4
				_refresh_remote_weapon_shadow(i)
		_vampir_rest_positions.clear()
	if _vampir_swarm != null and is_instance_valid(_vampir_swarm):
		if is_dead or Time.get_ticks_msec() - _vampir_bats_last_msec > int(VAMPIR_BATS_TIMEOUT * 1000.0):
			_vampir_swarm.queue_free()
			_vampir_swarm = null


## main.gd _rpc_update_vampir_bats: R yarasalarının konumları (boş dizi = sürü kapandı). Sürü
## burada SADECE görsel (authoritative=false) - hasar/can hiçbir şey yapmaz, bkz. vampir_bat_swarm.gd.
func update_vampir_bats_from_net(positions: PackedVector2Array) -> void:
	if positions.is_empty():
		if _vampir_swarm != null and is_instance_valid(_vampir_swarm):
			_vampir_swarm.queue_free()
		_vampir_swarm = null
		return
	_vampir_bats_last_msec = Time.get_ticks_msec()
	if _vampir_swarm == null or not is_instance_valid(_vampir_swarm):
		var swarm := Node2D.new()
		swarm.set_script(VampirBatSwarmScript)
		swarm.set("authoritative", false)
		swarm.set("caster", self)
		add_child(swarm)
		_vampir_swarm = swarm
	_vampir_swarm.apply_net_positions(positions)


## weapon.gd::_get_target_enemy() ile BİREBİR aynı seçim mantığı - hangi
## hedefleme moduna (en yakın / en yüksek can / donmamış tercih) göre
## saldıracağı, o silahın kendi (weapon_root'tan yakalanan) export
## bayraklarına göre belirlenir. `origin` çağıran ikonun KENDİ konumu.
func _get_target_for_weapon(i: int, origin: Vector2) -> Node2D:
	var max_range: float = _weapon_attack_range[i] if i < _weapon_attack_range.size() else 0.0
	## weapon.gd _get_target_enemy ile AYNI öncelik (menzilde boss / görev kopyası varsa daima o) - bkz.
	## weapon_target_priority.gd. Buradaki diğer seçiciler gibi sis süzgeci yok (kozmetik nişan).
	var priority: Node2D = WeaponTargetPriorityScript.nearest_priority_target(get_tree(), origin, max_range)
	if priority != null:
		return priority
	if i < _weapon_target_highest_health.size() and _weapon_target_highest_health[i]:
		return _get_highest_health_enemy_from(origin, max_range)
	if i < _weapon_target_prefer_unfrozen.size() and _weapon_target_prefer_unfrozen[i]:
		return _get_nearest_unfrozen_enemy_from(origin, max_range)
	return _get_nearest_enemy_from(origin, max_range)


func _get_nearest_enemy_from(origin: Vector2, max_range: float) -> Node2D:
	var enemies: Array = EnemyQueryScript.candidates(get_tree(), origin, max_range + 1.0 if max_range > 0.0 else INF)
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
	var enemies: Array = EnemyQueryScript.candidates(get_tree(), origin, max_range + 1.0 if max_range > 0.0 else INF)
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


## weapon.gd::_get_highest_health_enemy() ile AYNI seçim - Tüftüf için "canı
## yüksek > hiç zehirlenmemiş > tüm yaratıklar" kuralı TEK yerde (bkz.
## tuftuf_targeting.gd), iki taraf da onu çağırır.
func _get_highest_health_enemy_from(origin: Vector2, max_range: float) -> Node2D:
	var enemies: Array = EnemyQueryScript.candidates(get_tree(), origin, max_range + 1.0 if max_range > 0.0 else INF)
	if enemies.is_empty():
		return null
	return TuftufTargetingScript.pick(enemies, origin, max_range)


## SÜREKLİ kanal (bkz. main.gd _rpc_update_player_transform, unreliable,
## ~20Hz): sadece her karede gerçekten değişebilecek şeyler - konum ve o anki
## animasyon adı. Kullanıcı bildirimi: "bağlantım yaratıkların/silahların
## animasyonlarını bile veri olarak gönderiyor, halbuki bunlar oyunun
## kodlarıyla otomatik çalışmalı" - haklıydı; can/kalkan/silah envanteri/
## durum efektleri gibi NADİREN değişen veriler eskiden bu fonksiyonun
## İÇİNDE, aynı sıklıkta gönderiliyordu (bkz. update_extra_state_from_net,
## sadece değiştiğinde çalışır), silah nişan dönüşü de artık hiç ağdan
## gelmiyor (bkz. _update_local_weapon_aim - tamamen yerel hesaplanıyor).
## Işınlanma (network_manager.gd "teleport_snap" - Assasin "Gölge Kopyası"): yumuşatma/hız tahmini olmadan anında sıçrar.
## Hız tahmini sıfırlanmazsa bir sonraki pakette (eski hedef -> yeni konum) dev bir hız türetilip kukla ileri fırlardı.
func snap_to_network_position(pos: Vector2) -> void:
	global_position = pos
	_target_position = pos
	_network_velocity = Vector2.ZERO
	_network_time_since_update = 0.0
	_interp_prev_pos = pos
	reset_physics_interpolation()


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
	_vampir_bat_form = VampirMath.is_bat_anim(cur_anim)
	_apply_vampir_bat_scale()
	_shaman_golem_form = ShamanGolemMath.is_golem_anim(cur_anim)
	_shaman_golem_jumping = ShamanGolemMath.is_jump_anim(cur_anim)
	_apply_shaman_golem_scale()
	ShamanGolemMath.apply_overhead_lift(self, _shaman_golem_form and not is_dead, ShamanGolemMath.EVO_BIG_SCALE_MULT if has_evo("shaman_rf") else 1.0)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation(cur_anim) and not _cadi_ride_anim_driven:
		if anim.animation != cur_anim:
			anim.play(cur_anim)
		## Kullanıcı isteği: hareket hızı artınca yürüme animasyonu (aynı klip
		## içinde) biraz hızlansın - player.gd _update_animation'daki AYNI
		## efekt burada da uygulanmalı, yoksa sadece kaster kendi ekranında
		## hızlanmış görür, diğer istemcilerde eski/normal hızda donuk kalır
		## (bkz. CLAUDE.md "kaster görür, diğerleri görmez" hata sınıfı).
		## Yeni bir ağ alanı EKLEMİYORUZ: zaten dead-reckoning için tutulan
		## _network_velocity (gözlemlenen GERÇEK konum değişimi) player.gd'nin
		## kullandığı "effective_speed"in doğal karşılığı - iki taraf da AYNI
		## Characters.BASE_MOVE_SPEED'e bölüyor (bkz. player.gd
		## WALK_ANIM_SPEED_SCALE_MIN/MAX ile birebir aynı sınırlar).
		if cur_anim.begins_with("walk_"):
			anim.speed_scale = clampf(_network_velocity.length() / Characters.BASE_MOVE_SPEED, 0.7, 1.25)
		elif CharAnim.is_mine_anim(cur_anim):
			## Maden kazma (bkz. char_anim.gd MINE_ANIM_PREFIX): klip loop=false, kaster bitince yeniden başlatıyor - kukla da döngüde tutar
			anim.speed_scale = CharAnim.MINE_ANIM_SPEED
			if not anim.is_playing():
				anim.play(cur_anim)
		else:
			anim.speed_scale = 1.0
		if CharAnim.is_cast_anim(cur_anim) and not anim.is_playing():
			## DÜZELTME (derin multiplayer görsel denetimi: "Büyücü Kız'ın
			## Meteor kanalı uzak ekranlarda donuyor") - spellcast animasyonu
			## kendi kendine döngü yapmıyor (bkz. player.gd
			## _process_buyucu_meteor'daki yerel zorla-yeniden-oynatma; yeni
			## sprite setlerinde aynı klip "shrug_<yön>", bkz. CharAnim.CAST_PREFIXES). Bu
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
	## Kan + hırpalanma (bkz. death_blood.gd, player.gd aynı çağrı). Kukla yere düşmüşken is_dead false gelir (main.gd
	## send_dead) - bu yüzden is_downed da sayılır.
	DeathBlood.sync(self, is_dead or is_downed)
	if is_dead:
		if not _death_status_fx or not is_instance_valid(_death_status_fx):
			_death_status_fx = FxDeathScene.instantiate()
			_death_fx_parent().add_child(_death_status_fx)
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
			_death_fx_parent().add_child(_revive_rewind_fx) ## Hadime hayaletken: cesedin üstü (arkadaşlar cesedi diriltir)
		if _revive_rewind_fx.has_method("set_progress"):
			_revive_rewind_fx.set_progress(ratio)
	elif _revive_rewind_fx and is_instance_valid(_revive_rewind_fx):
		_revive_rewind_fx.queue_free()
		_revive_rewind_fx = null

	if _was_downed_for_heart_fx and not is_downed and not is_dead:
		var heart := FxReviveHeartScene.instantiate()
		(heart as Node2D).position.y = REMOTE_HEART_Y ## isim yazısının (-120) üstü
		add_child(heart)
	_was_downed_for_heart_fx = is_downed or is_dead ## bkz. player.gd aynı satır (kalıcı ölümden dönüşte de kalp)


## Talon Ayna Formu (R) boyutu: karakter sprite'ı + silah ikonları (taban ölçekleri de) FORM_SCALE_MULT kadar büyür.
## Oran (yeni/eski) uygulanır, böylece ateş animasyonlarının döndüğü _weapon_base_scales de tutarlı kalır.
func _apply_talon_form_scale() -> void:
	var want: float = TalonFormationMath.FORM_SCALE_MULT if _talon_form_active else 1.0
	if is_equal_approx(want, _talon_form_scale_applied):
		return
	var ratio: float = want / _talon_form_scale_applied
	_talon_form_scale_applied = want
	if anim and is_instance_valid(anim):
		anim.scale = _base_anim_scale * want
	for i in range(_weapon_icons.size()):
		var icon: Node2D = _weapon_icons[i]
		if is_instance_valid(icon):
			icon.scale *= ratio
		if i < _weapon_base_scales.size():
			_weapon_base_scales[i] = _weapon_base_scales[i] * ratio


## Shaman "Dev Golem" (shaman_rf) boyutu: golem formundayken sprite +%30 - player.gd _golem_evo_apply ile AYNI çarpan (form klip
## adından, evrim extra["evo"] listesinden türetilir; yeni ağ alanı yok). SADECE Shaman'a dokunur (Vampir/Talon ölçeklemesini ezmesin).
func _apply_shaman_golem_scale() -> void:
	if char_id != ShamanGolemMath.CHAR_ID or not (anim and is_instance_valid(anim)):
		return
	anim.scale = _base_anim_scale * (ShamanGolemMath.EVO_BIG_SCALE_MULT if (_shaman_golem_form and has_evo("shaman_rf")) else 1.0)


## Vampir Çocuk Yarasa Formu (E) boyutu: yarasa kareleri (96x112) insan karelerinden büyük olduğu
## için form boyunca sprite %30 küçülür - yerel oyuncuyla AYNI çarpan (bkz. vampir_math.gd
## BAT_FORM_SCALE_MULT ve player.gd _update_animation'ın yarasa dalı) yoksa uzak ekranda devasa
## görünürdü. SADECE Vampir'e dokunur: başka karakterin kuklasında anim.scale'e HİÇ yazmaz
## (Talon'un Ayna Formu ölçeklemesini - _apply_talon_form_scale - ezmesin).
func _apply_vampir_bat_scale() -> void:
	if char_id != VampirMath.CHAR_ID:
		return
	if not (anim and is_instance_valid(anim)):
		return
	anim.scale = _base_anim_scale * (VampirMath.BAT_FORM_SCALE_MULT if _vampir_bat_form else 1.0)


## ---------- Yetenek evrimleri (2026-09-28) ----------
## Bu oyuncunun aldığı evrimler (main.gd extra["evo"]) - player.gd has_evo ile AYNI sözleşme; uzak kuklanın görsel kararları
## ve host'taki simülasyonun sorduğu şeyler (get_talon_ward_radius) bundan okunur.
var _evolutions: Dictionary = {}
const TALON_BLOOD_COPY_TINT := Color(1.0, 0.55, 0.55, 1.0) ## player.gd EVO_TALON_BLOOD_COPY_TINT ile aynı


func has_evo(evo_id: String) -> bool:
	return _evolutions.has(evo_id)


## player.gd passes_walls() ile AYNI kural (orman üst katmanı z sırası, forest_canopy.gd).
func passes_walls() -> bool:
	return not is_dead and ((_vampir_bat_form and has_evo("vampir_e2")) or (_cadi_broom and has_evo("cadi_e1")))


## Talon "Kalkan Çemberi" (E finali): salvo sürerken silah çemberine giren yaratık atışları söner - player.gd
## get_talon_ward_radius ile AYNI formül (host'ta uzak Talon'un çemberi mermileri bu kuklaya göre söndürür).
func get_talon_ward_radius() -> float:
	if _talon_formation == "salvo" and has_evo("talon_ef") and not is_dead:
		return maxf(TalonFormationMath.SALVO_RADIUS * absf(global_scale.x), _enchant_ward)
	return 0.0 if is_dead else _enchant_ward


## Sahibinin efsun mermi kalkanı (main.gd extra["ench_ward"], player.gd get_enchant_ward_radius ile aynı değer).
var _enchant_ward: float = 0.0


## SAKLANMA ÇALILIĞI (bkz. player.gd set_brush_state / hide_brush_manager.gd): host bu oyuncunun çalı durumunu bildirir; kukla soluklaşır.
var brush_state: int = 0


func set_brush_state(state: int) -> void:
	brush_state = state
	if anim != null:
		anim.self_modulate.a = HideBrushScript.alpha_for(state)
	if overhead_bar != null:
		overhead_bar.set_brush_state(state) ## can barının üstünde saklı/görüldü simgesi (madde 275)


## Vampir Çocuk yarasa formundayken (anim adı bat_*) yaratıklar bu kuklanın içinden geçilebilir sayar - player.gd is_ghost_now ile aynı
## sözleşme (enemy.gd host'ta çalışır, uzak Vampir'i bu kukla temsil eder).
func is_ghost_now() -> bool:
	## Suriyeli Hadime Q'da havaya süzülürken de (main.gd extra["hadime"].q) - host'taki yaratıklar onu dışarı itmesin.
	## Matthew'in Elektrik Topu formunda da (main.gd extra["mt"][0]).
	return _vampir_bat_form or _elara_evasion or _hadime_q or _shaman_golem_jumping or _item_ninja or _matthew_ball > 0


## player.gd get_effective_move_speed ile AYNI sözleşme. Durum paketi henüz gelmediyse yerel oyuncunun hızı (aynı
## player.tscn tabanı) yedek olarak döner - eskiden kopya burada Characters.BASE_MOVE_SPEED (252) kullanıyordu, ama
## oyuncunun gerçek taban hızı player.tscn'de 91 x EntityScale.SPEED = ~82: host olmayan oyuncunun kopyası ondan ~2.5
## kat hızlıydı ("kopya sürekli karaktere ışınlanıyor ve bırakmıyor" bildiriminin kök nedeni).
## Sahibinin KALICI hızı (yetenek buff'sız, main.gd extra["base_speed"]) - bkz. player.gd get_base_move_speed.
func get_attack_interval_mult() -> float:
	return synced_attack_interval_mult


func get_base_move_speed() -> float:
	if synced_base_move_speed > 0.0:
		return synced_base_move_speed
	return Characters.BASE_MOVE_SPEED


func get_effective_move_speed() -> float:
	if synced_move_speed > 0.0:
		return synced_move_speed
	var local_p: Node = get_tree().get_first_node_in_group("player")
	if local_p and local_p.has_method("get_effective_move_speed"):
		return float(local_p.call("get_effective_move_speed"))
	return Characters.BASE_MOVE_SPEED


## Efsun kademesi parıltısı (kaster: weapon.gd set_enchant; bkz. enchant_weapon_glow.gd). tiers[i] = weapon_keys[i]'in
## kademesi; ikon adı "RemoteWeaponIcon_<i>" anahtar sırasını taşır (sahnesi/ikonu olmayan anahtar atlanınca kaymasın).
const EnchantGlowScript := preload("res://scripts/enchant_weapon_glow.gd")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const StaffTipFxScript := preload("res://scripts/staff_tip_fx.gd") ## asa ucu partikülleri (madde 299)


func _apply_enchant_glows(tiers: Array) -> void:
	for icon: Node2D in _weapon_icons:
		if not is_instance_valid(icon):
			continue
		var idx: int = int(str(icon.name).get_slice("_", 1))
		var t: int = int(tiers[idx]) if idx >= 0 and idx < tiers.size() else 0
		## Kademe sanatı (madde 196): kaster weapon.gd set_enchant -> _apply_tier_art; burada aynı kademe ench_tiers'tan.
		if idx >= 0 and idx < _weapon_keys.size():
			var art_key: String = str(_weapon_keys[idx])
			var art_t: int = WeaponTierArt.clamp_tier(t)
			if WeaponTierArt.has_art(art_key) and int(icon.get_meta("tier_art", 0)) != art_t and WeaponTierArt.set_art(icon, art_key, art_t):
				icon.set_meta("tier_art", art_t)
		var cur: Node = icon.get_node_or_null("EnchantGlow")
		if t <= 0 and cur == null:
			continue
		if cur != null and int(cur.get("tier")) == t:
			continue
		EnchantGlowScript.attach(icon, t)


func update_extra_state_from_net(hp: float, max_hp: float, s_hp: float, s_max: float, p_zone: bool, dead: bool, weapon_keys: Array, extra: Dictionary = {}) -> void:
	## Yetenek evrimleri (2026-09-28, main.gd extra["evo"]) - görsel kararlardan ÖNCE (bkz. has_evo).
	_enchant_ward = float(extra.get("ench_ward", 0.0))
	if extra.has("evo"):
		_evolutions.clear()
		for evo_id in extra["evo"]:
			_evolutions[str(evo_id)] = true
	update_weapon_visuals(weapon_keys, extra.get("weapon_tiers", {}))
	_apply_enchant_glows(extra.get("ench_tiers", []))
	synced_move_speed = float(extra.get("move_speed", synced_move_speed))
	synced_base_move_speed = float(extra.get("base_speed", synced_base_move_speed))
	damage_bonus = float(extra.get("dmg", damage_bonus))
	synced_attack_interval_mult = float(extra.get("atk_iv", synced_attack_interval_mult))
	crit_chance_bonus = float(extra.get("cc", crit_chance_bonus))
	crit_damage_bonus = float(extra.get("cd", crit_damage_bonus))
	health = hp
	max_health = max_hp
	item_shield_hp = s_hp
	item_shield_max = s_max
	paladin_zone_active = p_zone

	# Handle death state change
	if dead and not is_dead:
		_play_death_animation()
		## Takım arkadaşı düştü/öldü sesi - ilk durum paketinde değil (sonradan katılınca zaten ölü olan arkadaş için çalmasın).
		if _net_state_seen:
			EventSfx.play(get_tree(), &"ally_down")
	is_dead = dead
	_net_state_seen = true
	## Kullanıcı isteği: "öldüğü konum ve body si yerinde durmalı" - ceset
	## artık kalıcı olarak sahnede kaldığı için (bkz. yukarıdaki _play_death_
	## animation notu) can/kalkan çubuğu artık anlamsız (hep 0) hale geliyor,
	## çarpışması da kapatılmalı ki kimse cesede takılmasın - is_dead'e göre
	## HER güncellemede yeniden hesaplanıyor ki dükkandan diriltme
	## (revive_from_permadeath, is_dead tekrar false olur) sonrasında ikisi
	## de otomatik geri açılsın.
	if overhead_bar:
		## 2026-09-25: düşmüşken (downed) de gizli - "can ve kalkan barı ölünce gizlensin" (diriltme sayacı onun yerinde).
		overhead_bar.visible = not is_dead and not bool(extra.get("is_downed", false))
	var col: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", is_dead)
	is_downed = extra.get("is_downed", false)
	## Suriyeli Hadime: hayalet/ceset/form durumu - ölüm/diriltme efektlerinden ÖNCE (hayaletken onlar cesedin üstüne).
	_apply_hadime_net_state(extra.get("hadime", {}))
	_update_death_status_fx()
	_update_revive_rewind_fx()
	is_indoors = extra.get("is_indoors", false)
	is_in_merchant_zone = extra.get("is_in_merchant_zone", false)
	## Büyücü "Yükseliş" (R1): Meteor kanalında havada - host'un yaratıkları hedef almasın (köprü/enemy.gd is_invisible okur) ve
	## kukla kasterle aynı şekilde yükselsin (buyucu_levitate.gd is_buyucu_airborne'u her karede sorar, inince kendini siler).
	buyucu_airborne = bool(extra.get("byc_fly", false))
	is_invisible = bool(extra.get("is_invisible", false)) or buyucu_airborne
	if buyucu_airborne and anim and is_instance_valid(anim):
		BuyucuLevitateScript.ensure(self, anim, get_node_or_null("Shadow") as Node2D)
	## Elara'nın Sıvışma'sı (bkz. main.gd extra dict/player.gd _elara_evasion_timer üstündeki AYNI not) -
	## is_ghost_now()'da okunuyor ki enemy.gd bu oyuncuya sert yapışmasın.
	_elara_evasion = extra.get("elara_evasion", false)
	_item_ninja = extra.get("ninja", false)
	has_savas_sevki = extra.get("has_savas_sevki", false)
	luck = float(extra.get("luck", 0.0))
	item_extra_gold_chance = float(extra.get("extra_gold", 0.0))
	exp_gain_percent = float(extra.get("exp_gain", 0.0))
	match_damage_dealt = extra.get("dmg_dealt", 0.0)
	match_damage_taken = extra.get("dmg_taken", 0.0)
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
	## (Yerde yatan müttefiğin griye boyanması 2026-09-25'te kaldırıldı - "ölünce koyu görünüyor" - ölüm klibi yeterli.)
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
	_elara_double = bool(extra.get("elara_double", false)) ## Elara ultisi: tüm silah ikonları titrer (bkz. _update_beam_tremor)
	_elara_focus = bool(extra.get("elara_focus", false))
	## Elara Q/E/R görselleri: kasterdeki AYNI Driver bu bayraklardan kendisi başlatır/bitirir (elara_fx.gd, madde 178).
	if _elara_evasion or _elara_focus or _elara_double:
		ElaraFx.ensure_driver(self)
	if extra.get("matthew_dome", false):
		_ensure_matthew_dome_visual()
	else:
		_remove_matthew_dome_visual()
	_apply_matthew_net_state(extra.get("mt", null))
	_apply_cadi_net_state(extra.get("cadi", null), int(extra.get("cride", 0)))

	## DÜZELTME (derin multiplayer görsel denetimi): Elara'nın "Çift Tetik"
	## efekti TEK SEFERLİK (kısa süreli,
	## kendi kendini yok eden) sahnelerdir - aktivasyon anında zaten
	## _broadcast_skill_scene ile doğru şekilde bir kez yayınlanıyor (bkz.
	## player.gd _skill_elara_double_fire). Burada
	## "extra" durum bayrağı true kaldığı sürece (25s / 30s boyunca) bu
	## tek-seferlik sahneyi _ensure_overlay ile tekrar tekrar yeniden
	## başlatıyorduk - efekt kendi kendine bitip _ensure_overlay'in
	## is_instance_valid kontrolünü geçersiz kıldığı anda, bir sonraki durum
	## güncellemesinde yeniden doğuyordu. Sonuç: uzak oyuncular caster'ın
	## SADECE BİR KEZ gördüğü patlama/parıltı efektini ~1.3-2 saniyede bir
	## tekrar tekrar (sesiyle birlikte) görüyordu. Kalıcı renk tonları
	## artık yukarıdaki "modulate" senkronuyla zaten doğru gösteriliyor;
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
	## "Kan Aynası" tonu formasyon bitince (Ayna Formu kapanınca) sıfırlanır - _update_talon_formation artık çalışmaz.
	if new_talon_formation == "" and _talon_formation != "" and has_evo("talon_rf"):
		for icon in _weapon_icons:
			if is_instance_valid(icon):
				icon.modulate = Color.WHITE
	_talon_formation = new_talon_formation
	_talon_form_active = bool(extra.get("talon_form", false))
	_apply_talon_form_scale()
	_oakley_bond_on = bool(extra.get("oakley_bond", false))
	if _oakley_bond_on and not is_instance_valid(_oakley_bond_fx):
		_oakley_bond_fx = OakleyLeafBarrierScene.instantiate()
		add_child(_oakley_bond_fx)

	if overhead_bar:
		overhead_bar.set_health(health, max_health)
		overhead_bar.set_shield(item_shield_hp, item_shield_max)

	if shield_visual:
		## DÜZELTME (derin multiplayer görsel denetimi): kalkanın GÖRSEL türü
		## (standart/enerji/kale/savaş - bkz. shield_enchant_defs.gd /
		## _owned_shield_type_key) hiç senkronize edilmiyordu, uzak oyuncular
		## her zaman varsayılan (standart) baloncuk görselini görüyordu.
		shield_visual.set_shield_type(extra.get("shield_type", ""))
	if mana_fx:
		mana_fx.set_shield_type(str(extra.get("shield_type", "")))
		mana_fx.set_suppressed(is_dead)
	if shield_visual:
		## DÜZELTME (kullanıcı bildirimi #41): eskiden salt "item_shield_hp >
		## 0.0" kontrolü kalkan dolu dururken bile baloncuğu sürekli
		## gösteriyordu. Artık gönderen tarafın gerçek _bubble_active kararını
		## (bkz. main.gd extra["shield_bubble_visible"] / player.gd
		## _update_shield_bubble) doğrudan kullanıyoruz.
		## DÜZELTME (kullanıcı isteği: "body si yerinde durmalı") - kalıcı
		## ölen bir oyuncunun kalkan baloncuğu artık HİÇ gösterilmemeli (bkz.
		## yukarıdaki overhead_bar/collision ile AYNI gerekçe).
		shield_visual.visible = not is_dead and extra.get("shield_bubble_visible", item_shield_hp > 0.0 or paladin_zone_active)
	## Şovalye Adam'ın Koruma Bariyeri (skill3 id 29) - bkz. main.gd extra
	## dict/fx_paladin_barrier_link.gd. shield_bubble_visible ile AYNI
	## desen, sadece basit bir spawn/despawn child (hazır sahne node'u yok).
	_refresh_barrier_link_visual(extra.get("barrier_link_active", false))
	## Şovalye Adam E (Koruma Bariyeri) - kasterin kendi üstündeki emilim efekti (player.gd ile AYNI sahne).
	paladin_guard_active = bool(extra.get("paladin_guard", false)) and not is_dead
	_refresh_paladin_guard_visual(paladin_guard_active)
	## Ruhani Yetenek "Kalkan Bağı" - BUG DÜZELTMESİ (derin multiplayer denetimi): bağın FX'i eskiden SADECE
	## bağın kendi iki tarafının player.gd'sinde (_ensure_kalkan_bagi_link_fx) kuruluyordu - bağa dahil
	## OLMAYAN üçüncü bir oyuncunun ekranında iki tarafın kuklaları arasında HİÇBİR ŞEY görünmüyordu (tam
	## CLAUDE.md'nin "kaster/karşı taraf görür, geri kalan oyuncular görmez" hata sınıfı - bkz.
	## _barrier_link_fx üstteki AYNI satırla düzeltilen Paladin bariyer örneği, buraya birebir kopyalandı).
	_kalkan_bagi_partner_peer_id = int(extra.get("kalkan_bagi_partner_peer_id", 0))
	_refresh_kalkan_bagi_link_visual(_kalkan_bagi_partner_peer_id > 0)


## DÜZELTME (kullanıcı bildirimi: "Ölen oyuncu multiplayerda bir süre sonra
## tamamen yok oluyor öldüğü konum ve body si yerinde durmalı") - eskiden
## burada 0.6sn'de saydamlaşıp queue_free() ile bu kukla (collision, sprite,
## UI - HEPSİ) sahneden komple siliniyordu. Peer GERÇEKTEN ayrılınca zaten
## AYRI bir yol (bkz. main.gd _remote_players.erase/queue_free, "oyuncu
## ayrılınca" notu) kuklayı temizliyor - burada silmeye hiç gerek yoktu,
## sadece kalıcı ölüm ile "peer ayrıldı" birbirine karıştırılmıştı. Artık
## kukla hiç silinmiyor/saydamlaşmıyor - ölüm animasyonu son karede donuk
## kalıp bir ceset gibi öldüğü konumda kalıcı duruyor. Can/kalkan çubuğu ve
## çarpışmanın gizlenmesi/kapatılması BURADA değil update_extra_state_from_
## net()'te (bkz. orada "is_dead" bloğu) - dükkandan diriltme satın alınıp
## (revive_from_permadeath) is_dead tekrar false olursa o değerlerin GERİ
## açılması gerekiyor, bu yüzden tek seferlik burada değil, her senkron
## güncellemesinde is_dead'e göre yeniden hesaplanan bir yerde olmaları
## lazım (downed_timer_label/shield_visual zaten kendi kendini böyle
## yönetiyordu, bkz. set_remaining_seconds/"shield_bubble_visible" - aynı
## deseni overhead_bar ve çarpışmaya da uyguluyoruz).
func _play_death_animation() -> void:
	if not (anim and anim.sprite_frames):
		return
	## player.gd ölüm klibiyle AYNI öncelik: death_<yön> (yeni setler; yön kuklanın son klibinden okunur),
	## yönsüz "death" (eski atlas karakterler), o da yoksa "hurt" (eski LPC).
	var anim_name: String = CharAnim.pick(anim.sprite_frames, ["death_" + CharAnim.dir_of(String(anim.animation)), "death", "hurt"])
	## Yere düşen oyuncu artık ölüm klibiyle yatıyor (player.gd _go_down) - kalıcı ölüme geçişte aynı klip zaten son
	## karesinde donmuşsa baştan başlatma.
	if anim_name != "" and anim.animation != StringName(anim_name):
		anim.play(anim_name)


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
	## 2026-10-12 rework: tilki kulaklı kubbe yerine Yıldırım Kalkanı (player.gd _skill_shield_dome ile AYNI sahne).
	var shield_scene: PackedScene = load("res://scenes/fx_matthew_lightning_shield.tscn") as PackedScene
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


## Matthew rework (2026-10-12, madde 98): main.gd extra["mt"] = [top (0/1/2), iz güçlenmiş mi (0/1), kalkan parıltı basamağı (0..10)]
## (matthew_lightning.gd pack_state). Anahtar yoksa (Matthew değil) hiçbir şey yapılmaz.
func _apply_matthew_net_state(st: Variant) -> void:
	if not (st is Array) or (st as Array).size() < 3:
		return
	var arr: Array = st
	_matthew_has_mt = true
	var ball: int = int(arr[0])
	if ball != _matthew_ball:
		_set_matthew_ball(ball)
	_matthew_empowered = int(arr[1]) != 0
	_matthew_glow_step = int(arr[2])
	MatthewLightning.apply_glow(anim, float(_matthew_glow_step) / 10.0)


## Top formu aç/kapa: karakter sprite'ı gizlenir, yerine player.gd _skill_matthew_ball ile AYNI sahne (fx_matthew_ball.tscn) oynar.
## Dönüşüm patlaması ayrı gelir ("hitscan_impact", fx_matthew_form_burst.tscn); silah çekilmesi _process_vampir_remote'ta.
func _set_matthew_ball(ball: int) -> void:
	_matthew_ball = ball
	if is_instance_valid(_matthew_ball_fx):
		_matthew_ball_fx.queue_free()
	_matthew_ball_fx = null
	if anim and is_instance_valid(anim):
		anim.visible = ball == 0
	if ball <= 0:
		return
	var scene: PackedScene = load("res://scenes/fx_matthew_ball.tscn") as PackedScene
	if scene == null:
		return
	_matthew_ball_fx = scene.instantiate() as Node2D
	_matthew_ball_fx.set("big", ball >= 2)
	add_child(_matthew_ball_fx)


## Her fizik karesi: kukla ölürse topu kapat; yıldırım izini kuklanın KENDİ hareketinden bırak (kasterdeki _process_matthew_lightning
## ile aynı betik). "Hareket ediyor" ağ aralıklarında titremesin diye kısa bir tolerans süresi var.
func _process_matthew_remote(delta: float) -> void:
	if not _matthew_has_mt:
		return
	if is_dead and _matthew_ball > 0:
		_set_matthew_ball(0)
	if not is_instance_valid(_matthew_trail):
		_matthew_trail = Node.new()
		_matthew_trail.set_script(MatthewTrailScript)
		add_child(_matthew_trail)
		_matthew_trail_prev = global_position
	var step_speed: float = global_position.distance_to(_matthew_trail_prev) / maxf(delta, 0.0001)
	_matthew_trail_prev = global_position
	if step_speed > MatthewLightning.MOVING_SPEED:
		_matthew_move_grace = 0.15
	else:
		_matthew_move_grace = maxf(0.0, _matthew_move_grace - delta)
	var moving: bool = _matthew_move_grace > 0.0 and not is_dead and not is_downed
	_matthew_trail.set("level", 0 if not moving else (2 if _matthew_empowered else 1))
	_matthew_trail.set("intensity", 1.0 if _matthew_empowered else 0.5)


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
const FxSovalyeGuardScene: PackedScene = preload("res://scenes/fx_sovalye_guard.tscn")
var _paladin_guard_fx: Node = null


## bkz. player.gd _refresh_paladin_guard_visual - AYNI sahne yolu (CLAUDE.md "kaster görür, diğerleri görmez" sınıfı).
func _refresh_paladin_guard_visual(active: bool) -> void:
	if active:
		if _paladin_guard_fx == null or not is_instance_valid(_paladin_guard_fx):
			_paladin_guard_fx = FxSovalyeGuardScene.instantiate()
			add_child(_paladin_guard_fx)
	elif _paladin_guard_fx != null and is_instance_valid(_paladin_guard_fx):
		_paladin_guard_fx.queue_free()
		_paladin_guard_fx = null

func _refresh_barrier_link_visual(active: bool) -> void:
	if active:
		if not _barrier_link_fx or not is_instance_valid(_barrier_link_fx):
			_barrier_link_fx = Node2D.new()
			_barrier_link_fx.set_script(load("res://scripts/fx_paladin_barrier_link.gd"))
			add_child(_barrier_link_fx)
	elif _barrier_link_fx and is_instance_valid(_barrier_link_fx):
		_barrier_link_fx.queue_free()
		_barrier_link_fx = null


## Ruhani Yetenek "Kalkan Bağı" - bkz. update_extra_state_from_net()'teki çağrı. fx_kalkan_bagi_link.gd
## `_owner_ref.get("_kalkan_bagi_partner_peer_id")`'i duck-typing ile okuduğu için player.gd'deki AYNI
## isimli alanla değişiklik gerektirmeden çalışıyor - sadece "remote_players" grubunda doğru peer_id'yi arıyor.
var _kalkan_bagi_partner_peer_id: int = 0
var _kalkan_bagi_link_fx: Node2D = null

func _refresh_kalkan_bagi_link_visual(active: bool) -> void:
	if active:
		if not _kalkan_bagi_link_fx or not is_instance_valid(_kalkan_bagi_link_fx):
			_kalkan_bagi_link_fx = Node2D.new()
			_kalkan_bagi_link_fx.set_script(load("res://scripts/fx_kalkan_bagi_link.gd"))
			add_child(_kalkan_bagi_link_fx)
			_kalkan_bagi_link_fx.call("setup", self)
	elif _kalkan_bagi_link_fx and is_instance_valid(_kalkan_bagi_link_fx):
		_kalkan_bagi_link_fx.queue_free()
		_kalkan_bagi_link_fx = null


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
## Gökkuşağı Asası ışını (madde 306): Yıldırım ışınından AYRI kanal ("rbeam_*") - aynı oyuncuda iki ışın aynı anda açık olabilir.
## Kaster weapon.gd (beam_net_kind "rbeam"): start/stop güvenilir, update 0,05 sn'de bir (uç, namlu, pi = final delme, h = tutma/kamaşma),
## hit = vuruş tiki (ps = vurulan konumlar). Görsel fx_rainbow_beam.gd (kasterle AYNI sahne).
const RainbowBeamScene: PackedScene = preload("res://scenes/fx_rainbow_beam.tscn")
var _rbeam_fx: Node2D = null
var _rbeam_last_net_msec: int = 0


func _start_rbeam_vfx(end_pos: Vector2, extra: Dictionary) -> void:
	_stop_rbeam_vfx()
	_rbeam_fx = RainbowBeamScene.instantiate() as Node2D
	add_child(_rbeam_fx)
	_rbeam_last_net_msec = Time.get_ticks_msec()
	_rbeam_fx.setup_network(end_pos, extra)


func _update_rbeam_vfx(end_pos: Vector2, extra: Dictionary) -> void:
	_rbeam_last_net_msec = Time.get_ticks_msec()
	if _rbeam_fx and is_instance_valid(_rbeam_fx):
		_rbeam_fx.update_target(end_pos, Vector2(extra.get("from_pos", Vector2.ZERO)), extra)


func _rbeam_hit(extra: Dictionary) -> void:
	if _rbeam_fx and is_instance_valid(_rbeam_fx):
		_rbeam_fx.play_tick(extra.get("ps", []) as Array)


func _stop_rbeam_vfx() -> void:
	if _rbeam_fx and is_instance_valid(_rbeam_fx):
		_rbeam_fx.queue_free()
	_rbeam_fx = null


## BUG DÜZELTMESİ (çok oyunculu senkron denetimi 2026-09-25): "beam_stop" unreliable kanaldan geliyor - kaybolursa ışın
## (ve sesi) bir sonraki "beam_start"a kadar bu kuklada asılı kalıyordu (hafızada da not vardı). Işın açıkken sahibi
## 0.05 sn'de bir "beam_update" yollar (weapon.gd); BEAM_NET_TIMEOUT_MSEC boyunca hiç güncelleme gelmezse kendiliğinden kapanır.
const BEAM_NET_TIMEOUT_MSEC := 500
var _beam_last_net_msec: int = 0

func _start_beam_vfx(_beam_type: String, target_pos: Vector2, extra_data: Dictionary) -> void:
	if _beam_fx and is_instance_valid(_beam_fx):
		_beam_fx.queue_free()
		_beam_fx = null
	var beam_scene: PackedScene = load("res://scenes/fx_lightning_beam.tscn") as PackedScene
	if beam_scene:
		_beam_fx = beam_scene.instantiate() as Node2D
		add_child(_beam_fx)
		_beam_last_net_msec = Time.get_ticks_msec()
		if _beam_fx.has_method("setup_network"):
			_beam_fx.setup_network(target_pos, extra_data)
		## İlk çakış sesi (madde 294) - kasterde weapon.gd yeni hedefte çalar; setup_network'ten SONRA (uzak kısma + mesafe kuralı).
		if _beam_fx.has_method("play_strike_sfx"):
			_beam_fx.play_strike_sfx(target_pos, get_instance_id())


## Yıldırım Asası vuruş tiki (network_manager.gd "beam_hit", madde 294): kasterin seçtiği ses + perde hedef konumunda (ışın o an silinmiş
## olabilir - ses ışına bağlı değil), uzak ışının uğultusu çöker. Kural tek yerde: fx_lightning_beam.gd play_hit_at.
func _beam_hit_sfx(pos: Vector2, data: Dictionary) -> void:
	LightningBeamFxScript.play_hit_at(get_tree(), pos, data, LightningBeamFxScript.AudioBusesScript.remote_weapon_db(), true)
	if _beam_fx and is_instance_valid(_beam_fx) and _beam_fx.has_method("duck"):
		_beam_fx.duck()

## Yıldırım asası aktifken (ışın açık) ikon hafifçe titrer (kullanıcı isteği 2026-10-04) - kasterde weapon.gd _apply_beam_tremor,
## AYNI WeaponJuice.tremor_offset. Konum dinlenme yuvasına (WEAPON_ICON_SLOTS) göre; yuvanın konumunu başka bir sistem yönetirken
## (formasyon / Vampir çekilmesi / ölüm düşüşü) dokunulmaz.
var _beam_tremor_on: bool = false


var _elara_double: bool = false


## Yıldırım ışını (sadece asa) + 2026-10-10 Elara ultisi Çift Tetik (TÜM silahlar; kullanıcı: "Elara'nın ultisi aktifken tüm silahlarının titremesini istiyorum")
## - kasterde weapon.gd _apply_beam_tremor / _apply_ult_tremor ile AYNI WeaponJuice.tremor_offset.
func _update_beam_tremor() -> void:
	var beam_on: bool = _beam_fx != null and is_instance_valid(_beam_fx) and not is_dead
	var all_on: bool = _elara_double and not is_dead
	var active: bool = beam_on or all_on
	if not active and not _beam_tremor_on:
		return
	_beam_tremor_on = active
	if _talon_formation != "" or _vampir_pull > 0.0:
		return
	for slot in range(_weapon_keys.size()):
		## yakın dövüş silahları (savuruş konumu) kasterdeki gibi titremez
		var slot_on: bool = (all_on and not WeaponCatalogScript.MELEE_KEYS.has(str(_weapon_keys[slot]))) or (beam_on and str(_weapon_keys[slot]) == "lightning_staff")
		if not slot_on and not all_on and str(_weapon_keys[slot]) != "lightning_staff":
			continue
		var info: Array = get_weapon_icon_info(slot)
		if info.is_empty():
			continue
		var icon: Node2D = info[0] as Node2D
		var idx: int = _weapon_icons.find(icon)
		if idx < 0 or idx >= WEAPON_ICON_SLOTS.size():
			continue
		if is_dead or is_downed:
			continue
		if idx < _weapon_fire_tweens.size() and _weapon_fire_tweens[idx] is Tween and (_weapon_fire_tweens[idx] as Tween).is_valid():
			continue ## kritik tikinin "jitter" tween'i sürerken ona karışılmaz (kasterde weapon.gd _apply_beam_tremor aynısı)
		var base_pos: Vector2 = WEAPON_ICON_SLOTS[idx]
		icon.position = base_pos + (WeaponJuice.tremor_offset(Time.get_ticks_msec() / 1000.0 + float(slot) * 0.37) if slot_on else Vector2.ZERO)


func _stop_beam_vfx() -> void:
	if _beam_fx and is_instance_valid(_beam_fx):
		_beam_fx.queue_free()
		_beam_fx = null

func _update_beam_vfx(target_pos: Vector2, origin_pos: Vector2 = Vector2.ZERO) -> void:
	_beam_last_net_msec = Time.get_ticks_msec()
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
	## Necromancer golem evrimleri (E4 boyut): kozmetik kopya da sahibinin evrimlerine göre büyür (golem_pet.gd apply_necro_evos).
	if pet_visual.has_method("apply_necro_evos"):
		pet_visual.apply_necro_evos(self)
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


## Bu oyuncunun en yeni Necromancer golem kopyası (Son Çare Golemi kışkırtmasının hedefi, bkz. network_manager.gd "taunt_ally"); yoksa null.
func get_newest_golem_visual() -> Node2D:
	var best: Node2D = null
	for key in _pet_visuals.keys():
		var v: Variant = _pet_visuals[key]
		if is_instance_valid(v) and v.has_method("apply_size_evo"):
			best = v
	return best


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
			## Büyücü hortumu (madde 188): kasterdeki gibi alttan çözülerek kaybolur (begin_out kendini siler).
			if p.has_method("begin_out"):
				p.begin_out()
			else:
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
func _update_pet_visual_state(instance_id: String, pos: Vector2, is_attacking: bool, health_ratio: float = -1.0, shield_ratio: float = -1.0, sprite_row: int = -1, teleport: bool = false) -> void:
	if not _pet_visuals.has(instance_id):
		return
	var p = _pet_visuals[instance_id]
	if not is_instance_valid(p):
		return
	if health_ratio >= 0.0 and p.has_method("update_network_golem_state"):
		p.update_network_golem_state(pos, is_attacking, health_ratio, shield_ratio, sprite_row)
	elif p.has_method("update_network_pet_state"):
		## BUG DÜZELTMESİ (kullanıcı bildirimi 2026-09-24: "Necromancerın iskeletleri diğer oyuncularda sabit ve donuk
		## gözüküyor senkronize değil"): 2026-09-22'de Matthew'in tilkisi için "teleport" 4. argümanı eklenmiş, çağrı
		## HER pet'e 4 argümanla yapılıyordu - ama skeleton_pet.gd / papagan_pet.gd / fx_buyucu_tornado.gd /
		## wraith_pet.gd'nin update_network_pet_state'i 3 argüman alıyordu. Fazla argümanlı çağrı GDScript'te çalışma
		## anı hatası -> konum/yön/saldırı güncellemesi HİÇ uygulanmıyor, kozmetik kopya doğduğu yerde donuk kalıyordu
		## (iskelet, Büyücü'nün hortumu, papağan). Artık hedef metodun gerçek argüman sayısına göre çağrılıyor - ileride
		## bir pet'e yeni argüman eklense de diğerleri kırılmaz.
		var argc: int = p.get_method_argument_count("update_network_pet_state")
		if argc >= 4:
			p.update_network_pet_state(pos, is_attacking, sprite_row, teleport)
		elif argc == 3:
			p.update_network_pet_state(pos, is_attacking, sprite_row)
		else:
			p.update_network_pet_state(pos, is_attacking)


## Kullanıcı isteği: "senkronize et, ben nasıl görüyosam diğer oyuncular da
## öyle görmeli" - Oakley'in Sarmaşıkları (bkz. oakley_vine.gd dosya başı
## DÜZELTME notu) için _pet_visuals ile BİREBİR AYNI desen, ayrı bir sözlükte
## (id çakışması olmasın diye). Sahne dosyası YOK (oakley_vine.gd düz bir
## Node2D script'i, player.gd'nin GERÇEK sarmaşığı oluşturduğu şekliyle
## BİREBİR aynı - Node2D.new() + set_script) - bkz. network_manager.gd
## broadcast_oakley_vine_spawn/despawn/state.
var _vine_visuals: Dictionary = {} ## instance_id(String) -> Node2D

func _spawn_vine_visual(instance_id: String) -> void:
	_despawn_vine_visual(instance_id)
	var vine := Node2D.new()
	vine.set_script(preload("res://scripts/oakley_vine.gd"))
	## bkz. _spawn_pet_visual'daki AYNI DÜZELTME notu - RemotePlayer'ın kendi
	## (kuklayı küçültmek için) gizli scale'ini miras almasın diye sahnenin
	## KÖKÜNE, GERÇEK sarmaşıkla (player.gd _skill_oakley_vines) aynı şekilde ekleniyor.
	## Konum ve kozmetik bayrağı add_child'dan ÖNCE (bkz. player.gd _skill_oakley_vines DÜZELTME notu - _ready konumu kullanır).
	vine.position = global_position + preload("res://scripts/oakley_vine.gd").CASTER_FEET_OFFSET
	if vine.has_method("mark_as_network_visual"):
		vine.mark_as_network_visual()
	get_tree().current_scene.add_child(vine)
	_vine_visuals[instance_id] = vine
	vine.tree_exiting.connect(func() -> void:
		if _vine_visuals.get(instance_id) == vine:
			_vine_visuals.erase(instance_id)
	)


func _despawn_vine_visual(instance_id: String) -> void:
	if not _vine_visuals.has(instance_id):
		return
	var v = _vine_visuals[instance_id]
	if is_instance_valid(v):
		## Gerçek sarmaşıkla aynı gömülme efekti (bkz. oakley_vine.gd despawn).
		if v.has_method("despawn"):
			v.despawn()
		else:
			v.queue_free()
	_vine_visuals.erase(instance_id)


func _update_vine_visual_state(instance_id: String, pos: Vector2, target_pos: Vector2, has_target: bool) -> void:
	if not _vine_visuals.has(instance_id):
		return
	var v = _vine_visuals[instance_id]
	if not is_instance_valid(v) or not v.has_method("update_network_vine_state"):
		return
	v.update_network_vine_state(pos, target_pos, has_target)


## Gölgeyi ikonun konumuna bağlar (pivot dönüşümünü uygulayan _wf_update_all bunu ezer; ikon başka bir sistemin elindeyken
## ya da pivot kimlikteyken geçerli olan budur). Ölü/yerdeki kuklada silahlar yere düşmez, göğse çekilir (_wf_update_all).
func _refresh_remote_weapon_shadows() -> void:
	for i in range(_weapon_icons.size()):
		if is_instance_valid(_weapon_icons[i]):
			_refresh_remote_weapon_shadow(i)


func _refresh_remote_weapon_shadow(i: int) -> void:
	if i >= _weapon_shadows.size() or not is_instance_valid(_weapon_shadows[i]):
		return
	var gap: float = WeaponOrbitMath.hover_shadow_gap(_weapon_icons[i].position.y)
	_weapon_shadows[i].position = _weapon_icons[i].position + Vector2(0, gap)


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


## Tabanca/Tüfek şarjör doldurma (madde 296, "weapon_reload" yayını): kasterle AYNI GunReloadFx (poz + düşen şarjör + sesler
## + parıltı), kendi saatiyle `dur` sn. dur <= 0 = iptal (sahip öldü). İkon konumunu başka bir sistem yönetirken
## (Talon dizilimi / Vampir çekilmesi / kubbe halkası) kasterdeki gibi poz yok.
func _start_weapon_reload(slot_index: int, dur: float) -> void:
	if slot_index < 0 or slot_index >= _weapon_icons.size():
		return
	var icon: Node2D = _weapon_icons[slot_index]
	if not is_instance_valid(icon):
		return
	if dur <= 0.0:
		var cur: Variant = icon.get_meta(GunReloadFx.META) if icon.has_meta(GunReloadFx.META) else null
		if cur is Node and is_instance_valid(cur):
			(cur as Node).call("abort")
		return
	var wkey: String = str(_weapon_keys[slot_index]) if slot_index < _weapon_keys.size() else ""
	if not GunMagMath.has_mag(wkey) or _talon_formation != "" or _vampir_pull > 0.0 or _dome_rim_owns_icons():
		return
	var base_pos: Vector2 = WEAPON_ICON_SLOTS[slot_index] if slot_index < WEAPON_ICON_SLOTS.size() else icon.position
	var base_scale: Vector2 = _weapon_base_scales[slot_index] if slot_index < _weapon_base_scales.size() else icon.scale
	var fwd: float = float(_weapon_forward_angle_deg[slot_index]) if slot_index < _weapon_forward_angle_deg.size() else 0.0
	var kill := func() -> void:
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] is Tween and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		if is_instance_valid(icon) and icon.has_meta("punch_tween"):
			var pt: Variant = icon.get_meta("punch_tween")
			if pt is Tween and (pt as Tween).is_valid():
				(pt as Tween).kill()
	GunReloadFx.begin(self, icon, wkey, dur, self, {"base_pos": base_pos, "base_scale": base_scale, "forward_deg": fwd,
		"external": false, "kill_tweens": kill})


## KULLANICI BİLDİRİMİ: "Talon'un ultisi açıkken silahlarının yarattığı geri tepme diğer oyunculara çok daha yoğun
## gösteriliyor, silahlar yerlerinden fırlıyor gibi". KÖK NEDEN: _animate_weapon_recoil/_animate_weapon_fire_full ikon
## konumunu HER ZAMAN sabit WEAPON_ICON_SLOTS (kafanın üstündeki 5 nokta) tabanına göre tween'liyor. Talon'un Silah
## Salvosu/Ayna Formu sırasında ikonlar ise karakter ETRAFINDA bir çemberde (_update_talon_formation her fizik karesinde
## konumu yeniden yazıyor) - yani her ateş olayında ikon çemberden slot konumuna fırlatılıp (ve yakın dövüşte hedefe kadar
## savrulup) sonra çembere geri yazılıyordu; Ayna Formu silah sayısını 2'ye katladığı için çok daha sık. Caster'da bu
## hareket ikon spritenin YEREL ofsetiydi (weapon node'u formasyondaydı), uzak kopyada ise ikonun kendisi. Formasyon
## sürerken artık ikon konumuna DOKUNULMUYOR: sadece küçük, hızla sönen bir ofset (formasyon konumuna EKLENİR).
var _formation_kick: Array = [] ## ikon başına Vector2, _update_talon_formation konuma ekler
const FORMATION_KICK_MAX := 6.0 ## px
const FORMATION_KICK_TIME := 0.12
const DOME_RIM_BLEND_TIME := 0.45 ## weapon.gd RIM_BLEND_TIME ile aynı


func _formation_kick_offset(i: int) -> Vector2:
	return _formation_kick[i] if i < _formation_kick.size() else Vector2.ZERO


## Şovalye kubbesi halkası (dome_weapon_ring.gd) bu kuklanın silahlarını almasın: ölü/yerde ya da silahlar başka bir sistemin
## (Talon formasyonu, Vampir çekilmesi) elinde. player.gd dome_rim_blocked ile aynı kural.
## Talon dizilimi (E/R) artık engellemez - kubbe içinde halka önceliklidir (player.gd dome_rim_blocked ile aynı karar).
func dome_rim_blocked() -> bool:
	return is_dead or is_downed or _vampir_pull > 0.0


## Kubbe halkası yöneticisi (dome_weapon_ring.gd) için: bu kukla Talon Silah Salvosu'nda mı (kubbe girdabı).
func is_talon_salvo() -> bool:
	return _talon_formation == "salvo" and not is_dead


func _kick_formation_icon(slot_index: int, fire_dir: Vector2, recoil_dist: float) -> void:
	while _formation_kick.size() <= slot_index:
		_formation_kick.append(Vector2.ZERO)
	var start: Vector2 = -fire_dir.normalized() * minf(recoil_dist, FORMATION_KICK_MAX) if fire_dir.length() > 0.001 else Vector2.ZERO
	if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
		(_weapon_fire_tweens[slot_index] as Tween).kill()
	var tw := create_tween()
	tw.tween_method(func(v: Vector2) -> void:
		if slot_index < _formation_kick.size():
			_formation_kick[slot_index] = v
	, start, Vector2.ZERO, FORMATION_KICK_TIME)
	if slot_index < _weapon_fire_tweens.size():
		_weapon_fire_tweens[slot_index] = tw


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
	if _talon_formation != "" or _vampir_pull > 0.0 or _dome_rim_owns_icons():
		_kick_formation_icon(slot_index, Vector2.UP, recoil_dist) ## bkz. _formation_kick notu
		return
	## Geri tepmesi "weapon_fire" yayınındaki tam animasyonla (WeaponJuice.ranged_recoil) oynanan silahlarda bu basit aşağı
	## itme atlanır - iki tween aynı ikonda çekişirdi.
	if slot_index < _weapon_keys.size() and WeaponJuice.has_ranged_recoil(str(_weapon_keys[slot_index])):
		return
	var base_pos: Vector2 = WEAPON_ICON_SLOTS[slot_index] if slot_index < WEAPON_ICON_SLOTS.size() else icon.position
	# Quick kick-back tween
	var tw := create_tween()
	tw.tween_property(icon, "position", base_pos + Vector2(0, recoil_dist), 0.04)
	tw.tween_property(icon, "position", base_pos, 0.08).set_delay(0.02)


## Büyücü Kız pasifi "Büyü Dalgası" - atışsız yetenek kullanımında (hedef yok / şarjör / bumerang havada) silah ikonunun sertçe
## ileri fırlaması (kasterde weapon.gd _surge_visual). Atışlı durumda aynı görsel "weapon_fire" yayınındaki "surge" ile gelir.
func _animate_weapon_surge(slot_index: int, dir: Vector2) -> void:
	if slot_index < 0 or slot_index >= _weapon_icons.size():
		return
	var icon: Node2D = _weapon_icons[slot_index]
	if not is_instance_valid(icon) or not icon.visible:
		return
	if _talon_formation != "" or _vampir_pull > 0.0 or _dome_rim_owns_icons():
		WeaponJuice.surge_flash(self, icon) ## konumu başka bir sistem yönetiyor (bkz. _formation_kick): sadece parlama + kıvılcım
		WeaponJuice.spawn_surge_spark(self, icon)
		return
	var base_pos: Vector2 = WEAPON_ICON_SLOTS[slot_index] if slot_index < WEAPON_ICON_SLOTS.size() else icon.position
	var base_scale: Vector2 = _weapon_base_scales[slot_index] if slot_index < _weapon_base_scales.size() else icon.scale
	if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
		(_weapon_fire_tweens[slot_index] as Tween).kill()
	var tw: Tween = WeaponJuice.arcane_surge(self, icon, dir, base_pos, base_scale)
	if slot_index < _weapon_fire_tweens.size():
		_weapon_fire_tweens[slot_index] = tw


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
	## Talon formasyonu (Salvo/Ayna Formu) ya da Vampir'in silah çekilmesi sürerken ikon konumu başka bir sistemin (formül) elinde:
	## slot tabanlı savurma/geri tepme tween'i onunla çekişip silahı fırlatıyordu - sadece küçük ofset uygula (bkz. _formation_kick).
	var formation_owns_position: bool = _talon_formation != "" or _vampir_pull > 0.0 or _dome_rim_owns_icons()
	## Kritik atış (bkz. weapon_crit_anim.gd) - kaster weapon.gd'de aynı fonksiyonları oynatır.
	var is_crit: bool = bool(data.get("crit", false))
	var wkey: String = str(_weapon_keys[slot_index]) if slot_index < _weapon_keys.size() else ""
	var base_scale_all: Vector2 = _weapon_base_scales[slot_index] if slot_index < _weapon_base_scales.size() else icon.scale
	## Büyücü Kız pasifi (weapon.gd arcane_surge): güçlendirilmiş atış - mor parlama her silahta, menzilli ikon ayrıca ileri fırlar
	## (aşağıda, kasterle aynı WeaponJuice.arcane_surge).
	var is_surge: bool = bool(data.get("surge", false))
	if is_surge:
		WeaponJuice.surge_flash(self, icon)
		if is_melee:
			WeaponJuice.spawn_surge_spark(self, icon) ## menzilli silahta kıvılcım WeaponJuice.arcane_surge içinde

	if is_melee and formation_owns_position:
		_kick_formation_icon(slot_index, dir, float(_weapon_recoil_distance[slot_index]) if slot_index < _weapon_recoil_distance.size() else 8.0)
	elif is_melee and slot_index < _weapon_is_sword.size() and _weapon_is_sword[slot_index] and data.has("sword_side"):
		## Uzunkılıç: kasterle AYNI savuruş (bkz. weapon.gd _start_sword_swing) - plan kuklanın kendi kök ölçeğiyle kurulur.
		var s_target := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		var s_forward: float = deg_to_rad(_weapon_forward_angle_deg[slot_index] if slot_index < _weapon_forward_angle_deg.size() else 0.0)
		var s_rest_rot: float = deg_to_rad(_weapon_rest_rotation_deg[slot_index] if slot_index < _weapon_rest_rotation_deg.size() else 0.0)
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		var s_tw: Tween
		var s_hold: float = float(data.get("chain_hold", 0.0)) ## madde 347 zincir: kasterle aynı bekleme (eski sürüm göndermez -> hemen döner)
		if is_crit:
			var stab: Dictionary = SwordSwingMath.make_stab_plan(dir, s_target, float(data.get("sword_size", 1.0)), scale.x)
			s_tw = SwordSwingMath.play_stab(self, icon, stab, s_forward, base_pos, s_rest_rot, float(data.get("sword_speed", 1.0)), s_hold)
		else:
			var s_plan: Dictionary = SwordSwingMath.make_plan(dir, s_target, float(data.get("sword_side", 1.0)),
				float(data.get("sword_size", 1.0)), scale.x)
			s_tw = SwordSwingMath.play(self, icon, s_plan, s_forward, base_pos, s_rest_rot,
				float(data.get("sword_speed", 1.0)), get_tree().current_scene, s_hold)
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = s_tw
	elif is_melee and wkey == "dagger" and data.has("dagger_speed"):
		## Bıçak "Kıvılcım Saplama" (madde 231): kasterle AYNI saplama planı + efekt (bkz. weapon.gd _start_dagger_stab) - plan
		## kuklanın kendi kök ölçeğiyle kurulur; efekti burada DaggerStabMath.play çıkarır (broadcast_weapon_attack gelmez).
		var d_target := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		var d_forward: float = deg_to_rad(_weapon_forward_angle_deg[slot_index] if slot_index < _weapon_forward_angle_deg.size() else 0.0)
		var d_rest_rot: float = deg_to_rad(_weapon_rest_rotation_deg[slot_index] if slot_index < _weapon_rest_rotation_deg.size() else 0.0)
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		var d_plan: Dictionary = DaggerStabMath.make_plan(dir, d_target, float(data.get("dagger_size", 1.0)), scale.x)
		var d_tw: Tween = DaggerStabMath.play(self, icon, d_plan, d_forward, base_pos, d_rest_rot, base_scale_all,
			float(data.get("dagger_speed", 1.0)), is_crit, get_tree().current_scene, float(data.get("chain_hold", 0.0)))
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = d_tw
	elif is_melee and wkey == "topuz" and data.has("topuz_speed"):
		## Topuz "Yer Sarsıntısı" (madde 235): kasterle AYNI kaldır-indir planı + efektler (bkz. weapon.gd _start_topuz_slam) -
		## plan kuklanın kendi kök ölçeğiyle kurulur; efektleri burada TopuzSlamMath.play çıkarır (broadcast_weapon_attack gelmez).
		var t_target := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		var t_forward: float = deg_to_rad(_weapon_forward_angle_deg[slot_index] if slot_index < _weapon_forward_angle_deg.size() else 0.0)
		var t_rest_rot: float = deg_to_rad(_weapon_rest_rotation_deg[slot_index] if slot_index < _weapon_rest_rotation_deg.size() else 0.0)
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		var t_plan: Dictionary = TopuzSlamMath.make_plan(dir, t_target, float(data.get("topuz_size", 1.0)), scale.x)
		var t_tw: Tween = TopuzSlamMath.play(self, icon, t_plan, t_forward, base_pos, t_rest_rot, base_scale_all,
			float(data.get("topuz_speed", 1.0)), is_crit, get_tree().current_scene, float(data.get("chain_hold", 0.0)))
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = t_tw
	elif is_melee and wkey == "pence" and data.has("pence_speed"):
		## Pençe "Kanca Çekiş" (madde 237): kasterle AYNI atıl-saplan-yırt planı + efektler (bkz. weapon.gd _start_pence_hook) -
		## plan kuklanın kendi kök ölçeğiyle kurulur; efektleri burada PenceHookMath.play çıkarır (broadcast_weapon_attack gelmez).
		var p_target := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		var p_forward: float = deg_to_rad(_weapon_forward_angle_deg[slot_index] if slot_index < _weapon_forward_angle_deg.size() else 0.0)
		var p_rest_rot: float = deg_to_rad(_weapon_rest_rotation_deg[slot_index] if slot_index < _weapon_rest_rotation_deg.size() else 0.0)
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		var p_plan: Dictionary = PenceHookMath.make_plan(dir, p_target, float(data.get("pence_size", 1.0)), scale.x,
			float(data.get("pence_tilt", 0.0))) ## kasterin seçtiği geliş açısı (eski sürüm göndermez -> düz)
		var p_tw: Tween = PenceHookMath.play(self, icon, p_plan, p_forward, base_pos, p_rest_rot, base_scale_all,
			float(data.get("pence_speed", 1.0)), is_crit, get_tree().current_scene, float(data.get("chain_hold", 0.0)))
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = p_tw
	elif is_melee and wkey == "mizrak" and data.has("mizrak_speed"):
		## Mızrak "Işık Hattı" + cirit (madde 305): kasterle AYNI süzül-geri çek-sapla / fırlat planı + efektler (bkz. weapon.gd
		## _start_mizrak_thrust) - plan kuklanın kendi kök ölçeğiyle; ciritin uçuş boyu/hızı kasterden gelir. Delinen yaratık
		## yıldızları kuklanın kendi yaratık kuklalarıyla aynı hat sorgusundan (kozmetik).
		var m_target := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		var m_forward: float = deg_to_rad(_weapon_forward_angle_deg[slot_index] if slot_index < _weapon_forward_angle_deg.size() else 0.0)
		var m_rest_rot: float = deg_to_rad(_weapon_rest_rotation_deg[slot_index] if slot_index < _weapon_rest_rotation_deg.size() else 0.0)
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		var m_speed: float = float(data.get("mizrak_speed", 1.0))
		var m_throw: Dictionary = {}
		if data.has("mizrak_travel"):
			m_throw = {"speed": float(data.get("mizrak_fly", MizrakThrustMath.CIRIT_SPEED))}
		var m_plan: Dictionary = MizrakThrustMath.make_plan(dir, m_target, float(data.get("mizrak_size", 1.0)), scale.x, m_throw)
		var m_scene: Node = get_tree().current_scene
		var m_release: Callable = Callable()
		if bool(m_plan["throw"]):
			m_plan["travel"] = float(data.get("mizrak_travel", 0.0))
			m_release = func() -> void:
				MizrakThrustMath.schedule_hit_stars(self, m_plan, MizrakThrustMath.throw_victims(get_tree(), m_plan), 0.0, m_scene, 1.0)
		else:
			get_tree().create_timer(MizrakThrustMath.contact_delay(m_speed), false).timeout.connect(func() -> void:
				if is_inside_tree():
					MizrakThrustMath.schedule_hit_stars(self, m_plan, MizrakThrustMath.line_victims(get_tree(), m_plan), 0.0, m_scene, m_speed))
		var m_tw: Tween = MizrakThrustMath.play(self, icon, m_plan, m_forward, base_pos, m_rest_rot, base_scale_all, m_speed, is_crit,
			m_scene, m_release, float(data.get("chain_hold", 0.0)))
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = m_tw
	elif is_melee and wkey == "kalkan" and data.has("kalkan_speed"):
		## Kalkan "Hayalet Kalkan" (madde 338): kasterle AYNI darbe planı + hayalet (bkz. weapon.gd _start_kalkan_bash) - plan kuklanın
		## kendi kök ölçeğiyle; kademe ve Final kasterden. Ayaktaki halkalar kuklanın kendi yaratık kuklalarıyla aynı sorgudan (kozmetik).
		var k_target := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()
		var k_speed: float = float(data.get("kalkan_speed", 1.0))
		var k_plan: Dictionary = KalkanBashMath.make_plan(dir, k_target, float(data.get("kalkan_size", 1.0)), scale.x,
			bool(data.get("kalkan_wall", false)), global_position)
		var k_scene: Node = get_tree().current_scene
		get_tree().create_timer(KalkanBashMath.contact_delay(k_speed), false).timeout.connect(func() -> void:
			if is_inside_tree():
				k_plan["owner"] = global_position
				KalkanBashMath.spawn_rings(k_scene, KalkanBashMath.victims(get_tree(), k_plan), k_plan))
		var k_tw: Tween = KalkanBashMath.play(self, icon, k_plan, int(data.get("kalkan_tier", icon.get_meta("tier_art", 1))), base_pos,
			base_scale_all, k_speed, is_crit, k_scene, float(data.get("chain_hold", 0.0)))
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = k_tw
	elif is_melee:
		var target_pos := Vector2(float(data.get("target_pos_x", 0.0)), float(data.get("target_pos_y", 0.0)))
		var reps: int = _weapon_hit_segments[slot_index] if slot_index < _weapon_hit_segments.size() else 3
		var forward: float = deg_to_rad(_weapon_forward_angle_deg[slot_index] if slot_index < _weapon_forward_angle_deg.size() else 0.0)
		var rest_rot: float = deg_to_rad(_weapon_rest_rotation_deg[slot_index] if slot_index < _weapon_rest_rotation_deg.size() else 0.0)
		var slash_offset: float = _weapon_slash_fx_offset[slot_index] if slot_index < _weapon_slash_fx_offset.size() else 18.0
		var slash_above: float = _weapon_slash_fx_above_offset[slot_index] if slot_index < _weapon_slash_fx_above_offset.size() else 0.0
		var hold_duration: float = float(data.get("hold_duration", 0.0))
		
		var dist: float = global_position.distance_to(target_pos)
		var strike_center: Vector2 = base_pos + dir * max(0.0, dist - slash_offset) + Vector2(0.0, -slash_above)
		if is_crit and WeaponCritAnim.is_melee_kind(wkey):
			if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
				(_weapon_fire_tweens[slot_index] as Tween).kill()
			var c_tw: Tween = WeaponCritAnim.play_melee(self, icon, wkey, dir, base_pos, strike_center, forward, rest_rot,
				base_scale_all, hold_duration)
			if slot_index < _weapon_fire_tweens.size():
				_weapon_fire_tweens[slot_index] = c_tw
			return
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
		if GunMagMath.has_mag(wkey):
			ShellCasingFx.eject(icon, wkey, dir, self) ## boş kovan (madde 296) - kasterde weapon.gd _fire_at
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
		
		if formation_owns_position:
			_kick_formation_icon(slot_index, dir, recoil_dist)
			return
		## Önceki ateşten kalan (henüz bitmemiş) tween varsa öldürülür - üst
		## üste binen tween'ler aynı sabit hedeflere gittiği için artık
		## büyümeye katkı yapamaz, ama yine de titremeyi önlemek için kesilir.
		if slot_index < _weapon_fire_tweens.size() and _weapon_fire_tweens[slot_index] and (_weapon_fire_tweens[slot_index] as Tween).is_valid():
			(_weapon_fire_tweens[slot_index] as Tween).kill()

		if is_surge:
			var old_surge_punch: Variant = icon.get_meta("punch_tween") if icon.has_meta("punch_tween") else null
			if old_surge_punch is Tween and (old_surge_punch as Tween).is_valid():
				(old_surge_punch as Tween).kill()
			var s_tw2: Tween = WeaponJuice.arcane_surge(self, icon, dir, base_pos, base_scale, recoil_dist)
			if slot_index < _weapon_fire_tweens.size():
				_weapon_fire_tweens[slot_index] = s_tw2
			return
		if is_crit and WeaponCritAnim.kind_of(wkey) != "":
			var old_crit_punch: Variant = icon.get_meta("punch_tween") if icon.has_meta("punch_tween") else null
			if old_crit_punch is Tween and (old_crit_punch as Tween).is_valid():
				(old_crit_punch as Tween).kill()
			var r_tw: Tween = WeaponCritAnim.play_ranged(self, icon, wkey, dir, base_pos, base_scale, recoil_dist)
			if slot_index < _weapon_fire_tweens.size():
				_weapon_fire_tweens[slot_index] = r_tw
			return

		if WeaponJuice.has_ranged_recoil(wkey):
			## Yay/crossbow/tabanca/ateş-buz asası/tüfek/tüftüf: kasterle (weapon.gd _do_recoil) AYNI geri tepme + namlu kalkması.
			var old_rr_punch: Variant = icon.get_meta("punch_tween") if icon.has_meta("punch_tween") else null
			if old_rr_punch is Tween and (old_rr_punch as Tween).is_valid():
				(old_rr_punch as Tween).kill()
			var rr_tw: Tween = WeaponJuice.ranged_recoil(self, icon, wkey, dir, base_pos, base_scale, recoil_dist)
			if slot_index < _weapon_fire_tweens.size():
				_weapon_fire_tweens[slot_index] = rr_tw
			return

		var tw := create_tween()
		if slot_index < _weapon_fire_tweens.size():
			_weapon_fire_tweens[slot_index] = tw
		tw.tween_property(icon, "position", base_pos + kick, 0.04)
		tw.tween_property(icon, "position", base_pos, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		## Ölçek: gerçek silahla (weapon.gd _do_recoil) AYNI ezilip esneyen "punch" - bkz. weapon_juice.gd.
		## (Eskiden burada düz %15 büyüme vardı, yerel silahta hiç yoktu - iki taraf farklı görünüyordu.)
		## get_meta(ad, null): Godot varsayılan null'ı "varsayılan yok" sayıp HER atışta hata basıyordu (efsun çok
		## oyunculu testinde host logunda yakalandı) - önce has_meta.
		var old_punch: Variant = icon.get_meta("punch_tween") if icon.has_meta("punch_tween") else null
		if old_punch is Tween and (old_punch as Tween).is_valid():
			(old_punch as Tween).kill()
		var punch: Tween = WeaponJuice.fire_punch(self, icon, base_scale)
		icon.set_meta("punch_tween", punch)


## Eski format için geri uyumluluk.
func _animate_weapon_fire(slot_index: int, fire_direction: Vector2, is_melee: bool, atk_range: float) -> void:
	_animate_weapon_fire_full({
		"slot_index": slot_index,
		"direction_x": fire_direction.x,
		"direction_y": fire_direction.y,
		"is_melee": is_melee,
		"attack_range": atk_range,
	})


## Kullanıcı isteği (2026-09-25): "başka oyuncuların hasar/iyileştirme sayısını görmemeliyiz" - kukla heal()/
## heal_shield() artık SAYI GÖSTERMEZ (ör. host'ta bir arkadaşın yediği yemek). Sayı SADECE destek veren kişinin
## ekranında, onun açıkça çağırdığı show_support_number() ile çıkar (bkz. player.gd _apply_heal_to_ally); hedef
## kendi ekranında kendi Player'ında görür (network_manager.gd sync_ally_heal/sync_ally_shield_heal).
func heal(amount: float) -> void:
	if is_dead or is_downed or amount <= 0.0: ## yere düşen kukla is_dead false gelir (main.gd send_dead) - is_downed da sayılır
		return
	health = min(max_health, health + amount)
	if overhead_bar:
		overhead_bar.set_health(health, max_health)


func heal_shield(amount: float) -> void:
	if is_dead or is_downed or amount <= 0.0 or item_shield_max <= 0.0:
		return
	item_shield_hp = min(item_shield_max, item_shield_hp + amount)
	if overhead_bar:
		overhead_bar.set_shield(item_shield_hp, item_shield_max)


## BU istemcinin oyuncusu bu arkadaşa can (yeşil) / kalkan (mavi) bastığında onun üstünde miktarı gösterir.
## Canı/kalkanı zaten doluysa gösterilmez; 1'in altındaki tikler birikip tam sayıya ulaşınca yazılır.
var _shield_display_accum: float = 0.0

func show_support_number(amount: float, is_shield: bool) -> void:
	if is_dead or is_downed or amount <= 0.0:
		return
	if is_shield:
		if item_shield_max <= 0.0 or item_shield_hp >= item_shield_max:
			return
		_shield_display_accum += amount
		if _shield_display_accum >= 1.0:
			var shown_shield: int = int(_shield_display_accum)
			_shield_display_accum -= shown_shield
			## Aynı anda basılan can sayısıyla üst üste binmesin diye biraz yukarıda.
			_spawn_floating_text("%d" % shown_shield, Color(0.4, 0.7, 1.0), true, -61.0)
		return
	if health >= max_health:
		return
	_heal_display_accum += amount
	if _heal_display_accum >= 1.0:
		var shown: int = int(_heal_display_accum)
		_heal_display_accum -= shown
		_spawn_floating_text("%d" % shown, Color(0.4, 0.9, 0.45), true)


func _spawn_floating_text(text: String, color: Color, is_heal: bool = false, y_offset: float = -45.0) -> void:
	var scene: PackedScene = load("res://scenes/floating_text.tscn")
	if scene:
		var ft = scene.instantiate()
		get_tree().current_scene.add_child(ft)
		ft.global_position = global_position + Vector2(randf_range(-15, 15), y_offset)
		if ft.has_method("setup"):
			ft.setup(text, color, is_heal)


## Called by XP orbs when a remote player touches them on the host.
func add_xp(amount: float) -> void:
	if NetworkManager.is_host:
		NetworkManager.host_collect_xp(amount * (1.0 + GameManager.effective_exp_gain(exp_gain_percent))) ## üst sınır +%100 (madde 269)


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
## Yaratık yeteneklerinin özel hasarı (bkz. enemy_abilities.gd / player.gd take_special_damage) - host'taki yetkili
## lazer/diken/asit/ateş topu bu kuklaya değince hasar, türüyle birlikte gerçek oyuncunun makinesine iletilir (yanma,
## kalkana x2 gibi kurallar orada uygulanır).
func take_special_damage(amount: float, source: Node2D, kind: String) -> void:
	if is_dead or peer_id <= 0:
		return
	var enemy_net_id: int = 0
	if source and is_instance_valid(source):
		enemy_net_id = int(source.get_meta("network_enemy_id", 0))
	NetworkManager.forward_special_damage_to_peer.rpc_id(peer_id, amount * Enemy.damage_mult_of(source), enemy_net_id, kind)


func take_damage(amount: float, source: Node2D = null) -> void:
	if is_dead or peer_id <= 0:
		return
	var enemy_net_id: int = 0
	if source and is_instance_valid(source):
		enemy_net_id = int(source.get_meta("network_enemy_id", 0))
	NetworkManager.forward_damage_to_peer.rpc_id(peer_id, amount * Enemy.damage_mult_of(source), enemy_net_id, false)


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
	NetworkManager.forward_damage_to_peer.rpc_id(peer_id, amount * Enemy.damage_mult_of(attacker), enemy_net_id, true)


## ================= Cadı (kozmetik kopya) + süpürge yolculuğu (HER karakter) =================
## player.gd get_cadi_net_state -> main.gd extra["cadi"] = [Q açık mı, süpürgede mi]; extra["cride"] = süpürgesine binilen
## cadının peer id'si (her karakterde; binmiyorken anahtar yok). Görseller player.gd ile AYNI yardımcılardan (cadi_math.gd -
## CLAUDE.md madde 3). Dünya efektleri (bulut, şişe, biniş dumanı) ayrıca "cadi_fx" / "cadi_throw" (network_manager.gd).
var cadi_ride_host_peer: int = 0
var cadi_base_offset: Vector2 = Vector2.ZERO
var _cadi_q: bool = false
var _cadi_broom: bool = false
var _cadi_broom_time: float = 0.0
var _cadi_ride_time: float = 0.0
var _cadi_potion_on: bool = false
var _cadi_broom_visual_on: bool = false
var _cadi_lift_applied: bool = false
var _cadi_ride_anim_driven: bool = false ## klip bindiği cadının yönünden yerel seçiliyor (ağdan gelen klip adı yok sayılır)


## Süpürge görseli ve yolcular sorar (player.gd'de aynı adlı karşılıkları var).
func is_cadi_broom_active() -> bool:
	return _cadi_broom and not is_dead


func cadi_broom_time() -> float:
	return _cadi_broom_time


func cadi_peer() -> int:
	return peer_id


func _apply_cadi_net_state(st: Variant, ride_host: int) -> void:
	cadi_ride_host_peer = ride_host
	if not CadiMath.is_cadi(char_id) or not (st is Array) or (st as Array).size() < 2:
		_cadi_q = false
		_cadi_broom = false
		return
	_cadi_q = int(st[0]) != 0
	var broom: bool = int(st[1]) != 0
	if broom and not _cadi_broom:
		_cadi_broom_time = 0.0
	_cadi_broom = broom


func _process_cadi_remote(delta: float) -> void:
	if _cadi_broom:
		_cadi_broom_time += delta
	_cadi_ride_time = _cadi_ride_time + delta if cadi_ride_host_peer != 0 else 0.0
	var riding: bool = (_cadi_broom or cadi_ride_host_peer != 0) and not is_dead
	## Yolcu kuklasının yönü ağdaki kendi klip adından DEĞİL, bindiği cadının yönünden yerel türetilir: yoksa cadı dönünce
	## yön "cadı -> yolcunun istemcisi -> bize" iki ağ atlamasından geçip yolcular geç dönerdi (player.gd _update_animation ile AYNI klip).
	_cadi_ride_anim_driven = false
	if cadi_ride_host_peer != 0 and not is_dead and anim and is_instance_valid(anim) and anim.sprite_frames:
		var ride_host: Node = CadiMath.player_node(get_tree(), cadi_ride_host_peer)
		if CadiMath.can_ride(ride_host):
			var ride_face: String = CadiMath.facing_of(ride_host)
			var ride_clip: String = CharAnim.pick(anim.sprite_frames, [CadiMath.RIDE_ANIM_PREFIX + ride_face, "idle_" + ride_face])
			if ride_clip != "":
				_cadi_ride_anim_driven = true
				if anim.animation != ride_clip:
					anim.play(ride_clip)
				anim.speed_scale = 1.0
	if anim and is_instance_valid(anim):
		if riding:
			var t: float = _cadi_broom_time
			if not _cadi_broom:
				var host: Node = CadiMath.player_node(get_tree(), cadi_ride_host_peer)
				t = float(host.call("cadi_broom_time")) if host != null and host.has_method("cadi_broom_time") else _cadi_ride_time
			anim.offset = cadi_base_offset + Vector2(0, -CadiMath.rider_lift(t))
			_cadi_lift_applied = true
		elif _cadi_lift_applied:
			anim.offset = cadi_base_offset
			_cadi_lift_applied = false
	if not CadiMath.is_cadi(char_id):
		return
	var q_on: bool = _cadi_q and not is_dead
	if _cadi_potion_on != q_on:
		_cadi_potion_on = q_on
		CadiMath.set_potion_visual(self, q_on)
	var broom_on: bool = _cadi_broom and not is_dead
	if _cadi_broom_visual_on != broom_on:
		_cadi_broom_visual_on = broom_on
		CadiMath.set_broom_visual(self, broom_on)


func _cadi_snap_to_seat() -> void:
	var host: Node2D = CadiMath.player_node(get_tree(), cadi_ride_host_peer)
	if not CadiMath.can_ride(host) or global_position.distance_to(host.global_position) > CadiMath.RIDE_BREAK_DIST:
		return
	global_position = host.global_position + CadiMath.seat_offset(CadiMath.seat_index(get_tree(), cadi_ride_host_peer, peer_id), CadiMath.facing_of(host))


## ================= Suriyeli Hadime (kozmetik kopya) =================
## player.gd get_hadime_net_state -> main.gd extra["hadime"] -> burası. Görünüm formülleri/ceset/aura player.gd ile
## AYNI yardımcılardan (hadime_math.gd) - CLAUDE.md madde 3. Lanet/kara büyü efektleri ayrıca "hadime_fx" (network_manager).
func _apply_hadime_net_state(st: Dictionary) -> void:
	if not HadimeMath.is_hadime(char_id):
		return
	var was_ghost: bool = hadime_ghost_active
	var was_q: bool = _hadime_q
	_hadime_q = bool(st.get("q", false))
	_hadime_nm = bool(st.get("nm", false))
	hadime_ghost_active = bool(st.get("gh", false))
	if _hadime_q and not was_q:
		_hadime_q_time = 0.0
	if hadime_ghost_active and not was_ghost:
		## Ruh bedeninden ayrıldı: beden (ölüm klibinin son karesi) cesedin yerinde kalır, kukla hayalet olarak dolaşır.
		_hadime_corpse_pos = Vector2(st.get("cp", global_position))
		_hadime_corpse_clip = str(st.get("cc", ""))
		## Aynı pakette Karabasan/Q kapanışı da gelmiş olabilir (görünüm _process_hadime_remote'ta bir sonraki karede
		## sıfırlanır) - ceset formun büyüklüğünü/süzülmesini kopyalamasın diye taban ölçek/ofset önce geri alınır.
		if anim and is_instance_valid(anim):
			anim.scale = _base_anim_scale
			anim.offset = _hadime_base_offset
		var corpse: Node2D = HadimeMath.spawn_corpse(self, anim, _hadime_corpse_clip, _hadime_corpse_pos)
		for fx in [_death_status_fx, _revive_rewind_fx]:
			if fx != null and is_instance_valid(fx):
				fx.reparent(corpse, false)
		## Host'taki GERÇEK altın/yemek/sandık Area2D'leri bu kuklayı görmesin (hayalet hiçbir şey toplayamaz).
		collision_layer = 0
		_hadime_set_weapons_visible(false)
	elif was_ghost and not hadime_ghost_active:
		## Ruh bedenine döndü (diriltildi ya da kalıcı öldü): kukla cesedin yerine - player.gd _hadime_end_ghost ile aynı.
		global_position = _hadime_corpse_pos
		_target_position = _hadime_corpse_pos
		_network_velocity = Vector2.ZERO
		reset_physics_interpolation()
		HadimeMath.remove_corpse(self)
		collision_layer = _base_collision_layer
		_hadime_set_weapons_visible(true)
		## Kalıcı ölümde (bu pakette "dead" de geldi, bkz. update_extra_state_from_net başı) beden yeniden "ölmesin".
		if is_dead and anim and anim.sprite_frames and anim.sprite_frames.has_animation(_hadime_corpse_clip):
			anim.play(_hadime_corpse_clip)
			anim.frame = anim.sprite_frames.get_frame_count(_hadime_corpse_clip) - 1
			anim.pause()


## Şovalye R: bariyer_<yön> klibi oynarken havada süzülme + titreme (player.gd _process_paladin_levitate ile AYNI hesap, klip adından).
var _paladin_lev_on: bool = false
var _paladin_lev_t: float = 0.0


func _process_paladin_levitate_remote(delta: float) -> void:
	if not (anim and is_instance_valid(anim)):
		return
	if PaladinDome.is_anim(String(anim.animation)) and not is_dead:
		if not _paladin_lev_on:
			_paladin_lev_on = true
			_paladin_lev_t = 0.0
		_paladin_lev_t += delta
		anim.offset = cadi_base_offset + PaladinDome.levitate_offset(_paladin_lev_t)
	elif _paladin_lev_on:
		_paladin_lev_on = false
		anim.offset = cadi_base_offset


## Her kare (ölüyken de - görünüm geri dönsün): Q süzülmesi, Karabasan (koyu siluet + %15 büyük + aura), hayalet (yarı saydam).
func _process_hadime_remote(delta: float) -> void:
	if not HadimeMath.is_hadime(char_id) or not (anim and is_instance_valid(anim)):
		return
	if _hadime_q:
		_hadime_q_time += delta
	var lift: float = HadimeMath.channel_lift(_hadime_q_time) if _hadime_q else 0.0
	anim.offset = _hadime_base_offset + Vector2(0, -lift)
	anim.scale = _base_anim_scale * (HadimeMath.R_SCALE_MULT if _hadime_nm else 1.0)
	HadimeMath.apply_form(anim, _hadime_nm, hadime_ghost_active)
	if _hadime_aura_on != _hadime_nm:
		_hadime_aura_on = _hadime_nm
		HadimeMath.set_nightmare_aura(self, _hadime_aura_on)
	if _hadime_levitate_on != _hadime_q:
		_hadime_levitate_on = _hadime_q
		HadimeMath.set_levitate_fx(self, _hadime_levitate_on)
	var sh: Node2D = get_node_or_null("Shadow") as Node2D
	if sh:
		sh.modulate.a = HadimeMath.GHOST_ALPHA if hadime_ghost_active else 1.0


## Hayalet silah kullanamaz: yere saçılan ikonlar kuklanın YEREL çocukları olduğu için hayaletle birlikte sürüklenirdi -
## hayalet süresince gizlenir (player.gd'deki gerçek silahlarla aynı karar).
func _hadime_set_weapons_visible(v: bool) -> void:
	for icon in _weapon_icons:
		if is_instance_valid(icon):
			icon.visible = v
	for sh in _weapon_shadows:
		if is_instance_valid(sh):
			sh.visible = v


## player.gd is_hadime_ghost ile aynı sözleşme (drop_attraction.gd / world_event_manager.gd sorar).
func is_hadime_ghost() -> bool:
	return hadime_ghost_active


func _death_fx_parent() -> Node:
	if hadime_ghost_active:
		var corpse: Node2D = HadimeMath.get_corpse(self)
		if corpse != null:
			return corpse
	return self
