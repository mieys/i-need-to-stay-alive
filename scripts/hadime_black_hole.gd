extends Node2D

## Yaratık aday sorgusu (yeni yolda C++ ızgarası, eski yolda tüm "enemies" grubu; süzgeçler çağıranda aynen kalır).
const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")

## Suriyeli Hadime E - Kara Delik (kullanıcı isteği 2026-09-25: "bulunduğu konuma kara delik bırakıp yaratıkları hafifçe
## içine doğru çekip kalkanlarını emerek verdiği hasarın %20'si kadar Hadime'ye kalkan yenilesin, 5 saniye sürecek (2026-09-26: 6 sn, bkz. HadimeMath.HOLE_DURATION), her
## saniye %80 saldırı gücü hasar, 18 sn bekleme, kalkan çekme efektine gerek yok").
## 2026-09-28 yetenek evrimleri: kalkan emme temel yetenekten çıkıp "Kalkan Emici" evrimine geçti (player.gd
## _on_hadime_hole_tick). Bu script'teki evrim kancaları:
##  - radius_mult (Genişleyen Çukur, eski Genişleyen Boşluk): çekim/hasar yarıçapı büyür, görsel x1,5 KENDİ sayfasıyla.
##  - moving (Gezgin Çukur, eski Gezgin Delik): delik kalabalık yaratıklara doğru çekim hızıyla (HOLE_PULL_SPEED) ilerler ve yarıçapındaki
##    yaratıkları kendisiyle SÜRÜKLER (çekim kopyası deliğin o karedeki yer değiştirmesini onlara da ekler).
##  - on_end (Yer Yarılması, eski Süpernova): ömrün sonunda yetkili kopya merkezi ve yarıçapı player.gd'ye bildirir (patlama hasarı + efekti orada).
##
## Dünya konumunda sabit (HadimeMath.spawn_black_hole). GÖRSEL (2026-11-11, madde 556: "Kara Delik" -> "LANET ÇUKURU", prototip
## A "Çöken Zemin"): iki sprite sayfası (tools/gen_hadime_cukur_fx.py, intro -> loop -> outro): ZEMİN = bu düğüm (haritanın hemen
## üstü, yaratıkların altı: çatlaklar, moloz halkası, dibi yeşil parlayan çukur, sarmal çizip düşen toprak parçaları, soluk alan
## sınırı), ÖN = z 20 (giriş toz halkası + çarpmadaki yeşil ışık sütunu ve toz halkası). 1 sanat px = 0,903 dünya (karakter
## pikseli); Genişleyen Çukur (x1,5) kendi büyük sayfasıyla çizilir (germe yok). Çöl / zindan haritasında toprak tonları
## shaders/hadime_cukur_palet.gdshader ile zemine uyar. Zaman çizelgesi ses senkronuyla AYNI (giriş 0,4 sn, çıkış 6,0 sn,
## çarpma çıkışın 4. karesi = 6,25 sn). Kopyalar ve görevleri:
##  - authoritative (kasterin kendi kopyası): her HOLE_TICK'te on_tick(merkez, yarıçap) -> player.gd _on_hadime_hole_tick
##    (hasar + kalkan yenileme kasterde bir kez hesaplanır, istemciyse hasar host'a zaten take_damage yoluyla gider).
##    Hareketli delikte yolu da BU kopya belirler ve konumunu ~10 Hz yayınlar (NetworkManager.broadcast_hadime_hole_pos).
##  - pull_authority (host'taki kopya): yaratıklar host'ta simüle edildiği için çekim SADECE orada uygulanır; konumlar
##    normal yaratık senkronuyla herkese gider. Kaster host değilse bu kopya network_manager.gd
##    broadcast_hadime_black_hole'dan (reliable) gelir ve hareketli delikte kasterin yayınladığı konumu izler.
##  - diğer istemcilerdeki kopyalar sadece görseldir (hareketli delikte onlar da ağ konumunu izler).

