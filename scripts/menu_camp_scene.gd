extends RefCounted

## ANA MENÜ SAHNESİ "Nehir Kenarı Kampı" (2026-11-15, kullanıcı: "Şovalye, Oakley, Hadime, Matthew, Talon ve Elara ana haritanın cozy nehir
## kenarında, hafif loş günbatımı olmak üzere olan havada kamp yapıyor; bazıları oturuyor, iyi vakit geçiriyor; kamp ateşi + birkaç yiyecek.
## Hava hep günbatımı" -> aynı gün denemelerden AY IŞIKLI GECE seçildi, bkz. SKY). Eski "Ocak Başı" (şömine, madde 187/326) yerine; ana menü + menu_hearth_bg.gd (tek/çok oyunculu, oda listesi,
## karakter seçimi, Ruh Mağazası arka planı) aynı sahneyi buradan kurar.
##
## Taban `nehir_kamp.png` = ANA HARİTANIN gerçek çizici yakalaması (320x180 dünya px, tools/proto_20261115/kamp_menu/kamp_capture.gd) + oyunun
## kendi sanatından yer eşyaları (oturma kütüğü, ağaç kütüğü tabure, yastıklar; gen_nehir_kamp.py; yiyecekler 2026-11-15 kalktı). Canlı:
## Night Camp paketinin kamp ateşi (FIRE_*) + ufak eşyalar (PROPS), gerçek SpriteFrames karakterler + uyuyan köpek, Talon'un yanında dikili
## meşale. Hava tonu (SKY) + ateş/meşale ışığı + nehirdeki yansıma kamp_gunbatimi.gdshader'da (ekranın üstünde, okunan ekran dokusu -
## karakterler de aynı ışığı alır); alevler bu katmanın ÜSTÜNDE (kendi ışığı).
## Ölçek: 1 dünya px = MAP_K ekran px; karakter/alev pikseli CHAR_K (oyunda karakter dünyanın yarısı ölçekte; burada biraz büyük, okunur).
## Konumlar dünya px (taban png'si) uzayında; yer eşyaları gen_nehir_kamp.py'de (FIRE_FOOT/PARTY oradaki yorumla aynı yerler).

