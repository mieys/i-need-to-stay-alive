class_name BuyucuFx
extends RefCounted
## Büyücü Kız efektleri (2026-10-16/17, madde 188; kullanıcı prototipleri onayladı, sadece "Yükseliş" havalanması eskisi gibi: "ben sadece
## havaya uçma geliştirmesi eskisi gibi olsun dedim yeni hazırladığın meteorlar iyiydi onlar kalsın"). MEKANİK DEĞİŞMEDİ - sadece görsel. Sanat: tools/gen_buyucu_fx.py (onaylanan prototip
## tools/proto_20261016/gen_buyucu_buyu.py çizimleri) -> assets/fx/buyucu/*.png (yatay şerit, Sprite2D hframes; .tres YOK).
##   Q Büyü Değişimi  fx_mage_swap.tscn (props target_set) - havada büyü kitabı + set zerreleri, Set 1 soğuk / Set 2 sıcak
##   E Arcane Lanet   fx_arcane_skull_bounce.gd (lanet gözü + iz + kıvılcım) + fx_arcane_impact.gd (patlama + ayak mührü + lanet ipi)
##   E Hortum         fx_buyucu_tornado.gd (hortum_in -> hortum_loop -> hortum_out) + fx_buyucu_tornado_cast/_hit.tscn
##   Pasif            fx_buyucu_surge_wave.tscn (mor dalga) + güçlendirilmiş mermiye style_surge_projectile (namlu parlaması + mor iz
##                    + isabette mor patlama). Geri tepme/mor parlama/kıvılcım (WeaponJuice.arcane_surge) aynen kaldı.
##   R Meteor         fx_buyucu_meteor_channel.tscn (ayak altında rün çemberi, ateş yayı 3 sn'de dolar + şapka ucundan korlar) +
##                    fx_meteor_strike.gd (uyarı gölgesi/halkası, korlu kaya, patlama + parçalar, hasar yarıçapında halka, krater).
##                    "Yükseliş" (R1) havalanması ESKİ (buyucu_levitate.gd) - kullanıcı 2026-10-17. Don Nova ESKİ.
## TEK KOD İKİ YER: kaster ve uzak kopya aynı sahne/fonksiyonu çağırır (CLAUDE.md "MP iki-yer hatası") - yeni RPC yok.
## Ölçek: 1 sayfa pikseli = 1 Büyücü sanat pikseli. Karaktere bağlı sayfalar (char_layer) karakter AnimatedSprite2D'sinin konum/offset/taban
## ölçeğini kopyalar (karenin merkezi = karakter karesinin merkezi), dünyada duranlar PX dünya birimi/piksel.

const DIR := "res://assets/fx/buyucu/"
## ad -> kare sayısı (tools/gen_buyucu_fx.py ile aynı)
const SHEETS := {
	"q_back_0": 21, "q_front_0": 21, "q_back_1": 21, "q_front_1": 21,
	"lanet_eye": 16, "lanet_cast": 3, "lanet_burst": 7, "lanet_brand": 12,
	"hortum_loop": 28, "hortum_in": 6, "hortum_out": 12, "hortum_cast": 5, "hortum_hit": 4,
	"surge_wave": 6, "surge_muzzle": 2, "surge_hit": 7,
	"r_ring": 45, "r_ring_end": 7, "r_embers": 20,
	"meteor_fall": 4, "meteor_warn": 7, "meteor_burst": 10, "meteor_ring": 4, "meteor_crater": 20,
}
## Bir Büyücü sanat pikselinin dünya boyutu (2,2368375 x EntityScale 0,8075 x oyuncu kökü 0,5).
const PX := 0.903
## [kontur, koyu, orta, açık, parlak] - prototipteki ARC (büyü menekşesi) / HEX (lanet).
const ARC: Array[Color] = [Color8(30, 12, 54), Color8(74, 34, 136), Color8(130, 80, 214), Color8(192, 152, 255), Color8(246, 234, 255)]
const HEX: Array[Color] = [Color8(46, 10, 50), Color8(112, 28, 124), Color8(182, 64, 200), Color8(236, 140, 240), Color8(255, 230, 250)]
const SURGE_TRAIL_LEN := 16.0 ## güçlendirilmiş mermi izi (sanat pikseli; Elara izinden uzun/kalın - prototip)
const SURGE_TRAIL_WIDTH := 3.0
const SURGE_FPS := 15.0
const CadiMathScript := preload("res://scripts/cadi_math.gd")
const ElaraFxScript := preload("res://scripts/elara_fx.gd")

static var _tex_cache: Dictionary = {}


static func tex(sheet: String) -> Texture2D:
	if not _tex_cache.has(sheet):
		_tex_cache[sheet] = load(DIR + sheet + ".png")
	return _tex_cache[sheet]