const HadimeMath := preload("res://scripts/hadime_math.gd")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const MapProfilesScript := preload("res://scripts/map_profiles.gd")
## Sayfalar çukur merkezi = karenin TAM ortası (üretici tuvali formülle merkezler) -> centered sprite, ofset yok.
const GroundFrames: SpriteFrames = preload("res://assets/fx/hadime/cukur/cukur_zemin.tres")
const FrontFrames: SpriteFrames = preload("res://assets/fx/hadime/cukur/cukur_on.tres")
const GroundFramesBig: SpriteFrames = preload("res://assets/fx/hadime/cukur/cukur_buyuk_zemin.tres")
const FrontFramesBig: SpriteFrames = preload("res://assets/fx/hadime/cukur/cukur_buyuk_on.tres")
const PaletteShader: Shader = preload("res://shaders/hadime_cukur_palet.gdshader")
## 1 sanat pikseli (dünya) ve büyük sayfanın ölçeği (gen_hadime_cukur_fx.py WORLD_PX / build(1.5)) - üreticiyle AYNI olmalı.
const ART_PX := 0.903
const BIG_SHEET_MULT := 1.5
## Ön katman (toz + ışık sütunu) yaratıkların üstünde.
const FRONT_Z := 20
## Harita zeminine göre toprak tonları: kaynak = üreticinin paleti (OUTL, ED, EM, EL, EH, GM, GL, WALL_DEEP, DUST 0-3), hedef
## haritaya göre. "cimen" (ana harita, bataklık) malzemesiz çizilir. Harita profili "cukur_zemin" verir; yoksa zindan = "tas".
const PALETTE_SRC: Array[Color] = [
	Color8(30, 19, 14), Color8(68, 45, 31), Color8(112, 78, 52), Color8(158, 116, 78), Color8(196, 156, 108),
	Color8(82, 132, 52), Color8(128, 176, 72), Color8(36, 24, 24),
	Color8(92, 76, 58), Color8(140, 122, 98), Color8(180, 164, 138), Color8(214, 202, 178),
]
const PALETTES := {
	## çöl kumu (Altın Kumlar zemini 210,178,104 / 189,155,96); kopan çimen yerine kum topakları
	"kum": [
		Color8(72, 46, 28), Color8(128, 94, 56), Color8(176, 140, 82), Color8(210, 178, 104), Color8(234, 208, 142),
		Color8(189, 155, 96), Color8(226, 196, 128), Color8(54, 34, 22),
		Color8(150, 124, 84), Color8(196, 170, 124), Color8(226, 206, 160), Color8(244, 232, 200),
	],
	## zindan taşı (gri-kahve döşeme); kopan çimen yerine taş kırıkları
	"tas": [
		Color8(34, 30, 30), Color8(72, 66, 60), Color8(106, 98, 88), Color8(140, 130, 116), Color8(176, 166, 150),
		Color8(106, 98, 88), Color8(140, 130, 116), Color8(30, 26, 28),
		Color8(96, 90, 84), Color8(140, 134, 124), Color8(178, 172, 160), Color8(212, 206, 194),
	],
	## Ayaz Dağı karı (madde 630 zemini: kar 170,187,196 / ıslak toprak 153,128,89 - shaders/kis_desen.gdshaderinc rampası): donmuş koyu
	## toprak, kopan çimen yerine kar topakları, toz = kar tozu (eski açık kar tonları aynı rampadan geçirildi)
	"kar": [
		Color8(28, 34, 44), Color8(54, 49, 48), Color8(89, 75, 61), Color8(123, 105, 79), Color8(153, 128, 89),
		Color8(170, 187, 196), Color8(208, 220, 225), Color8(30, 28, 34),
		Color8(132, 149, 162), Color8(160, 177, 187), Color8(183, 199, 206), Color8(198, 212, 217),
	],
}
static var _palette_mats: Dictionary = {}
## Görsel "outro" herhangi bir sebeple bitmezse (ağaç duraklatma vb.) güvenlik ömrü.
const SAFETY_EXTRA := 2.0
## Hareketli deliğin ağ konumu yayın aralığı (sn) ve uzak kopyanın bu konuma yaklaşma hızı.
const NET_SEND_INTERVAL := 0.1
const NET_FOLLOW_RATE := 10.0

var authoritative: bool = false
var pull_authority: bool = false
var on_tick: Callable = Callable()
var radius_mult: float = 1.0
var moving: bool = false
var owner_peer: int = 0
var on_end: Callable = Callable()