const SCREEN := Vector2(1920, 1080)
## 2026-11-16 UZAKLAŞTIRMA (kullanıcı: "sahneyi azcık uzaklaştır"): harita x6 -> x5 (kadraj 320x180 -> 384x216 dünya px, sol üst (34, 26) px
## geride; bütün dünya px konumları bu kadar kaydırıldı - kamp ekranda aynı yerde), karakter/ateş/eşya x4 -> x3, ışık yarıçapları x5/6.
## (Aynı gün bir kademe daha - x4 / x2, 480x270 - denendi; kullanıcı "öncekine dön" dedi: x5 / x3 kaldı.)
const MAP_K := 5.0
const CHAR_K := 3.0
const BG_PATH := "res://assets/ui/ana_menu/nehir_kamp.png"
const WATER_PATH := "res://assets/ui/ana_menu/nehir_kamp_su.png"
const SHADER_PATH := "res://shaders/kamp_gunbatimi.gdshader"
## NEHİR = OYUNUN SUYU (2026-11-16, kullanıcı: "ana menüdeki su shaderı normal ana haritadaki su shaderı gibi değil"): taban dalgacıklar
## KAPALIYKEN yakalandı; dalgacıkları kamp_su.gdshader tabanın üstünde canlı çizer - oyunun su.gdshader'ıyla aynı kod
## (shaders/su_dalgacik.gdshaderinc), aynı kıyı/akış dokuları (water_fx.gd), aynı dünya pikseli. WORLD_ORIGIN = nehir_kamp.png (0, 0)
## pikselinin ana haritadaki dünya pikseli (kamp_capture.gd "ORIGIN"; kadraj değişirse ikisi birlikte), HARITA_OFFSET = main.tscn'de
## Harita'nın konumu (water_fx.attach doku_origin'i bununla kaydırır). Dalgacıklar oyundaki gibi "Zemin ayrıntısı" ayarına bağlı.
const WaterFx := preload("res://scripts/water_fx.gd")
const WATER_SHADER_PATH := "res://shaders/kamp_su.gdshader"
const WORLD_ORIGIN := Vector2(2062, 1692)
const HARITA_OFFSET := Vector2(-2, 21)
## Nehrin animasyonlu kıyı / akıntı karoları (haritanın "Su ayrıntılar 2/3/4" katmanları: kıyı köpüğü, akıntı çizgileri, nilüfer; 2026-11-16,
## kullanıcı: "haritada nehirde normalde akıntı sprite'ları vardı, burda neden yok?"): yakalamada tek kareye donuyordu. Harita (sallanma
## kapalı) 50 ms arayla örneklendi, nehir bölgesinde döngü bulundu (72 örnek = 3,6 sn; karolar 120 ms adımla döner) ve yalnız döngüde
## DEĞİŞEN pikseller şeride girdi (gen_nehir_kamp.py akinti_serit) -> önü kapalı yerler örtülü kalır. 12 sütunlu ızgara, tabanın hemen
## üstünde, karakterlerin altında 50 ms'de oynar (gece ışığını alır).
const AKINTI_PATH := "res://assets/ui/ana_menu/nehir_kamp_akinti.png"
const AKINTI_FRAMES := 72
## 20 fps = haritadaki hız; menüde idle'lar gibi YAVAŞ (kullanıcı 2026-11-16: "harita çok hızlı kaldı diğerlerine göre, haritanın sprite'ları
## da yavaş olsun") - dalgacıklar da aynı oranda (kamp_su.gdshader zaman_olcek).
const AKINTI_FPS := 20.0 * IDLE_SLOW
const AKINTI_COLS := 12
## SALLANAN BİTKİLER (2026-11-16, kullanıcı: "ağaçlar ve çalılar sallanmıyor, sallanmalıydı ama yavaşça"): taban (BG_PATH) artık BİTKİSİZ zemin;
## oyunda sallanan ağaç / çalı / çiçek pikselleri ayrı doku, kamp_bitki.gdshader kökünden sallar (oyunun ağaç eğrisi). Akıntının üstünde,
## karakterlerin altında (gece ışığını alır). Üretim: kamp_capture.gd KAMP_ZEMIN=1 + gen_nehir_kamp.py bitki_katmani. Hız oyundakinin
## (0,9 rad/sn) 0,6 katı - menüdeki her şey gibi yavaş.
const BITKI_PATH := "res://assets/ui/ana_menu/nehir_kamp_bitki.png"
const BITKI_VERI_PATH := "res://assets/ui/ana_menu/nehir_kamp_bitki_veri.png"
const BITKI_SHADER_PATH := "res://shaders/kamp_bitki.gdshader"
const BITKI_HIZ := 0.9 * 0.6
## KAMP ATEŞİ: Craftpix Night Camp paketinin ateşi (kullanıcı 2026-11-15: "bu attığım arşivde kamp ateşi var, bununla değiştir, ekrandaki kamp
## ateşini sevmedim"; eski kazansız çukur kalktı). 6 kare x 48x80, karakter pikseli ölçeğinde (x CHAR_K - paketin karakter/ateş oranı; x MAP_K'da
## alev Talon'un ~2,5 katı). gece_kamp_atesi.png ortam ışığını alır (taşlar), gece_kamp_atesi_alev.png (yalnız alev + yarı saydam parıltısı)
## ışık katmanının ÜSTÜNDE aynı karede (SheetAnim ortak saat). gen_kamp_kareler.py gece_ates.
const FIRE_PATH := "res://assets/ui/ana_menu/gece_kamp_atesi.png"
const FIRE_FLAME_PATH := "res://assets/ui/ana_menu/gece_kamp_atesi_alev.png"
const FIRE_FRAME := Vector2(48, 80)
const FIRE_FRAMES := 6
const FIRE_FPS := 1000.0 / 120.0
const FIRE_FOOT := Vector2(204, 167) ## taş halkanın alt ortası (dünya px)
const FIRE_BASE_AT := Vector2(22.5, 70.0) ## karede halkanın alt ortası (karakter px)
## Taban ışık katmanının ÜSTÜNDE kendi shader'ıyla (paket taşları zaten ateş ışığıyla boyamış; katmanın altında ikinci kez aydınlanıp düz
## pembe lekeye dönüyordu - kullanıcı: "kamp ateşinin neden gölgesi yok, ışığa duyarlı"). Altında yönsüz temas gölgesi (AO): taş halkanın
## çevresinde iki DÜZ alfa bandı, ışık katmanının altında (zemin gibi aydınlanır). Merkez/yarıçaplar karede karakter px.
const FIRE_BASE_SHADER_PATH := "res://shaders/kamp_ates_taban.gdshader"
const FIRE_SHADOW_CENTER := Vector2(21.5, 57.0)
const FIRE_SHADOW_BANDS := [[Vector2(23.0, 14.0), 0.16], [Vector2(21.0, 12.5), 0.22]]
## Ufak tefek eşyalar (aynı paket, minimal: kullanıcı "çanta, kılıç falan da var, ufak tefek ayrıntı ekleyebilirsin minimal düzeyde"):
## [doku, ayak ortası (dünya px)], x CHAR_K. Kılıç kütüğün sol ucuna yaslı (Şovalye'nin), çanta kütüğün sağ ucunda, kese Hadime'nin yanında.
const PROPS := [
	["res://assets/ui/ana_menu/kamp_esya_kilic.png", Vector2(178, 133)],
	["res://assets/ui/ana_menu/kamp_esya_canta.png", Vector2(233, 135)],
	["res://assets/ui/ana_menu/kamp_esya_kese.png", Vector2(163, 187)],
]
const LIGHT_POS := Vector2(204, 149) ## ateş ışığının merkezi (dünya px) - alevlerin yüksekliğinde (halkanın üstünde olunca taşlar krem rengine açılıyordu)
## HAVA: AY IŞIKLI "COZY" GECE (2026-11-15, kullanıcı gece / gündüz denemelerinden geceyi seçti -> "çok karanlık, ay ışığı hissiyatı olmalı"
## -> "ışıklandırmayı beğenmedim, daha cozy yap ortam hissini"). kamp_gunbatimi.gdshader'ın varsayılanları günbatımıdır; bu değerler onları
## ezer (boş sözlük = günbatımına dönüş). Ortam ay ışığında mavi (renkler az solar, desat 0,25), ay tarafı (sun_uv, sağ üst) hafif parlak;
## ateş kehribar (özü sarıya kaçmaz - ilk cozy denemede özü/havadaki parıltı kazanı süt gibi örtüyordu), çok geniş zayıf ikinci ışık
## (fire_wide_*) sahneyi ateşin sıcaklığına sarar, havada hafif sıcak parıltı, nehirde ateş yansıması, kenar karartması kampa odaklı;
## ayrıca ateş böcekleri (Fireflies). Deneme tablosu: tools/proto_20261115/kamp_menu/menu_capture.gd HAVA ("ay2" = bu; "sicak", "mor" alternatif).
const SKY := {
	"dusk_color": Color(0.40, 0.48, 0.70), "gold_color": Color(0.58, 0.66, 0.88), "desat": 0.25, "dim": 0.66, "vignette": 0.38,
	"vignette_center": Vector2(0.56, 0.62), "warm_glow": Color(0.04, 0.06, 0.10), "haze_color": Color(0.02, 0.03, 0.06),
	## ateş ışığı biraz KIRMIZIYA çekildi (2026-11-16, kullanıcı: "ışıklandırmalar çok sarımtırak, çok az ateş kırmızısı tonlarına yakınlaşabilir";
	## önce (1, 0.44, 0.18) / öz (1, 0.64, 0.34)) - kamp ateşi + meşale aynı renkleri kullanır
	"fire_color": Color(1.0, 0.38, 0.15), "fire_core": Color(1.0, 0.55, 0.28), "fire_strength": 0.8, "fire_lum": 0.4,
	"fire_radius": 467.0, "fire_falloff": 1.25, "fire_halo": 0.05,
	"fire_wide_radius": 1000.0, "fire_wide_strength": 0.22, "fire_bloom": 0.09, "fire_bloom_radius": 117.0, "water_fire": 0.5,
	"water_tint": Color(0.58, 0.68, 0.95), "sky_far": Color(0.18, 0.24, 0.40), "sky_near": Color(0.42, 0.52, 0.78),
	"sky_amount": 1.0,
}
## Ateş böcekleri (gece ortamı, Fireflies): sayı; 0 = yok.
const FIREFLY_COUNT := 12
## İdle'lar menüde oyundakinden YAVAŞ (kullanıcı: "idle animasyonları çok hızlı, baya yavaşlaması gerekiyor"): klibin kendi hızı x IDLE_SLOW.
## Talon'un idle şeridi, oturanların idle ritmi ve Oakley'nin ısırık arası idle'ı bunu kullanır (eat_ ısırığı kendi hızında).
const IDLE_SLOW := 0.35
## [karakter id, klip, ayak ortası (dünya px)] - sit_ son kare sabit (belden yukarısı kendi idle ritmiyle), read_ yavaş döngü (ilk kare =
## kitabı kaldırma, atlanır), eat_ bir kez oynar, aralarda kendi idle_'i; "res://..." = elle düzenlenmiş kare/şerit (tools/proto_20261115/kamp_menu/gen_kamp_kareler.py).
## Kuzeydeki kütüğün ÜSTÜNDE Şovalye + Matthew (bize dönük; Matthew'in elindeki tavuk budu 2026-11-16 kalktı), batıda yastıkta Büyücü Kız, doğuda ağaç kütüğü
## taburede Elara, güneybatıda Hadime yerde geriye yaslanmış bacaklarını uzatmış, güneydoğuda (eski yiyecek örtüsünün yerinde) ayakta
## Oakley ateşe dönük kitap okuyor (oturma klibi yok); Talon kampın kuzeyinde nehir kıyısında AYAKTA nehre dönük, oltası yumruğunda balık tutuyor (talon_olta.png = kendi idle_left'i
## + kol, FISHING); köpek kütüğün önünde Matthew'in solunda (bize göre) ateşe dönük
## uyuyor. Kütükte/taburede oturanların ayağı kütüğün alt kenarının hemen üstünde (taban png'sindeki kütük onların arkasında kalır).
## PARTY sırası ana menünün alt yüz şeridinin sırası.
const PARTY := [
	[7, "sit_down", Vector2(191, 131)],
	[3, "sit_down", Vector2(220.4, 131)], ## yemekli karenin dolu alanı budla sola genişti (orta x 20 -> 24): aynı yerde kalsın diye +2,4
	[4, "sit_right", Vector2(173, 162)],
	[8, "sit_left", Vector2(240, 160)],
	[14, "res://assets/ui/ana_menu/hadime_uzanik.png", Vector2(178, 184)],
	[2, "read_left", Vector2(244, 192)],
	[1, "res://assets/ui/ana_menu/talon_olta.png", Vector2(211, 76)],
]
## Talon'un oltası (2026-11-16, kullanıcı: "şu anki koyduğun olta AI; arşivdeki oltayı çıkarıp ipini suyun içine uzanacak şekilde düzeltip
## Talon'un eline ver"): Craftpix Fishing Game Icons Icon37 kamışı (talon_olta_kamis.png, ikonun sarkan ip döngüsü silinmiş, yatay çevrik;
## gen_kamp_kareler.py paket_olta) karakter pikseli ölçeğinde (x CHAR_K), tutma noktası (ROD_GRIP, dokuda köşe koordinatı) yumrukta
## (TALON_FIST = talon_olta.png karesinde yumruğun ortası, köşe koordinatı; gen_kamp_kareler.py TALON_KOL). Talon'dan ÖNCE çizilir: kamış
## yumruğun arkasından geçer, dip ucu gövdenin arkasında kalır. İp ROD_TIP pikselinden suya (FISHING "giris", dünya px) ikonun KENDİ ip
## renkleriyle iner, girişte birkaç piksel suyun içinde sönerek devam eder; girişte ara ara halka açılır.
const ROD_TEX_PATH := "res://assets/ui/ana_menu/talon_olta_kamis.png"
const TALON_FIST := Vector2(17, 28)
const ROD_GRIP := Vector2(24, 25)
const ROD_TIP := Vector2(8, 1) ## kamış ucu pikseli (dokuda)
## DİKİLİ MEŞALE (kullanıcı: önce "Talon'un elinde bir meşale olsun"; elde tutma denemeleri olmadı -> "yanına meşale ekle; elle taşınan kutu
## gibi meşaleler var ya, onları yere bırakmış olsun" -> Şifa Feneri ikonu konuldu -> "bu şifa fenerinin ikonu, bunu kullanamazsın"; oyunun
## dünya sanatında taşınan kutu fener YOK): Ayaz Dağı'nın kendi dikili meşalesi Talon'un sağında yere dikili, yarım boy (5x28) dünya ölçeğinde
## (x MAP_K, kütükle aynı piksel; gen_kamp_kareler.py dikili_mesale). Alevi kendi 6 karesiyle (150 ms) ışık katmanının ÜSTÜNDE; ışığı
## shader'da (lamp_*), merkezi alevin ortası.
const MESALE_BODY_PATH := "res://assets/ui/ana_menu/mesale_govde.png"
const MESALE_FLAME_PATH := "res://assets/ui/ana_menu/mesale_alev.png"
const MESALE_FOOT := Vector2(223, 79) ## dünya px (alt orta)
const MESALE_FRAME := Vector2(5, 28)
const MESALE_FLAME_AT := 22.0 ## alevin ortası: dibinden bu kadar dünya px yukarıda
const MESALE_LIGHT := {"lamp_radius": 233.0, "lamp_strength": 0.95, "lamp_bloom": 0.10}
const FISHING := {"giris": Vector2(186.0, 66.0)} ## ipin suya girdiği nokta (dünya px)
## Köpek (2026-11-16, kullanıcı: "köpeği kamp ateşine, Matthew'in soluna (benim bakış açımın solu) yaklaştır"): kütüğün önünde, Matthew'in
## solunda, başı (soldaki) ateşe dönük; alev sütunu (x ~202-207 bu yükseklikte) ile çakışmasın diye solu x ~208'de biter.
const DOG := ["kopek", "sleep_down", Vector2(215, 138)]


