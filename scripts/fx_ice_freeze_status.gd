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

const BottomShader := preload("res://shaders/buz_donma_dip.gdshader")
static var _shared_material: ShaderMaterial = null

static func _bottom_material() -> ShaderMaterial:
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = BottomShader
	return _shared_material


func _ready() -> void:
	position = Vector2.ZERO
	_variant = VARIANT_NAMES[randi() % VARIANT_NAMES.size()]
	animation = _variant
	frame = 0
	## Doğal dip (madde 544, kullanıcı B seçti): düzensiz kırılıp basamaklı sönen taban; kırağı lekesi denendi, seçilmedi.
	material = _bottom_material()

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

	var body: Rect2 = body_rect(get_parent() as Node2D)
	if body.size.x > 1.0 and body.size.y > 1.0:
		_fit_to_rect(body)
	else:
		## Görünen sınır okunamadıysa (headless/dummy sürücü) eski yarıçap kuralı.
		var s: float = clamp(body_radius / REFERENCE_RADIUS, MIN_SCALE, MAX_SCALE) * SIZE_MULT
		scale = Vector2(s, s)


## DÜZELTME (kullanıcı isteği 2026-11-09: "buz donma efekti gereksiz büyük çıkıyor, yaratığın bedenini hafif
## dışına taşacak, bedeni kaplayacak şekilde olmalıydı"): yarıçap x 1,6 kuralı yaratığın GÖRÜNEN bedenini
## temsil etmiyordu (16x30 dikey buz sütunu: slime 24x22 bedene 18x34, ağaç 53x67'ye 50x94). Artık buz
## yaratık sprite'ının o anki satırının opak sınırına (`body_rect`) oturur: yükseklik bedenin FIT_PAD katı,
## taban ayakların biraz altında, genişlik dar kalırsa yatayda en çok MAX_X_STRETCH kat açılır.
const ICE_ART_W := 16.0 ## buz karesinin opak genişliği (sanat pikseli)
const ICE_ART_H := 30.0 ## tut karesinin (3) opak yüksekliği; kare 32, opak kısım y 2..32
const ICE_ART_BOTTOM := 16.0 ## ortalı karede opak tabanın yerel y'si
const FIT_PAD := 1.12 ## bedenden ne kadar taşsın (yükseklik)
const FIT_PAD_X := 1.08 ## genişlikte taşma
const FIT_FOOT_PAD := 2.0 ## taban ayakların bu kadar altında (yaratık yerel birimi)
const MAX_X_STRETCH := 1.5 ## geniş yaratıkta yatay açılma sınırı (piksel bozulması az kalsın)

func _fit_to_rect(body: Rect2) -> void:
	var s: float = body.size.y * FIT_PAD / ICE_ART_H
	var sx: float = clampf(body.size.x * FIT_PAD_X / ICE_ART_W, s, s * MAX_X_STRETCH)
	scale = Vector2(sx, s)
	position = Vector2(body.get_center().x, body.end.y + FIT_FOOT_PAD - ICE_ART_BOTTOM * s)


## Sprite satırı başına opak sınır önbelleği (doku okuma tek sefer; anahtar doku + satır).
static var _rect_cache: Dictionary = {}

## Yaratığın görünen bedeni, yaratığın YEREL koordinatında (Sprite2D ya da AnimatedSprite2D).
## Okunamazsa boş Rect2.
static func body_rect(enemy: Node2D) -> Rect2:
	if enemy == null:
		return Rect2()
	var spr: Sprite2D = enemy.get_node_or_null("Sprite2D") as Sprite2D
	if spr and spr.visible and spr.texture:
		return _sprite_rect(spr)
	var anim: AnimatedSprite2D = enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if anim and anim.sprite_frames:
		return _anim_rect(anim)
	return Rect2()


static func _sprite_rect(spr: Sprite2D) -> Rect2:
	var tex: Texture2D = spr.texture
	var hf: int = maxi(spr.hframes, 1)
	var vf: int = maxi(spr.vframes, 1)
	var row: int = clampi(spr.frame_coords.y, 0, vf - 1)
	var key: String = "%s|%d|%d|%d" % [tex.resource_path if tex.resource_path != "" else str(tex.get_rid()), hf, vf, row]
	var cell_rect: Rect2
	if _rect_cache.has(key):
		cell_rect = _rect_cache[key]
	else:
		cell_rect = Rect2()
		var img: Image = tex.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			var cw: int = floori(img.get_width() / float(hf))
			var ch: int = floori(img.get_height() / float(vf))
			var found := false
			for i in hf:
				var r: Rect2i = img.get_region(Rect2i(i * cw, row * ch, cw, ch)).get_used_rect()
				if r.size.x <= 0:
					continue
				cell_rect = Rect2(r) if not found else cell_rect.merge(Rect2(r))
				found = true
			if found:
				cell_rect.position -= Vector2(cw, ch) * 0.5 ## ortalı karede yerel
		_rect_cache[key] = cell_rect
	return _to_parent(cell_rect, spr.centered, Vector2(tex.get_size()) / Vector2(hf, vf), spr.offset, spr.flip_h, spr.flip_v, spr)


static func _anim_rect(anim: AnimatedSprite2D) -> Rect2:
	var sf: SpriteFrames = anim.sprite_frames
	var a: StringName = anim.animation
	if not sf.has_animation(a) or sf.get_frame_count(a) == 0:
		return Rect2()
	var first: Texture2D = sf.get_frame_texture(a, 0)
	if first == null:
		return Rect2()
	var key: String = "%s|%s" % [str(sf.get_instance_id()) if sf.resource_path == "" else sf.resource_path, a]
	var cell_rect: Rect2
	if _rect_cache.has(key):
		cell_rect = _rect_cache[key]
	else:
		cell_rect = Rect2()
		var found := false
		for i in mini(sf.get_frame_count(a), 8):
			var t: Texture2D = sf.get_frame_texture(a, i)
			var img: Image = t.get_image() if t else null
			if img == null:
				continue
			if img.is_compressed():
				img.decompress()
			var r: Rect2i = img.get_used_rect()
			if r.size.x <= 0:
				continue
			var rr := Rect2(Vector2(r.position) - Vector2(img.get_size()) * 0.5, Vector2(r.size))
			cell_rect = rr if not found else cell_rect.merge(rr)
			found = true
		_rect_cache[key] = cell_rect
	return _to_parent(cell_rect, anim.centered, first.get_size(), anim.offset, anim.flip_h, anim.flip_v, anim)


## Ortalı kare yerelindeki dikdörtgeni sprite düğümünün ebeveyn (yaratık) koordinatına taşır.
static func _to_parent(r: Rect2, centered: bool, cell: Vector2, offset: Vector2, flip_h: bool, flip_v: bool, node: Node2D) -> Rect2:
	if r.size.x <= 0.0:
		return Rect2()
	if flip_h:
		r.position.x = -r.end.x
	if flip_v:
		r.position.y = -r.end.y
	r.position += offset
	if not centered:
		r.position += cell * 0.5
	var sc: Vector2 = node.scale.abs()
	return Rect2(node.position + r.position * sc, r.size * sc)


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
