extends Node2D

## YETENEK EVRİMİ DÜNYA ALANLARI (2026-09-28) - dünyada bir süre duran evrim etkileri. enchant_area.gd ile AYNI desen: TEK
## script hem yetkili kopya (authoritative = true: kasterin makinesi - hasar/yavaşlatma burada, istemcide take_damage/apply_*
## zaten host'a gider) hem diğer oyunculardaki görsel kopya (authoritative = false: aynı çizim, hasar YOK) için. spawn()
## yetkili kopyayı NetworkManager.broadcast_evo_area ile yayınlar, uzakta AYNI spawn() authoritative=false ile çağrılır
## (bkz. CLAUDE.md "iki ayrı yer" hata sınıfı). Görseller sprite sayfası (tools/gen_evolution_fx.py).
## Türler:
##  "korsan_fire" - Korsan "Cehennem Ateşi" (Q finali): patlayan bombanın yerinde 4 sn yanan zemin; içindeki yaratıklar her
##                  saniye yanar (enemy.gd apply_burn - saldırı gücünün %20'si/sn). p: radius, duration, dps, peer.
##  "korsan_mine" - Korsan "Mayın Saçan" (E finali): patlamanın çevresine saçılan mayın; üstüne basan yaratık saldırı
##                  gücünün %30'u hasar alır ve %30 yavaşlar, mayın patlar (yetkili kopya broadcast_evo_area_end ile uzak
##                  kopyaları da patlatır). p: dmg, slow, duration, peer, id.
## Assasin Çocuk (2026-09-30) - hasar veren türlerde isabet, kasterin oyuncusuna (source, sadece yetkili kopyada) geri döner:
## player.gd evo_area_hit (yetenek kritik zarı + "Av Zinciri" bayrağı + isabet kıvılcımı). source yoksa düz take_damage.
##  "assasin_clone" - "Gölge Kopyası" (E finali): Gölge Adımı'nın başladığı yerde duran koyu mor kopya - karakterin KENDİ
##                  SpriteFrames'i (p.frames yolu, iki tarafta aynı kaynak) + ayağında gölge girdabı. Hasar YOK. Işınlanınca /
##                  görünmezlik bitince kaster _pop + broadcast_evo_area_end (duman pufu). p: frames, anim, flip, scale, offset,
##                  rel (sprite'ın düğüme göre dünya ofseti), ground (ayak ofseti), tint, duration (güvenlik), peer, id.
##  "assasin_kunai" - "Kunai Yağmuru" (Q finali): hamle bitiminde 6 kunai yıldız gibi açılır; düz uçar (konum = yön x hız x
##                  süre - iki tarafta aynı formül), yaratıkları delip geçer (kunai başına yaratık başına 1 isabet), orman
##                  duvarında düşer. p: count, angle (ilk kunainin yönü), speed, range, dmg, hit_radius, peer.
##  "assasin_trail" - "Gölge İzi" (R finali): Gölge Hücumu'nun bir sıçrayışının yolunda (düğüm -> p.to) 1 sn kalan gölge
##                  şeridi; çizgiye p.width'ten yakın yaratık saldırı gücünün %80'i hasar alır - aynı yaratık tüm şeritlerden en
##                  sık p.hit_interval'de bir (üst üste binen şeritler katlanmasın). p: to, ground, duration, dmg, width,
##                  hit_interval, peer.
## Büyücü Kız (2026-10-04):
##  "buyucu_crater" - "Ateş ve Buz" (R finali): her meteorun düştüğü yerde kalan, içi kor çatlaklı yanan krater. Üstüne basan
##                  yaratık yanar: 3 sn boyunca saniyede saldırı gücünün %30'u (enemy.gd apply_burn - yenilenir, katlanmaz). Korsan
##                  ateşiyle aynı açılış/kapanış solması. p: radius, duration, dps, burn_time, peer.

