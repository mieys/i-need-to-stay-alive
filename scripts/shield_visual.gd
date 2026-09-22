extends Node2D

## Kalkan baloncuğu: eski prosedürel çember yerine gerçek bir su baloncuğu
## sprite animasyonu (bkz. assets/fx/shield_bubble/, BubbleSprite child
## node'u) - "grow" (belirme), "loop" (sürekli hafif dalgalanma) ve "pop"
## (kaybolma) olmak üzere 3 animasyonu var.
##
## DÖRT ayrı görünürlük fonksiyonu var, GERÇEK olay tipine göre seçilmeli:
##   - appear()       : GERÇEK bir yenilenme/aktifleşme anı - "grow" oynar.
##   - dismiss()      : GERÇEK bir "kalkan kırıldı/skill bitti" anı - "pop" oynar.
##   - show_instant() : sadece hasar flaşı gibi geçici bir gösterim - grow
##                       ATLANIR, doğrudan "loop"a geçilir.
##   - hide_instant() : geçici gösterimin sessizce bitmesi - pop ATLANIR,
##                       hafif bir solmayla kaybolur.
## Bu ayrım olmadan (player.gd'nin _update_shield_bubble() fonksiyonu her
## hasar flaşında appear()/dismiss() çağırıyordu) baloncuk hiçbir zaman
## "loop"a ulaşamıyor, sürekli grow/pop arasında kesiliyordu (bkz. kullanıcı
## bildirimi: "hasar alırken sadece orta kısımları göstermesi lazım").
##
## Hasar alındığında ayrıca flash(angle) çağrılır: baloncuğun tamamı değil,
## hasarın geldiği YÖN ekstra parıldar - parlak bir hilal + birkaç kıvılcım
## çizgisi, hızla sönen (bkz. _draw()). Bu, appear/dismiss/show_instant/
## hide_instant'tan bağımsız, HER hasarda (baloncuk zaten görünürken de) çalışır.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const RADIUS := 77.0
## Kıvılcımların çıktığı nokta: baloncuğun GÖRÜNEN kenarı (fx_shield_hit.gd RADIUS ile aynı sayı).
const FLASH_RADIUS := 40.0
## "pop" animasyonu artık kare sayfasının son %10'u (9 kare, 12 fps) - bkz.
## assets/fx/shield_bubble/bubble_frames.tres (grow ilk %10, loop orta %10-90,
## pop son %10 olacak şekilde yeniden bölündü - "kalkan hasar alırken
## büyüyormuş/patlıyormuş gibi görünme" hatasını gidermek için).
const POP_DURATION := 9.0 / 12.0

@onready var bubble: AnimatedSprite2D = $BubbleSprite
@onready var break_sound: AudioStreamPlayer2D = $BreakSound
@onready var regen_sound: AudioStreamPlayer2D = $RegenSound

## Kalkan TÜRÜNE göre farklı baloncuk sprite sheet'i - Standart Kalkan'ın
## sahnede zaten atanmış olan varsayılan bubble_frames.tres'ine HİÇ
## dokunulmuyor (bkz. player.tscn BubbleSprite.sprite_frames); diğer 3 tür
## (Enerji/Kale/Savaş) kendi bubble_frames.tres'lerini kullanır. Anahtarlar
## player.gd SHIELD_TYPES ile birebir aynı ("shield_enerji"/"shield_kale"/
## "shield_savas") - set_shield_type() player.gd _owned_shield_type_key()'in
## döndürdüğü anahtarla çağrılır ve bunlar arasında geçiş yapar.
const TYPE_FRAMES := {
	"shield_enerji": preload("res://assets/fx/shield_bubble_enerji/bubble_frames.tres"),
	"shield_kale": preload("res://assets/fx/shield_bubble_kale/bubble_frames.tres"),
	"shield_savas": preload("res://assets/fx/shield_bubble_savas/bubble_frames.tres"),
}

## Sahnede BubbleSprite'a zaten atanmış olan Standart Kalkan sprite_frames'i -
## _ready()'de bir kere okunup saklanıyor ki shield_standart'a (ya da hiçbir
## tür sahip değilken) dönüldüğünde bubble_frames.tres'e elle dokunmadan
## orijinaline geri dönebilelim.
var _default_frames: SpriteFrames = null
var _current_shield_type: String = ""

var _flash: float = 0.0
var _flash_angle: float = 0.0
var _sparks: Array = []
## hide_instant()'ın solma tween'i - appear()/dismiss()/show_instant() araya
## girerse (ör. solma bitmeden kalkan tekrar aktifleşirse) yarım kalmaması ve
## modulate.a'yı yanlış değerde kilitlememesi için iptal edilir.
var _fade_tween: Tween = null


func _ready() -> void:
	if bubble:
		bubble.animation_finished.connect(_on_bubble_animation_finished)
		_default_frames = bubble.sprite_frames


## Aktif kalkan TÜRÜNE göre baloncuk görselini değiştirir (bkz. TYPE_FRAMES).
## "shield_standart" ya da hiçbir tür sahip değilken ("") sahnede zaten
## atanmış orijinal bubble_frames.tres'e (Standart Kalkan - HİÇ dokunulmayan
## tür) döner. Sadece GERÇEKTEN değiştiğinde sprite_frames'i yeniden atar -
## her karede çağrılsa bile o an oynayan animasyonu kesmez (bkz. player.gd
## _update_shield_bubble).
func set_shield_type(type_key: String) -> void:
	if type_key == _current_shield_type:
		return
	_current_shield_type = type_key
	if not bubble:
		return
	var frames: SpriteFrames = TYPE_FRAMES.get(type_key, _default_frames)
	if frames == null or frames == bubble.sprite_frames:
		return
	var was_playing: bool = bubble.is_playing()
	var current_anim: StringName = bubble.animation
	bubble.sprite_frames = frames
	if was_playing and frames.has_animation(current_anim):
		bubble.play(current_anim)


