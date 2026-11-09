extends Control

## Oyuncu panelindeki (hud.gd "oyuncu dock'u") can/kalkan çubuğu. Görünüş 2026-11-08'den beri D "Pirinç Kapaklı" + LoL tarzı dolgu
## animasyonu (madde 470, aşağıda _draw_round_bar); eski düz çizim yalnız çok küçük çubukta.
## hud.gd update_health / _on_item_shield_changed besler (set_values).

var ratio: float = 1.0
var fill: Color = HudTheme.HP_GREEN
var under: Color = HudTheme.DOCK_INSET ## madde 454: Gömme Tepsi kuyusu
var text: String = ""
var font_size: int = 24

const HudTheme := preload("res://scripts/hud_theme.gd")
const OUTLINE := HudTheme.OUTLINE
const TEXT_COLOR := Color("#fff0d6")

## 2026-10-14 (oyuncu paneli yeniden tasarımı, kullanıcının seçtiği prototip 2): "birleşik" kip - solda piksel ikon
## (icon_kind: "heart" / "shield"), değer yazısı çubuğun SAĞ ucunda ve dolgu yazının altından geçer; mevcut değer açık,
## "/azami" soluk. Yazı kalın piksel yazı tipinin TAM katında (PixeloidSans 9 x 2) - eski bulanıklığın sebebi kesirli
## ölçekti (22 px x 0,85). Telefon HUD'u bu kipi açmaz (eski ortalanmış yazı).
const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const VALUE_FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const VALUE_FONT_SIZE := 18
const VALUE_CAP := 14.0 ## rakam yüksekliği (7 sanat pikseli x 2)
const VALUE_DIM := HudTheme.DIM
const ICON_SPACE := 28.0 ## ikon (22 px) + boşluk; çubuk bundan sonra başlar
var merged: bool = false
var icon_kind: String = ""
var value_color: Color = TEXT_COLOR
## Madde 475 (LoL gibi): çubuğun SAĞ ucunda solgun yenilenme yazısı ("+2.5"); boşsa çizilmez. hud.gd _process besler (set_regen).
var regen_text: String = ""
const REGEN_ALPHA := 0.7 ## "hafif solgun": VALUE_DIM'in bu saydamlığı (kontur da)
const PLUS_PX := 5.0 ## yenilenme yazısının elle çizilen artısı (ekran px)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	set_notify_transform(true) ## değer yazısı katmanı (top_level) paneli izlesin, bkz. _notification
	set_process(true) ## LoL dolgu animasyonu + parlaklık geçişi (madde 470); iş yokken yeniden çizmez


func set_regen(t: String) -> void:
	if t == regen_text:
		return
	regen_text = t
	queue_redraw()


func set_values(new_ratio: float, new_fill: Color, new_text: String) -> void:
	new_ratio = clampf(new_ratio, 0.0, 1.0)
	if is_equal_approx(new_ratio, ratio) and new_fill.is_equal_approx(fill) and new_text == text:
		return
	## LoL tarzı (madde 470): düşüşte dolgu hemen iner, kaybedilen kısım `_trail` olarak bekleyip erir; artışta `_shown` _process'te yetişir.
	if _shown < 0.0:
		_shown = new_ratio
		_trail = new_ratio
	elif new_ratio < _shown - 0.0005:
		_trail = maxf(_trail, _shown)
		_shown = new_ratio
		_hold = TRAIL_HOLD
	ratio = new_ratio
	fill = new_fill
	text = new_text
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if merged and icon_kind != "":
		var ip := Vector2(0.0, roundf((size.y - 20.0) * 0.5))
		if icon_kind == "shield":
			PixelIcons.draw_shape(self, PixelIcons.SHIELD, ip, 2.0, PixelIcons.SHIELD_COLOR)
		else:
			PixelIcons.draw_shape(self, PixelIcons.HEART, ip, 2.0, PixelIcons.HEART_COLOR)
		r = Rect2(Vector2(ICON_SPACE, 0.0), size - Vector2(ICON_SPACE, 0.0))
	if r.size.x < 6.0 or r.size.y < 6.0:
		return
	if not _draw_round_bar(r):
		draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(r.size.x - 4, r.size.y)), OUTLINE)
		draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, r.size.y - 4)), OUTLINE)
		var inner := r.grow(-2)
		draw_rect(inner, under)
		var w: float = round(inner.size.x * ratio / 2.0) * 2.0
		if w > 0.0:
			draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)
			draw_rect(Rect2(inner.position, Vector2(w, 2)), fill.lightened(0.35))
			draw_rect(Rect2(inner.position + Vector2(0, inner.size.y - 2), Vector2(w, 2)), fill.darkened(0.3))
	if merged:
		_draw_value(r)
	elif text != "":
		var f: Font = get_theme_default_font()
		var ts: Vector2 = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var p := Vector2(round((size.x - ts.x) * 0.5), round((size.y + ts.y * 0.62) * 0.5))
		draw_string_outline(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, maxi(3, int(round(font_size * 0.2))), OUTLINE) ## kontur yazıyla orantılı (eskiden sabit 6: küçük yazıyı dolduruyordu)
		draw_string(f, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_COLOR)