const SELF_PATH := "res://scripts/evo_area.gd"
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const TEXEL := 1.212
const FIRE_FRAMES_PATH := "res://assets/fx/evolution/korsan_fire_frames.tres"
const MINE_FRAMES_PATH := "res://assets/fx/evolution/korsan_mine_frames.tres"
const MINE_POP_SCENE_PATH := "res://scenes/fx_evo_mine_pop.tscn"
## Ateş sayfasının (korsan_fire, 160x96 sanat px) zemin elipsinin yatay yarıçapı (sanat px) - görsel radius'a bununla ölçeklenir.
const FIRE_ART_RADIUS := 74.0
const FIRE_TICK := 1.0
const FIRE_BURN_TIME := 1.4
const FIRE_FADE := 0.4
## Mayın: üstüne basma mesafesi (dünya birimi), bırakıldıktan sonra kurulma süresi, yavaşlatma süresi.
const MINE_TRIGGER_RADIUS := 18.0
const MINE_ARM_TIME := 0.45
const MINE_SLOW_TIME := 2.5
const MINE_CHECK_INTERVAL := 0.1
## Sayfalarda zemin merkezinin karenin ortasına göre konumu (sanat pikseli).
const FIRE_GROUND_ART := Vector2(0.0, 8.0)
const MINE_GROUND_ART := Vector2(0.0, 2.0)
## Assasin
const CLONE_BASE_FRAMES_PATH := "res://assets/fx/evolution/assasin_clone_base_frames.tres"
const KUNAI_FRAMES_PATH := "res://assets/fx/evolution/kunai_frames.tres"
const TRAIL_FRAMES_PATH := "res://assets/fx/evolution/shadow_trail_frames.tres"
const SHADOW_PUFF_SCENE_PATH := "res://scenes/fx_evo_shadow_puff.tscn"
const CLONE_FADE_IN := 0.18
const KUNAI_FADE := 0.08 ## menzil sonunda / duvarda sönme
const TRAIL_CHECK_INTERVAL := 0.1
## Gölge şeridi karoları arası (dünya birimi) - karo sayfası 16 sanat px (~19 birim) genişliğinde, hafif üst üste biner.
const TRAIL_TILE_STEP := 13.0
## Büyücü krateri: sayfa (buyucu_crater - tools/gen_buyucu_evo_fx.py) kül halesinin yatay yarıçapı (sanat px) ve zemin merkezinin
## karenin ortasına göre yeri (sayfa merkezi = zemin merkezi) - görsel radius'a korsan ateşi gibi ölçeklenir. Basma kontrolü 2/sn.
const CRATER_FRAMES_PATH := "res://assets/fx/evolution/buyucu_crater_frames.tres"
const CRATER_ART_RADIUS := 44.0
const CRATER_GROUND_ART := Vector2.ZERO
const CRATER_TICK := 0.5

static var _by_id: Dictionary = {}
static var _next_local_id: int = 1
static var _frames_cache: Dictionary = {}
## "assasin_trail": yaratık instance id -> bir sonraki izinli isabet (ms). Statik: kasterin TÜM şeritleri paylaşır (yetkili
## kopya yalnız kasterin makinesinde çalışır, başka oyuncunun şeritleriyle karışmaz).
static var _trail_hit_until: Dictionary = {}

var kind: String = ""
var p: Dictionary = {}
var authoritative: bool = false
var area_id: int = 0
## Yetkili kopyada isabetleri işleyen kaster (player.gd evo_area_hit) - uzak kopyalarda null.
var source: Node = null
var _kunai: Array = [] ## "assasin_kunai": [{spr, dir, dist, hits, alive}]
## Gece ışığı (night_glow_catalog.gd BY_SCRIPT "cp"/"rp" ile okunur).
var glow_color: Color = Color(1.0, 0.55, 0.2)
var glow_radius: float = 40.0
## Gölge türleri (Assasin kopya / iz) gece parlamaz - night_glow_catalog.gd resolve bu bayrağa bakar (kan/duman kuralı).
var night_glow_off: bool = false

var _t: float = 0.0
var _tick: float = 0.0
var _sprite: AnimatedSprite2D = null
var _done: bool = false


static func _frames(path: String) -> SpriteFrames:
	if not _frames_cache.has(path):
		_frames_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _frames_cache[path]


static func spawn(tree: SceneTree, area_kind: String, pos: Vector2, params: Dictionary, is_authoritative: bool, src: Node = null) -> Node2D:
	if tree == null or tree.current_scene == null or area_kind == "":
		return null
	var prm: Dictionary = params.duplicate()
	if is_authoritative and not prm.has("id"):
		## Oyuncular arasında çakışmasın: peer x 100000 + yerel sayaç.
		prm["id"] = int(prm.get("peer", 0)) * 100000 + _next_local_id
		_next_local_id += 1
	var a: Node2D = (load(SELF_PATH) as GDScript).new()
	a.kind = area_kind
	a.p = prm
	a.authoritative = is_authoritative
	a.source = src if is_authoritative else null
	a.area_id = int(prm.get("id", 0))
	a.position = pos
	tree.current_scene.add_child(a)
	a.global_position = pos
	if a.area_id != 0:
		_by_id[a.area_id] = a
	if is_authoritative and NetworkManager.is_multiplayer_active:
		NetworkManager.broadcast_evo_area.rpc(area_kind, pos, prm)
	return a