## ============================================================== sayfa oynatıcı
## Yatay şerit sayfa; seq: [[ad, döngü mü], ...]. Döngüsüz son sayfa bitince kendini siler. finish(out): döngüden çıkış sayfasına geçer.
class Sheet extends Sprite2D:
	var fps := 15.0
	var _seq: Array = []
	var _loop := false
	var _frame := 0
	var _t := 0.0
	var _delay := 0.0

	## delay: bu kadar saniye görünmez bekler (ör. aynı anda doğan hortumlar aynı fazda dönmesin).
	func setup(seq: Array, p_fps: float, start_frame: int = 0, delay: float = 0.0) -> Sheet:
		fps = p_fps
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_seq = seq.duplicate()
		_delay = delay
		visible = delay <= 0.0
		_next()
		if _loop and start_frame > 0:
			_frame = start_frame % hframes
			frame = _frame
		return self

	func _next() -> bool:
		if _seq.is_empty():
			queue_free()
			return false
		var s: Array = _seq.pop_front()
		var n: String = str(s[0])
		_loop = bool(s[1])
		texture = BuyucuFx.tex(n)
		hframes = int(BuyucuFx.SHEETS[n])
		frame = 0
		_frame = 0
		return true

	func finish(out_sheet: String) -> void:
		_seq = [[out_sheet, false]]
		_next()

	## Şu anki (döngüsüz) sayfa bitince bu sayfaya geçer (meteor kanalı: çember dolar -> parçalanır).
	func finish_after(out_sheet: String) -> void:
		_seq.append([out_sheet, false])

	func _process(delta: float) -> void:
		if _delay > 0.0:
			_delay -= delta
			if _delay > 0.0:
				return
			visible = true
			_t = 0.0
		_t += delta
		var step: float = 1.0 / fps
		while _t >= step:
			_t -= step
			_frame += 1
			if _frame >= hframes:
				if _loop:
					_frame = 0
				elif not _next():
					return
				else:
					continue
			frame = _frame


## Karaktere bağlı sayfa: host (karakterin çocuğu, konumu 0) altına, karakter sprite'ıyla AYNI konum/offset/taban ölçek. flip: sola bakarken.
## loop: sayfa döngüde oynar (çağıran siler).
static func char_layer(host: Node2D, p: Node, sheet: String, z: int, fps: float, flip: bool = false, loop: bool = false) -> Sheet:
	var s := Sheet.new()
	s.z_index = z
	s.centered = true
	var anim: Node2D = p.get("anim") as Node2D if p != null else null
	if anim != null:
		s.position = anim.position
		if anim is AnimatedSprite2D:
			s.offset = (anim as AnimatedSprite2D).offset
		s.scale = _base_scale(p, anim)
	else:
		s.scale = Vector2.ONE * PX / 0.5
	s.flip_h = flip
	host.add_child(s)
	return s.setup([[sheet, loop]], fps)


## Dünyada duran sayfa (sahnenin köküne): 1 piksel = PX * size dünya birimi.
static func spawn_world(tree: SceneTree, sheet: String, pos: Vector2, z: int, fps: float, size: float = 1.0) -> Sheet:
	if tree == null or tree.current_scene == null:
		return null
	var s := Sheet.new()
	s.z_index = z
	s.centered = true
	s.scale = Vector2.ONE * PX * size
	tree.current_scene.add_child(s)
	s.global_position = pos
	return s.setup([[sheet, false]], fps)


static func facing_left(p: Node) -> bool:
	return p != null and CadiMathScript.facing_of(p) == "left"


## Sprite'ın TABAN ölçeği (vuruş sıkışması gibi geçici ölçek oynamaları efekti titretmesin): kaster char_base_anim_scale, uzak _base_anim_scale.
static func _base_scale(p: Node, anim: Node2D) -> Vector2:
	for key in ["char_base_anim_scale", "_base_anim_scale"]:
		var v: Variant = p.get(key)
		if v is Vector2:
			return (v as Vector2).abs()
	return anim.scale.abs()


## ============================================================== Pasif: güçlendirilmiş mermi
## Namlu parlaması + mor iz (ElaraFx.Trail, ARC paleti) + isabette mor patlama (projectile.gd _spawn_impact "buyucu_surge" meta'sı).
## Kaster weapon.gd _fire_at (look["surge"]) ve uzak kopya EnchantFx.apply_projectile_look aynı fonksiyon.
static func style_surge_projectile(proj: Node2D) -> void:
	if proj == null or not proj.is_inside_tree():
		return
	spawn_world(proj.get_tree(), "surge_muzzle", proj.global_position, 5, SURGE_FPS)
	var tr := ElaraFxScript.Trail.new()
	tr.pal = ARC
	tr.len_px = SURGE_TRAIL_LEN
	tr.width_px = SURGE_TRAIL_WIDTH
	proj.add_child(tr)
	proj.set_meta("buyucu_surge", true)


## projectile.gd _spawn_impact: güçlendirilmiş merminin İLK isabetinde mor patlama (delici mermide bir kez).
static func surge_impact(proj: Node2D) -> void:
	if proj == null or not proj.has_meta("buyucu_surge"):
		return
	proj.remove_meta("buyucu_surge")
	spawn_world(proj.get_tree(), "surge_hit", proj.global_position, 46, SURGE_FPS)