## Tam ekran sahne (SCREEN boyutunda `stage` içine): taban + canlı parçalar + günbatımı katmanı + alev.
static func build(stage: Control) -> void:
	var bg := TextureRect.new()
	bg.name = "SceneBg"
	bg.texture = load(BG_PATH)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var su := ShaderMaterial.new()
	su.shader = load(WATER_SHADER_PATH)
	su.set_shader_parameter("su_mesafe", load(WaterFx.MESAFE_TEX))
	su.set_shader_parameter("su_akis", load(WaterFx.AKIS_TEX))
	su.set_shader_parameter("doku_origin", WaterFx.TEX_ORIGIN + HARITA_OFFSET)
	su.set_shader_parameter("doku_size", WaterFx.TEX_WORLD_SIZE)
	su.set_shader_parameter("dunya_origin", WORLD_ORIGIN)
	su.set_shader_parameter("dunya_size", SCREEN / MAP_K)
	su.set_shader_parameter("dalgacik_acik", UISound.gfx_ground_detail)
	su.set_shader_parameter("zaman_olcek", IDLE_SLOW)
	bg.material = su
	stage.add_child(bg)
	bg.position = Vector2.ZERO
	bg.size = SCREEN
	var akinti := SheetAnim.new(load(AKINTI_PATH), SCREEN / MAP_K, AKINTI_FRAMES, AKINTI_FPS, MAP_K, AKINTI_COLS)
	akinti.name = "NehirAkinti"
	stage.add_child(akinti)
	akinti.position = Vector2.ZERO
	var bitki := TextureRect.new()
	bitki.name = "Bitkiler"
	bitki.texture = load(BITKI_PATH)
	bitki.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bitki.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bitki.stretch_mode = TextureRect.STRETCH_SCALE
	bitki.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bmat := ShaderMaterial.new()
	bmat.shader = load(BITKI_SHADER_PATH)
	bmat.set_shader_parameter("veri", load(BITKI_VERI_PATH))
	bmat.set_shader_parameter("dunya_size", SCREEN / MAP_K)
	bmat.set_shader_parameter("hiz", BITKI_HIZ)
	bitki.material = bmat
	stage.add_child(bitki)
	bitki.position = Vector2.ZERO
	bitki.size = SCREEN
	## y-sıralı canlı parçalar: [ayak y, düğüm]
	var items: Array = []
	var mesale := GroundProp.new(load(MESALE_BODY_PATH), MAP_K)
	mesale.position = ((MESALE_FOOT - Vector2(MESALE_FRAME.x * 0.5, MESALE_FRAME.y)).floor()) * MAP_K
	items.append([MESALE_FOOT.y, mesale])
	var fire := SheetAnim.new(load(FIRE_PATH), FIRE_FRAME, FIRE_FRAMES, FIRE_FPS, CHAR_K)
	fire.name = "CampFireBase"
	fire.position = (FIRE_FOOT * MAP_K - FIRE_BASE_AT * CHAR_K).floor()
	var fire_mat := ShaderMaterial.new()
	fire_mat.shader = load(FIRE_BASE_SHADER_PATH)
	fire.material = fire_mat
	var fire_shadow := FireContactShadow.new(FIRE_SHADOW_CENTER, FIRE_SHADOW_BANDS, CHAR_K)
	fire_shadow.position = fire.position
	items.append([FIRE_FOOT.y, fire_shadow])
	for pr: Array in PROPS:
		var ptex: Texture2D = load(str(pr[0]))
		var prop := GroundProp.new(ptex, CHAR_K)
		prop.position = ((pr[1] as Vector2) * MAP_K - Vector2(ptex.get_width() * CHAR_K * 0.5, ptex.get_height() * CHAR_K)).floor()
		items.append([(pr[1] as Vector2).y, prop])
	var pet_spec: Array = load("res://scripts/pet_catalog.gd").FRAMES.get(DOG[0], [])
	if not pet_spec.is_empty():
		var dog := CampSprite.new(load(str(pet_spec[0])) as SpriteFrames, str(DOG[1]), CHAR_K)
		dog.place_at(DOG[2] * MAP_K)
		items.append([(DOG[2] as Vector2).y, dog])
	for i in range(PARTY.size()):
		var p: Array = PARTY[i]
		var sf := load(str(Characters.get_def(int(p[0])).get("frames", ""))) as SpriteFrames
		if sf == null:
			continue
		var s := CampSprite.new(sf, str(p[1]), CHAR_K, 4.0 / (4.0 * IDLE_SLOW), i * 0.83) ## yeme arası = bir tam yavaş idle döngüsü
		s.place_at((p[2] as Vector2) * MAP_K)
		items.append([(p[2] as Vector2).y, s])
		if int(p[0]) == 1: ## Talon: olta yumruğundan başlar, kendisinden önce çizilir (kamış yumruğun arkasında)
			var rod := FishingRod.new(load(ROD_TEX_PATH) as Texture2D, s.position + (TALON_FIST - ROD_GRIP) * CHAR_K, ROD_TIP,
					FISHING["giris"] * MAP_K, CHAR_K)
			items.append([(p[2] as Vector2).y - 0.1, rod])
	items.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for it: Array in items:
		stage.add_child(it[1])
	var grade := ColorRect.new()
	grade.name = "SunsetGrade"
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("water_mask", load(WATER_PATH))
	mat.set_shader_parameter("stage_size", SCREEN)
	mat.set_shader_parameter("world_size", SCREEN / MAP_K)
	mat.set_shader_parameter("fire_pos", LIGHT_POS * MAP_K)
	for key: String in SKY:
		mat.set_shader_parameter(key, SKY[key])
	mat.set_shader_parameter("lamp_pos", (MESALE_FOOT - Vector2(0, MESALE_FLAME_AT)) * MAP_K)
	for key: String in MESALE_LIGHT:
		mat.set_shader_parameter(key, MESALE_LIGHT[key])
	grade.material = mat
	stage.add_child(grade)
	grade.position = Vector2.ZERO
	grade.size = SCREEN
	stage.add_child(fire) ## taban ışık katmanının üstünde (kendi shader'ı), alev onun da üstünde
	var flame := SheetAnim.new(load(FIRE_FLAME_PATH), FIRE_FRAME, FIRE_FRAMES, FIRE_FPS, CHAR_K)
	flame.name = "CampFlame"
	flame.position = fire.position
	stage.add_child(flame)
	var mflame := SheetAnim.new(load(MESALE_FLAME_PATH), MESALE_FRAME, 6, 1000.0 / 150.0, MAP_K)
	mflame.name = "MesaleAlev"
	mflame.position = mesale.position
	stage.add_child(mflame)
	if FIREFLY_COUNT > 0:
		var ff := Fireflies.new(FIREFLY_COUNT, MAP_K)
		ff.name = "Fireflies"
		stage.add_child(ff)
		ff.position = Vector2.ZERO
		ff.size = SCREEN


