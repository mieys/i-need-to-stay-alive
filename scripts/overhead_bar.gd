extends Node2D

## Karakterin/yaratığın üstünde duran can (+ kalkan) çubuğu - kullanıcı
## isteği üzerine yuvarlak/hap şeklindeki "modern" görünüm yerine PİKSEL
## SANATI oyuna uygun, keskin köşeli, kalın siyah pikselik anahatlı bir
## stile çevrildi (bkz. _draw_pixel_bar - anti-aliasing YOK, tüm koordinatlar
## tam pixel'e yuvarlanıyor). Can çubuğunda ayrıca LoL'daki can çubuğu gibi
## her SEGMENT_HP (40) can başına ince bir bölme çizgisi var (bkz.
## _draw_health_segments) - örn. 200 canlı bir yaratıkta çubuk 5 eşit dilime
## bölünmüş görünür. Shield strip only shows up while there's shield to show.

const WIDTH := 44.0
const HEIGHT := 7.0
const GAP := 2.0
const SHADOW_OFFSET := Vector2(1.0, 1.0)
const OUTLINE := 2.0 ## kalın, piksel-sanatı tarzı siyah çerçeve

## Kaç can biriminde bir bölme çizgisi çizileceği (kullanıcı isteği: "can
## barında her 40 can başına bir çizgi olsun loldeki can barı gibi").
## DÜZELTME (kullanıcı bildirimi: "boss'larda çizgi çok fazla göründüğü için
## can barları simsiyah oluyor, 400 can başına 1 çizgi görünsün, veya
## çizgilerin bir sınırı olsun") - bir süre 40'tan 400'e çıkarılmıştı, ama bu
## küçük canlı yaratıklarda/oyuncuda 40'lık bölünmeyi tamamen kaybettiriyordu.
## Kullanıcı isteği (yeni tur): "40 can başına bir çizgi olmalı ama çizgi
## sayısı 20'yi geçmemeli" - SEGMENT_HP tekrar 40'a döndü, aşırı yüksek canlı
## yaratıklarda (bkz. boss) çizgi patlamasını/simsiyah görünümü önleyen üst
## sınır (MAX_SEGMENT_LINES) 20'ye çekildi. (2026-09-21: 800 canı aşan yaratıklarda çizgiler artık ilk 800 canda yığılmıyor - 20 çizgi
## de tüm çubuğa EŞİT aralıkla yayılıyor, bkz. _draw_health_segments.)
const SEGMENT_HP := 40.0
const MAX_SEGMENT_LINES := 20

## Above the character's head, with clear breathing room. Default is tuned
## for the player sprite; bosses (much bigger, wildly varying sizes) call
## set_offset() right after this script is attached to push it clear of
## their head instead - see enemy_spawner.gd's _attach_boss_bar.
var y_offset: float = -62.0

## OYNANABİLİR KARAKTERLERİN barı (kullanıcı bildirimi 2026-09-25: "karakterin üstündeki can ve kalkan barını biraz yukarı
## yükselt, bazı karakterlerin şapkasının görünmemesine neden oluyor"). Ölçüm (tüm karakterlerin idle/walk karelerindeki en
## üst opak piksel, characters.gd ölçek/ofset x EntityScale 0.95, karakter kökünün yerel biriminde): en uzunlar Büyücü
## (şapka) ve Melek -52.7, Assasin -50.6, Shaman -48.4. Eski -62'de can+kalkan çubuğu (7 + 2 + 5 px + çerçeve) -48'e kadar
## iniyor, şapkaların ucunu örtüyordu. -76'da çubukların altı ~-60 - en uzun şapkanın 7 px üstü. İsim etiketinin alt kenarı
## (remote_player_name.gd, -92) ile arasında hâlâ boşluk var. player.gd, remote_player.gd ve mission_player_copy.gd
## (oyuncunun kopyası) bunu set_offset ile uygular; varsayılan (-62) yaratık dışı diğer kullanıcılar (ağaç görevi) için
## değişmedi. downed_timer_label.gd de bu yüksekliğe hizalı.
const CHARACTER_Y_OFFSET := -76.0

