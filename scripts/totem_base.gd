extends Node2D
class_name TotemBase
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")

## Yaratık aday sorgusu (yeni yolda C++ ızgarası, eski yolda tüm "enemies" grubu; süzgeçler çağıranda aynen kalır).
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

## Shaman'ın 3 totem yeteneğinin paylaşılan temeli - CLAUDE.md'nin anlattığı
## hata sınıfının (kastın kendi ekranında doğru görünen ama diğer
## oyunculara hiç/eski görünen efektler) tam tersini hedefler: totemler
## `golem_pet.gd`'nin AYNI "sabit dünya konumu, host/client'tan bağımsız
## reliable spawn/despawn RPC'si" desenini kullanır (bkz. network_manager.gd
## broadcast_pet_spawn/broadcast_pet_despawn - BUNLAR ZATEN GENEL, totem
## için YENİ bir RPC eklemeye gerek yok, sadece sahne yolu geçiliyor).
##
## Golem/İskelet'ten FARKI: totemler HAREKET ETMEZ ve SALDIRI ALMAZ - bu
## yüzden golem_pet.gd'nin sürekli pozisyon/sağlık senkronu (broadcast_pet_
## state, saniyede ~5 kez) hiç gerekmiyor. Tek seferlik spawn (konum RPC
## paketinde zaten var, bkz. remote_player.gd _spawn_pet_visual - kozmetik
## kopya kendi RemotePlayer'ının O ANKİ konumuna yerleşir, totem anlık
## dikildiği için bu kastın gerçek dikme konumuyla pratikte örtüşür) ve
## kendi kendine süre dolunca kapanma yeterli - HER İKİ taraf (gerçek totem
## + kozmetik kopya) AYNI DURATION sabitiyle bağımsız ama eşzamanlı sayar.
##
## Gerçek oynanış mantığı (_tick, alt sınıflarda override edilir) SADECE
## dikeni oyuncunun kendi client'ında çalışır (bkz. mark_as_network_visual -
## diğer oyunculardaki kozmetik kopyalar bunu asla çağırmaz, salt görsel
## kalırlar) - tıpkı golem_pet.gd'nin "_is_network_visual" ayrımı gibi.

signal died

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const DepthOccluders := preload("res://scripts/depth_occluders.gd")
## Gölge: oyunun yerdeki nesne gölgesi (sandık/altın/mıknatıs ile aynı ince hilal; madde 557 ek, kullanıcı: "gölgelerini oyun içi
## gölgelerinden biri ile yerleştir, kendin üretme") - eski 1 texel dama (dither) elips gölge kaldırıldı.
const DropShadowScript := preload("res://scripts/drop_shadow.gd")
const ShamanSfx := preload("res://scripts/shaman_sfx.gd")
## "shield" | "attack" - alt sınıflar _init'te atar: dikilme sesini seçer.
var totem_kind: String = "shield"

var caster: Node = null
var network_instance_id: String = ""
## Kullanıcı isteği: "shamanın totemleri 30 saniye boyunca dursun" (eskiden
## 8sn) - bkz. player.gd SKILL_TIMING[26]/SKILL2_TIMING[27]/SKILL3_TIMING[28]
## "duration" alanları da AYNI değere güncellendi (sadece HUD ilerleme
## halkası için, gerçek ömür burada).
var duration: float = 30.0
var _is_network_visual: bool = false
var _tick_timer: float = 0.0
const TICK_INTERVAL := 1.0

## Alt sınıflar override eder - efekt rengi ve etki yarıçapı. Taban menzili yere ÇİZMEZ (madde 557 ek 2, kullanıcı: "dış halkaları kaldır,
## onları istemiyorum": noktalı menzil halkası + soluk ikinci halka + halkada dönen 6 rün + Alan Totemi dolgusu silindi). İSTİSNA (madde 586,
## kullanıcı isteği): Kalkan Totemi (E) kendi aura sınırını "Işık Perdesi" olarak çizer - totem_shield.gd + totem_aura_border.gd.
var totem_color: Color = Color(0.6, 0.8, 1.0)
var totem_radius: float = 220.0