## Madde 467 (kullanıcı: "can ve kalkan barı pek oval gibi değil pixel bir ovalliğinin olmasını sağla") -> madde 470 (kullanıcı 4 prototipten
## "D yi beğendim. league of legends gibi yapar mısın içindeki bar sıvısının animasyonunu"): görünüş D "PİRİNÇ KAPAKLI" + LoL tarzı dolgu.
## EKRAN PİKSELİNDE çizilir (dock 0,92 ölçekli; global dönüşüm geri alınır, dikdörtgen tam piksele ve sanat pikseli katına yuvarlanır),
## 1 sanat px = BAR_PX ekran px:
##   - iki uçta perçinli pirinç kapak (CAP_ART sanat px; HudTheme ACCENT_DK / SPOT / ACCENT), arada koyu kanal + kuyu (`under`)
##   - dolgu 3 bant (üst açık / orta / alt koyu) + dolgunun ucunda açık sıvı yüzeyi sütunu (sabit parlama çizgisi kullanıcı isteğiyle yok)
##   - LoL: hasarda kaybedilen parça (`_trail`) krem-açık renkte TRAIL_HOLD sn durur sonra üstel erir; iyileşmede dolgu (`_shown`) yumuşak büyür;
##     her GLEAM_PERIOD sn'de bir hafif parlaklık dolgunun üstünden geçer (kalkanınki kaydırılmış). Yalnız iş varken yeniden çizilir.
## Sığmayan çok küçük çubukta false döner, eski düz çizim çalışır. Prototipler: tools/proto_20261108/bar_proto/ (A-D).
const BAR_PX := 2.0
const CAP_ART := 4
const BRASS_DK := HudTheme.ACCENT_DK
const BRASS := HudTheme.SPOT
const BRASS_HI := HudTheme.ACCENT
const TRAIL_HOLD := 0.5 ## hasar parçası bu kadar bekler
const TRAIL_EASE := 5.0 ## sonra kalan farkın bu katı / sn hızla erir
const TRAIL_MIN_SPEED := 0.15 ## (oran/sn) en yavaş erime - kuyruk uzamasın
const HEAL_EASE := 8.0
const HEAL_MIN_SPEED := 0.3
const GLEAM_PERIOD := 6.0
const GLEAM_TIME := 1.1
## Değer yazısı da ekran pikselinde, kenarı keskin ve küçük (kullanıcı: "yazılar çok büyük görünüyor dışarı taşmak üzereler"): eskisi 18 punto
## x0,92 ölçek + 6'lık kontur (~19 px) 18 px'lik kuyuyu dolduruyordu. Madde 467'de ara boy 13 punto (rakam ~10 px) seçilmişti; madde 474'te yazı
## çubuğun ORTASINA, yani dolgunun üstüne geçince 13 px'lik dolguda konturuyla kenarlara değdi (kullanıcı: "bar doluyken sayılar çok sınırda
## duruyor") -> PixeloidSans'ın 1:1 boyu 9 punto (rakam 7 px, stil rehberinin sayı boyu): kontur dahil 9 px, dolguda üstte/altta 2 px pay.
## 10-12 punto denendi: piksel font ~9 px'e yuvarlanıyor, pay açılmıyor.
const VALUE_SCREEN_SIZE := 9
const VALUE_SCREEN_CAP := 7.0 ## rakam yüksekliği (dikey ortalama)
## Yazı boyu (ekran pikseli punto) - yalnız "outline" biçiminde (madde 474 Pixeloid 9).
var value_fs: int = VALUE_SCREEN_SIZE
## Yazı biçimi. Madde 511 (kullanıcı: "her ekranda yumuşak olsun"): varsayılan "smooth" = sayılar yumuşak kenarlı, kalınlaştırılmış Nunito + yumuşak
## koyu kontur (Terraria yolu; 2560x1440 gibi tam kat olmayan ölçekte piksel fontun eşitsiz pikselleri okunmuyordu, madde 508). "outline" =
## eski piksel yazı (Pixeloid 9 + 8 yönlü 1 px kontur) duruyor. Madde 506'nın A-D biçimleri reddedildi, silindi.
var value_style: String = "smooth"
const NUNITO: Font = preload("res://assets/fonts/Nunito-SemiBold.ttf")
const SMOOTH_FS := 13
const SMOOTH_OUTLINE := 4
## Kalınlaştırma: Nunito SemiBold 12-13 px'te ince ve gri kalıyordu (1080p'de soluk); 0,8 = Bold'a yakın, rakam içleri açık kalır.
const SMOOTH_EMBOLDEN := 0.8
static var _smooth_font: Font = null