var health_current: float = 1.0
var health_max: float = 1.0
var health_ratio: float = 1.0
## Can dolgusunun rengi - varsayılan yeşil (oyuncu/müttefik/görev objeleri); düşman bosslar kırmızı (kullanıcı isteği
## 2026-09-24: "düşman bossların can barı kırmızı renkte gözüksün" - bkz. enemy.gd _create_overhead_bar).
const HEALTH_COLOR_DEFAULT := Color(0.30, 0.82, 0.24, 1.0)
const HEALTH_COLOR_ENEMY := Color(0.88, 0.2, 0.17, 1.0)
var health_color: Color = HEALTH_COLOR_DEFAULT

var shield_current: float = 0.0
var shield_max: float = 0.0
var shield_ratio: float = 0.0
var show_shield: bool = false


func set_offset(offset: float) -> void:
	y_offset = offset
	queue_redraw()


func set_health(current: float, max_value: float) -> void:
	health_current = current
	health_max = max(max_value, 0.001)
	health_ratio = clamp(current / health_max, 0.0, 1.0)
	queue_redraw()


func set_shield(current: float, max_value: float) -> void:
	show_shield = max_value > 0.0
	shield_current = current
	shield_max = max(max_value, 0.001)
	shield_ratio = clamp(current / shield_max, 0.0, 1.0) if show_shield else 0.0
	queue_redraw()


## Kullanıcı isteği: "karakterin üstündeki can ve kalkan barları hafiften
## oval olsun" - eskiden tamamen keskin köşeli dikdörtgenlerdi (bkz. eski
## yorum), artık her katman (gölge/çerçeve/arkaplan/dolu kısım) StyleBoxFlat
## ile ÇOK HAFİF bir köşe yuvarlaklığıyla (bar yüksekliğinin ~%28'i - tam
## "hap" şekli DEĞİL, "hafiften oval" istendiği için bilinçli olarak küçük)
## çiziliyor. Piksel sanatı hissi (kalın siyah çerçeve, sert gölge, üstte
## parlama şeridi) korunuyor - sadece köşeler artık keskin değil.
const CORNER_RATIO := 0.28

func _draw_pixel_bar(rect: Rect2, ratio: float, fill_color: Color, bg_color: Color) -> void:
	var r := Rect2(rect.position.round(), rect.size.round())
	var corner: float = r.size.y * CORNER_RATIO

	var shadow_rect := Rect2(r.position + SHADOW_OFFSET, r.size)
	var shadow_style := StyleBoxFlat.new()
	shadow_style.bg_color = Color(0, 0, 0, 0.5)
	shadow_style.set_corner_radius_all(int(corner))
	draw_style_box(shadow_style, shadow_rect)

	var outer := r.grow(OUTLINE)
	var outline_style := StyleBoxFlat.new()
	outline_style.bg_color = Color(0, 0, 0, 1.0)
	outline_style.set_corner_radius_all(int(corner + OUTLINE))
	draw_style_box(outline_style, outer)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.set_corner_radius_all(int(corner))
	draw_style_box(bg_style, r)

	if ratio > 0.0:
		var fill_w: float = round(r.size.x * ratio)
		if fill_w > 0.0:
			var fill_rect := Rect2(r.position, Vector2(fill_w, r.size.y))
			var fill_style := StyleBoxFlat.new()
			fill_style.bg_color = fill_color
			fill_style.set_corner_radius_all(int(corner))
			draw_style_box(fill_style, fill_rect)
			var glow_rect := Rect2(r.position, Vector2(fill_w, max(1.0, r.size.y * 0.3)))
			var glow_style := StyleBoxFlat.new()
			glow_style.bg_color = fill_color.lightened(0.4)
			glow_style.corner_radius_top_left = int(corner)
			glow_style.corner_radius_top_right = int(corner)
			draw_style_box(glow_style, glow_rect)


