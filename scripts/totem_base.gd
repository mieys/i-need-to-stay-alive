extends Node2D
class_name TotemBase

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

## Alt sınıflar override eder - HUD/aura rengi ve yarıçapı.
var totem_color: Color = Color(0.6, 0.8, 1.0)
var totem_radius: float = 220.0
## Alan Totemi'nin (TotemArea) içi hafif dolgun göstermesi için - diğer
## totemlerde 0 kalır (sadece halka çizilir). Kozmetiktir.
var aura_fill_alpha: float = 0.0
## Aura halkasının dönen rünleri ve nabız animasyonu için - KOZMETİK zaman
## biriktirici. _process zaten hem gerçek totemde hem ağ görsel kopyasında
## çalışır (mantık _tick'te korumalı), bu yüzden animasyon HER client'ta akar.
var visual_time: float = 0.0

## Totem sahnesindeki bespoke sprite (totem_*.tscn içindeki AnimatedSprite2D).
## Yoksa (eski sahne) sessizce yok sayılır - _draw sadece aura çizer.
@onready var _totem_sprite: AnimatedSprite2D = get_node_or_null("TotemSprite")


func setup_from_player(p_caster: Node) -> void:
	caster = p_caster
	global_position = p_caster.global_position


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
	get_tree().create_timer(duration).timeout.connect(_on_expire)
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
	_play_plant_animation()


## ---------- Pixel-art efektler (kullanıcı isteği: "efektleri pixel-art yap") ----
## Üç tek-seferlik piksel-art patlama sahnesi - hepsi aynı
## scripts/fx_totem_burst.gd davranışını paylaşır (bir kez oynat, kendini sil).
const PlantDustScene := preload("res://scenes/fx_totem_plant_dust.tscn")
const CollapseDustScene := preload("res://scenes/fx_totem_collapse_dust.tscn")
const RuneFlashScene := preload("res://scenes/fx_totem_rune_flash.tscn")

## Dikilirken totemin "topraktan yükselme" mesafesi (piksel).
const PLANT_RISE_PIXELS := 14.0

## Aura çevresinde dönen 6 KÜÇÜK PİKSEL-ART rün işareti (eskiden antialias'lı
## draw_arc yaylarıydı - bkz. _draw üstündeki pixel-art notu). Sprite'lar
## kod ile oluşturulur: 3 totem sahnesine ayrı ayrı node eklemeye gerek yok
## ve kozmetik ağ kopyalarında da otomatik belirirler.
const RuneTexture := preload("res://assets/generated/shaman_totem_rune.png")
const RUNE_COUNT := 6
var _rune_sprites: Array[Sprite2D] = []


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
	_spawn_rune_flash(Vector2(0, -22), 0.75)


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


func _on_expire() -> void:
	died.emit()
	## Süre dolunca totem toprağa "çöker" - piksel-art toz savrulması.
	## Sahneye KARDEŞ olarak eklenir (bkz. _spawn_dust_sibling üstündeki
	## düzeltme notu: çocuk olarak eklenirse totemle birlikte yok oluyordu).
	_spawn_dust_sibling(CollapseDustScene)
	queue_free()


func _process(delta: float) -> void:
	## Aura nabzı/dönen rünler için kozmetik saat - ağ görsel kopyalarında DA
	## işler (çizim sadece çizimdir, oyun durumu paylaşmaz; bkz. dosya başı).
	visual_time += delta
	queue_redraw()
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
	if caster.get("is_in_merchant_zone") == true:
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


func _draw() -> void:
	## Eski "kristal totem" silueti KALDIRILDI - totemlerin bespoke sprite'ı
	## (totem_*.tscn içindeki AnimatedSprite2D) gövdeyi çizer. _draw artık
	## SADECE yetenek menzilini ve aura sihrini gösterir.
	##
	## Toprak gölgesi - totemin yere oturmasını sağlar (bas kısmı).
	draw_set_transform(Vector2(0, 6), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	##
	## Aura sınırı - oyuncuların etki yarıçapını görebilmesi için. Hafif
	## nabız: yarıçap +/-4px salınır (kozmetik, görsel canlılık).
	var pulse: float = sin(visual_time * 2.0) * 4.0
	draw_arc(Vector2.ZERO, totem_radius + pulse, 0.0, TAU, 64, Color(totem_color.r, totem_color.g, totem_color.b, 0.35), 3.0, true)
	## İç dolgu (Alan Totemi kullanır - alandaki yavaşlatma bölgesini gösterir).
	if aura_fill_alpha > 0.0:
		draw_circle(Vector2.ZERO, totem_radius, Color(totem_color.r, totem_color.g, totem_color.b, aura_fill_alpha))
	## Dönen rün halkası - aura çevresinde yavaşça dönen 6 rün kısa yayı.
	var rune_alpha: float = 0.5 + 0.2 * sin(visual_time * 3.0)
	for i in 6:
		var rune_angle: float = visual_time * 0.6 + float(i) * TAU / 6.0
		draw_arc(Vector2.ZERO, totem_radius + pulse, rune_angle - 0.09, rune_angle + 0.09, 8, Color(totem_color.r, totem_color.g, totem_color.b, rune_alpha), 4.0, true)
	## Totemin dibinde ikinci, iç halka - canlı totem hissi.
	var inner_pulse: float = sin(visual_time * 2.0 + PI * 0.5) * 3.0
	draw_arc(Vector2.ZERO, 26.0 + inner_pulse, 0.0, TAU, 32, Color(totem_color.r, totem_color.g, totem_color.b, 0.28), 2.0, true)