## Çubuk sayıları için kalınlaştırılmış Nunito (içe aktarma ayarları aynı: 2x yeniden çizim + gri kenar yumuşatma). Denenen: 0 / 12 / 3
## soluk, kopyada oversampling 0 + hafif ipucu daha da soluk; 0,8 / 13 / 4 iki çözünürlükte en okunur (madde 511).
static func smooth_font() -> Font:
	if _smooth_font == null:
		var v := FontVariation.new()
		v.base_font = NUNITO
		v.variation_embolden = SMOOTH_EMBOLDEN
		_smooth_font = v
	return _smooth_font


func _style_font() -> Font:
	return smooth_font() if value_style == "smooth" else VALUE_FONT


func _style_fs(fs: int) -> int:
	return SMOOTH_FS if value_style == "smooth" else fs


func _text_w(s: String, fs: int) -> float:
	return _style_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _style_fs(fs)).x


func _text_cap(fs: int) -> float:
	if value_style == "smooth":
		return roundf(float(SMOOTH_FS) * 0.7) ## Nunito büyük harf/rakam yüksekliği ~0,7 em
	return VALUE_SCREEN_CAP * float(fs) / float(VALUE_SCREEN_SIZE)
var _bar_px: Rect2 = Rect2() ## son çizilen çubuğun yazı dikdörtgeni (tam piksel, sağ kapak hariç); boşsa yazı eski yoldan
var _shown: float = -1.0 ## çizilen dolgu oranı (iyileşmede ratio'ya yumuşak yetişir); -1 = henüz değer yok
var _trail: float = 0.0 ## hasar parçasının ucu (>= _shown)
var _hold: float = 0.0
var _anim_t: float = 0.0
var _gleam_was: bool = false
## Madde 471'deki "yalnız mevcut değer, fare üstündeyken mevcut/azami" kuralı madde 474'te KALDIRILDI (kullanıcı: "maksimum can-kalkan
## miktarı da daima gözükür olsun ... o fikirden vazgeçtim"): yazı hep "mevcut/azami" ve çubuğun ORTASINDA.


func _process(delta: float) -> void:
	_anim_t += delta
	var busy: bool = false
	if _shown >= 0.0 and _shown < ratio:
		_shown = minf(ratio, _shown + maxf(HEAL_MIN_SPEED * delta, (ratio - _shown) * HEAL_EASE * delta))
		busy = true
	if _trail > _shown:
		if _hold > 0.0:
			_hold -= delta
		else:
			_trail = maxf(_shown, _trail - maxf(TRAIL_MIN_SPEED * delta, (_trail - _shown) * TRAIL_EASE * delta))
		busy = true
	var gleam: bool = _gleam_phase() >= 0.0
	if busy or gleam or _gleam_was:
		queue_redraw()
	_gleam_was = gleam


## 0..1 parlaklık geçişi sürerken, değilse -1. Kalkan çubuğu yarım dönem kaydırılır (ikisi aynı anda parlamasın).
func _gleam_phase() -> float:
	var off: float = GLEAM_PERIOD * 0.5 if icon_kind == "shield" else 0.0
	var t: float = fmod(_anim_t + off, GLEAM_PERIOD)
	return t / GLEAM_TIME if t < GLEAM_TIME else -1.0


func _round_rows(g: Rect2, p: float, prof: Array, col: Color) -> void:
	var rows: int = int(g.size.y / p)
	for y in rows:
		var k: int = 0
		if y < prof.size():
			k = prof[y]
		elif rows - 1 - y < prof.size():
			k = prof[rows - 1 - y]
		draw_rect(Rect2(g.position.x + k * p, g.position.y + y * p, g.size.x - 2 * k * p, p), col)


