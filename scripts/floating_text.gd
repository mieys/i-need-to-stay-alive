extends Node2D

const VisionFogScript := preload("res://scripts/vision_fog.gd")

## Karakterin (oyuncu/düşman) TAM ÜSTÜNDE belirir, SADECE hafifçe yukarı
## kayar, sonra söner. Başka hiçbir hareket yok: yana kaymaz, zıplamaz,
## büyüyüp küçülmez, "nabız" atmaz - tek animasyonu bu küçük, yavaş, tek
## yönlü (yukarı) kayış.
@onready var label: Label = $Label
## DÜZELTME (kullanıcı bildirimi: "yazılar çok kötü ve düşük çözünürlüklü
## görünüyor ... önceden böyle değildi çok şirinlerdi aynı fontta") - bir
## önceki turda eklenen Godot'un YERLEŞİK Label outline'ı (font_outline_
## color/outline_size) bu küçük piksel fontunda (m5x7, antialiasing KAPALI -
## bkz. m5x7.ttf.import) net/keskin çıkmıyor, bulanık/"kirli" bir hale
## görünüyordu - Godot'un outline çizimi glyph'i vektörel olarak
## genişletiyor, bu da piksel-kusursuz ızgaraya oturmuyor. Bunun yerine
## retro piksel oyunlarında standart olan "sahte kontür" (poor man's
## outline) tekniğine geçildi: metnin AYNI (zaten piksel-kusursuz render
## edilen) kopyası 8 yönde 1px kaydırılıp SİYAH olarak arkaya, gerçek metin
## en üste çiziliyor - hiçbir vektörel genişletme yok, sadece aynı crisp
## glyph'in tekrar tekrar çizilmesi, bu yüzden HER ZAMAN piksel-kusursuz.
## DÜZELTME (kullanıcı isteği: "hasar sayılarının kontürü çok kalın çok az
## azalt") - eskiden 8 yönde (4 kenar + 4 köşegen) kopya vardı; köşegenler
## üst üste binince köşelerde kontür GÖRÜNÜR şekilde daha kalın duruyordu.
## Köşegen 4 kopya (eski Outline0/2/5/7) tamamen kaldırıldı, sadece 4 kenar
## (yukarı/aşağı/sağ/sol) kaldı - hâlâ piksel-kusursuz (sub-pixel/bulanık
## YOK), sadece köşelerdeki çift kalınlık gitti, biraz daha ince görünüyor.
@onready var _outline_labels: Array[Label] = [$Outline1, $Outline3, $Outline4, $Outline6]
const OUTLINE_COLOR := Color(0, 0, 0, 1)
const OUTLINE_OFFSETS := [
	Vector2(0, -1),
	Vector2(-1, 0), Vector2(1, 0),
	Vector2(0, 1),
]

const RISE := 6.0
const LIFETIME := 0.9
const FADE_IN_DURATION := 0.08

var _fade_tw: Tween = null
var _rise_tw: Tween = null
var _rise_offset: float = 0.0 ## 0 -> RISE, animasyonla artar

## Takip edilecek karakter (enemy.gd/player.gd kendini atar) - her karede
## sayının konumu buna göre yeniden hesaplanır, böylece karakter hareket
## ederken sayı geride kalmaz/eski konumunda takılı durmaz (bkz. kullanıcı
## bildirimi: "düşman hareket edince hasar sayısının konumu hızlı
## güncellenmiyor... düşmanları iyi takip etmesi gerek"). null bırakılırsa
## (ör. altın/yemek toplama yazıları gibi sabit bir noktadan çıkanlar) eski
## davranış gibi sadece ilk spawn noktasında kalıp oradan yükselir.
var follow_target: Node2D = null
var follow_offset: Vector2 = Vector2.ZERO

## Takip edilen karakter öldüğünde/queue_free() olduğunda (is_instance_valid
## artık false) sayı ESKİ, bayat bir spawn noktasına SIÇRAMAMALI - bu yüzden
## "ilk spawn noktası" yerine SON GEÇERLİ karede nerede olduğu saklanır ve
## hedef kaybolunca sayı sessizce tam o son noktada kalıp normal şekilde
## sönmeye devam eder (bkz. kullanıcı bildirimi: "yaratık öldükten sonra
## bazen glitchleniyor... anlık görünüp kayboluyor").
var _last_known_origin: Vector2 = Vector2.ZERO


