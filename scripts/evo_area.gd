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

static var _by_id: Dictionary = {}
static var _next_local_id: int = 1
static var _frames_cache: Dictionary = {}

var kind: String = ""
var p: Dictionary = {}
var authoritative: bool = false
var area_id: int = 0
## Gece ışığı (night_glow_catalog.gd BY_SCRIPT "cp"/"rp" ile okunur).
var glow_color: Color = Color(1.0, 0.55, 0.2)
var glow_radius: float = 40.0

var _t: float = 0.0
var _tick: float = 0.0
var _sprite: AnimatedSprite2D = null
var _done: bool = false


static func _frames(path: String) -> SpriteFrames:
	if not _frames_cache.has(path):
		_frames_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _frames_cache[path]


static func spawn(tree: SceneTree, area_kind: String, pos: Vector2, params: Dictionary, is_authoritative: bool) -> Node2D:
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
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"loop"):
		_sprite.play(&"loop")
	## Zemin efekti: yaratık/karakterlerin ALTINDA (kara delik / asit gölüyle aynı çözüm) - ekleme bitince.
	_place_on_ground.call_deferred()


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
	if _t >= duration:
		_done = true
		queue_free()


func _fire_tick() -> void:
	var r: float = float(p.get("radius", 80.0))
	var dps: float = float(p.get("dps", 5.0))
	for e in Enemy.get_enemies_near(get_tree(), global_position, r):
		if is_instance_valid(e) and e.get("is_dead") != true and e.has_method("apply_burn"):
			e.apply_burn(dps, FIRE_BURN_TIME)


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


## Mayın patlaması (yetkili kopyada tetiklenince, uzakta end_remote'tan) - küçük patlama efekti, düğüm silinir.
func _pop() -> void:
	if _done:
		return
	_done = true
	if ResourceLoader.exists(MINE_POP_SCENE_PATH) and get_tree() != null and get_tree().current_scene != null:
		var scene: PackedScene = load(MINE_POP_SCENE_PATH) as PackedScene
		if scene:
			var fx: Node2D = scene.instantiate() as Node2D
			get_tree().current_scene.add_child(fx)
			fx.global_position = global_position
	queue_free()