## Totem sahnesindeki gövde (madde 557'den beri RÜN TAŞI: totem_*.tscn içindeki TotemRuneStone Sprite2D'si; rünler + parıltı onun çocukları).
## Yoksa (eski sahne) sessizce yok sayılır.
@onready var _totem_sprite: Node2D = get_node_or_null("TotemSprite")
## Taşın rün merkezi (düğüm kökünden): dikilme parlaması, gece ışığı ("o", night_glow_catalog.gd), Q ateş topu / E kalkan dalgası çıkışı.
## Alt sınıflar _init'te kendi taşlarının merkezine ayarlar (TotemAttack.BOLT_ORIGIN_OFFSET / TotemShield.ORB_ORIGIN_OFFSET).
var rune_center: Vector2 = Vector2(-1.0, -10.0)
## Yerdeki gölge (DropShadow; ShadowsFlag.entities kapalıysa null) - süzülen taş yükseldikçe daralır.
var _ground_shadow: Node2D = null
const SHADOW_SHRINK := 0.15
## Derinlik (bkz. _ready): ayak hizası = totem kökü (taşın altındaki gölge), taş süzülmesiyle birlikte ~26 birim yükselir.
const DEPTH_SORT_GROUP := "ysort_props" ## main.gd CREATURE_SORT_GROUPS
const DEPTH_Z := 0
const DEPTH_FRONT_Z := 2
const FOOT_Y := 2.0
const STONE_HALF_W := 12.0
const STONE_HEIGHT := 30.0
const DEPTH_EVERY := 3 ## kare - karakter taşın arkasına 3 karede geçemez


func setup_from_player(p_caster: Node) -> void:
	caster = p_caster
	global_position = p_caster.global_position
	_apply_evolutions()


## Sahibin yetenek evrimi (skill_evolutions.gd DEFS[12]) - gerçek totemde caster = Player, ağ kopyasında caster = o oyuncunun
## RemotePlayer kuklası; ikisinde de has_evo var (kuklada main.gd extra["evo"] listesinden). Evrim yoksa/caster yoksa false.
func _caster_has_evo(evo_id: String) -> bool:
	return is_instance_valid(caster) and caster.has_method("has_evo") and bool(caster.call("has_evo", evo_id))


## setup_from_player'dan (add_child'dan SONRA) çağrılır - yani _ready'de kurulan aura bile burada yeniden ölçeklenebilir.
## Hem gerçek totemde hem ağ kopyasında çalışır, böylece diğer oyuncular da büyütülmüş alanı görür.
## "Geniş Alan" (shaman_e1, Kalkan Totemi): hem müttefik/menzil alanı (totem_radius) hem hasar alanı (area_radius) +%30.
func _apply_evolutions() -> void:
	if totem_kind == "shield" and _caster_has_evo("shaman_e1"):
		totem_radius *= EVO_AREA_MULT
		area_radius *= EVO_AREA_MULT
		if is_instance_valid(_aura):
			_aura.scale *= EVO_AREA_MULT


func mark_as_network_visual() -> void:
	_is_network_visual = true