var _sprite: AnimatedSprite2D = null
var _front: AnimatedSprite2D = null
var _t: float = 0.0
var _tick_timer: float = HadimeMath.HOLE_FIRST_TICK
var _ending: bool = false
var _move_goal: Vector2 = Vector2.INF
var _retarget_timer: float = 0.0
var _net_send_timer: float = 0.0
var _net_target: Vector2 = Vector2.INF
var _prev_pos: Vector2 = Vector2.ZERO


func radius() -> float:
	return HadimeMath.HOLE_RADIUS * radius_mult


func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	## Genişleyen Çukur (x1,5) kendi sayfası; başka bir çarpan gelirse en yakın sayfa ölçeklenir.
	var big: bool = radius_mult > 1.25
	var k: float = ART_PX * radius_mult / (BIG_SHEET_MULT if big else 1.0)
	_sprite = _make_layer(GroundFramesBig if big else GroundFrames, k)
	_front = _make_layer(FrontFramesBig if big else FrontFrames, k)
	_front.z_as_relative = false
	_front.z_index = FRONT_Z
	var mat: ShaderMaterial = palette_material(ground_palette())
	if mat != null:
		_sprite.material = mat
		_front.material = mat
	_sprite.animation_finished.connect(_on_animation_finished)
	_play(&"intro")
	_prev_pos = global_position
	add_to_group("hadime_black_holes")
	## Zemin efekti: haritanın hemen arkasına - tüm karakter/yaratıkların ALTINDA (asit gölü / düşmelerle aynı çözüm).
	## Ertelenmiş: ebeveyn şu an bu düğümü eklemekle meşgulken move_child çağrılamaz (xp_orb.gd ile aynı).
	_place_on_ground.call_deferred()


func _place_on_ground() -> void:
	if is_inside_tree():
		EnemyAbilities.place_on_ground(get_tree(), self)


