extends Node2D

## İskelet kemiği (madde 368, bkz. enemy_abilities.gd _process_bone; kullanıcı: "K1-K2'ye ... kemik atan iskelet"): düz çizgide dönerek uçan küçük
## kemik; ilk değdiği oyuncuya iskeletin temas hasarının bir kısmını verir. Orman duvarına, Şovalye kalkanına, Talon çemberine ve satıcı bölgesine
## çarpınca kırılır. enemy_fireball.gd ile AYNI yapı: yetkili (host/tek oyunculu) örnek hasar verir, istemcideki görsel kopya sadece uçar.
## Sanat: doku kodla çizilir (bkz. build_image, 14x8 piksel, koyu kontür) - dosya yok, ısınma listesi gerekmez.

const TEXEL := 1.212 ## ateş topu ve diğer yaratık yetenek efektleriyle aynı piksel yoğunluğu
const PaladinDome := preload("res://scripts/paladin_dome.gd")
const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")
const ProjectileRangeScript := preload("res://scripts/projectile_range.gd")
const LIFETIME := 1.8
const HIT_RADIUS := 6.0
const WALL_IGNORE_TIME := 0.08
const SPIN_SPEED := 11.0 ## rad/sn
const POOF_TIME := 0.18

const CREAM := Color8(236, 226, 198)
const LIGHT := Color8(255, 250, 232)
const DARK := Color8(46, 34, 26)

static var _tex: Texture2D = null

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _speed: float = 190.0
var _life: float = 0.0
var _poof: float = -1.0
var _sprite: Sprite2D = null


## Kemik dokusu: iki ucu çentikli kalın uçlar + ince gövde, krem dolgu, üst gövde satırı parlak, 1 px koyu kontür.
static func build_image() -> Image:
	var w: int = 14
	var h: int = 8
	var fill: Array = []
	for y in range(h):
		fill.append([])
		for x in range(w):
			fill[y].append(0)
	for x in range(2, 12): ## gövde
		fill[3][x] = 2 if x % 2 == 0 else 1
		fill[4][x] = 1
	for ex: int in [0, 11]: ## uçlar: 3 geniş, ortasında çentik
		for y in range(1, 7):
			for x in range(ex, ex + 3):
				if y >= 3 and y <= 4 and x == (ex if ex == 0 else ex + 2):
					continue ## dış çentik
				fill[y][x] = 1
	var img := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		for x in range(w):
			if int(fill[y][x]) == 0:
				continue
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or int(fill[ny][nx]) == 0:
					img.set_pixel(x + 1 + d.x, y + 1 + d.y, DARK)
	for y in range(h):
		for x in range(w):
			var v: int = int(fill[y][x])
			if v != 0:
				img.set_pixel(x + 1, y + 1, LIGHT if v == 2 else CREAM)
	return img


static func texture() -> Texture2D:
	if _tex == null:
		_tex = ImageTexture.create_from_image(build_image())
	return _tex


func _ready() -> void:
	z_index = 11
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_speed = float(data.get("speed", 190.0))
	_sprite = Sprite2D.new()
	_sprite.texture = texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * TEXEL
	add_child(_sprite)
	rotation = randf() * TAU


func _physics_process(delta: float) -> void:
	if _poof >= 0.0:
		_poof += delta
		if _poof >= POOF_TIME:
			queue_free()
		else:
			queue_redraw()
		return
	_life += delta
	if _life >= LIFETIME:
		queue_free()
		return
	if not ProjectileRangeScript.within(self):
		queue_free()
		return
	global_position += _dir * _speed * delta
	rotation += SPIN_SPEED * delta
	if _life >= WALL_IGNORE_TIME and GameManager.is_position_blocked_by_forest(global_position):
		_break()
		return
	if GameManager.merchant_zone_active and global_position.distance_to(GameManager.merchant_zone_pos) <= GameManager.MERCHANT_ZONE_RADIUS:
		_break()
		return
	for p in AbilitiesScript.damageable_players(get_tree()):
		var pn := p as Node2D
		if PaladinDome.node_contains(pn, global_position):
			_break()
			return
		## Talon "Kalkan Çemberi" evrimi: salvo çemberine değen yaratık atışı söner (ateş topuyla aynı kural).
		if pn.has_method("get_talon_ward_radius"):
			var ward_r: float = float(pn.call("get_talon_ward_radius"))
			if ward_r > 0.0 and global_position.distance_to(pn.global_position) <= ward_r:
				_break()
				return
		if global_position.distance_to(pn.global_position) <= HIT_RADIUS + AbilitiesScript.TARGET_BODY_RADIUS:
			if authoritative:
				AbilitiesScript.deal_special_damage(p, damage, source, "bone")
			_break()
			return


## Kırılma: kemik kaybolur, 5 krem kırıntı dışa saçılıp söner.
func _break() -> void:
	_poof = 0.0
	if _sprite:
		_sprite.visible = false
	rotation = 0.0
	queue_redraw()


func _draw() -> void:
	if _poof < 0.0:
		return
	var t: float = clampf(_poof / POOF_TIME, 0.0, 1.0)
	var col := Color(CREAM, 1.0 - t)
	for i in range(5):
		var a: float = float(i) / 5.0 * TAU + 0.4
		var r: float = 3.0 + 9.0 * t
		draw_rect(Rect2(Vector2.from_angle(a) * r - Vector2(1, 1), Vector2(2, 2)), col)