## Yetkili kopya bitirdi (mayın patladı) - uzak kopyayı da aynı anda patlat (network_manager.gd broadcast_evo_area_end).
static func end_remote(id: int, pos: Vector2) -> void:
	var a: Variant = _by_id.get(id)
	_by_id.erase(id)
	if a == null or not is_instance_valid(a):
		return
	(a as Node2D).global_position = pos
	a.call("_pop")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	match kind:
		"korsan_fire":
			var r: float = float(p.get("radius", 80.0))
			_sprite.sprite_frames = _frames(FIRE_FRAMES_PATH)
			var s: float = r / (FIRE_ART_RADIUS * TEXEL)
			_sprite.scale = Vector2.ONE * TEXEL * s
			_sprite.offset = -FIRE_GROUND_ART
			glow_color = Color(1.0, 0.5, 0.18)
			glow_radius = r * 1.1
			modulate.a = 0.0
			_tick = 0.3
		"korsan_mine":
			_sprite.sprite_frames = _frames(MINE_FRAMES_PATH)
			_sprite.scale = Vector2.ONE * TEXEL
			_sprite.offset = -MINE_GROUND_ART
			glow_color = Color(1.0, 0.35, 0.25)
			glow_radius = 16.0
			_tick = MINE_ARM_TIME
		"assasin_clone":
			_setup_clone()
		"assasin_kunai":
			_setup_kunai()
		"assasin_trail":
			_setup_trail()
		"buyucu_crater":
			var cr: float = float(p.get("radius", 56.0))
			_sprite.sprite_frames = _frames(CRATER_FRAMES_PATH)
			_sprite.scale = Vector2.ONE * TEXEL * (cr / (CRATER_ART_RADIUS * TEXEL))
			_sprite.offset = -CRATER_GROUND_ART
			glow_color = Color(1.0, 0.45, 0.15)
			glow_radius = cr * 1.05
			modulate.a = 0.0
			_tick = 0.0 ## düştüğü an içindekiler de yanar
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"loop"):
		_sprite.play(&"loop")
	## Zemin efekti: yaratık/karakterlerin ALTINDA (kara delik / asit gölüyle aynı çözüm) - ekleme bitince. Ayakta duran
	## kopya ve havada uçan kunailer zemine değil, birimlerin arasına/üstüne çizilir.
	if kind != "assasin_clone" and kind != "assasin_kunai":
		_place_on_ground.call_deferred()


## ---------- Assasin kurulumları ----------
func _setup_clone() -> void:
	night_glow_off = true
	var ground: Vector2 = Vector2(p.get("ground", Vector2(0.0, 15.0)))
	## Ayağındaki gölge girdabı (_sprite, döngü) - gövdeden önce eklendi, altında kalır.
	_sprite.sprite_frames = _frames(CLONE_BASE_FRAMES_PATH)
	_sprite.scale = Vector2.ONE * TEXEL
	_sprite.position = ground
	var body := AnimatedSprite2D.new()
	body.name = "Body"
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fr_path: String = str(p.get("frames", ""))
	var fr: SpriteFrames = load(fr_path) as SpriteFrames if fr_path != "" and ResourceLoader.exists(fr_path) else null
	if fr != null:
		body.sprite_frames = fr
		var clip := StringName(str(p.get("anim", "")))
		if fr.has_animation(clip):
			body.play(clip)
	body.flip_h = bool(p.get("flip", false))
	## Kök sahnenin çocuğu (ölçeksiz) - kasterin sprite'ının DÜNYA ölçeği/ofseti birebir.
	body.scale = Vector2(p.get("scale", Vector2.ONE))
	body.offset = Vector2(p.get("offset", Vector2.ZERO))
	body.position = Vector2(p.get("rel", Vector2.ZERO))
	body.modulate = Color(p.get("tint", Color(0.24, 0.1, 0.4, 0.78)))
	add_child(body)
	modulate.a = 0.0


func _setup_kunai() -> void:
	z_index = 5 ## uçan bıçaklar yaratık/karakterlerin üstünde
	glow_color = Color(0.72, 0.55, 1.0)
	glow_radius = 16.0
	var fr: SpriteFrames = _frames(KUNAI_FRAMES_PATH)
	var count: int = maxi(1, int(p.get("count", 6)))
	var base_ang: float = float(p.get("angle", 0.0))
	for i in range(count):
		var ang: float = base_ang + TAU * float(i) / float(count)
		var spr := AnimatedSprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.sprite_frames = fr
		spr.scale = Vector2.ONE * TEXEL
		spr.rotation = ang ## sayfa +x'e (uca) bakar
		if fr != null and fr.has_animation(&"loop"):
			spr.play(&"loop")
		add_child(spr)
		_kunai.append({"spr": spr, "dir": Vector2(cos(ang), sin(ang)), "dist": 0.0, "hits": {}, "alive": true, "fade": 0.0})


