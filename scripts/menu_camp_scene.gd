extends RefCounted

## ANA MENÜ SAHNESİ "Nehir Kenarı Kampı" (2026-11-15, kullanıcı: "Şovalye, Oakley, Hadime, Matthew, Talon ve Elara ana haritanın cozy nehir
## kenarında, hafif loş günbatımı olmak üzere olan havada kamp yapıyor; bazıları oturuyor, iyi vakit geçiriyor; kamp ateşi + birkaç yiyecek.
## Hava hep günbatımı"). Eski "Ocak Başı" (şömine, madde 187/326) yerine; ana menü + menu_hearth_bg.gd (tek/çok oyunculu, oda listesi,
## karakter seçimi, Ruh Mağazası arka planı) aynı sahneyi buradan kurar.
##
## Taban `nehir_kamp.png` = ANA HARİTANIN gerçek çizici yakalaması (320x180 dünya px, tools/proto_20261115/kamp_menu/kamp_capture.gd) + oyunun
## kendi sanatından yer eşyaları (kütük, yastık, hasır, yiyecek örtüsü; gen_nehir_kamp.py). Canlı: kazanlı ateş çukuru (kamp paketi, kor
## animasyonu; korları günbatımının üstünde ayrıca), gerçek SpriteFrames karakterler + uyuyan köpek. Günbatımı tonu + ateş ışığı + nehirdeki yansıma kamp_gunbatimi.gdshader'da
## (ekranın üstünde, okunan ekran dokusu - karakterler de aynı ışığı alır); çukurun korları bu katmanın ÜSTÜNDE (kendi ışığı).
## Ölçek: 1 dünya px = MAP_K ekran px; karakter/alev pikseli CHAR_K (oyunda karakter dünyanın yarısı ölçekte; burada biraz büyük, okunur).
## Konumlar dünya px (taban png'si) uzayında; yer eşyaları gen_nehir_kamp.py'de (FIRE_FOOT/PARTY oradaki yorumla aynı yerler).