## Kareli sayfayı sırayla oynatan piksel-tam çizim: yatay şerit (cols = 0) ya da cols sütunlu ızgara (soldan sağa, yukarıdan aşağı).
class SheetAnim extends Control:
	var tex: Texture2D = null
	var frame_size: Vector2 = Vector2.ZERO
	var count: int = 1
	var fps: float = 8.0
	var k: float = 4.0
	var cols: int = 0

	func _init(t: Texture2D, fsz: Vector2, n: int, speed: float, scale_k: float, grid_cols: int = 0) -> void:
		tex = t
		frame_size = fsz
		count = n
		fps = speed
		k = scale_k
		cols = grid_cols
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size = fsz * scale_k

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var i: int = int(Time.get_ticks_msec() * 0.001 * fps) % count ## ortak saat: ateş + alev şeridi aynı karede
		var cell := Vector2(i, 0) if cols <= 0 else Vector2(i % cols, i / cols)
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, frame_size * k), Rect2(cell * frame_size, frame_size))


## Gerçek SpriteFrames klibi; ayak ortası place_at(ekran px) noktasına oturur, altında küçük piksel gölge.
## sit_ = oturma HAREKETİ (kare 0 ayakta -> son kare oturmuş): son kare sabit. read_: kitabı kaldırma karesi atlanır, sayfa kareleri yavaş
## döngü. eat_: klip bir kez oynar, aralarda karakterin KENDİ
## idle_ klibi (aynı yön) döner. "res://..." = elle düzenlenmiş doku: kare (48x48) ya da yatay şerit (Nx48, kendi idle hızında döner).
## CANLILIK (kullanıcı 2026-11-15: "karakterler donuk, idle'ları yok" -> "kendi idle'larını kullan, kafaları tuhaf sallanıyor, konuşma
## efekti gerekmez"): oturan/sabit karede duranların oturma idle'ı yok; belden yukarısı karakterin KENDİ idle_ klibinin ritmini birebir
## izler (idle karelerinin tepe satırı kayması, klibin hızı x IDLE_SLOW, kişiye göre faz) AMA yalnız aşağı (1 px omuz düşüşü): idle'ın 1 px
## yukarı uzaması menüde x4 büyüklükte "gereksiz uzama" gibi görünüyordu (kullanıcı) -> uzama karesi/adımı her yerde atlanır. Gülme yok.
class CampSprite extends Control:
	var frames: SpriteFrames = null
	var tex: Texture2D = null ## elle düzenlenmiş kare/şerit (frames yerine çizilir; ritim yine frames'in idle'ından)
	var anim: StringName = &"idle_down"
	var idle_anim: StringName = &"idle_down"
	var k: float = 4.0
	var hold: int = -1
	var rest: float = 0.0
	var strip_n: int = 1
	var strip_fps: float = 4.0
	var _t: float = 0.0
	var _used: Rect2i = Rect2i()
	var _fsize: Vector2 = Vector2.ZERO
	var _rhythm: PackedInt32Array = PackedInt32Array() ## idle karelerinin tepe kayması (karakter px)
	var _rhythm_fps: float = 4.0
	var _idle_frames: PackedInt32Array = PackedInt32Array() ## idle_ kareleri, uzama karesi (tepe satırı yukarı çıkan) hariç
	var _loop_frames: PackedInt32Array = PackedInt32Array() ## read_: döngüde oynayan kareler (kitabı kaldırma karesi hariç)
	var _loop_fps: float = 1.4

	func _init(sf: SpriteFrames, clip: String, scale_k: float, rest_sec: float = 0.0, phase: float = 0.0) -> void:
		frames = sf
		k = scale_k
		_t = phase
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if sf == null:
			return
		var dir: String = "down"
		for d: String in ["down", "left", "right", "up"]:
			if clip.ends_with("_" + d) or clip.ends_with("_" + d + ".png"):
				dir = d
		idle_anim = StringName("idle_" + dir) if sf.has_animation("idle_" + dir) else &"idle_down"
		if clip.begins_with("res://"):
			tex = load(clip) as Texture2D
			if tex == null:
				return
			var img: Image = tex.get_image()
			strip_n = maxi(1, img.get_width() / maxi(1, img.get_height()))
			strip_fps = sf.get_animation_speed(idle_anim) * IDLE_SLOW
			if strip_n == 1:
				hold = 0
				_learn_rhythm()
			_measure(img.get_region(Rect2i(0, 0, img.get_height(), img.get_height())))
			return
		anim = StringName(clip) if sf.has_animation(clip) else &"idle_down"
		if String(anim).begins_with("sit_"):
			hold = frames.get_frame_count(anim) - 1
			_learn_rhythm()
		elif String(anim).begins_with("read_"):
			## okuma: ilk kare kitabı kaldırma (1 px uzun), sonrası sayfa çevirme -> yalnız 1.. kareler, idle gibi YAVAŞ döngü
			var rn: int = frames.get_frame_count(anim)
			for i in range(1 if rn > 2 else 0, rn):
				_loop_frames.append(i)
			_loop_fps = frames.get_animation_speed(anim) * IDLE_SLOW
		elif String(anim).begins_with("eat_"):
			rest = rest_sec
			_learn_rhythm()
			_rhythm.clear() ## ayakta: ritim değil, idle karelerinin kendisi (_idle_frames) oynar
		_measure(frames.get_frame_texture(anim, _loop_frames[0] if not _loop_frames.is_empty() else maxi(hold, 0)).get_image())

	func _learn_rhythm() -> void:
		var n: int = frames.get_frame_count(idle_anim)
		if n < 2:
			return
		_rhythm_fps = frames.get_animation_speed(idle_anim) * IDLE_SLOW
		var top0: int = -1
		for i in range(n):
			var im: Image = frames.get_frame_texture(idle_anim, i).get_image()
			if im.is_compressed():
				im.decompress()
			var top: int = im.get_used_rect().position.y
			if top0 < 0:
				top0 = top
			_rhythm.append(clampi(top - top0, 0, 1)) ## yukarı UZAMA yok (menüde x4 büyük, "gereksiz uzuyor"): yalnız 1 px omuz düşüşü
			if top >= top0:
				_idle_frames.append(i)

	func _measure(img: Image) -> void:
		if img.is_compressed():
			img.decompress()
		_used = img.get_used_rect()
		_fsize = Vector2(img.get_width(), img.get_height())
		size = _fsize * k

	## foot: ayak ortası (ekran px); karakter pikseli ızgarasına oturur.
	func place_at(foot: Vector2) -> void:
		position = (foot - Vector2(_used.position.x + _used.size.x * 0.5, _used.end.y) * k).floor()

	func _ready() -> void:
		set_process(hold < 0 or not _rhythm.is_empty())

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	## Bu an çizilecek [klip, kare] (frames yolu).
	func _pick() -> Array:
		if hold >= 0:
			return [anim, hold]
		if not _loop_frames.is_empty():
			return [anim, _loop_frames[int(_t * _loop_fps) % _loop_frames.size()]]
		var n: int = maxi(1, frames.get_frame_count(anim))
		var spd: float = maxf(1.0, frames.get_animation_speed(anim))
		if rest <= 0.0:
			if String(anim).begins_with("sleep_"): ## uyuyan köpeğin nefesi idle'lar gibi yavaş (kullanıcı 2026-11-16: "köpeğin nefes alması çok hızlı")
				spd *= IDLE_SLOW
			return [anim, int(_t * spd) % n]
		var play: float = n / spd
		var ph: float = fmod(_t, play + rest)
		if ph < play:
			return [anim, mini(int(ph * spd), n - 1)]
		if _idle_frames.is_empty():
			return [anim, 0]
		var j: int = int((ph - play) * frames.get_animation_speed(idle_anim) * IDLE_SLOW) % _idle_frames.size()
		return [idle_anim, _idle_frames[j]]

	func _draw() -> void:
		if frames == null:
			return
		var sw: float = maxf(12.0, _used.size.x * 0.7)
		var cx: float = _used.position.x + _used.size.x * 0.5
		draw_rect(Rect2((cx - sw * 0.5) * k, (_used.end.y - 1) * k, sw * k, 2 * k), Color(0, 0, 0, 0.28))
		var dst := Rect2(Vector2.ZERO, _fsize * k)
		if tex != null and strip_n > 1:
			var fi: int = int(_t * strip_fps) % strip_n
			draw_texture_rect_region(tex, dst, Rect2(fi * _fsize.x, 0, _fsize.x, _fsize.y))
			return
		var t: Texture2D = tex
		if t == null:
			var pk: Array = _pick()
			t = frames.get_frame_texture(pk[0], pk[1])
		var off: int = 0 if _rhythm.is_empty() else _rhythm[int(_t * _rhythm_fps) % _rhythm.size()]
		if off == 0:
			draw_texture_rect(t, dst, false)
			return
		## belden yukarısı (`_used` yüksekliğinin ortası) idle ritmiyle 1 px kayar; yukarı kayınca bel satırı yerinde bir kez daha (boşluk olmasın)
		var split: int = _used.position.y + int(_used.size.y * 0.5)
		var w: float = _fsize.x
		draw_texture_rect_region(t, Rect2(0, split * k, w * k, (_fsize.y - split) * k), Rect2(0, split, w, _fsize.y - split))
		if off < 0:
			draw_texture_rect_region(t, Rect2(0, (split - 1) * k, w * k, k), Rect2(0, split - 1, w, 1))
		draw_texture_rect_region(t, Rect2(0, off * k, w * k, split * k), Rect2(0, 0, w, split))