## LoL tarzı bölme çizgileri: can havuzu büyüdükçe çubuk daha çok dilime bölünür (yaklaşık her SEGMENT_HP canda bir çizgi,
## en fazla MAX_SEGMENT_LINES çizgi) - büyük can havuzlu yaratıklarda/oyuncuda can çubuğunun kaç "parça" olduğu anında okunur.
##
## KULLANICI BİLDİRİMİ (2026-09-21): "can barlarında belli bir miktar can başına çıkan çizgi simetrik durmuyor, kaç çizgi olursa
## olsun aralarındaki mesafe aynı olmalı." KÖK NEDENLER (eski hâl her çizgiyi x = genişlik * (40 * k / max_can) yuvarlayarak koyuyordu):
##  1) max_can 40'ın katı değilse son dilim diğerlerinden KISA kalıyordu (ör. 100 canda 40/40/20 oranında);
##  2) max_can > 800'de çizgiler yalnızca ilk 800 canın üstüne yığılıyor, barın geri kalanı çizgisiz düz kalıyordu;
##  3) kesirli konum piksele yuvarlanınca komşu aralıklar 8-9-8-9 piksel gibi dönüşümlü farklı çıkıyordu.
## Şimdi: çizgi sayısı can havuzundan hesaplanır (bkz. _segment_line_count), çizgiler barı EŞİT dilimlere böler ve aralık
## TAM PİKSEL (hepsi birebir aynı) tutulur; artan birkaç piksel iki uca simetrik olarak paylaştırılır (bkz. _segment_line_offsets).
static func _segment_line_count(max_health: float) -> int:
	if max_health <= SEGMENT_HP:
		return 0
	return mini(int(ceil(max_health / SEGMENT_HP)) - 1, MAX_SEGMENT_LINES)


## Çubuğun sol kenarından (iç genişlik `width` piksel) itibaren `lines` çizginin piksel konumları; ardışık iki çizgi arası hep aynı.
static func _segment_line_offsets(width: float, lines: int) -> Array[float]:
	var out: Array[float] = []
	if lines <= 0:
		return out
	var slices: int = lines + 1
	var gap: float = floor(width / float(slices))
	if gap < 1.0:
		return out ## çubuk bu kadar çizgiyi sığdıramaz
	var leftover: float = width - gap * float(slices)
	var first: float = gap + floor(leftover * 0.5)
	for i in range(lines):
		out.append(first + gap * float(i))
	return out


func _draw_health_segments(rect: Rect2) -> void:
	var lines: int = _segment_line_count(health_max)
	if lines <= 0:
		return
	var r := Rect2(rect.position.round(), rect.size.round())
	for off: float in _segment_line_offsets(r.size.x, lines):
		var x: float = r.position.x + off
		## draw_rect (tam 1 piksel) - 1 px'lik draw_line tam piksel koordinatında iki piksele yarıya bölünüp aralıkları eşitsiz gösterebilir
		draw_rect(Rect2(x, r.position.y, 1.0, r.size.y), Color(0, 0, 0, 0.7))


func _draw() -> void:
	var half_w: float = WIDTH * 0.5
	var health_rect := Rect2(Vector2(-half_w, y_offset), Vector2(WIDTH, HEIGHT))
	_draw_pixel_bar(health_rect, health_ratio, health_color, Color(0.12, 0.04, 0.04, 1.0))
	_draw_health_segments(health_rect)

	if show_shield:
		var shield_rect := Rect2(Vector2(-half_w, y_offset + HEIGHT + GAP), Vector2(WIDTH, HEIGHT * 0.72))
		_draw_pixel_bar(shield_rect, shield_ratio, Color(0.35, 0.72, 1.0, 1.0), Color(0.04, 0.08, 0.14, 1.0))
