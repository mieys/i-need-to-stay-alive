extends Node2D

## ZEHİRLİ GONCA TOHUMU (madde 682; dünya efekti "gonca_seed", gonca_boss.gd throw_seed). Paketin "plant shot" sanatı (36x40, 3 kare döngü + 3 kare patlama).
##  1. UÇUŞ (data.flight sn): başlangıçtan data.to'ya kavis (tepe data.arc px), yerde gölgesi; bu sırada kimseye değmez.
##  2. DÜŞÜŞ: düştüğü yerde oyuncu varsa (HIT_RADIUS) ona hasar + zehir ("gonca_seed", player.gd) ve tohum patlar (filizlenmez).
##  3. YERDE (data.sprout sn): hafifçe nabız atar; üstüne basan oyuncu (CRUSH_RADIUS) tohumu EZER.
##  4. FİLİZLENME: süre dolunca yetkili örnek (host / tek oyunculu) tohumun yerinde bir Filiz doğurur (EnemySpawner.spawn_summon) - boss ölüyse ya da
##     Filiz tavanı doluysa tohum kurur (patlar). İstemci kopyası o anda kendini siler (Filiz normal yaratık doğuş RPC'siyle gelir).
## Patlama kararı host'ta: istemcilere data {"pop": sid} ile aynı türün ikinci bir yayını gider; istemcideki kopya kimliğiyle bulunup patlatılır.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const BossKit := preload("res://scripts/gonca_boss.gd")
const LOOP_TEX := preload("res://assets/fx/gonca/seed_loop.png")
const END_TEX := preload("res://assets/fx/gonca/seed_end.png")
const FRAMES := 3
const FPS := 10.0
const END_FPS := 14.0
const SPRITE_SCALE := 0.8 ## 200% sanat: Balkabağı büyüsüyle aynı piksel yoğunluğu
const HIT_RADIUS := 22.0
const CRUSH_RADIUS := 20.0
const SHADOW := Color(0.05, 0.08, 0.04, 0.32)

static var _live: Dictionary = {} ## sid -> WeakRef (istemcide patlama olayını bulmak için)

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
var _flight: float = 0.85
var _sprout: float = 1.6
var _arc: float = 70.0
var _sid: int = 0
var _t: float = 0.0
var _landed: bool = false
var _ended: bool = false
var _end_t: float = 0.0
var _height: float = 0.0
var _sprite: Sprite2D = null


func _ready() -> void:
	if data.has("pop"):
		pop_by_id(int(data["pop"]))
		queue_free()
		return
	_from = global_position
	_to = Vector2(data.get("to", global_position))
	_flight = maxf(float(data.get("flight", 0.85)), 0.05)
	_sprout = float(data.get("sprout", 1.6))
	_arc = float(data.get("arc", 70.0))
	_sid = int(data.get("sid", 0))
	z_index = 6
	_sprite = Sprite2D.new()
	_sprite.texture = LOOP_TEX
	_sprite.hframes = FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	add_child(_sprite)
	if _sid > 0:
		_live[_sid] = weakref(self)


static func pop_by_id(sid: int) -> void:
	var w: WeakRef = _live.get(sid) as WeakRef
	_live.erase(sid)
	if w == null:
		return
	var n: Object = w.get_ref()
	if n != null and is_instance_valid(n) and n.has_method("pop"):
		n.call("pop", false)


func _exit_tree() -> void:
	if _sid > 0 and _live.has(_sid) and (_live[_sid] as WeakRef).get_ref() == self:
		_live.erase(_sid)


func _physics_process(delta: float) -> void:
	if _ended:
		_end_t += delta
		var f: int = int(_end_t * END_FPS)
		if f >= FRAMES:
			queue_free()
			return
		_sprite.frame = f
		return
	_t += delta
	_sprite.frame = int(_t * FPS) % FRAMES
	if _t < _flight:
		var k: float = _t / _flight
		global_position = _from.lerp(_to, k)
		_height = 4.0 * _arc * k * (1.0 - k)
		var dh: float = 4.0 * _arc * (1.0 - 2.0 * k) / _flight ## yükseklik değişim hızı
		var vel: Vector2 = (_to - _from) / _flight - Vector2(0.0, dh)
		_sprite.position = Vector2(0.0, -_height)
		_sprite.rotation = vel.angle()
		queue_redraw()
		return
	if not _landed:
		_landed = true
		global_position = _to
		_height = 0.0
		_sprite.position = Vector2(0.0, -4.0)
		_sprite.rotation = 0.0 if (_to - _from).x >= 0.0 else PI
		queue_redraw()
		if authoritative and _hit_on_landing():
			return
	var pulse: float = 1.0 + 0.12 * sin((_t - _flight) * 14.0)
	_sprite.scale = Vector2.ONE * SPRITE_SCALE * pulse
	if authoritative and _crushed():
		pop(true)
		return
	if _t >= _flight + _sprout:
		if authoritative:
			if not _sprout_filiz():
				pop(true)
				return
		set_physics_process(false)
		queue_free()


func _hit_on_landing() -> bool:
	var hit: bool = false
	for p in AbilitiesScript.damageable_players(get_tree()):
		if (p as Node2D).global_position.distance_to(_to) <= HIT_RADIUS + AbilitiesScript.TARGET_BODY_RADIUS:
			AbilitiesScript.deal_special_damage(p, damage, source, "gonca_seed")
			hit = true
	if hit:
		pop(true)
	return hit


func _crushed() -> bool:
	for p in AbilitiesScript.damageable_players(get_tree()):
		if (p as Node2D).global_position.distance_to(_to) <= CRUSH_RADIUS:
			return true
	return false


## Filiz doğur (yetkili örnek). false = doğmadı (boss yok / tavan dolu / sahne yok) -> tohum kurur.
func _sprout_filiz() -> bool:
	if source == null or not is_instance_valid(source) or source.get("is_dead") == true:
		return false
	var kit: Variant = _boss_kit(source)
	if kit != null and BossKit.filiz_count(source) >= int(kit.filiz_cap()):
		return false
	var scene: Node = get_tree().current_scene
	var spawner: Node = scene.get_node_or_null("EnemySpawner") if scene != null else null
	if spawner == null or not spawner.has_method("spawn_summon"):
		return false
	return spawner.spawn_summon(BossKit.FILIZ_ID, _to, source) != null


static func _boss_kit(boss: Node) -> Variant:
	var ab: Variant = boss.get("_abilities")
	if ab == null:
		return null
	var kit: Variant = (ab as Object).get("_boss_kit")
	return kit if kit != null and (kit as Object).has_method("filiz_cap") else null


## Patla (yere değdi / ezildi / kurudu). broadcast: host istemcilere de bildirir.
func pop(broadcast: bool) -> void:
	if _ended:
		return
	_ended = true
	_end_t = 0.0
	_sprite.texture = END_TEX
	_sprite.hframes = FRAMES
	_sprite.frame = 0
	_sprite.scale = Vector2.ONE * SPRITE_SCALE
	_height = 0.0
	queue_redraw()
	if broadcast and authoritative and _sid > 0:
		AbilitiesScript._broadcast_world_fx("gonca_seed", global_position, {"pop": _sid})


func _draw() -> void:
	if _ended:
		return
	## Gölge: yükseldikçe küçülür ve solar (bantlı).
	var k: float = clampf(1.0 - _height / maxf(_arc, 1.0) * 0.5, 0.4, 1.0)
	var r: float = 7.0 * k
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.45))
	draw_colored_polygon(pts, Color(SHADOW, SHADOW.a * (0.5 if k < 0.7 else 1.0)))