func _draw_round_bar(r: Rect2) -> bool:
	var xf: Transform2D = get_global_transform()
	var a: Vector2 = (xf * r.position).round()
	var b: Vector2 = (xf * r.end).round()
	var p: float = BAR_PX
	var w: float = floorf((b.x - a.x) / p) * p
	var h: float = floorf((b.y - a.y) / p) * p
	if w < (2 * CAP_ART + 8) * p or h < 6.0 * p:
		_bar_px = Rect2()
		return false
	var g := Rect2(a + ((b - a - Vector2(w, h)) * 0.5).floor(), Vector2(w, h))
	_bar_px = g ## değer yazısı bütün çubuğun ortasında (kapaklar simetrik -> kanalın da ortası)
	draw_set_transform_matrix(xf.affine_inverse())
	var cap_w: float = CAP_ART * p
	## kanal (iki kapak arası): koyu çerçeve + kuyu
	var ch := Rect2(g.position.x + cap_w - p, g.position.y + p, g.size.x - 2 * cap_w + 2 * p, g.size.y - 2 * p)
	draw_rect(ch, OUTLINE)
	var inner := ch.grow(-p)
	draw_rect(inner, under)
	var shown: float = clampf(ratio if _shown < 0.0 else _shown, 0.0, 1.0)
	var fw: float = floorf(inner.size.x * shown / p) * p
	var tw: float = floorf(inner.size.x * clampf(maxf(_trail, shown), 0.0, 1.0) / p) * p
	var hgt: float = inner.size.y
	var band: float = floorf(hgt / 3.0 / p) * p
	## LoL hasar parçası (dolgunun önünde kalan krem-açık kısım)
	if tw > fw:
		var tc: Color = fill.lerp(HudTheme.TEXT, 0.6)
		var tr := Rect2(inner.position.x + fw, inner.position.y, tw - fw, hgt)
		draw_rect(tr, tc)
		draw_rect(Rect2(tr.position.x, tr.end.y - band, tr.size.x, band), tc.darkened(0.15))
	if fw > 0.0:
		draw_rect(Rect2(inner.position, Vector2(fw, hgt)), fill)
		draw_rect(Rect2(inner.position, Vector2(fw, band)), fill.lightened(0.22))
		draw_rect(Rect2(inner.position.x, inner.end.y - band, fw, band), fill.darkened(0.25))
		## Sabit cam parıltısı çizgisi KALDIRILDI (kullanıcı: "bu beyazlıklar ne" -> önce dolgu boyunca soluk, sonra "o parıltıyı kaldır en iyisi").
		if fw < inner.size.x:
			draw_rect(Rect2(inner.position.x + fw - p, inner.position.y, p, hgt), fill.lightened(0.35)) ## sıvı yüzeyi
		var ph: float = _gleam_phase()
		if ph >= 0.0:
			var gw: float = 6.0 * p
			var gx: float = floorf((inner.position.x - gw + ph * (fw + gw)) / p) * p
			var x0: float = maxf(gx, inner.position.x)
			var x1: float = minf(gx + gw, inner.position.x + fw)
			if x1 > x0:
				draw_rect(Rect2(x0, inner.position.y, x1 - x0, hgt), Color(1, 1, 1, 0.14))
				var cx0: float = maxf(gx + 2.0 * p, inner.position.x)
				var cx1: float = minf(gx + 4.0 * p, inner.position.x + fw)
				if cx1 > cx0:
					draw_rect(Rect2(cx0, inner.position.y, cx1 - cx0, hgt), Color(1, 1, 1, 0.12))
	## pirinç kapaklar
	for side in [0, 1]:
		var cx: float = g.position.x if side == 0 else g.end.x - cap_w
		var cap := Rect2(cx, g.position.y, cap_w, g.size.y)
		_round_rows(cap, p, [1], BRASS_DK)
		var ci := cap.grow(-p)
		draw_rect(ci, BRASS)
		draw_rect(Rect2(ci.position, Vector2(ci.size.x, p)), BRASS_HI)
		draw_rect(Rect2(ci.position.x, ci.end.y - p, ci.size.x, p), BRASS.darkened(0.3))
		draw_rect(Rect2(ci.position.x + (p if side == 0 else 0.0), ci.position.y + p, p, ci.size.y - 2 * p), BRASS_HI if side == 0 else BRASS.darkened(0.3))
		var rv := Vector2(ci.position.x + floorf((ci.size.x - p) * 0.5 / p) * p, ci.position.y + floorf((ci.size.y - p) * 0.5 / p) * p)
		draw_rect(Rect2(rv, Vector2(p, p)), BRASS_DK)
		draw_rect(Rect2(rv - Vector2(0, p * 0.5), Vector2(p * 0.5, p * 0.5)), BRASS_HI)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


