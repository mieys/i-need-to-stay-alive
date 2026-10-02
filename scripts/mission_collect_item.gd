extends Area2D

## "Topla" görevi (bkz. world_event_manager.gd) objesi - "obje olarak temsili bir şey ekle"
## (kullanıcı isteği) için basit, prosedürel çizilmiş bir mücevher; yeni bir sanat eseri
## gerektirmiyor. fx_ring.gd gibi TAMAMEN kod içinde kurulur, .tscn YOK.
##
## AĞ MİMARİSİ (bkz. network_manager.gd world_event_item_collected notu): konumlar
## world_event_started'ın extra["items"]'inden HER istemcide (host dahil) yerel olarak
## kuruluyor - bu yüzden item_index'ler TÜM istemcilerde AYNI sırada aynı konumlara denk
## gelir. Sadece bu istemcinin KENDİ yerel oyuncusu ("player" grubu, uzak kuklalar DEĞİL -
## yoksa her istemci gördüğü HERHANGİ bir oyuncu/kukla temasında ayrı ayrı rapor ederdi)
## dokununca broadcast_world_event_item_collected çağrılır; host bunu dinleyip ilerlemeyi
## artırır, AYNI RPC'nin call_local'ı sayesinde TÜM istemciler (bu obje dahil) o index'i
## gizler.

const RADIUS := 14.0
const PICKUP_RADIUS := 30.0
const EventSfx := preload("res://scripts/event_sfx.gd")
## Kullanıcı bildirimi (2026-09-24): obje görünmüyordu / pixel art + spritesheet olmalı - eskiden her karede
## draw_colored_polygon ile yumuşak kenarlı bir elmas çiziliyordu. Artık tools/gen_collect_item_sprite.py'nin pişirdiği
## 6 karelik kristal döngüsü (1 sanat pikseli = PixelDraw.TEXEL, karakterlerle aynı yoğunluk).
const CrystalFrames := preload("res://assets/fx/mission_collect/crystal_frames.tres")
## Toplanınca oynayan parıltı (tools/gen_collect_item_sprite.py pickup_* - 40x40, kristal gövdesi karenin ortasında).
const PickupFrames := preload("res://assets/fx/mission_collect/pickup_frames.tres")
const TEXEL := 1.212 ## PixelDraw.TEXEL
var _sprite: AnimatedSprite2D = null
## GÜNDÜZ PARILTISI (kullanıcı isteği 2026-09-25: "eşyalar gündüzleri de gece olduğu gibi parıldasın"): gece ışığı
## (night_glow_catalog.gd, atmosphere_overlay.gd ışık haritası) tasarım gereği gündüz 0 kazançla çalışır. Gündüz aynı
## renkte (katalogdaki c) yumuşak, toplamalı (ADD) bir hale çizilir; hava karardıkça söner ve yerini gece ışığı alır
## (ikisi üst üste binip aşırı parlamasın). Hafifçe nabız atar.
const DAY_GLOW_COLOR := Color(0.45, 1.0, 0.9)
const DAY_GLOW_RADIUS := 38.0 ## dünya birimi - gece ışığının yarıçapıyla aynı (katalog "r")
const DAY_GLOW_ALPHA := 0.55
var _day_glow: Sprite2D = null
var _atmosphere: Node = null

var mission_id: int = 0
var item_index: int = 0
var _collected: bool = false
var _bob_time: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 ## oyuncu katmanı (bkz. player.tscn CollisionShape2D layer) - diğer objelerle çakışmasın
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = CrystalFrames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * TEXEL
	_sprite.offset = Vector2(0, -8) ## gölge (karenin altı) objenin konumuna otursun
	add_child(_sprite)
	_sprite.play("idle")
	_sprite.frame = randi() % 6 ## hepsi aynı anda parlamasın
	_day_glow = _make_day_glow()
	add_child(_day_glow)
	move_child(_day_glow, 0) ## kristalin arkasında
	_base_y = position.y
	set_process(true)


func _process(delta: float) -> void:
	## Kullanıcı isteği yok ama xp_orb/gold_drop'un AYNI "nefes alma" dilinde hafif bir
	## yukarı-aşağı sallanma - farkedilir/canlı dursun diye (bkz. xp_orb.gd PULSE_* notu).
	_bob_time += delta
	if _sprite:
		_sprite.position.y = round(sin(_bob_time * 2.2) * 2.0) * TEXEL ## tam texel adımlarıyla (pixel kalsın)
	if _day_glow:
		if _atmosphere == null or not is_instance_valid(_atmosphere):
			_atmosphere = get_tree().get_first_node_in_group("atmosphere")
		var dark: float = float(_atmosphere.call("get_darkness")) if _atmosphere != null and _atmosphere.has_method("get_darkness") else 0.0
		var pulse: float = 0.85 + 0.15 * sin(_bob_time * 2.2)
		_day_glow.modulate.a = DAY_GLOW_ALPHA * pulse * clampf(1.0 - dark * 1.6, 0.0, 1.0)
	## DÜZELTME (kullanıcı bildirimi 2026-09-24: "görevlerden çoğu çalışmıyor") - toplama SADECE
	## body_entered (fizik, collision_mask=2) ile algılanıyordu ama Player'ın collision_layer'ı 0 (bkz.
	## player.tscn), yani objeler HİÇ toplanamıyordu. Bayrak/Konvoy ile AYNI mesafe kontrolü; her istemci
	## sadece KENDİ yerel oyuncusuna bakar, sonuç yine RPC ile host'a gider.
	if not _collected:
		for p: Node in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p.get("is_dead") != true and (p as Node2D).global_position.distance_to(global_position) <= PICKUP_RADIUS:
				_on_body_entered(p)
				break