func _ready() -> void:
	## Pasif (Totem Auraları): "totemlerine yakın müttefiklerin düşmanlara
	## verdiği hasar yakma bırakır" - bkz. weapon.gd _maybe_apply_shaman_burn.
	## Kozmetik (network visual) kopyalar da bu gruba eklenir ama zararsız -
	## sadece gerçek oyuncuların KENDİ client'ında, KENDİ totemleri (ve varsa
	## aynı yakınlıktaki müttefik totemleri) taranır, uzak bir kopyanın grup
	## üyeliği başka bir client'ın hesaplamasını etkilemez.
	add_to_group("shaman_totems")
	## DERİNLİK (2026-11-11, kullanıcı: "rün taşının y ekseni sorunu var, yukarısındayken üstünde görünüyorum"): totem hiçbir y-sıralama
	## grubunda değildi (z 0, sahneye eklenme sırası) ve yerel oyuncu z 1 -> taşın ARKASINDAKİ (yukarıdaki) oyuncu taşın üstüne çiziliyordu.
	## Oakley çiçeğiyle (oakley_flower.gd DERİNLİK) aynı yöntem: "ysort_props" ile yaratık/evcil ayak sıralamasına katılır (ayak = kök,
	## taş süzülse de gölge yerde) + arkasında duran karakter varsa z 2 (oyuncu z 1'in üstü, ağaç/ev ön kopyası z 3'ün altı).
	add_to_group(DEPTH_SORT_GROUP)
	set_meta("_foot_visual", self)
	set_meta("_foot_local", FOOT_Y)
	z_index = DEPTH_Z
	get_tree().create_timer(duration).timeout.connect(_on_expire)
	## Dikilme sesi: konum player.gd'de add_child'dan HEMEN SONRA atandığı için ses bir kare ertelenir. Kozmetik ağ kopyaları da
	## _ready çalıştırdığı için ses her oyuncuda aynı çalar (kastta doğru, diğerlerinde yok hatası olmasın).
	call_deferred("_play_plant_sound")
	## DÜZELTME (kullanıcı bildirimi: "yeni totem assetleri oyunda
	## görünmüyor") - buradaki z_index=-1, player.gd _talon_aura_sprite'ın
	## AYNISI OLARAK eklenmişti ama o örnek yanlış kıyastı: Talon'un aurası
	## `anim.add_child(...)` ile PLAYER SPRITE'ININ ÇOCUĞU, yani z_index orada
	## SADECE Talon'un kendi sprite'ına göre RELATİF (onu bir katman geriye
	## iter). Totem ise get_tree().current_scene'e DOĞRUDAN EKLENEN (bkz.
	## player.gd _spawn_shaman_totem) ÜST SEVİYE bir node - z_index orada
	## MUTLAK ve zemin/tilemap katmanlarıyla AYNI havuzda karşılaştırılıyor.
	## Zemin katmanları z_index 0'da (bkz. main.gd y_sort_enabled notu),
	## totem -1'de olunca zeminin TAMAMEN ALTINDA, hiç görünmez kalıyordu.
	## golem_pet.gd (aynı "sahneye doğrudan eklenen top-level obje" deseni)
	## hiç z_index set ETMİYOR, sadece varsayılan (0) + Y-sort'a bırakıyor -
	## totem de artık AYNI şekilde varsayılanda, diğer oyuncu/yaratıklarla
	## aynı katmanda Y konumuna göre doğal olarak sıralanıyor.
	## Gölge dikilme animasyonu taşı aşağı kaydırmadan ÖNCE ölçülür (immediate): taşın dinlenme konumundaki alt kenarının altında kalır.
	if _totem_sprite:
		## Taş süzülse de (madde 569) gölge YERDE: süzülme ilk _process'te başlar, ölçü burada (offset 0) alınır.
		_ground_shadow = DropShadowScript.attach(self, _totem_sprite, false, 2, Rect2(), true)
	_play_plant_animation()
	## Rün taşı (madde 557): rün döngüsü sahibin evrimlerini okur - gerçek totemde Player, ağ kopyasında RemotePlayer (caster
	## setup_from_player'da _ready'den sonra gelir; Callable her çağrıda güncel caster'a bakar).
	if _totem_sprite and "has_evo_func" in _totem_sprite:
		_totem_sprite.set("has_evo_func", _caster_has_evo)
	if area_damage_enabled and show_area_aura:
		_build_area_aura()


## ---------- Pixel-art efektler (kullanıcı isteği: "efektleri pixel-art yap") ----
## Üç tek-seferlik piksel-art patlama sahnesi - hepsi aynı
## scripts/fx_totem_puff.gd davranışını paylaşır (bir kez oynat, kendini sil).
const PlantDustScene := preload("res://scenes/fx_totem_plant_dust.tscn")
const CollapseDustScene := preload("res://scenes/fx_totem_collapse_dust.tscn")
const RuneFlashScene := preload("res://scenes/fx_totem_rune_flash.tscn")

## Dikilirken totemin "topraktan yükselme" mesafesi (piksel).
const PLANT_RISE_PIXELS := 10.0 ## rün taşı ~19 birim boy (madde 557 ek: %30 küçüldü; eski totem 14)