## "1284/2150": çubuğun ORTASINDA (madde 474), mevcut değer value_color, "/azami" soluk; koyu kontur dolgunun üstünde de okutur.
func _draw_value(r: Rect2) -> void:
	if text == "":
		_clear_value_layer()
		return
	var cut: int = text.find("/")
	var cur: String = text if cut < 0 else text.substr(0, cut)
	var rest: String = "" if cut < 0 else text.substr(cut)
	if _bar_px.size.x > 0.0:
		_draw_value_screen(cur, rest)
		return
	_clear_value_layer()
	var w_cur: float = VALUE_FONT.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE).x
	var w_rest: float = VALUE_FONT.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE).x
	var p := Vector2(roundf(r.position.x + (r.size.x - w_cur - w_rest) * 0.5), roundf(r.position.y + (r.size.y + VALUE_CAP) * 0.5))
	draw_string_outline(VALUE_FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE, 6, OUTLINE)
	draw_string(VALUE_FONT, p, cur, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE, value_color)
	if rest != "":
		draw_string(VALUE_FONT, p + Vector2(w_cur, 0.0), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, VALUE_FONT_SIZE, VALUE_DIM)


## Ekran pikselinde keskin değer: çubuğun ortasında (yatay + dikey, madde 474), 1 px kontur (8 yön kopya).
## TUZAK (madde 467): yazı draw_set_transform_matrix(global^-1) ile çizilirse Godot glif konumunu düğümün KENDİ (0,92 ölçekli) biriminde
## yuvarlar -> çubuğun hangi piksele düştüğüne göre satırlar kaybolup ikileniyordu (bar_proto'da kalkan değeri bozuk çıktı). Yazı bu yüzden
## ÖLÇEKSİZ, top_level ve tam piksel konumlu ayrı bir çocukta (_ValueLayer) çizilir.
class _ValueLayer extends Control:
	var cur: String = ""
	var rest: String = ""
	var base := Vector2.ZERO ## katmanın içinde taban çizgisi başlangıcı
	var cur_color := Color.WHITE
	var rest_color := Color.WHITE
	var outline := Color.BLACK
	var font: Font = null
	var fs: int = 13
	var w_cur: float = 0.0
	var regen: String = ""
	var cap: float = 7.0 ## rakam yüksekliği (artının dikey ortası)
	var plus_px: float = PLUS_PX ## artı boyu yazı boyuyla büyür (tek sayı: ortası tam piksel)
	var regen_base := Vector2.ZERO
	var regen_color := Color.WHITE
	var style: String = "outline"
	var contour_px: int = 3
	## yumuşak biçim: önce bütün konturlar, sonra dolgular (bir parçanın konturu yanındaki harfin üstüne binmesin)
	func _pass(s: String, p: Vector2, col: Color, contour: bool) -> void:
		if contour:
			draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, contour_px, col)
		else:
			draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	func _draw_styled() -> void:
		var segs: Array = []
		if regen != "":
			segs.append([regen, regen_base, regen_color])
		segs.append([cur, base, cur_color])
		if rest != "":
			segs.append([rest, base + Vector2(w_cur, 0.0), rest_color])
		for sg: Array in segs:
			_pass(sg[0], sg[1], Color(outline, (sg[2] as Color).a), true)
		for sg2: Array in segs:
			_pass(sg2[0], sg2[1], sg2[2], false)
	func _draw() -> void:
		if font == null or cur == "":
			return
		if style != "outline":
			_draw_styled()
			return
		if regen != "":
			## "+" 9 puntoda 3 px'lik noktaya dönüyor -> PLUS_PX'lik artı elle (1 px çizgi, konturlu), rakamların dikey ortasında
			var oc := Color(outline, regen_color.a)
			var num: String = regen.substr(1) if regen.begins_with("+") else regen
			var nb: Vector2 = regen_base + (Vector2(plus_px + 1.0, 0.0) if regen.begins_with("+") else Vector2.ZERO)
			for o: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
				draw_string(font, nb + o, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, oc)
			if regen.begins_with("+"):
				var c := Vector2(regen_base.x + floorf(plus_px * 0.5), regen_base.y - ceilf(cap * 0.5))
				var h := Rect2(regen_base.x, c.y, plus_px, 1.0)
				var v := Rect2(c.x, c.y - floorf(plus_px * 0.5), 1.0, plus_px)
				draw_rect(h.grow(1.0), oc)
				draw_rect(v.grow(1.0), oc)
				draw_rect(h, regen_color)
				draw_rect(v, regen_color)
			draw_string(font, nb, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, regen_color)
		var txt: String = cur + rest
		for o: Vector2 in [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]:
			draw_string(font, base + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline)
		draw_string(font, base, cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cur_color)
		if rest != "":
			draw_string(font, base + Vector2(w_cur, 0.0), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, rest_color)