func _setup_trail() -> void:
	night_glow_off = true
	var to_rel: Vector2 = Vector2(p.get("to", global_position)) - global_position
	var ground: Vector2 = Vector2(p.get("ground", Vector2(0.0, 15.0)))
	var fr: SpriteFrames = _frames(TRAIL_FRAMES_PATH)
	var length: float = to_rel.length()
	var n: int = maxi(1, int(ceil(length / TRAIL_TILE_STEP)))
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var tile := AnimatedSprite2D.new()
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tile.sprite_frames = fr
		tile.scale = Vector2.ONE * TEXEL
		tile.position = to_rel * t + ground
		tile.flip_h = i % 2 == 1 ## karolar birbirini tekrar etmesin (iki tarafta aynı - deterministik)
		if fr != null and fr.has_animation(&"play"):
			tile.play(&"play")
		add_child(tile)
	_tick = 0.0


func _place_on_ground() -> void:
	if is_inside_tree():
		EnemyAbilities.place_on_ground(get_tree(), self)


func _exit_tree() -> void:
	if area_id != 0 and _by_id.get(area_id) == self:
		_by_id.erase(area_id)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var duration: float = float(p.get("duration", 4.0))
	match kind:
		"korsan_fire":
			## Açılış/kapanış solması (sayfanın kendisi döngü).
			modulate.a = clampf(minf(_t / FIRE_FADE, (duration - _t) / FIRE_FADE), 0.0, 1.0)
			if authoritative:
				_tick -= delta
				if _tick <= 0.0:
					_tick += FIRE_TICK
					_fire_tick()
		"korsan_mine":
			if authoritative:
				_tick -= delta
				if _tick <= 0.0:
					_tick = MINE_CHECK_INTERVAL
					_mine_check()
			## Son saniye yanıp söner (süresi dolunca sessizce kaybolur).
			if duration - _t < 1.0:
				visible = int(_t * 10.0) % 2 == 0
		"assasin_clone":
			## Belirir, hafifçe nefes alır gibi titrer (gölge). Bitişi kaster verir (_pop); güvenlik süresinde sessizce söner.
			modulate.a = clampf(_t / CLONE_FADE_IN, 0.0, 1.0) * (0.86 + 0.14 * sin(_t * 5.0))
			if _t >= duration:
				_pop()
				return
		"assasin_kunai":
			_process_kunai(delta)
			return
		"assasin_trail":
			if authoritative:
				_tick -= delta
				if _tick <= 0.0:
					_tick += TRAIL_CHECK_INTERVAL
					_trail_check()
		"buyucu_crater":
			modulate.a = clampf(minf(_t / FIRE_FADE, (duration - _t) / FIRE_FADE), 0.0, 1.0)
			if authoritative:
				_tick -= delta
				if _tick <= 0.0:
					_tick += CRATER_TICK
					_crater_tick()
	if _t >= duration:
		_done = true
		queue_free()


## Kunailer: dist = hız x süre (iki tarafta aynı), duvarda / menzil sonunda kısa sönme. Hasar sadece yetkili kopyada.
func _process_kunai(delta: float) -> void:
	var speed: float = float(p.get("speed", 520.0))
	var max_range: float = float(p.get("range", 250.0))
	var any_left: bool = false
	for k in _kunai:
		var spr: AnimatedSprite2D = k["spr"]
		if not bool(k["alive"]):
			k["fade"] = float(k["fade"]) + delta
			spr.modulate.a = clampf(1.0 - float(k["fade"]) / KUNAI_FADE, 0.0, 1.0)
			if float(k["fade"]) < KUNAI_FADE:
				any_left = true
			continue
		any_left = true
		var prev_d: float = float(k["dist"])
		var d: float = minf(max_range, prev_d + speed * delta)
		k["dist"] = d
		spr.position = (k["dir"] as Vector2) * d
		var world: Vector2 = global_position + spr.position
		## Bu karede uçulan parça [önceki, şimdiki] süpürülür - düşük FPS'te büyük adımda yaratığın üstünden atlamasın.
		if authoritative:
			_kunai_sweep(k, global_position + (k["dir"] as Vector2) * prev_d, world)
		if d >= max_range or GameManager.is_position_blocked_by_forest(world):
			k["alive"] = false
	if not any_left:
		_done = true
		queue_free()