## Dikilme anı: totem topraktan PİKSEL ADIMLARIYLA yükselerek belirir +
## tabanında toprak patlaması + yetenek renginde rün parlaması.
## Tamamen kozmetik - süre/denge hesaplarına etkisi yok.
##
## DÜZELTME (pixel-art): eskiden burada TÜM node 0.25 ölçeğinden 1.0'a
## YUMUŞAK bir tween'le (TRANS_BACK) büyütülüyordu. Nearest filtreli piksel
## sprite'ı ondalıklı ölçeklerde DÜZENSİZ piksel boyutlarıyla ("yamuk")
## görünür; üstelik TRANS_BACK 1.0'ı aşıp geri döndüğü için titriyordu.
## Artık ölçek HİÇ değişmiyor - sprite tam sayı piksel adımlarıyla yukarı
## kayarak "topraktan çıkıyor" (roundf ile piksel ızgarasına sabitleniyor).
func _play_plant_animation() -> void:
	if not _totem_sprite:
		_spawn_dust_child(PlantDustScene)
		return
	var target_y: float = _totem_sprite.position.y
	_totem_sprite.modulate.a = 0.0
	_totem_sprite.position.y = target_y + PLANT_RISE_PIXELS
	var tw := create_tween()
	tw.set_parallel(true)
	## roundf(...) her karede Y'yi TAM piksele sabitler - sprite asla yarım
	## piksele düşmez, pixel-art netliği bozulmaz.
	tw.tween_method(func(v: float) -> void:
		_totem_sprite.position.y = roundf(v)
	, target_y + PLANT_RISE_PIXELS, target_y, 0.34) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_totem_sprite, "modulate:a", 1.0, 0.20)
	_spawn_dust_child(PlantDustScene)
	_spawn_rune_flash(rune_center, 0.75)  ## rün taşının rün merkezi (madde 557)


## Rün taşı kısa parlar (Q ateş topu / E kalkan dalgası çıkarken; gerçek totemde ve ağ kopyasında aynı yerden çağrılır).
## Süzülen rün taşının o anki kayması (madde 569): ateş topu / kalkan şeridi çıkışı taşla birlikte hareket eder.
func _stone_hover() -> Vector2:
	if _totem_sprite and _totem_sprite.has_method("hover_world"):
		return Vector2(0.0, float(_totem_sprite.call("hover_world")))
	return Vector2.ZERO


func _flare_stone() -> void:
	if _totem_sprite and _totem_sprite.has_method("flare"):
		_totem_sprite.call("flare")


## Yetenek renginde rün parlaması (bkz. totem_color). Kozmetik ağ kopyaları da
## aynı sahneyi aynı script'le kurduğu için totem rengi HER client'ta aynı
## çıkar - ayrı bir ağ senkronu gerekmez.
func _spawn_rune_flash(offset: Vector2, scale_mult: float) -> void:
	var flash: Node2D = RuneFlashScene.instantiate()
	flash.position = offset
	flash.scale = Vector2(scale_mult, scale_mult)
	if flash.has_method("setup_tint"):
		flash.call("setup_tint", totem_color)
	add_child(flash)


## Toz patlamasını totemin ÇOCUĞU olarak ekler (totemle birlikte hareket eder).
## Yalnızca totem YAŞARKEN oynayan efektler için (dikilme).
func _spawn_dust_child(scene: PackedScene) -> void:
	var burst: Node2D = scene.instantiate()
	burst.position = Vector2(0, 2)
	add_child(burst)


## Toz patlamasını SAHNE KÖKÜNE (totemin kardeşi olarak) ekler - totem hemen
## silinse bile efekt görünür kalır (sönme anı bunu gerektirir).
##
## DÜZELTME (iki ayrı önceden var olan hata): eskiden sönme tozu totemin
## ÇOCUĞU yapılıp hemen ardından queue_free() ediliyordu - çocuk da onunla
## yok olduğu için sönme efekti pratikte HİÇ görünmüyordu. Ayrıca partiküle
## z_index = -1 veriliyordu; üst düzey node'larda z_index MUTLAK olduğu için
## zemin katmanlarının (z=0) ALTINDA kalıp yine görünmez oluyordu (aynı
## hatanın dosya başındaki totem z_index notuyla birebir aynısı).
func _spawn_dust_sibling(scene: PackedScene) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not is_instance_valid(scene_root):
		return
	var burst: Node2D = scene.instantiate()
	scene_root.add_child(burst)
	burst.global_position = global_position + Vector2(0, 2)