var _value_layer: _ValueLayer = null


## 9 puntoda 5 px; büyük yazıda oranla, tek sayıya yuvarlı (13 -> 7).
static func _plus_px(fs: int) -> float:
	var v: int = int(round(PLUS_PX * float(fs) / float(VALUE_SCREEN_SIZE)))
	return float(v if v % 2 == 1 else v + 1)


func _clear_value_layer() -> void:
	if _value_layer != null and is_instance_valid(_value_layer) and _value_layer.cur != "":
		_value_layer.cur = ""
		_value_layer.queue_redraw()


## Katman top_level: panel yer değiştirince (yeniden yerleşim, pencere boyu) çubuk yeniden çizilsin ki yazı onu izlesin.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		queue_redraw()


func _draw_value_screen(cur: String, rest: String) -> void:
	var fs: int = value_fs
	var w_cur: float = _text_w(cur, fs) if value_style != "outline" else VALUE_FONT.get_string_size(cur, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w_rest: float = _text_w(rest, fs) if value_style != "outline" else VALUE_FONT.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var b: Rect2 = _bar_px
	var base := Vector2(roundf(b.position.x + (b.size.x - w_cur - w_rest) * 0.5), roundf(b.position.y + (b.size.y + _text_cap(fs)) * 0.5))
	if _value_layer == null or not is_instance_valid(_value_layer):
		_value_layer = _ValueLayer.new()
		_value_layer.name = "ValueLayer"
		_value_layer.top_level = true
		_value_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_value_layer)
	var lay: _ValueLayer = _value_layer
	## katman çubuğun ekran dikdörtgeninde, ölçek 1, tam pikselde (top_level: konum = kanvas konumu)
	lay.position = b.position
	lay.size = b.size
	lay.scale = Vector2.ONE
	lay.cur = cur
	lay.rest = rest
	lay.base = base - b.position
	lay.cur_color = value_color
	lay.rest_color = VALUE_DIM
	lay.outline = OUTLINE
	lay.font = _style_font()
	lay.fs = _style_fs(fs)
	lay.w_cur = w_cur
	lay.style = value_style
	lay.contour_px = SMOOTH_OUTLINE
	## yumuşak font: proje varsayılanı en yakın piksel süzgeci kenarlarını tırtıklıyor -> bu katmanda pürüzsüz süzgeç
	lay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if value_style == "smooth" else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	if value_style != "outline":
		lay.rest_color = VALUE_DIM.lerp(HudTheme.TEXT, 0.5) ## "/azami" bir ton açık (yumuşak yazıda soluk DIM fazla kayboluyordu)
	## yenilenme: sağ kapağın (CAP_ART) 2 sanat px soluna sağa yaslı; ortadaki değere binecekse çizilmez
	lay.regen = ""
	if regen_text != "":
		var num: String = regen_text.substr(1) if regen_text.begins_with("+") else regen_text
		var pp: float = _plus_px(fs)
		var w_reg: float = VALUE_FONT.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + (pp + 1.0 if regen_text.begins_with("+") else 0.0)
		if value_style != "outline": ## yumuşak: artı fontun kendi glifi
			w_reg = _text_w(regen_text, fs)
		var rx: float = roundf(b.end.x - (CAP_ART + 2) * BAR_PX - w_reg)
		if rx > base.x + w_cur + w_rest + 4.0 * BAR_PX:
			lay.regen = regen_text
			lay.regen_base = Vector2(rx, base.y) - b.position
			lay.regen_color = Color(VALUE_DIM, REGEN_ALPHA)
			lay.cap = VALUE_SCREEN_CAP * float(fs) / float(VALUE_SCREEN_SIZE)
			lay.plus_px = pp
	lay.queue_redraw()