## Gerçek bir "yenilenme anı" (kalkan yeni aktifleşti / gerçekten yukarı
## tırmanmaya başladı) için: "grow" oynar, bitince otomatik "loop"a geçer
## (bkz. _on_bubble_animation_finished). SADECE bunun için kullanılır - salt
## hasar flaşı grow'u TETİKLEMEMELİ (bkz. show_instant).
func appear() -> void:
	_kill_fade_tween()
	visible = true
	modulate.a = 1.0
	if bubble and bubble.sprite_frames and bubble.sprite_frames.has_animation("grow"):
		bubble.play("grow")
	elif bubble:
		bubble.play("loop")
	if regen_sound:
		regen_sound.pitch_scale = randf_range(0.92, 1.08)
		regen_sound.play()


## Kalkan GERÇEKTEN kırılınca/skill süresi dolunca çağrılır: aniden
## kaybolmak yerine kısa bir "pop" (patlama) animasyonu oynayıp öyle kaybolur.
## SADECE gerçek bir "kalkan bitti" olayında kullanılır (bkz. hide_instant).
func dismiss() -> void:
	if not visible:
		return
	_kill_fade_tween()
	modulate.a = 1.0
	if bubble and bubble.sprite_frames and bubble.sprite_frames.has_animation("pop"):
		bubble.play("pop")
		get_tree().create_timer(POP_DURATION).timeout.connect(_hide_now)
	else:
		_hide_now()
	if break_sound:
		break_sound.pitch_scale = randf_range(0.92, 1.08)
		break_sound.play()


## Hasar flaşı gibi kalkanın hâlâ dolu/aktif olduğu, sadece kısa süreliğine
## görünür kılındığı durumlar için: "grow" oynatmadan DOĞRUDAN "loop"a geçer.
## Kullanıcı isteği: "kalkan hasar alırken sadece orta [loop] kısımlar
## görünmeli, büyüyormuş gibi görünmemeli" - grow artık sadece appear()'da,
## gerçek bir yenilenme başlangıcında oynuyor.
func show_instant() -> void:
	_kill_fade_tween()
	visible = true
	modulate.a = 1.0
	if bubble and bubble.sprite_frames and bubble.sprite_frames.has_animation("loop"):
		bubble.play("loop")


## show_instant()'ın tersi: hasar flaşı süresi bittiğinde (kalkan hâlâ dolu,
## sadece o an göstermeye gerek kalmadığında) "pop" oynatmadan sessizce,
## hafif bir solma ile kaybolur - "patlıyormuş gibi görünmemeli" isteğiyle
## pop artık yalnızca dismiss()'te, gerçek kırılma anında oynuyor.
const INSTANT_FADE_DURATION := 0.18

func hide_instant() -> void:
	if not visible:
		return
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, INSTANT_FADE_DURATION)
	_fade_tween.tween_callback(_hide_now)


func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _hide_now() -> void:
	visible = false
	modulate.a = 1.0
	if bubble:
		bubble.stop()


func _on_bubble_animation_finished() -> void:
	if bubble and bubble.animation == "grow":
		bubble.play("loop")


func _process(delta: float) -> void:
	if _flash <= 0.0 or not visible:
		return
	_flash = max(0.0, _flash - delta * 2.5)
	_apply_flare()
	queue_redraw()


## Kullanıcı isteği (2026-09-22): "kalkan hasar alınca hafif çatlama ve BARİYER BALONCUĞU efekti çıkmalıydı" - gerçek baloncuk sprite'ı
## hasar anında bir an PARLAR (mavi-beyaza doğru aydınlanır) ve söner; çatlak/yüzey dalgası ayrıca fx_shield_hit.gd'de çizilir.
func _apply_flare() -> void:
	if not bubble:
		return
	var f: float = _flash * _flash
	bubble.self_modulate = Color(1.0 + 0.7 * f, 1.0 + 0.9 * f, 1.0 + 1.3 * f, 1.0)


## angle: hasarın geldiği yön (radyan, player.gd take_damage()'da hesaplanır) -
## baloncuğun o tarafı ekstra parıldar. Verilmezse rastgele bir yön kullanılır.
func flash(angle: float = INF) -> void:
	_flash_angle = angle if is_finite(angle) else randf() * TAU
	_sparks.clear()
	for i in range(5):
		var jitter: float = deg_to_rad(randf_range(-26.0, 26.0))
		var spark_len: float = randf_range(8.0, 18.0)
		_sparks.append(Vector2(jitter, spark_len))
	_flash = 1.0
	_apply_flare()
	queue_redraw()


func _draw() -> void:
	## Eski kıvılcım çizgileri kaldırıldı (2026-09-22): hasar görseli artık fx_shield_hit.gd (baloncuk + yüzey dalgası + çatlak) ve
	## yukarıdaki baloncuk parlaması (_apply_flare) - üst üste binip karışmasın diye burada çizim yok.
	pass