## Yetkili kopya: kunainin bu karede süpürdüğü parçaya hit_radius'tan yakın yaratıklar - kunai başına yaratık başına bir
## isabet (delip geçer).
func _kunai_sweep(k: Dictionary, a: Vector2, b: Vector2) -> void:
	var r: float = float(p.get("hit_radius", 16.0))
	var hits: Dictionary = k["hits"]
	for e in Enemy.get_enemies_near(get_tree(), (a + b) * 0.5, a.distance_to(b) * 0.5 + r):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var eid: int = e.get_instance_id()
		if hits.has(eid):
			continue
		var epos: Vector2 = (e as Node2D).global_position
		if epos.distance_to(Geometry2D.get_closest_point_to_segment(epos, a, b)) > r:
			continue
		hits[eid] = true
		_deal(e, float(p.get("dmg", 10.0)), k["dir"])


## Yetkili kopya: şerit çizgisine (düğüm -> p.to) width'ten yakın yaratıklar, paylaşılan yaratık başı bekleme süresiyle.
func _trail_check() -> void:
	var a: Vector2 = global_position
	var b: Vector2 = Vector2(p.get("to", a))
	var width: float = float(p.get("width", 18.0))
	var interval_ms: int = int(float(p.get("hit_interval", 0.5)) * 1000.0)
	var now: int = Time.get_ticks_msec()
	if _trail_hit_until.size() > 512:
		_trail_hit_until.clear()
	var mid: Vector2 = (a + b) * 0.5
	for e in Enemy.get_enemies_near(get_tree(), mid, a.distance_to(b) * 0.5 + width):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		var epos: Vector2 = (e as Node2D).global_position
		if epos.distance_to(Geometry2D.get_closest_point_to_segment(epos, a, b)) > width:
			continue
		var eid: int = e.get_instance_id()
		if now < int(_trail_hit_until.get(eid, 0)):
			continue
		_trail_hit_until[eid] = now + interval_ms
		_deal(e, float(p.get("dmg", 10.0)), Vector2.ZERO)


func _deal(e: Node, dmg: float, dir: Vector2) -> void:
	if is_instance_valid(source) and source.has_method("evo_area_hit"):
		source.evo_area_hit(e, dmg, kind, dir)
	elif e.has_method("take_damage"):
		e.take_damage(dmg, false, 0.0, true)


func _fire_tick() -> void:
	var r: float = float(p.get("radius", 80.0))
	var dps: float = float(p.get("dps", 5.0))
	for e in Enemy.get_enemies_near(get_tree(), global_position, r):
		if is_instance_valid(e) and e.get("is_dead") != true and e.has_method("apply_burn"):
			e.apply_burn(dps, FIRE_BURN_TIME)


## Büyücü krateri: içindeki her yaratık yanar (süre yenilenir; enemy.gd apply_burn tik hasarı en güçlüsünde kalır, katlanmaz).
func _crater_tick() -> void:
	var r: float = float(p.get("radius", 56.0))
	var dps: float = float(p.get("dps", 5.0))
	var burn_time: float = float(p.get("burn_time", 3.0))
	for e in Enemy.get_enemies_near(get_tree(), global_position, r):
		if not is_instance_valid(e) or e.get("is_dead") == true or not e.has_method("apply_burn"):
			continue
		if global_position.distance_to((e as Node2D).global_position) > r:
			continue
		e.apply_burn(dps, burn_time)


func _mine_check() -> void:
	for e in Enemy.get_enemies_near(get_tree(), global_position, MINE_TRIGGER_RADIUS):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if e.has_method("take_damage"):
			e.take_damage(float(p.get("dmg", 10.0)), false, 0.0, false)
		if e.has_method("apply_slow"):
			e.apply_slow(float(p.get("slow", 0.3)), MINE_SLOW_TIME)
		if NetworkManager.is_multiplayer_active and area_id != 0:
			NetworkManager.broadcast_evo_area_end.rpc(area_id, global_position)
		_pop()
		return


## Mayın patlaması / gölge kopyasının sönmesi (yetkili kopyada tetiklenince, uzakta end_remote'tan) - küçük efekt, düğüm silinir.
func _pop() -> void:
	if _done:
		return
	_done = true
	var pop_path: String = SHADOW_PUFF_SCENE_PATH if kind == "assasin_clone" else MINE_POP_SCENE_PATH
	if ResourceLoader.exists(pop_path) and get_tree() != null and get_tree().current_scene != null:
		var scene: PackedScene = load(pop_path) as PackedScene
		if scene:
			var fx: Node2D = scene.instantiate() as Node2D
			get_tree().current_scene.add_child(fx)
			fx.global_position = global_position
	queue_free()
