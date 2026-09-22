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

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const ShamanSfx := preload("res://scripts/shaman_sfx.gd")
## "shield" | "attack" | "area" - alt sınıflar _init'te atar: dikilme sesini, rün biçimini ve aura görünümünü seçer.
var totem_kind: String = "shield"
## Aura yalnızca ~20 kez/sn yeniden çizilir (halka çizimi pahalı, gerisi Godot'nun önceki çizimi tutmasıyla bedava).
const REDRAW_INTERVAL := 0.05
var _redraw_acc: float = 0.0

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
## true => menzil halkası/rünleri/dolgu TotemBase tarafından ÇİZİLMEZ (alt sınıf kendi aurasını çizer - ör. Alan Totemi'nin shader aurası).
var use_custom_aura: bool = false
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
	_play_plant_animation()


## ---------- Pixel-art efektler (kullanıcı isteği: "efektleri pixel-art yap") ----
## Üç tek-seferlik piksel-art patlama sahnesi - hepsi aynı
## scripts/fx_totem_puff.gd davranışını paylaşır (bir kez oynat, kendini sil).
const PlantDustScene := preload("res://scenes/fx_totem_plant_dust.tscn")
const CollapseDustScene := preload("res://scenes/fx_totem_collapse_dust.tscn")
const RuneFlashScene := preload("res://scenes/fx_totem_rune_flash.tscn")

## Dikilirken totemin "topraktan yükselme" mesafesi (piksel).
const PLANT_RISE_PIXELS := 14.0

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


func _process(delta: float) -> void:
	## Aura nabzı/dönen rünler için kozmetik saat - ağ görsel kopyalarında DA
	## işler (çizim sadece çizimdir, oyun durumu paylaşmaz; bkz. dosya başı).
	visual_time += delta
	_redraw_acc += delta
	if _redraw_acc >= REDRAW_INTERVAL:
		_redraw_acc = 0.0
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
	## Kullanıcı isteği (2026-09-21): totem görsellerini SIFIRDAN pixel tarzında (1 texel detay, bkz. hafıza "Pixel density 48x48").
	## Totemin gövdesini yeni 48x48 sprite (totem_*.tscn) çizer; burası SADECE zemin gölgesi + yetenek menzili/aura sihri:
	##  - kaide altında 1 texel dither elips gölge
	##  - menzil sınırı: totem_radius'ta nabız atan NOKTALI pixel halka + içte küçük ikinci halka
	##  - halkada yavaşça dönen 6 rün (yetenek türüne göre biçim)
	##  - alan totemi: alanın içi seyrek pixel "toz" noktalarıyla yanıp söner (eski düz dolgu yerine)
	var texel: float = PixelDraw.TEXEL
	## Zemin gölgesi
	for iy in range(-3, 4):
		var hw: int = int(round(sqrt(maxf(0.0, 1.0 - pow(float(iy) / 3.5, 2.0))) * 12.0))
		for ix in range(-hw, hw + 1):
			if ((ix + iy) & 1) == 0:
				continue
			PixelDraw.px(self, Vector2(float(ix) * texel, float(iy) * texel + 6.0), 1, Color(0.0, 0.0, 0.0, 0.32))
	if use_custom_aura:
		return
	var pulse: float = sin(visual_time * 2.0) * 3.0
	var ring_col := Color(totem_color.r, totem_color.g, totem_color.b, 0.85)
	_draw_dotted_ring(totem_radius + pulse, ring_col, 3.0, visual_time * 6.0)
	_draw_dotted_ring(totem_radius + pulse - 3.0, Color(ring_col.r, ring_col.g, ring_col.b, 0.22), 6.0, -visual_time * 4.0)
	var inner_pulse: float = sin(visual_time * 2.0 + PI * 0.5) * 2.0
	_draw_dotted_ring(26.0 + inner_pulse, Color(ring_col.r, ring_col.g, ring_col.b, 0.42), 2.0, visual_time * 8.0)
	## Dönen rünler
	var rune_alpha: float = 0.65 + 0.25 * sin(visual_time * 3.0)
	for i in range(6):
		var ang: float = visual_time * 0.6 + float(i) * TAU / 6.0
		_draw_rune(Vector2(cos(ang), sin(ang)) * (totem_radius + pulse), ang, Color(totem_color.r, totem_color.g, totem_color.b, rune_alpha))
	## İç dolgu (Alan Totemi): seyrek yanıp sönen pixel noktaları
	if aura_fill_alpha > 0.0:
		var dots: int = int(totem_radius * totem_radius * 0.011)
		for i in range(dots):
			var rr: float = totem_radius * sqrt(PixelDraw.hash01(i * 3 + 1))
			var aa: float = TAU * PixelDraw.hash01(i * 5 + 7)
			var tw: float = 0.5 + 0.5 * sin(visual_time * 2.0 + float(i) * 1.7)
			PixelDraw.px(self, Vector2(cos(aa), sin(aa)) * rr, 1, Color(totem_color.r, totem_color.g, totem_color.b, aura_fill_alpha * 7.0 * tw))


## Noktalı pixel halka: her `step_texels` texel'de bir nokta (kesikli/noktalı görünüm, ucuz).
func _draw_dotted_ring(radius: float, col: Color, step_texels: float, phase: float) -> void:
	var count: int = maxi(12, int(TAU * radius / (PixelDraw.TEXEL * step_texels)))
	var offset: float = phase / float(count)
	for i in range(count):
		var a: float = TAU * (float(i) / float(count)) + offset
		var p: Vector2 = Vector2(cos(a), sin(a)) * radius
		## Koyu 1 texel alt gölge: açık çim üstünde de okunur (pixel-art kontur mantığı)
		PixelDraw.px(self, p + Vector2(0, PixelDraw.TEXEL), 1, Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, col.a * 0.55))
		PixelDraw.px(self, p, 1, col)


## Halkadaki küçük rün: shield = artı, attack = alev üçgeni, area = sarmal nokta çifti (her biri 5-6 texel).
func _draw_rune(pos: Vector2, ang: float, col: Color) -> void:
	var t: float = PixelDraw.TEXEL
	PixelDraw.px(self, pos, 1, col.lerp(Color(1, 1, 1, col.a), 0.5))
	match totem_kind:
		"attack":
			PixelDraw.px(self, pos + Vector2(-t, t), 1, col)
			PixelDraw.px(self, pos + Vector2(t, t), 1, col)
			PixelDraw.px(self, pos + Vector2(0, -t), 1, col)
			PixelDraw.px(self, pos + Vector2(0, -t * 2.0), 1, col)
		"area":
			var d: Vector2 = Vector2(cos(ang * 2.0), sin(ang * 2.0)) * t * 1.6
			PixelDraw.px(self, pos + d, 1, col)
			PixelDraw.px(self, pos - d, 1, col)
		_:
			PixelDraw.px(self, pos + Vector2(t, 0), 1, col)
			PixelDraw.px(self, pos - Vector2(t, 0), 1, col)
			PixelDraw.px(self, pos + Vector2(0, t), 1, col)
			PixelDraw.px(self, pos - Vector2(0, t), 1, col)