## Kullanıcı isteği: "yazıları %80 büyüt ve hasar sayılarının okunabilirliğini
## ayarla okumak çok zor" - eski boyutlar (19/13) hem genel metin büyütmesiyle
## (bkz. theme.tres default_font_size) hem de okunabilirlik kaygısıyla ×1.8'e
## çıkarıldı (23/34) - bkz. aşağıdaki _ready() notu, asıl okunabilirlik
## sorunu boyuttan çok zayıf outline'dı, o da ayrıca güçlendirildi.
## Kullanıcı isteği (yeni tur): "hasar ve iyileşme sayıları v.s %30 küçült" -
## 34/23 -> ×0.7 (24/16).
func setup(text: String, color: Color, big: bool = false) -> void:
	var font_size: int = 24 if big else 16
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	for i in range(_outline_labels.size()):
		var ol: Label = _outline_labels[i]
		ol.text = text
		ol.add_theme_color_override("font_color", OUTLINE_COLOR)
		ol.add_theme_font_size_override("font_size", font_size)
		ol.position = label.position + OUTLINE_OFFSETS[i]
	## Tüm etiketler (asıl metin + 8 kontür kopyası) TEK bir kök Node2D'nin
	## çocuğu - modulate KÖKTE ayarlanınca hepsine birden kademelenir (bkz.
	## _start_fade_timer'daki AYNI değişiklik), tek tek her Label'ı ayrı ayrı
	## solduramaya/görünür yapmaya gerek yok.
	modulate.a = 0.0
	_last_known_origin = global_position
	_start_rise()
	_start_fade_timer()


func _process(_delta: float) -> void:
	if follow_target and is_instance_valid(follow_target):
		_last_known_origin = follow_target.global_position + follow_offset
		## Görüş alanı sisinde gizlenen/solan bir düşmanın hasar sayısı karanlıkta
		## tek başına süzülüp düşmanın yerini ele vermesin (bkz. vision_fog.gd).
		## Sayı düşmanın çocuğu DEĞİL, sahne köküne ekleniyor - bu yüzden
		## görünürlüğü elle takip etmesi gerekiyor. SADECE sisin yönettiği
		## görünürlüğe bakılıyor (is_visible_in_tree DEĞİL): başka bir sebeple
		## gizlenen bir hedefin (ör. görünmez oyuncu) sayıları eskisi gibi çıkmaya
		## devam etmeli.
		visible = VisionFogScript.fog_visibility_of(follow_target) >= VisionFogScript.SIDE_ELEMENT_MIN_VISIBILITY
	global_position = _last_known_origin - Vector2(0, _rise_offset)


## Yükseliş SADECE bir kez, ilk spawn'da oynar - update_text() (aynı
## karaktere ard arda hızlı gelen hasarları birleştirmek için, bkz.
## enemy.gd) bunu tekrar TETİKLEMEZ. Böylece hasar hızı ne olursa olsun
## toplam yükseliş miktarı hep aynı, küçük, sabit RISE değeriyle sınırlı
## kalır.
func _start_rise() -> void:
	if _rise_tw and _rise_tw.is_valid():
		_rise_tw.kill()
	_rise_tw = create_tween()
	_rise_tw.tween_method(_set_rise_offset, _rise_offset, RISE, LIFETIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_rise_offset(value: float) -> void:
	_rise_offset = value


func _start_fade_timer() -> void:
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	_fade_tw.tween_interval(LIFETIME * 0.4)
	_fade_tw.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_tw.tween_callback(queue_free)


## Aynı karaktere art arda çok hızlı gelen ayrı vuruşları (ör. çok yüksek
## ateş hızı) yeni bir kutucuk daha açıp üst üste yığmak yerine BU
## kutucuğun üzerine toplamak için (bkz. enemy.gd _spawn_floating_text).
## Yükseliş/takip HİÇ etkilenmez - sadece metin/renk güncellenir ve solma
## süresi tazelenir ki barraj sürerken kutucuk kaybolmasın.
func update_text(text: String, color: Color) -> void:
	label.text = text
	label.add_theme_color_override("font_color", color)
	for ol: Label in _outline_labels:
		ol.text = text
	_start_fade_timer()