const SCREEN := Vector2(1920, 1080)
const MAP_K := 6.0
const CHAR_K := 4.0
const BG_PATH := "res://assets/ui/ana_menu/nehir_kamp.png"
const WATER_PATH := "res://assets/ui/ana_menu/nehir_kamp_su.png"
const SHADER_PATH := "res://shaders/kamp_gunbatimi.gdshader"
## Ateş çukuru: kamp paketinin kertenkelesiz kazanlı ateşi (12 kare x 36x29, 150 ms; tools/kamp/gen_kamp.py).
const PIT_PATH := "res://assets/map/kamp/ates.png"
const PIT_FRAME := Vector2(36, 29)
const PIT_FRAMES := 12
const PIT_FPS := 1000.0 / 150.0
const FIRE_FOOT := Vector2(170, 141) ## çukur karesinin alt ortası (dünya px)
## Çukurun KENDİ ateşi (kazanın altındaki kor pikselleri, ates.png'den ayrılmış aynı 12 karelik şerit): günbatımı katmanının ÜSTÜNDE
## çukurla aynı karede çizilir, loşlukta sönmez. (2026-11-15 ilk sürümdeki ek piksel alev fx_burn_flames kalktı - kullanıcı: "çok kötü,
## kendi ateşini kullan bu assetin".)
const PIT_EMBER_PATH := "res://assets/ui/ana_menu/kamp_ates_kor.png"
const LIGHT_POS := Vector2(170, 128) ## ateş ışığının merkezi (dünya px)
## İdle'lar menüde oyundakinden YAVAŞ (kullanıcı: "idle animasyonları çok hızlı, baya yavaşlaması gerekiyor"): klibin kendi hızı x IDLE_SLOW.
## Talon'un idle şeridi, oturanların idle ritmi ve Oakley'nin ısırık arası idle'ı bunu kullanır (eat_ ısırığı kendi hızında).
const IDLE_SLOW := 0.35
## [karakter id, klip, ayak ortası (dünya px)] - sit_ son kare sabit (belden yukarısı kendi idle ritmiyle), eat_/read_ bir kez oynar, aralarda
## kendi idle_'i; "res://..." = elle düzenlenmiş kare/şerit (tools/proto_20261115/kamp_menu/gen_kamp_kareler.py).
## Kuzeydeki kütüğün ÜSTÜNDE Şovalye + Matthew (bize dönük; Matthew'in elinde tavuk budu), batıda yastıkta Büyücü Kız, doğuda ağaç kütüğü
## taburede Elara, güneybatıda Hadime yerde geriye yaslanmış bacaklarını uzatmış, yiyecek örtüsünün yanında ayakta Oakley (oturma klibi
## yok) bir şeyler yiyor; Talon kampın kuzeyinde nehir kıyısında AYAKTA nehre dönük, oltası yumruğunda balık tutuyor (talon_olta.png = kendi idle_left'i
## + kol, FISHING); köpek Elara'nın arkasında
## uyuyor. Kütükte/taburede oturanların ayağı kütüğün alt kenarının hemen üstünde (taban png'sindeki kütük onların arkasında kalır).
## PARTY sırası ana menünün alt yüz şeridinin sırası.
const PARTY := [
	[7, "sit_down", Vector2(157, 105)],
	[3, "res://assets/ui/ana_menu/matthew_yemek.png", Vector2(184, 105)],
	[4, "sit_right", Vector2(139, 136)],
	[8, "sit_left", Vector2(208, 129)],
	[14, "res://assets/ui/ana_menu/hadime_uzanik.png", Vector2(144, 158)],
	[2, "eat_left", Vector2(232, 160)],
	[1, "res://assets/ui/ana_menu/talon_olta.png", Vector2(177, 50)],
]
## Talon'un oltası: yumruktan (TALON_FIST = talon_olta.png karesinde yumruğun ortası, karakter px; gen_kamp_kareler.py TALON_KOL) kamış
## ucuna, misina şamandıraya (suda; kıyı bu yükseklikte x ~162). Olta kodla çizilir (oyunda olta sanatı yok) ve Talon'dan ÖNCE çizilir:
## kamış yumruğun arkasından geçer (tutuluyor görünür). Kamış + misina karakter pikseli ızgarasında, şamandıra iner-kalkar, suda halka açılır.
const TALON_FIST := Vector2(16.5, 27.5)
const FISHING := {"tip": Vector2(153.0, 22.0), "bobber": Vector2(149.0, 41.0)}
const DOG := ["kopek", "sleep_down", Vector2(238, 121)]


## Tam ekran sahne (SCREEN boyutunda `stage` içine): taban + canlı parçalar + günbatımı katmanı + alev.
static func build(stage: Control) -> void:
	var bg := TextureRect.new()
	bg.name = "SceneBg"
	bg.texture = load(BG_PATH)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(bg)
	bg.position = Vector2.ZERO
	bg.size = SCREEN
	## y-sıralı canlı parçalar: [ayak y, düğüm]
	var items: Array = []
	var pit := SheetAnim.new(load(PIT_PATH), PIT_FRAME, PIT_FRAMES, PIT_FPS, MAP_K)
	pit.position = (FIRE_FOOT - Vector2(PIT_FRAME.x * 0.5, PIT_FRAME.y)).floor() * MAP_K
	items.append([FIRE_FOOT.y, pit])
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
			var rod := FishingRod.new(s.position + TALON_FIST * CHAR_K, FISHING["tip"] * MAP_K, FISHING["bobber"] * MAP_K, CHAR_K)
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
	grade.material = mat
	stage.add_child(grade)
	grade.position = Vector2.ZERO
	grade.size = SCREEN
	var embers := SheetAnim.new(load(PIT_EMBER_PATH), PIT_FRAME, PIT_FRAMES, PIT_FPS, MAP_K)
	embers.name = "CampEmbers"
	embers.position = pit.position
	stage.add_child(embers)


## Yan yana kareli şeridi (sayfa) sırayla oynatan piksel-tam çizim.
class SheetAnim extends Control:
	var tex: Texture2D = null
	var frame_size: Vector2 = Vector2.ZERO
	var count: int = 1
	var fps: float = 8.0
	var k: float = 4.0

	func _init(t: Texture2D, fsz: Vector2, n: int, speed: float, scale_k: float) -> void:
		tex = t
		frame_size = fsz
		count = n
		fps = speed
		k = scale_k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size = fsz * scale_k

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var i: int = int(Time.get_ticks_msec() * 0.001 * fps) % count ## ortak saat: çukur + kor şeridi aynı karede
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, frame_size * k), Rect2(Vector2(i * frame_size.x, 0), frame_size))


