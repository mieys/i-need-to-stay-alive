extends Node2D

## Kalkan "isabet" (bariyer hasar alma) efekti - artik PROSEDUREL degil, BAKED sprite.
## Kullanıcı bildirimi (2026-09-23): "şovalye adamın kalkan baloncuğunu açtığımda fps 10'a
## düşüyor çünkü çok sayıda kalkan hasar alma efekti oluyor" - eski hal her isabette bu node'u
## _draw() icinde ~1200 draw_rect() cagrisiyla (dither dolgu + tam çemberler + yüzey dalgası +
## çatlaklar) YENİDEN CİZİYORDU; Şovalye'nin bariyerini saran bir yaratık sürüsü aynı anda
## onlarca tanesini canlı tutunca FPS çöküyordu. Artık görünüm tools/gen_perf_sprite_fx.py ile
## PNG'ye "pişirildi" (assets/fx/shield_hit/hit_sheet.png, 3 rastgele çatlak varyantı x 24 kare,
## orijinal ~60fps akıcılığa yakın durmak için) ve burada TEK BİR AnimatedSprite2D çizimiyle
## oynatılıyor - draw_rect sayısı ~1200 -> 1'e indi. Referans yarıçap 40 world biriminde, vuruş
## açısı 0 (sağa bakan) olarak pişirildi; her yöne/yarıçapa uyması için node rotation=angle,
## scale=radius/REFERENCE_RADIUS ile ayarlanıyor (bkz. aşağıdaki ÖLÇEK NOTU - TEXEL çarpanı YOK) -
## "her pozisyonda" doğru görünmesi TAM OLARAK bu rotation/scale ikilisiyle sağlanıyor.
## Hem KASTERİN kendi ekranında (player.gd _spawn_shield_hit_fx) hem uzak oyuncularda
## (network_manager.gd "shield_hit_flash" dalı) hem Şovalye bariyerinde (fx_paladin_barrier.gd)
## AYNI script - görünüm tek yerde (bkz. proje kökündeki CLAUDE.md).
## ÖLÇEK NOTU: tools/gen_perf_sprite_fx.py bu PNG'yi `_radius`nin KENDİSİ WORLD BİRİMİ olduğu
## (pixel_draw.gd'de _radius doğrudan world birimi olarak kullanılıyor, TEXEL çarpanı YOK)
## kabulüyle "1 raster piksel = 1 world birimi" olarak pişirdi - yani burada PixelDraw.TEXEL ile
## AYRICA ölçeklemek YANLIŞ olur (görüntüyü ~%21 büyütür), sadece radius/REFERENCE_RADIUS oranı
## uygulanır.

const HIT_FRAMES := preload("res://assets/fx/shield_hit/hit_frames.tres")
const VARIANT_COUNT := 3

## Oyuncunun kalkan baloncuğunun görünen kenarı (ekranda ölçüldü, ~40 birim) - PNG bu yarıçapa
## göre pişirildi (bkz. tools/gen_perf_sprite_fx.py SH_RADIUS).
const REFERENCE_RADIUS := 40.0

var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	z_index = 60


## angle: karakterden vuran tarafa radyan. radius: bariyerin yarıçapı (varsayılan: oyuncu kalkan
## baloncuğu). `light` parametresi artık gereksiz (sprite maliyeti detaydan bağımsız TEK çizim) -
## eski çağrı yerlerinde hâlâ 3. argüman gelirse sessizce yok sayılır.
## crack_scale (> 0): efektin boyutunu bariyer yarıçapından AYIRIR - sprite bu sabit ölçekte çizilir ve vuruş noktası
## yine bariyerin kenarına (radius) gelecek şekilde vuruş yönünde kaydırılır. Kullanıcı bildirimi (2026-09-24):
## "Şovalye adamın kalkan baloncuğu hasar alma efektindeki çatlama efektleri çok büyük" - baloncuk yarıçapı 126
## olduğu için radius/REFERENCE_RADIUS ölçeği çatlakları ~3.2 kat büyütüyordu (bkz. fx_paladin_barrier.gd).
func setup(angle: float, radius: float = REFERENCE_RADIUS, _unused_light: bool = false, crack_scale: float = -1.0) -> void:
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = HIT_FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.rotation = angle
	if crack_scale > 0.0:
		_sprite.scale = Vector2.ONE * crack_scale
		_sprite.position = Vector2(cos(angle), sin(angle)) * (radius - REFERENCE_RADIUS * crack_scale)
	else:
		_sprite.scale = Vector2.ONE * (radius / REFERENCE_RADIUS)
	_sprite.animation_finished.connect(queue_free)
	_sprite.play("hit_%d" % randi_range(0, VARIANT_COUNT - 1))