func _play_plant_sound() -> void:
	if not is_inside_tree():
		return
	ShamanSfx.play_at(get_tree().current_scene, str(ShamanSfx.PLANT.get(totem_kind, ShamanSfx.PLANT["shield"])), global_position, -4.0)


func _on_expire() -> void:
	died.emit()
	ShamanSfx.play_at(get_tree().current_scene, ShamanSfx.EXPIRE, global_position, -6.0)
	## Süre dolunca totem toprağa "çöker" - piksel-art toz savrulması.
	## Sahneye KARDEŞ olarak eklenir (bkz. _spawn_dust_sibling üstündeki
	## düzeltme notu: çocuk olarak eklenirse totemle birlikte yok oluyordu).
	_spawn_dust_sibling(CollapseDustScene)
	queue_free()


## Arkasında (ayağı kökün üstünde, taşın tepesinin altında) ve yatayda örtüşen bir karakter varsa totem onun üstüne çıkar.
func _update_depth() -> void:
	var base_y: float = global_position.y + FOOT_Y
	var top_y: float = base_y - STONE_HEIGHT
	var behind: bool = false
	for c: Vector4 in DepthOccluders.collect_characters(get_tree()):
		if c.y < base_y and c.y > top_y and absf(c.x - global_position.x) < STONE_HALF_W + c.z:
			behind = true
			break
	z_index = DEPTH_FRONT_Z if behind else DEPTH_Z


func _process(delta: float) -> void:
	if (Engine.get_process_frames() + get_instance_id()) % DEPTH_EVERY == 0:
		_update_depth()
	## Süzülen taşın gölgesi taş yükseldikçe daralır (madde 569).
	if is_instance_valid(_ground_shadow) and _totem_sprite and _totem_sprite.has_method("lift_frac"):
		_ground_shadow.scale.x = 1.0 - SHADOW_SHRINK * float(_totem_sprite.call("lift_frac"))
	## Alan hasarı (bkz. dosya sonundaki "ALAN HASARI" bloğu): görseller her kopyada, hasar sadece dikenin client'ında.
	if area_damage_enabled:
		_process_area_visuals(delta)
		_process_area_damage(delta)
	if _is_network_visual:
		return
	if not is_instance_valid(caster):
		return
	## DÜZELTME (kullanıcı bildirimi: "Shopta kalkan baloncuğunun içinde
	## silahlar ateş etmesin") - totemler owned_weapon_nodes/_necro_active_
	## pets'te DEĞİL (bkz. player.gd _spawn_shaman_totem, doğrudan sahneye
	## eklenir), bu yüzden set_combat_active()'in devre dışı bıraktığı
	## silahların/necro yaratıklarının aksine, sahibi seyyar satıcının güvenli
	## bölgesine girse BİLE tik atıp hasar vermeye devam ediyorlardı. Silahlar
	## için weapon.gd _process()'teki AYNI kontrol.
	if _caster_in_safe_zone():
		return
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return
	_tick_timer += _current_tick_interval()
	_tick()


## Alt sınıflar override eder - SADECE gerçek (kozmetik olmayan) totem'de
## her TICK_INTERVAL'de bir çağrılır.
func _tick() -> void:
	pass


## Kullanıcı isteği (Saldırı Totemi): "saldırı hızı shaman'ın statlarının
## %150'si kadar geçerli olmalı" - GDScript alt sınıfların bir const'u
## yeniden ATAYAMAMASI yüzünden (bkz. totem_attack.gd dosya başı notu)
## TICK_INTERVAL sabit kalıyor, ama gerçek tik aralığı artık BU virtual
## fonksiyondan okunuyor - varsayılan TotemBase davranışı (Kalkan/Alan
## Totemi) değişmeden TICK_INTERVAL'i döndürür, sadece TotemAttack override
## edip caster'ın kendi saldırı hızı statına göre ölçekler.
func _current_tick_interval() -> float:
	return TICK_INTERVAL