## Balık tutan Talon'un oltası: paketin kamış dokusu (x px) yumrukta; ip kamış ucundan suya hafif sarkarak, ikonun kendi ip renkleriyle
## (uçlarda koyu lacivert, ortada ikonun parlak tonu); suya girdikten sonra iki piksel sönerek devam eder (suyun içinde); ara ara balık
## dokunur (giriş 1 piksel seğirir) ve girişte genişleyip sönen halka açılır. Hepsi `px` (karakter pikseli) ızgarasında dolu kareler.
class FishingRod extends Control:
	## Icon37'nin ip renkleri (sarkan döngü: uçlarda c, ortada i)
	const LINE_DARK := Color8(4, 8, 20)
	const LINE_MID := Color8(17, 21, 32)
	const LINE_LIGHT := Color8(22, 26, 36)
	const RIPPLE := Color(0.80, 0.90, 1.0)
	var tex: Texture2D
	var origin: Vector2
	var tip: Vector2
	var entry: Vector2
	var px: float = 4.0
	var _t: float = 0.0

	## o = dokunun ekrandaki sol üstü, tip_px = kamış ucu pikseli (dokuda), e = ipin suya girişi (ekran px)
	func _init(t: Texture2D, o: Vector2, tip_px: Vector2, e: Vector2, pixel: float) -> void:
		tex = t
		origin = o
		px = pixel
		tip = o + (tip_px + Vector2(0.5, 0.5)) * pixel ## ip uç pikselinden çıkar (kamış üstte çizilir)
		entry = e
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _cell(p: Vector2) -> Vector2:
		return origin + ((p - origin) / px).floor() * px ## kamış dokusunun piksel ızgarası

	## a -> b arası piksel çizgi hücreleri (sıralı, tekrarsız); sag > 0: ortası aşağı sarkar.
	func _cells(a: Vector2, b: Vector2, sag: float = 0.0) -> Array[Vector2]:
		var out: Array[Vector2] = []
		var n: int = maxi(1, int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y)) / px)))
		for i in range(n + 1):
			var f: float = float(i) / n
			var c: Vector2 = _cell(a.lerp(b, f) + Vector2(0, sag * 4.0 * f * (1.0 - f)))
			if out.is_empty() or out[-1] != c:
				out.append(c)
		return out

	func _draw() -> void:
		## ara sıra balık dokunur: ipin suya girdiği yer kısa bir an 1 piksel aşağı seğirir (3,7 sn'de bir)
		var twitch: bool = fmod(_t, 3.7) < 0.3
		var e: Vector2 = entry + Vector2(0, px if twitch else 0.0)
		## halka: 2,4 sn'de bir girişten açılır (yatay elips, piksel noktalar)
		var ph: float = fmod(_t, 2.4) / 2.4
		if ph < 0.6:
			var r: float = 2.0 + ph / 0.6 * 5.0
			var a: float = 0.45 * (1.0 - ph / 0.6)
			for i in range(16):
				var ang: float = TAU * i / 16.0
				var c: Vector2 = _cell(e + Vector2(cos(ang) * r * px, sin(ang) * r * px * 0.45 + px))
				draw_rect(Rect2(c, Vector2(px, px)), Color(RIPPLE, a))
		## ip: uçtan girişe; ikondaki sarkan ip gibi uçlarda koyu, ortada açık ton
		var cells := _cells(tip, e, px * 1.5)
		for i in range(cells.size()):
			var f: float = float(i) / maxf(1.0, cells.size() - 1.0)
			var m: float = 1.0 - absf(f - 0.5) * 2.0 ## 0 uçlarda, 1 ortada
			var col: Color = LINE_LIGHT if m > 0.6 else (LINE_MID if m > 0.3 else LINE_DARK)
			draw_rect(Rect2(cells[i], Vector2(px, px)), col)
		## suyun içi: aynı yönde iki piksel daha, sönerek
		var dir: Vector2 = (e - tip).normalized()
		for j in range(1, 3):
			var c: Vector2 = _cell(e + dir * px * j * 1.2)
			if c != cells[-1]:
				draw_rect(Rect2(c, Vector2(px, px)), Color(LINE_MID, 0.55 - 0.2 * j))
		draw_texture_rect(tex, Rect2(origin, tex.get_size() * px), false)