## PİKSEL HALE (kullanıcı bildirimi 2026-09-27: "parıltıların pixel parıltı olması gerekiyor"): eskiden yumuşak bir
## GradientTexture2D idi. Artık 1 doku pikseli = 1 sanat pikseli (TEXEL), güç DAY_GLOW_STEP'lik düz bantlara bölünür,
## bant sınırları 4x4 Bayer dither'lı - gece ışığıyla aynı dil (atmosphere_grade.gdshader pixel_light).
const DAY_GLOW_STEP := 0.2
const DAY_GLOW_DITHER := 0.4
const BAYER4: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
static var _day_glow_tex: ImageTexture = null


static func _make_day_glow_texture() -> ImageTexture:
	if _day_glow_tex != null:
		return _day_glow_tex
	var r_tex: int = int(round(DAY_GLOW_RADIUS / TEXEL))
	var size: int = r_tex * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x) + 0.5 - r_tex, float(y) + 0.5 - r_tex).length() / float(r_tex)
			## Eski gradyanla aynı profil: merkez 1, d=0.35'te 0.45, kenarda 0.
			var a: float = lerpf(1.0, 0.45, d / 0.35) if d < 0.35 else lerpf(0.45, 0.0, clampf((d - 0.35) / 0.65, 0.0, 1.0))
			var v: float = a / DAY_GLOW_STEP
			var t: float = clampf((fposmod(v, 1.0) - 0.5) / DAY_GLOW_DITHER + 0.5, 0.0, 1.0)
			var threshold: float = (float(BAYER4[(y % 4) * 4 + (x % 4)]) + 0.5) / 16.0
			var q: float = (floorf(v) + (1.0 if t > threshold else 0.0)) * DAY_GLOW_STEP
			img.set_pixel(x, y, Color(DAY_GLOW_COLOR, clampf(q, 0.0, 1.0)))
	_day_glow_tex = ImageTexture.create_from_image(img)
	return _day_glow_tex


func _make_day_glow() -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = _make_day_glow_texture()
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sp.material = mat
	sp.scale = Vector2.ONE * TEXEL
	sp.position = Vector2(0.0, -10.0) ## gece ışığının ofsetiyle aynı (katalog "o")
	return sp


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group("player"):
		return
	_collected = true
	## Sadece toplayan oyuncunun ekranında (bu fonksiyon yalnız yerel oyuncu için çağrılır; diğerleri mark_collected alır).
	EventSfx.play(get_tree(), &"crystal_collect")
	NetworkManager.broadcast_world_event_item_collected.rpc(mission_id, item_index)
	_fade_out()


## world_event_manager.gd'nin main.gd üzerinden çağırdığı, bu index toplanınca (kendi
## istemcimizde toplanmamış olsa bile - bkz. call_local) görsel kopyayı kaldırmak için.
func mark_collected() -> void:
	_collected = true
	_fade_out()


## Toplanan obje (kendimiz topladıysak da, başkası topladıysa da) kısa bir solmayla sahneden SİLİNİR - eskiden kendi
## topladığımız obje sadece gizlenip görev bitene kadar görünmez olarak sahnede kalıyordu.
var _fading: bool = false

## GÜNCELLEME (kullanıcı isteği 2026-09-24: "topladığımız şey saydamlaşarak yok olmak yerine toplama efektine benzer bir
## parıltı falan olsun") - saydamlaşma yerine kristal beyaz parlayıp 4 kollu yıldıza ve yukarı süzülen parıltılara
## dönüşür (pixel spritesheet, tek seferlik 0.5 sn), bitince obje silinir. Hem kendi toplamamızda hem başka oyuncu
## toplayınca (mark_collected) aynı efekt - herkes aynı şeyi görür.
func _fade_out() -> void:
	if _fading:
		return
	_fading = true
	set_process(false)
	if _sprite:
		_sprite.visible = false
	if _day_glow:
		_day_glow.visible = false
	var burst := AnimatedSprite2D.new()
	burst.sprite_frames = PickupFrames
	burst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	burst.scale = Vector2.ONE * TEXEL
	## Kristal gövdesinin ortası: kristal karesinde merkezin ~2 sanat pikseli üstü + kristalin offset'i (-8) -> -10.
	burst.offset = Vector2(0, -10)
	burst.z_index = 5
	add_child(burst)
	burst.play("pickup")
	burst.animation_finished.connect(queue_free)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(self):
			queue_free())