## ---------- ALAN HASARI (opsiyonel; 2026-10-21'den beri YALNIZ Kalkan Totemi - Saldırı Totemi'nden kaldırıldı) ----------
## Kullanıcı istekleri: 2026-09-29 eski Alan Saldırı Totemi'nin (R) alan hasarı yavaşlatmasız Saldırı Totemi'ne (Q) birleşti;
## 2026-09-30 "Q yeteneğinin alan hasarı özelliğini E yeteneğine eklemeni istiyorum" - Kalkan Totemi'ne (E) de. Tek kod burada:
## alt sınıf _init'te area_damage_enabled = true yapar. Alanda duran düşmanlar her saniye shaman'ın saldırı gücünün %20'si kadar
## hasar alır (kendi sabit 1 sn'lik saatinde - totemin kendi _tick ritminden bağımsız, ilk hasar dikildiği anda).
## Görseller (KOZMETİK) tools/gen_shaman_area_fx.py'nin sheet'leri (bkz. fx_enemy_ability.gd FxSprite): mor AURA çemberi
## (148 sanat px * TEXEL = ~180 birim = AREA_RADIUS), her tikte NABIZ halkası, hasar yiyen düşmanın üstünde RUH. Hepsi hem gerçek
## totemde hem ağ görsel kopyasında kurulur (aynı sahne) - diğer oyuncular da aynı alanı görür.
var area_damage_enabled: bool = false
## Alan hasarı yarıçapı (AREA_RADIUS taban; "Geniş Alan" evrimi büyütür - bkz. _apply_evolutions).
var area_radius: float = AREA_RADIUS
## Yetenek evrimi sayıları (kart metinleriyle birebir - skill_evolutions.gd DEFS[12]).
const EVO_AREA_MULT := 1.3 ## Geniş Alan (shaman_e1)
## false => alan hasarı aynen çalışır ama sabit mor çember (AreaAura) ve her tikteki mor nabız halkası çizilmez (ses + hasar yiyen
## yaratıktaki ruh kalır). Kalkan Totemi (E) madde 557 ek 2'den beri false (kullanıcı: "dış halkaları kaldır, onları istemiyorum").
## Görsel her kopyada aynı _ready / _process yolundan kurulduğu için ağ kopyaları da otomatik aynı kararı verir.
var show_area_aura: bool = true
const AREA_RADIUS := 180.0
const AREA_DAMAGE_ATTACK_POWER_RATIO := 0.20
const AREA_TICK_INTERVAL := 1.0
const AURA_FRAMES := preload("res://assets/fx/shaman_area/aura_frames.tres")
const PULSE_FRAMES := preload("res://assets/fx/shaman_area/pulse_frames.tres")
const WISP_FRAMES := preload("res://assets/fx/shaman_area/wisp_frames.tres")
const FxSprite := preload("res://scripts/fx_enemy_ability.gd")
const WISP_OFFSET := Vector2(0, -10)
var _aura: AnimatedSprite2D = null
var _area_pulse_timer: float = 0.0
var _area_damage_timer: float = 0.0


func _build_area_aura() -> void:
	_aura = AnimatedSprite2D.new()
	_aura.name = "AreaAura"
	_aura.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_aura.sprite_frames = AURA_FRAMES
	_aura.scale = Vector2.ONE * PixelDraw.TEXEL
	add_child(_aura)
	move_child(_aura, 0) ## totem gövdesinin (TotemSprite) ARKASINDA çizilsin
	_aura.play(&"loop")
	_aura.modulate.a = 0.0
	create_tween().tween_property(_aura, "modulate:a", 1.0, 0.8)