## Ateş böcekleri (gece, "cozy" ortam): karakter pikseli ızgarasında küçük açık öz + üç DÜZ alfa bandı sarı-yeşil hale (benek/titreşim yok),
## yavaşça süzülür ve yavaşça yanıp söner; ışık katmanının ÜSTÜNDE (kendi ışığı), toplamalı karışım. Kamp ateşinin çevresine (ışıkta
## kaybolur) ve sol menünün gölgesine konmaz. Konumlar sabit tohumla (her açılışta aynı yerleşim).
class Fireflies extends Control:
	const CELL := 3.0 ## karakter pikseli (ekran px) = CHAR_K
	const GLOW_N := 15 ## hale dokusu hücre sayısı (merkez 7)
	var _flies: Array[Dictionary] = []
	var _glow: ImageTexture = null
	var _t: float = 0.0

	func _init(count: int, map_k: float) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = m
		_glow = _make_glow()
		var rng := RandomNumberGenerator.new()
		rng.seed = 1115
		var tries: int = 0
		while _flies.size() < count and tries < 500:
			tries += 1
			var w := Vector2(rng.randf_range(150.0, 382.0), rng.randf_range(8.0, 212.0)) ## dünya px (sol menü gölgesi dışında)
			if ((w - Vector2(206.0, 154.0)) / Vector2(50.0, 37.0)).length() < 1.0:
				continue
			_flies.append({
				"pos": w * map_k, "ax": rng.randf_range(4.0, 11.0) * map_k, "ay": rng.randf_range(3.0, 8.0) * map_k,
				"sx": rng.randf_range(0.04, 0.09), "sy": rng.randf_range(0.05, 0.11), "ph": rng.randf_range(0.0, TAU),
				"per": rng.randf_range(2.8, 5.4), "off": rng.randf_range(0.0, 5.0),
			})

	static func _make_glow() -> ImageTexture:
		var img := Image.create(GLOW_N, GLOW_N, false, Image.FORMAT_RGBA8)
		var c := Vector2(7, 7)
		for y in range(GLOW_N):
			for x in range(GLOW_N):
				var d: float = Vector2(x, y).distance_to(c)
				var a: float = 0.0
				if d <= 1.5:
					a = 0.45
				elif d <= 3.5:
					a = 0.2
				elif d <= 6.0:
					a = 0.08
				img.set_pixel(x, y, Color(0.84, 1.0, 0.40, a))
		img.set_pixel(7, 7, Color(1.0, 1.0, 0.82, 1.0)) ## açık öz
		return ImageTexture.create_from_image(img)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var gs := Vector2(GLOW_N, GLOW_N) * CELL
		for f: Dictionary in _flies:
			var per: float = f["per"]
			var s: float = fmod(_t + float(f["off"]), per) / per
			var b: float = smoothstep(0.0, 0.25, s) * (1.0 - smoothstep(0.5, 0.8, s))
			if b <= 0.02:
				continue
			var ph: float = f["ph"]
			var p: Vector2 = f["pos"] + Vector2(sin(_t * float(f["sx"]) * TAU + ph) * float(f["ax"]), sin(_t * float(f["sy"]) * TAU + ph * 1.7) * float(f["ay"]))
			p = (p / CELL).floor() * CELL
			draw_texture_rect(_glow, Rect2(p - Vector2(7, 7) * CELL, gs), false, Color(1, 1, 1, b * 0.9))