## Gerçek SpriteFrames klibi; ayak ortası place_at(ekran px) noktasına oturur, altında küçük piksel gölge.
## sit_ = oturma HAREKETİ (kare 0 ayakta -> son kare oturmuş): son kare sabit. eat_/read_: klip bir kez oynar, aralarda karakterin KENDİ
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
		elif String(anim).begins_with("eat_") or String(anim).begins_with("read_"):
			rest = rest_sec
			_learn_rhythm()
			_rhythm.clear() ## ayakta: ritim değil, idle karelerinin kendisi (_idle_frames) oynar
		_measure(frames.get_frame_texture(anim, maxi(hold, 0)).get_image())

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
		var n: int = maxi(1, frames.get_frame_count(anim))
		var spd: float = maxf(1.0, frames.get_animation_speed(anim))
		if rest <= 0.0:
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


## Balık tutan Talon'un oltası: kamış (koyu ahşap) elden uca, misina uçtan şamandıraya hafif sarkarak, kırmızı-beyaz şamandıra 1 piksel
## iner-kalkar, ara ara suda genişleyip sönen halka. Hepsi `px` (karakter pikseli) ızgarasında dolu kareler - yumuşatma/benek yok.
class FishingRod extends Control:
	const ROD := Color(0.36, 0.22, 0.13)
	const LINE := Color(0.88, 0.86, 0.80, 0.55)
	const RIPPLE := Color(0.80, 0.90, 1.0)
	var hand: Vector2
	var tip: Vector2
	var bobber: Vector2
	var px: float = 4.0
	var _t: float = 0.0

	func _init(h: Vector2, t: Vector2, b: Vector2, pixel: float) -> void:
		hand = h
		tip = t
		bobber = b
		px = pixel
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _cell(p: Vector2) -> Vector2:
		return (p / px).floor() * px

	## a -> b arası piksel çizgi (ızgara hücreleri); sag > 0: ortası aşağı sarkar.
	func _line(a: Vector2, b: Vector2, col: Color, sag: float = 0.0) -> void:
		var n: int = maxi(1, int(ceil(maxf(absf(b.x - a.x), absf(b.y - a.y)) / px)))
		var last := Vector2(INF, INF)
		for i in range(n + 1):
			var f: float = float(i) / n
			var c: Vector2 = _cell(a.lerp(b, f) + Vector2(0, sag * 4.0 * f * (1.0 - f)))
			if c != last:
				draw_rect(Rect2(c, Vector2(px, px)), col)
				last = c

	func _draw() -> void:
		## ara sıra balık vurur: kamış ucu + şamandıra kısa bir an 1 piksel aşağı seğirir (3,7 sn'de bir)
		var twitch: bool = fmod(_t, 3.7) < 0.3
		var bob: float = px if fmod(_t, 1.6) > 1.1 or twitch else 0.0
		var b: Vector2 = bobber + Vector2(0, bob)
		var tp: Vector2 = tip + Vector2(0, px if twitch else 0.0)
		## halka: 2,4 sn'de bir şamandıradan açılır (yatay elips, dört yöne piksel noktalar)
		var ph: float = fmod(_t, 2.4) / 2.4
		if ph < 0.6:
			var r: float = 2.0 + ph / 0.6 * 5.0
			var a: float = 0.45 * (1.0 - ph / 0.6)
			for i in range(16):
				var ang: float = TAU * i / 16.0
				var c: Vector2 = _cell(b + Vector2(cos(ang) * r * px, sin(ang) * r * px * 0.45 + px))
				draw_rect(Rect2(c, Vector2(px, px)), Color(RIPPLE, a))
		_line(tp, b, LINE, px * 1.5)
		_line(hand, tp, ROD)
		var bc: Vector2 = _cell(b)
		draw_rect(Rect2(bc + Vector2(0, -px), Vector2(px, px)), Color(0.86, 0.18, 0.16))
		draw_rect(Rect2(bc, Vector2(px, px)), Color(0.95, 0.93, 0.88))