## Her alan tikinde nabız halkası + alçak "vızıltı" - gerçek totemde de ağ kopyasında da (salt görsel/ses). Ağ kopyası hasar
## tikini çalıştırmadığı için alandaki düşmanlarda AYNI ruh efektini kendi nabzında oynatır (diğer oyuncular da "alan hasar
## veriyor" sinyalini görsün).
func _process_area_visuals(delta: float) -> void:
	_area_pulse_timer -= delta
	if _area_pulse_timer > 0.0:
		return
	_area_pulse_timer += AREA_TICK_INTERVAL
	var scene: Node = get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	if show_area_aura:
		var pulse: Node2D = FxSprite.spawn(self, global_position, PULSE_FRAMES, &"play", 0)
		if pulse:
			move_child(pulse, 1) ## auranın üstünde, totem gövdesinin altında (zemindeki halka)
	ShamanSfx.play_at(scene, ShamanSfx.AREA_PULSE, global_position, -18.0, 0.05)
	if _is_network_visual:
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Node2D and is_instance_valid(e) and e.get("is_dead") != true and global_position.distance_to((e as Node2D).global_position) <= area_radius:
				_spawn_void_wisp((e as Node2D).global_position)


## Sahibi güvenli alanda mı: seyyar satıcı koruma bölgesi VEYA demirci iç mekanı (player.gd is_safe_zone_frozen, madde 325/327) - totem orada çalışmaz
## (eskiden sadece satıcı bölgesine bakıyordu, sahibi demircideyken totemler hâlâ tik atıyordu).
func _caster_in_safe_zone() -> bool:
	if caster.has_method("is_safe_zone_frozen"):
		return caster.is_safe_zone_frozen()
	return caster.get("is_in_merchant_zone") == true


## Alan hasarı - SADECE dikenin client'ında (ateş _tick'iyle aynı korumalar: ağ kopyası değil, caster geçerli, satıcı bölgesinde
## değil - bkz. TotemBase._process). Alan hasarı hedef SEÇMEDİĞİ için görünürlük (can_target) şartı yok (bkz. vision_fog.gd).
func _process_area_damage(delta: float) -> void:
	if _is_network_visual or not is_instance_valid(caster):
		return
	if _caster_in_safe_zone():
		return
	_area_damage_timer -= delta
	if _area_damage_timer > 0.0:
		return
	_area_damage_timer += AREA_TICK_INTERVAL
	if not ("damage_bonus" in caster):
		return
	var dmg: float = float(caster.damage_bonus) * AREA_DAMAGE_ATTACK_POWER_RATIO
	if dmg <= 0.0:
		return
	for e in EnemyQueryScript.candidates(get_tree(), global_position, area_radius + 1.0):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if not (e is Node2D):
			continue
		if global_position.distance_to((e as Node2D).global_position) > area_radius:
			continue
		if not e.has_method("take_damage"):
			continue
		_on_area_enemy_tick(e as Node2D) ## alt sınıf kancası (Kalkan Totemi evrimleri - totem_shield.gd)
		var is_crit: bool = false
		if caster.has_method("_roll_ability_crit"):
			is_crit = caster._roll_ability_crit()
		var hit_dmg: float = dmg
		if caster.has_method("_apply_ability_crit"):
			hit_dmg = caster._apply_ability_crit(dmg, is_crit)
		BalanceLogScript.tag(_area_balance_tag())
		e.call("take_damage", hit_dmg, is_crit)
		_spawn_void_wisp((e as Node2D).global_position)


## Alan hasarının balans/Shift ipucu etiketi (Saldırı Totemi = Q; Kalkan Totemi bunu "s:shaman_kalkan_alan" = E ile ezer).
func _area_balance_tag() -> StringName:
	return &"s:shaman_totem_alan"


## Alan hasar tikinde alandaki HER yaratık için bir kez çağrılır (hasardan önce) - SADECE dikenin client'ında. Varsayılan: hiçbir şey
## (alan YAVAŞLATMAZ - kullanıcı 2026-09-29); Kalkan Totemi evrimleri bunu override eder.
func _on_area_enemy_tick(_enemy: Node2D) -> void:
	pass


## Hasar tikinde düşmanın üstünde kısa süreli mor ruh - "bu düşman şu an alan hasarı yiyor" sinyali. Salt kozmetik.
func _spawn_void_wisp(enemy_pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or not is_instance_valid(scene):
		return
	FxSprite.spawn(scene, enemy_pos + WISP_OFFSET, WISP_FRAMES, &"play", 2)