func _make_layer(frames: SpriteFrames, k: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.sprite_frames = frames
	s.scale = Vector2.ONE * k
	add_child(s)
	return s


## İki katman aynı animasyonu aynı anda başlatır (aynı kare sayısı / hız -> birlikte biter; ön katmanın döngüsü tek boş kare).
func _play(anim: StringName) -> void:
	_sprite.play(anim)
	_front.play(anim)


## Haritanın çukur zemini: profil "cukur_zemin", yoksa zindan haritası "tas", diğerleri "cimen".
static func ground_palette() -> String:
	var p: Dictionary = MapProfilesScript.current()
	if p.has("cukur_zemin"):
		return str(p["cukur_zemin"])
	return "tas" if str(p.get("tur", "")) == MapProfilesScript.KIND_ZINDAN else "cimen"


## Paylaşılan malzeme (palet başına bir tane -> aynı haritadaki bütün çukurlar birlikte çizilir); "cimen" = null (malzemesiz).
static func palette_material(palette: String) -> ShaderMaterial:
	if not PALETTES.has(palette):
		return null
	if _palette_mats.has(palette):
		return _palette_mats[palette]
	var src := PackedVector3Array()
	var dst := PackedVector3Array()
	var to: Array = PALETTES[palette]
	for i in PALETTE_SRC.size():
		src.append(Vector3(PALETTE_SRC[i].r, PALETTE_SRC[i].g, PALETTE_SRC[i].b))
		dst.append(Vector3(to[i].r, to[i].g, to[i].b))
	var mat := ShaderMaterial.new()
	mat.shader = PaletteShader
	mat.set_shader_parameter("src", src)
	mat.set_shader_parameter("dst", dst)
	_palette_mats[palette] = mat
	return mat


func _on_animation_finished() -> void:
	if _sprite.animation == &"intro" and not _ending:
		_play(&"loop")
	elif _sprite.animation == &"outro":
		queue_free()


## Kasterin yayınladığı konum (hareketli delik - bkz. network_manager.gd broadcast_hadime_hole_pos).
func set_net_target(pos: Vector2) -> void:
	_net_target = pos


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < HadimeMath.HOLE_DURATION:
		_prev_pos = global_position
		if moving:
			_process_move(delta)
		if authoritative:
			_tick_timer -= delta
			if _tick_timer <= 0.0:
				_tick_timer += HadimeMath.HOLE_TICK
				if on_tick.is_valid():
					on_tick.call(global_position, radius())
		if pull_authority:
			_pull(delta, global_position - _prev_pos)
	elif not _ending:
		_ending = true
		_play(&"outro")
		## Yer Yarılması (eski Süpernova): sayfanın çöküşüyle aynı anda patlama (hasar + efekt player.gd'de - yetkili kopya bir kez).
		if authoritative and on_end.is_valid():
			on_end.call(global_position, radius())
	elif _t > HadimeMath.HOLE_DURATION + SAFETY_EXTRA:
		queue_free()


## Gezgin Delik: yetkili kopya en kalabalık yaratık kümesine (yarıçapı içinde en çok komşusu olan yaratık) çekim hızıyla
## ilerler ve konumunu yayınlar; diğer kopyalar bu konumu yumuşakça izler (hasar/çekim kararları kendi kopyalarında).
func _process_move(delta: float) -> void:
	if authoritative:
		_retarget_timer -= delta
		if _retarget_timer <= 0.0:
			_retarget_timer = HadimeMath.EVO_HOLE_RETARGET
			_move_goal = _pick_crowd_goal()
		if _move_goal != Vector2.INF:
			var to_goal: Vector2 = _move_goal - global_position
			var step: float = minf(HadimeMath.HOLE_PULL_SPEED * delta, to_goal.length())
			if step > 0.01:
				var np: Vector2 = global_position + to_goal.normalized() * step
				if not GameManager.is_position_blocked_by_walls(np):
					global_position = np
		if NetworkManager.is_multiplayer_active:
			_net_send_timer -= delta
			if _net_send_timer <= 0.0:
				_net_send_timer = NET_SEND_INTERVAL
				NetworkManager.broadcast_hadime_hole_pos.rpc(owner_peer, global_position)
	elif _net_target != Vector2.INF:
		global_position = global_position.lerp(_net_target, 1.0 - exp(-NET_FOLLOW_RATE * delta))


func _pick_crowd_goal() -> Vector2:
	var r: float = radius()
	var r2: float = r * r
	var search2: float = HadimeMath.EVO_HOLE_MOVE_SEARCH * HadimeMath.EVO_HOLE_MOVE_SEARCH
	var cands: Array = []
	for e in EnemyQueryScript.candidates(get_tree(), global_position, HadimeMath.EVO_HOLE_MOVE_SEARCH + 1.0):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true:
			continue
		if global_position.distance_squared_to((e as Node2D).global_position) <= search2:
			cands.append((e as Node2D).global_position)
	var best: Vector2 = Vector2.INF
	var best_n: int = 0
	for p in cands:
		var n: int = 0
		for q in cands:
			if p.distance_squared_to(q) <= r2:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	return best


## Yarıçap içindeki yaratıkları merkeze doğru sabit ve yavaş kaydırır (yürüyüşlerine ek). Bosslar çekilmez; orman/uçurum
## karosuna girecekse o karede kaydırılmaz. drag: deliğin bu karedeki yer değiştirmesi (Gezgin Delik - içindekiler de aynı
## kadar sürüklenir).
func _pull(delta: float, drag: Vector2) -> void:
	var c: Vector2 = global_position
	var r: float = radius()
	var r2: float = r * r
	for e in EnemyQueryScript.candidates(get_tree(), c - drag, r + 1.0):
		if not is_instance_valid(e) or not (e is Node2D) or e.get("is_dead") == true or e.get("is_boss") == true:
			continue
		var ep: Vector2 = (e as Node2D).global_position + drag
		var to_c: Vector2 = c - ep
		var d2: float = to_c.length_squared()
		if d2 > r2:
			continue
		var d: float = sqrt(d2)
		var np: Vector2 = ep
		if d > HadimeMath.HOLE_PULL_DEADZONE:
			np = ep + to_c / d * minf(HadimeMath.HOLE_PULL_SPEED * delta, d - HadimeMath.HOLE_PULL_DEADZONE)
		if GameManager.is_position_blocked_by_walls(np):
			continue
		(e as Node2D).global_position = np
