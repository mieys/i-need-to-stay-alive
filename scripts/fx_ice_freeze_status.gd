extends AnimatedSprite2D

## Buz Asası'nın donma efekti VE Büyücü Kız'ın Don Nova'sı sonrası yaratıkların
## üstünde beliren donma görseli - enemy.gd _start_freeze/apply_freeze_full
## VE _spawn_freeze_status_fx (ağ üzerinden kozmetik kopya), hepsi AYNI
## FreezeStatusFxScene'i kullanıyor (bkz. oradaki notlar).
##
## DÜZELTME (kullanıcı isteği: "efekt sistemi" - Ice.png): eskiden 60 karelik
## TEK bir "oluş -> tut -> kır" klibi vardı (freeze_shatter.png), speed_scale
## ile donma süresine uniform şekilde yayılıyordu. Yeni asset 3 farklı 9
## karelik "buz oluşumu" varyasyonu (freeze1/2/3, fx_freeze_variants_frames.
## tres) - her donma olayında rastgele biri seçilir. Kullanıcı isteği:
## "efektler 4. framelerinde (her efektin kendi 4. sprite sheeti) sabit
## kalması ve donma süresi bitmeye yakın diğer framelere geçerek donmanın
## bitişiyle aynı anda bitmesini istiyorum" - bu UNIFORM speed_scale ile
## YAPILAMAZ (o durumda 9 kare süreye eşit aralıklarla yayılır, "4te
## takılma" hissi olmaz). Bu yüzden AnimatedSprite2D'nin play()'i hiç
## kullanılmıyor, frame indexi elle 3 fazlı bir zamanlayıcıyla sürülüyor:
## INTRO (0->3, hızlı oluşum) -> HOLD (3'te sabit kalır, donmanın büyük
## kısmı) -> OUTRO (3->8, donma bitimiyle TAM aynı anda 8'e ulaşır).
##
## DÜZELTME (kullanıcı isteği: "donma efektinin yaratıkların bedenini doğru
## kapladığından emin ol çünkü efektin konumunu yanlış yapınca yaratıklar
## efektin dışarısında kalabiliyor") - eskiden TÜM yaratıklar için sabit
## scale=1.1 kullanılıyordu; yaratık gövde yarıçapı 12.8'den 44.2'ye kadar
## değiştiği için (bkz. enemy.gd _body_radius) büyük yaratıklarda efekt
## gövdeyi kaplamıyordu. Artık setup() body_radius parametresi alıp REFERENCE_
## RADIUS'a oranla ölçekliyor - küçük/büyük tüm yaratıklarda gövdeyi kaplar.

const FRAME_COUNT := 9
const HOLD_FRAME := 3 ## 0-indeksli - kullanıcının "4. frame"i (1-indeksli)
const INTRO_FRAMES := 4 ## 0,1,2,3
const OUTRO_START_FRAME := 3 ## outro HOLD_FRAME'den devam eder
## DÜZELTME (kullanıcı isteği: "biraz daha yavaş anime olsun") - eskiden
## 0.28/0.4 idi, oluşma/kırılma geçişleri artık daha belirgin/yavaş.
const INTRO_TIME := 0.45
const OUTRO_TIME := 0.65

const REFERENCE_RADIUS := 20.0
const MIN_SCALE := 0.7
const MAX_SCALE := 2.4
## DÜZELTME (kullanıcı isteği: "Buz donma efektini %60 büyüt") - gövde
## boyutuna göre hesaplanan orana (aşağıda) ek olarak uygulanan sabit çarpan.
const SIZE_MULT := 1.6

const VARIANT_NAMES := ["freeze1", "freeze2", "freeze3"]

var _duration: float = 5.0
var _elapsed: float = 0.0
var _intro_time: float = INTRO_TIME
var _outro_time: float = OUTRO_TIME
var _variant: String = "freeze1"


func _ready() -> void:
	position = Vector2.ZERO
	_variant = VARIANT_NAMES[randi() % VARIANT_NAMES.size()]
	animation = _variant
	frame = 0

	var sound: AudioStreamPlayer2D = get_node_or_null("Sound")
	if sound:
		sound.play()


## enemy.gd bunu ekledikten hemen sonra çağırır. body_radius verilmezse
## (ör. eski bir çağrı yeri güncellenmemişse) REFERENCE_RADIUS'a düşer,
## yani scale=1.0 - hiç çökmez, sadece eski sabit boyuta benzer davranır.
## DÜZELTME (kullanıcı isteği 2026-09-24: "yaratıklar tekrar dondurulduğunda donma efekti tekrar başlamasın donuk halde
## kalsın süresi resetleniyor sadece"): donmuş bir yaratık yeniden donunca enemy.gd (_start_freeze / istemcide
## _spawn_freeze_status_fx) MEVCUT efektte setup()'ı tekrar çağırıyor - eskiden _elapsed = 0 ile buz oluşma (intro)
## animasyonu baştan oynuyordu. Artık ikinci ve sonraki setup'larda sadece KALAN SÜRE yenilenir: giriş hâlâ
## sürüyorsa kaldığı yerden devam eder, donuk (hold) karedeyse orada kalır, çözülmeye (outro) başlamışsa donuk kareye
## geri döner - buz kütlesi hiç yeniden "oluşmaz".
var _setup_done: bool = false

func setup(duration: float, body_radius: float = REFERENCE_RADIUS) -> void:
	if _setup_done:
		var remaining: float = max(duration, 0.1)
		if _elapsed > _intro_time:
			_elapsed = _intro_time ## donuk kareye (outro'daysa geri) sabitle
		_duration = _elapsed + remaining
		_outro_time = min(OUTRO_TIME, remaining * 0.45)
		return
	_setup_done = true
	_duration = max(duration, 0.1)
	_elapsed = 0.0
	## Çok kısa donmalarda intro+outro süreyi aşmasın diye orantılı sıkıştır.
	var budget: float = _duration * 0.9
	_intro_time = min(INTRO_TIME, budget * 0.5)
	_outro_time = min(OUTRO_TIME, budget * 0.5)

	var s: float = clamp(body_radius / REFERENCE_RADIUS, MIN_SCALE, MAX_SCALE) * SIZE_MULT
	scale = Vector2(s, s)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return

	if _elapsed <= _intro_time:
		var t: float = _elapsed / _intro_time if _intro_time > 0.0 else 1.0
		frame = clampi(int(round(t * float(INTRO_FRAMES - 1))), 0, INTRO_FRAMES - 1)
		return

	var outro_start_time: float = _duration - _outro_time
	if _elapsed < outro_start_time:
		frame = HOLD_FRAME
		return

	var ot: float = (_elapsed - outro_start_time) / _outro_time if _outro_time > 0.0 else 1.0
	var outro_frame: int = OUTRO_START_FRAME + int(round(clampf(ot, 0.0, 1.0) * float(FRAME_COUNT - 1 - OUTRO_START_FRAME)))
	frame = clampi(outro_frame, OUTRO_START_FRAME, FRAME_COUNT - 1)