## Yönsüz temas gölgesi (AO): karakter pikseli ızgarasında iç içe elips DÜZ alfa bantları (benek/dither yok). bands = [[yarıçap, alfa], ...]
## dıştan içe; merkez/yarıçap karakter px, Control'ün sol üstüne göre.
class FireContactShadow extends Control:
	var center: Vector2
	var bands: Array
	var k: float

	func _init(c: Vector2, b: Array, scale_k: float) -> void:
		center = c
		bands = b
		k = scale_k
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for band: Array in bands:
			var r: Vector2 = band[0]
			var col := Color(0, 0, 0, float(band[1]))
			for yi in range(-int(ceil(r.y)), int(ceil(r.y))):
				var yc: float = yi + 0.5
				if absf(yc) >= r.y:
					continue
				var hw: float = r.x * sqrt(1.0 - (yc / r.y) * (yc / r.y))
				var x0: float = roundf(center.x - hw)
				var x1: float = roundf(center.x + hw)
				if x1 > x0:
					draw_rect(Rect2(x0 * k, (center.y + yi) * k, (x1 - x0) * k, k), col)


## Yere konmuş tek parça (dikili meşale gövdesi, kılıç/çanta/kese): doku x k, altında küçük piksel gölge (shadow = false: yalnız doku).
class GroundProp extends Control:
	var tex: Texture2D = null
	var k: float = 2.0
	var shadow: bool = true

	func _init(t: Texture2D, scale_k: float, with_shadow: bool = true) -> void:
		tex = t
		k = scale_k
		shadow = with_shadow
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if tex != null:
			size = Vector2(tex.get_width(), tex.get_height()) * k

	func _draw() -> void:
		if tex == null:
			return
		var sz := Vector2(tex.get_width(), tex.get_height()) * k
		if shadow:
			draw_rect(Rect2(sz.x * 0.15, sz.y - 2.0 * k, sz.x * 0.7, 3.0 * k), Color(0, 0, 0, 0.3))
		draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false)
